/*
 * GOMove — AzerothCore port
 * Original by Rochet2 (TrinityCore 3.3.5)
 * Ported and adapted for AzerothCore
 */

#ifndef GOMOVE_H
#define GOMOVE_H

#include "Define.h"
#include "ObjectGuid.h"
#include <list>
#include <mutex>
#include <unordered_map>

constexpr uint32 GOMOVE_SPELL_PLACE = 27651;

class Player;
class GameObject;

class GameObjectStore
{
public:
    typedef std::mutex LockType;
    typedef std::lock_guard<LockType> WriteGuard;

    void SpawnQueAdd(ObjectGuid const& guid, uint32 entry);
    void SpawnQueRem(ObjectGuid const& guid);
    uint32 SpawnQueGet(ObjectGuid const& guid);

private:
    LockType _objectsToSpawnLock;
    std::unordered_map<ObjectGuid, uint32> objectsToSpawn;
};

class GOMoveScaleCache
{
public:
    void Load();
    void Set(uint32 spawnId, float scale);
    void Remove(uint32 spawnId);
    bool Get(uint32 spawnId, float& outScale) const;

private:
    mutable std::mutex _lock;
    std::unordered_map<uint32, float> _scales;
};

class GOMove
{
public:
    static GameObjectStore Store;
    static GOMoveScaleCache ScaleCache;

    static void SendAdd(Player* player, ObjectGuid::LowType lowguid);
    static void SendRemove(Player* player, ObjectGuid::LowType lowguid);
    static void SendAddonMessage(Player* player, const char* msg);

    static void DeleteGameObject(GameObject* object);
    static GameObject* GetGameObject(Player* player, ObjectGuid::LowType lowguid);
    static GameObject* SpawnGameObject(Player* player, float x, float y, float z, float o, uint32 p, uint32 entry);
    static GameObject* MoveGameObject(Player* player, float x, float y, float z, float o, uint32 p, ObjectGuid::LowType lowguid);
    static void ScaleGameObject(Player* player, float scale, ObjectGuid::LowType lowguid);
    static void SendSearchResults(Player* player, const std::string& search);
    static std::list<GameObject*> GetNearbyGameObjects(Player* player, float range);
};

#endif // GOMOVE_H
