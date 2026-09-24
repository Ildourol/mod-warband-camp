/*
 * Warband Camp — Native 3D Construction & Housing Module
 * Header for Camp Object Services, 3D Building, and Permissions
 */

#ifndef WARBAND_CAMP_H
#define WARBAND_CAMP_H

#include "Define.h"
#include "ObjectGuid.h"
#include <string>
#include <vector>

class Player;
class GameObject;
class Map;

namespace WarbandCamp
{
    struct CampObjectRecord
    {
        uint64 id = 0;
        uint32 accountId = 0;
        uint32 spawnGuid = 0;
        uint32 entry = 0;
        uint32 map = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float orientation = 0.0f;
        float scale = 1.0f;
        uint32 phaseMask = 0;
        ObjectGuid liveGuid = ObjectGuid::Empty;
    };

    struct CampCreatureRecord
    {
        uint64 id = 0;
        uint32 accountId = 0;
        uint32 entry = 0;
        uint32 map = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
        float orientation = 0.0f;
        uint32 phaseMask = 0;
        ObjectGuid liveGuid = ObjectGuid::Empty;
    };

    // Configuration gates
    bool IsCampEnabled();
    bool IsBuildingEnabled();
    bool IsGOMoveBuildingEnabled();
    uint32 GetMaxProps();

    // Camp state queries
    bool HasCamp(uint32 accountId);
    bool IsPlayerInCamp(Player* player);
    bool IsPositionInCamp(Player* player, float x, float y);
    uint32 GetCampPhaseMask(uint32 accountId);
    uint32 GetCampPropCount(uint32 accountId);

    // Entry validation
    bool IsEntryAllowedForCamp(uint32 entry, bool isGM, std::string& outError);

    // Camp object lookups
    bool GetCampObject(uint32 accountId, uint64 propId, CampObjectRecord& outRecord);
    inline bool GetCampObject(uint64 propId, CampObjectRecord& outRecord)
    {
        return GetCampObject(0, propId, outRecord);
    }
    bool IsCampObjectOwnedByAccount(uint32 accountId, uint64 propId);
    uint64 FindNearestCampObject(Player* player, float maxDist = 20.0f);
    std::vector<uint64> FindNearbyCampObjects(Player* player, float range = 30.0f);
    GameObject* GetLiveCampGameObject(Player* player, uint64 propId);
    uint64 GetCampObjectIdFromGameObject(GameObject const* go);

    // Camp object mutations (authoritative pipeline)
    uint64 PlaceCampObject(Player* player, uint32 entry, float x, float y, float z, float o, float scale, std::string& outError);
    bool MoveCampObject(Player* player, uint64 propId, float x, float y, float z, float o, std::string& outError);
    bool ScaleCampObject(Player* player, uint64 propId, float scale, std::string& outError);
    bool DeleteCampObject(Player* player, uint64 propId, std::string& outError);

    // Lifecycle
    void DespawnCampProp(Map* map, uint64 propId);
}

#endif // WARBAND_CAMP_H
