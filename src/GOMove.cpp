/*
 * GOMove — AzerothCore port
 * Original by Rochet2 (TrinityCore 3.3.5)
 * Ported and adapted for AzerothCore
 */

#include "GOMove.h"
#include <cmath>
#include <string>
#include "Cell.h"
#include "Log.h"
#include "CellImpl.h"
#include "WorldDatabase.h"
#include "Chat.h"
#include "DBCStores.h"
#include "GameObject.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Language.h"
#include "MapMgr.h"
#include "Object.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"

GameObjectStore GOMove::Store;
GOMoveScaleCache GOMove::ScaleCache;

void GOMoveScaleCache::Load()
{
    std::lock_guard<std::mutex> guard(_lock);
    _scales.clear();
    QueryResult result = WorldDatabase.Query("SELECT guid, scale FROM gomove_scale");
    if (!result)
        return;
    do
    {
        Field* fields = result->Fetch();
        _scales[fields[0].Get<uint32>()] = fields[1].Get<float>();
    } while (result->NextRow());
    LOG_INFO("module", "[GOMove] Loaded {} scale overrides.", _scales.size());
}

void GOMoveScaleCache::Set(uint32 spawnId, float scale)
{
    std::lock_guard<std::mutex> guard(_lock);
    _scales[spawnId] = scale;
}

void GOMoveScaleCache::Remove(uint32 spawnId)
{
    std::lock_guard<std::mutex> guard(_lock);
    _scales.erase(spawnId);
}

bool GOMoveScaleCache::Get(uint32 spawnId, float& outScale) const
{
    std::lock_guard<std::mutex> guard(_lock);
    auto it = _scales.find(spawnId);
    if (it == _scales.end())
        return false;
    outScale = it->second;
    return true;
}

void GOMove::SendAddonMessage(Player* player, const char* msg)
{
    if (!player || !msg)
        return;

    char buf[256];
    snprintf(buf, 256, "GOMOVE\t%s", msg);

    WorldPacket data;
    ChatHandler::BuildChatPacket(data, CHAT_MSG_SYSTEM, LANG_ADDON,
        player->GetGUID(), player->GetGUID(), buf, 0);
    player->GetSession()->SendPacket(&data);
}

GameObject* GOMove::GetGameObject(Player* player, ObjectGuid::LowType lowguid)
{
    return ChatHandler(player->GetSession()).GetObjectFromPlayerMapByDbGuid(lowguid);
}

void GOMove::SendAdd(Player* player, ObjectGuid::LowType lowguid)
{
    GameObjectData const* data = sObjectMgr->GetGameObjectData(lowguid);
    if (!data)
        return;
    GameObjectTemplate const* temp = sObjectMgr->GetGameObjectTemplate(data->id);
    if (!temp)
        return;
    std::string name = temp->name;
    if (name.size() > 100)
        name = name.substr(0, 100);
    char msg[256];
    snprintf(msg, 256, "ADD|%u|%s|%u", lowguid, name.c_str(), data->id);
    SendAddonMessage(player, msg);
}

void GOMove::SendRemove(Player* player, ObjectGuid::LowType lowguid)
{
    char msg[256];
    snprintf(msg, 256, "REMOVE|%u||0", lowguid);
    SendAddonMessage(player, msg);
}

void GOMove::DeleteGameObject(GameObject* object)
{
    if (!object)
        return;

    ObjectGuid::LowType spawnId = object->GetSpawnId();

    if (ObjectGuid ownerGuid = object->GetOwnerGUID())
    {
        Unit* owner = ObjectAccessor::GetUnit(*object, ownerGuid);
        if (owner && ownerGuid.IsPlayer())
            owner->RemoveGameObject(object, false);
    }

    object->DeleteFromDB();
    object->SetRespawnTime(0);
    object->Delete();

    // Clean up per-instance scale override
    WorldDatabase.Execute("DELETE FROM gomove_scale WHERE guid = {}", spawnId);
    ScaleCache.Remove(uint32(spawnId));
}

GameObject* GOMove::SpawnGameObject(Player* player, float x, float y, float z, float o, uint32 p, uint32 entry)
{
    if (!player || !entry)
        return nullptr;

    if (!MapMgr::IsValidMapCoord(player->GetMapId(), x, y, z))
        return nullptr;

    GameObjectTemplate const* objectInfo = sObjectMgr->GetGameObjectTemplate(entry);
    if (!objectInfo)
        return nullptr;

    if (objectInfo->displayId && !sGameObjectDisplayInfoStore.LookupEntry(objectInfo->displayId))
        return nullptr;

    Map* map = player->GetMap();

    GameObject* object = new GameObject();
    ObjectGuid::LowType guidLow = map->GenerateLowGuid<HighGuid::GameObject>();

    if (!object->Create(guidLow, objectInfo->entry, map, p, x, y, z, o, G3D::Quat(), 0, GO_STATE_READY))
    {
        delete object;
        return nullptr;
    }

    object->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), p);
    guidLow = object->GetSpawnId();

    delete object;

    object = new GameObject();
    if (!object->LoadGameObjectFromDB(guidLow, map, true))
    {
        delete object;
        return nullptr;
    }

    sObjectMgr->AddGameobjectToGrid(guidLow, sObjectMgr->GetGameObjectData(guidLow));

    SendAdd(player, guidLow);
    return object;
}

GameObject* GOMove::MoveGameObject(Player* player, float x, float y, float z, float o, uint32 p, ObjectGuid::LowType lowguid)
{
    if (!player)
        return nullptr;

    GameObject* object = ChatHandler(player->GetSession()).GetObjectFromPlayerMapByDbGuid(lowguid);
    if (!object)
    {
        SendRemove(player, lowguid);
        return nullptr;
    }

    if (!MapMgr::IsValidMapCoord(object->GetMapId(), x, y, z))
        return nullptr;

    Map* map = object->GetMap();

    object->Relocate(x, y, z, o);
    object->SetWorldRotationAngles(o, 0, 0);

    sObjectMgr->RemoveGameobjectFromGrid(lowguid, object->GetGameObjectData());
    object->SaveToDB();
    sObjectMgr->AddGameobjectToGrid(lowguid, sObjectMgr->GetGameObjectData(lowguid));

    // 3.3.5a client caches recently deleted objects; delete + reload forces a fresh CreateObject block
    object->Delete();

    object = new GameObject();
    if (!object->LoadGameObjectFromDB(lowguid, map, true))
    {
        delete object;
        SendRemove(player, lowguid);
        return nullptr;
    }

    // Apply phase change if requested (SetPhaseMask with true already calls SaveToDB)
    if (object->GetPhaseMask() != p)
        object->SetPhaseMask(p, true);

    return object;
}

void GameObjectStore::SpawnQueAdd(ObjectGuid const& guid, uint32 entry)
{
    WriteGuard lock(_objectsToSpawnLock);
    objectsToSpawn[guid] = entry;
}

void GameObjectStore::SpawnQueRem(ObjectGuid const& guid)
{
    WriteGuard lock(_objectsToSpawnLock);
    objectsToSpawn.erase(guid);
}

uint32 GameObjectStore::SpawnQueGet(ObjectGuid const& guid)
{
    WriteGuard lock(_objectsToSpawnLock);
    auto it = objectsToSpawn.find(guid);
    if (it != objectsToSpawn.end())
    {
        uint32 entry = it->second;
        objectsToSpawn.erase(it);
        return entry;
    }
    return 0;
}

void GOMove::ScaleGameObject(Player* player, float scale, ObjectGuid::LowType lowguid)
{
    if (!player || scale <= 0.0f)
        return;

    GameObject* object = ChatHandler(player->GetSession()).GetObjectFromPlayerMapByDbGuid(lowguid);
    if (!object)
    {
        SendRemove(player, lowguid);
        return;
    }

    Map* map = object->GetMap();

    // Persist per-instance scale override (OnGameObjectAddWorld hook applies it on reload)
    WorldDatabase.Execute("INSERT INTO gomove_scale (guid, scale) VALUES ({}, {}) "
        "ON DUPLICATE KEY UPDATE scale = {}", lowguid, scale, scale);
    ScaleCache.Set(uint32(lowguid), scale);

    // Delete and reload; OnGameObjectAddWorld hook will apply the per-instance scale
    object->Delete();

    object = new GameObject();
    if (!object->LoadGameObjectFromDB(lowguid, map, true))
    {
        delete object;
        SendRemove(player, lowguid);
        return;
    }
}

void GOMove::SendSearchResults(Player* player, const std::string& search)
{
    if (!player || search.empty())
        return;

    bool isNumeric = search.find_first_not_of("0123456789") == std::string::npos;

    QueryResult result;
    if (isNumeric)
    {
        uint32 entry = static_cast<uint32>(std::stoul(search));
        result = WorldDatabase.Query("SELECT entry, name, displayId FROM gameobject_template WHERE entry = {} LIMIT 1", entry);
    }
    else
    {
        std::string escaped = search;
        WorldDatabase.EscapeString(escaped);
        result = WorldDatabase.Query("SELECT entry, name, displayId FROM gameobject_template WHERE name LIKE '%{}%' LIMIT 500", escaped);
    }

    uint32 total = 0;
    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            uint32 entry      = fields[0].Get<uint32>();
            std::string name  = fields[1].Get<std::string>();
            uint32 displayId  = fields[2].Get<uint32>();

            // Resolve model path from DBC
            std::string modelPath;
            if (displayId)
                if (GameObjectDisplayInfoEntry const* info = sGameObjectDisplayInfoStore.LookupEntry(displayId))
                    if (info->filename)
                        modelPath = info->filename;

            // Truncate to keep message within packet limits
            if (name.size() > 50)
                name = name.substr(0, 50);
            if (modelPath.size() > 150)
                modelPath = modelPath.substr(0, 150);

            char msg[256];
            snprintf(msg, sizeof(msg), "GSRES|%u|%s|%s", entry, name.c_str(), modelPath.c_str());
            SendAddonMessage(player, msg);
            ++total;
        } while (result->NextRow());
    }

    char endMsg[64];
    snprintf(endMsg, sizeof(endMsg), "GSEND|%u", total);
    SendAddonMessage(player, endMsg);
}

std::list<GameObject*> GOMove::GetNearbyGameObjects(Player* player, float range)
{
    float x, y, z;
    player->GetPosition(x, y, z);

    std::list<GameObject*> objects;
    Acore::GameObjectInRangeCheck check(x, y, z, range);
    Acore::GameObjectListSearcher<Acore::GameObjectInRangeCheck> searcher(player, objects, check);
    Cell::VisitObjects(player, searcher, range);
    return objects;
}
