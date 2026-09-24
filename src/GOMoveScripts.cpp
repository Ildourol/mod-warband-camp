/*
 * Warband Camp — Native 3D Construction & Housing Module
 * Camp Builder & GameObject Manipulation Engine
 *
 * Normal players operate in Camp Builder Mode on camp-owned objects.
 * Game Masters retain unrestricted Admin Mode on world objects.
 */

#include "GOMove.h"
#include "WarbandCamp.h"
#include <cmath>
#include <string>
#include "AllGameObjectScript.h"
#include "Chat.h"
#include "ChatCommand.h"
#include "CommandScript.h"
#include "GameObject.h"
#include "MapMgr.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Position.h"
#include "ScriptMgr.h"
#include "SpellScript.h"
#include "WorldSession.h"

using namespace Acore::ChatCommands;

// ---------------------------------------------------------------------------
// Permission & Mode helper
// ---------------------------------------------------------------------------

enum class GOMoveMode
{
    None,
    Admin,
    CampBuilder
};

static GOMoveMode GetGOMoveMode(ChatHandler* handler, Player* player, bool sendErrors = true)
{
    if (!player || !player->GetSession())
        return GOMoveMode::None;

    if (player->GetSession()->GetSecurity() >= SEC_GAMEMASTER)
        return GOMoveMode::Admin;

    if (!WarbandCamp::IsCampEnabled() || !WarbandCamp::IsGOMoveBuildingEnabled())
    {
        if (sendErrors)
            handler->SendErrorMessage("Camp building tools are disabled on this realm.");
        return GOMoveMode::None;
    }

    uint32 const accountId = player->GetSession()->GetAccountId();
    if (!WarbandCamp::HasCamp(accountId))
    {
        if (sendErrors)
            handler->SendErrorMessage("You do not have a Warband Camp. Establish one first with .camp claim.");
        return GOMoveMode::None;
    }

    if (!WarbandCamp::IsPlayerInCamp(player))
    {
        if (sendErrors)
            handler->SendErrorMessage("You must be standing in your Warband Camp to use building tools.");
        return GOMoveMode::None;
    }

    return GOMoveMode::CampBuilder;
}

// ---------------------------------------------------------------------------
// Command script
// ---------------------------------------------------------------------------

class GOMove_commandscript : public CommandScript
{
public:
    GOMove_commandscript() : CommandScript("GOMove_commandscript") { }

    enum CommandIDs
    {
        // No-arg or player-position commands (ID < SPAWN)
        TEST          = 0,
        SELECTNEAR    = 1,
        DELET         = 2,
        X             = 3,
        Y             = 4,
        Z             = 5,
        O             = 6,
        GROUND        = 7,
        FLOOR         = 8,
        RESPAWN       = 9,
        GOTO          = 10,
        FACE          = 11,

        // Commands requiring an ARG (ID >= SPAWN)
        SPAWN         = 12,
        NORTH         = 13,
        EAST          = 14,
        SOUTH         = 15,
        WEST          = 16,
        NORTHEAST     = 17,
        NORTHWEST     = 18,
        SOUTHEAST     = 19,
        SOUTHWEST     = 20,
        UP            = 21,
        DOWN          = 22,
        LEFT          = 23,
        RIGHT         = 24,
        PHASE         = 25,
        SCALE         = 26,
        SELECTALLNEAR = 27,
        SPAWNSPELL    = 28,
    };

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable GOMoveCommandTable =
        {
            { "gomove",       HandleGOMoveCommand,       SEC_PLAYER, Console::No },
            { "gomovesearch", HandleGOMoveSearchCommand, SEC_PLAYER, Console::No },
        };
        return GOMoveCommandTable;
    }

    static bool HandleGOMoveSearchCommand(ChatHandler* handler, Tail searchString)
    {
        if (searchString.empty())
        {
            handler->SendErrorMessage("Usage: .gomovesearch <name or entry id>");
            return true;
        }

        WorldSession* session = handler->GetSession();
        if (!session)
            return false;

        Player* player = session->GetPlayer();
        if (GetGOMoveMode(handler, player) == GOMoveMode::None)
            return true;

        GOMove::SendSearchResults(player, std::string(searchString));
        return true;
    }

    static bool HandleGOMoveCommand(ChatHandler* handler, uint32 ID, Optional<uint32> cLowguid, Optional<uint32> ARG_t)
    {
        uint32 lowguid = cLowguid.value_or(0);
        uint32 ARG     = ARG_t.value_or(0);

        WorldSession* session = handler->GetSession();
        if (!session)
            return false;

        Player* player = session->GetPlayer();
        GOMoveMode const mode = GetGOMoveMode(handler, player);
        if (mode == GOMoveMode::None)
            return true;

        bool const isGM = (mode == GOMoveMode::Admin);

        // Ensure placement spell is learned
        if (!player->HasSpell(GOMOVE_SPELL_PLACE))
            player->learnSpell(GOMOVE_SPELL_PLACE, false);

        // Check if target object is a camp object
        WarbandCamp::CampObjectRecord campRecord;
        bool const isCampObj = (lowguid != 0 && WarbandCamp::GetCampObject(lowguid, campRecord));

        // For non-GM players, any object-targeting command MUST target an object belonging to their own camp
        if (!isGM && lowguid != 0)
        {
            if (!isCampObj || campRecord.accountId != player->GetSession()->GetAccountId())
            {
                handler->SendErrorMessage("You can only manipulate objects in your own Warband Camp.");
                return true;
            }
        }

        if (ID < SPAWN)
        {
            if (ID >= DELET && ID <= GOTO)
            {
                if (isCampObj)
                {
                    std::string err;
                    switch (ID)
                    {
                        case DELET:
                        {
                            if (!WarbandCamp::DeleteCampObject(player, lowguid, err))
                                handler->SendErrorMessage("{}", err);
                            else
                                handler->PSendSysMessage("Camp object packed away.");
                        } break;
                        case X:
                        {
                            if (!WarbandCamp::MoveCampObject(player, lowguid, player->GetPositionX(), campRecord.y, campRecord.z, campRecord.orientation, err))
                                handler->SendErrorMessage("{}", err);
                        } break;
                        case Y:
                        {
                            if (!WarbandCamp::MoveCampObject(player, lowguid, campRecord.x, player->GetPositionY(), campRecord.z, campRecord.orientation, err))
                                handler->SendErrorMessage("{}", err);
                        } break;
                        case Z:
                        {
                            if (!WarbandCamp::MoveCampObject(player, lowguid, campRecord.x, campRecord.y, player->GetPositionZ(), campRecord.orientation, err))
                                handler->SendErrorMessage("{}", err);
                        } break;
                        case O:
                        {
                            if (!WarbandCamp::MoveCampObject(player, lowguid, campRecord.x, campRecord.y, campRecord.z, player->GetOrientation(), err))
                                handler->SendErrorMessage("{}", err);
                        } break;
                        case RESPAWN:
                        {
                            uint64 const newId = WarbandCamp::PlaceCampObject(player, campRecord.entry, player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(), player->GetOrientation(), campRecord.scale, err);
                            if (!newId)
                                handler->SendErrorMessage("{}", err);
                            else
                                handler->PSendSysMessage("Camp object duplicated.");
                        } break;
                        case GOTO:
                        {
                            if (player->IsInFlight())
                                player->CleanupAfterTaxiFlight();
                            else
                                player->SaveRecallPosition();
                            player->TeleportTo(campRecord.map, campRecord.x, campRecord.y, campRecord.z, campRecord.orientation);
                        } break;
                        case GROUND:
                        {
                            float const ground = player->GetMap()->GetHeight(campRecord.phaseMask, campRecord.x, campRecord.y, MAX_HEIGHT);
                            if (ground != INVALID_HEIGHT)
                            {
                                if (!WarbandCamp::MoveCampObject(player, lowguid, campRecord.x, campRecord.y, ground, campRecord.orientation, err))
                                    handler->SendErrorMessage("{}", err);
                            }
                        } break;
                        case FLOOR:
                        {
                            float const floor = player->GetMap()->GetHeight(campRecord.phaseMask, campRecord.x, campRecord.y, campRecord.z);
                            if (floor != INVALID_HEIGHT)
                            {
                                if (!WarbandCamp::MoveCampObject(player, lowguid, campRecord.x, campRecord.y, floor, campRecord.orientation, err))
                                    handler->SendErrorMessage("{}", err);
                            }
                        } break;
                    }
                }
                else
                {
                    // Administrative GM mode on world GameObject
                    GameObject* target = GOMove::GetGameObject(player, lowguid);
                    if (!target)
                    {
                        ChatHandler(session).PSendSysMessage("Object GUID: {} not found.", lowguid);
                        return true;
                    }

                    float x, y, z, o;
                    target->GetPosition(x, y, z, o);
                    uint32 const p = target->GetPhaseMask();

                    switch (ID)
                    {
                        case DELET:
                        {
                            GOMove::DeleteGameObject(target);
                            GOMove::SendRemove(player, lowguid);
                        } break;
                        case X:       GOMove::MoveGameObject(player, player->GetPositionX(), y, z, o, p, lowguid); break;
                        case Y:       GOMove::MoveGameObject(player, x, player->GetPositionY(), z, o, p, lowguid); break;
                        case Z:       GOMove::MoveGameObject(player, x, y, player->GetPositionZ(), o, p, lowguid); break;
                        case O:       GOMove::MoveGameObject(player, x, y, z, player->GetOrientation(), p, lowguid); break;
                        case RESPAWN: GOMove::SpawnGameObject(player, x, y, z, o, p, target->GetEntry()); break;
                        case GOTO:
                        {
                            if (player->IsInFlight())
                                player->CleanupAfterTaxiFlight();
                            else
                                player->SaveRecallPosition();
                            player->TeleportTo(target->GetMapId(), x, y, z, o);
                        } break;
                        case GROUND:
                        {
                            float const ground = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, MAX_HEIGHT);
                            if (ground != INVALID_HEIGHT)
                                GOMove::MoveGameObject(player, x, y, ground, o, p, lowguid);
                        } break;
                        case FLOOR:
                        {
                            float const floor = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, z);
                            if (floor != INVALID_HEIGHT)
                                GOMove::MoveGameObject(player, x, y, floor, o, p, lowguid);
                        } break;
                    }
                }
            }
            else
            {
                switch (ID)
                {
                    case TEST:
                        session->SendAreaTriggerMessage("{}", player->GetName());
                        break;
                    case FACE:
                    {
                        float const piper2    = float(M_PI) / 2.0f;
                        float const multi     = player->GetOrientation() / piper2;
                        float const multi_int = std::floor(multi);
                        float const new_ori   = (multi - multi_int > 0.5f)
                            ? (multi_int + 1) * piper2
                            : multi_int * piper2;
                        player->SetFacingTo(new_ori);
                    } break;
                    case SELECTNEAR:
                    {
                        if (!isGM)
                        {
                            uint64 const propId = WarbandCamp::FindNearestCampObject(player, 25.0f);
                            if (!propId)
                                ChatHandler(session).PSendSysMessage("No camp objects found nearby.");
                            else
                            {
                                GOMove::SendAdd(player, propId);
                                session->SendAreaTriggerMessage("Selected camp object");
                            }
                        }
                        else
                        {
                            GameObject* object = handler->GetNearbyGameObject();
                            if (!object)
                                ChatHandler(session).PSendSysMessage("No objects found.");
                            else
                            {
                                uint64 const campPropId = WarbandCamp::GetCampObjectIdFromGameObject(object);
                                uint32 const sendId = campPropId ? uint32(campPropId) : object->GetSpawnId();
                                GOMove::SendAdd(player, sendId);
                                session->SendAreaTriggerMessage("Selected {}", object->GetName());
                            }
                        }
                    } break;
                }
            }
        }
        else if (ARG && ID >= SPAWN)
        {
            if (ID >= NORTH && ID <= SCALE)
            {
                if (isCampObj)
                {
                    float const d = static_cast<float>(ARG) / 100.0f;
                    std::string err;
                    switch (ID)
                    {
                        case NORTH:     WarbandCamp::MoveCampObject(player, lowguid, campRecord.x + d, campRecord.y,     campRecord.z,     campRecord.orientation, err); break;
                        case EAST:      WarbandCamp::MoveCampObject(player, lowguid, campRecord.x,     campRecord.y - d, campRecord.z,     campRecord.orientation, err); break;
                        case SOUTH:     WarbandCamp::MoveCampObject(player, lowguid, campRecord.x - d, campRecord.y,     campRecord.z,     campRecord.orientation, err); break;
                        case WEST:      WarbandCamp::MoveCampObject(player, lowguid, campRecord.x,     campRecord.y + d, campRecord.z,     campRecord.orientation, err); break;
                        case NORTHEAST: WarbandCamp::MoveCampObject(player, lowguid, campRecord.x + d, campRecord.y - d, campRecord.z,     campRecord.orientation, err); break;
                        case SOUTHEAST: WarbandCamp::MoveCampObject(player, lowguid, campRecord.x - d, campRecord.y - d, campRecord.z,     campRecord.orientation, err); break;
                        case SOUTHWEST: WarbandCamp::MoveCampObject(player, lowguid, campRecord.x - d, campRecord.y + d, campRecord.z,     campRecord.orientation, err); break;
                        case NORTHWEST: WarbandCamp::MoveCampObject(player, lowguid, campRecord.x + d, campRecord.y + d, campRecord.z,     campRecord.orientation, err); break;
                        case UP:        WarbandCamp::MoveCampObject(player, lowguid, campRecord.x,     campRecord.y,     campRecord.z + d, campRecord.orientation, err); break;
                        case DOWN:      WarbandCamp::MoveCampObject(player, lowguid, campRecord.x,     campRecord.y,     campRecord.z - d, campRecord.orientation, err); break;
                        case RIGHT:     WarbandCamp::MoveCampObject(player, lowguid, campRecord.x,     campRecord.y,     campRecord.z,     campRecord.orientation - d, err); break;
                        case LEFT:      WarbandCamp::MoveCampObject(player, lowguid, campRecord.x,     campRecord.y,     campRecord.z,     campRecord.orientation + d, err); break;
                        case SCALE:
                        {
                            float const s = static_cast<float>(ARG) / 100.0f;
                            if (s > 0.0f)
                                WarbandCamp::ScaleCampObject(player, lowguid, s, err);
                        } break;
                        case PHASE:
                        {
                            if (!isGM)
                            {
                                handler->SendErrorMessage("Camp objects inherit your camp phase mask automatically.");
                                return true;
                            }
                        } break;
                    }
                    if (!err.empty())
                        handler->SendErrorMessage("{}", err);
                }
                else
                {
                    // Administrative GM mode on world GameObject
                    GameObject* target = GOMove::GetGameObject(player, lowguid);
                    if (!target)
                    {
                        ChatHandler(session).PSendSysMessage("Object GUID: {} not found.", lowguid);
                        return true;
                    }

                    float x, y, z, o;
                    target->GetPosition(x, y, z, o);
                    uint32 const p = target->GetPhaseMask();
                    float const d  = static_cast<float>(ARG) / 100.0f;

                    switch (ID)
                    {
                        case NORTH:     GOMove::MoveGameObject(player, x + d, y,     z,     o, p, lowguid); break;
                        case EAST:      GOMove::MoveGameObject(player, x,     y - d, z,     o, p, lowguid); break;
                        case SOUTH:     GOMove::MoveGameObject(player, x - d, y,     z,     o, p, lowguid); break;
                        case WEST:      GOMove::MoveGameObject(player, x,     y + d, z,     o, p, lowguid); break;
                        case NORTHEAST: GOMove::MoveGameObject(player, x + d, y - d, z,     o, p, lowguid); break;
                        case SOUTHEAST: GOMove::MoveGameObject(player, x - d, y - d, z,     o, p, lowguid); break;
                        case SOUTHWEST: GOMove::MoveGameObject(player, x - d, y + d, z,     o, p, lowguid); break;
                        case NORTHWEST: GOMove::MoveGameObject(player, x + d, y + d, z,     o, p, lowguid); break;
                        case UP:        GOMove::MoveGameObject(player, x,     y,     z + d, o, p, lowguid); break;
                        case DOWN:      GOMove::MoveGameObject(player, x,     y,     z - d, o, p, lowguid); break;
                        case RIGHT:     GOMove::MoveGameObject(player, x,     y,     z, o - d, p, lowguid); break;
                        case LEFT:      GOMove::MoveGameObject(player, x,     y,     z, o + d, p, lowguid); break;
                        case PHASE:     GOMove::MoveGameObject(player, x, y, z, o, ARG, lowguid); break;
                        case SCALE:
                        {
                            float const s = static_cast<float>(ARG) / 100.0f;
                            if (s > 0.0f)
                                GOMove::ScaleGameObject(player, s, lowguid);
                        } break;
                    }
                }
            }
            else
            {
                switch (ID)
                {
                    case SPAWN:
                    {
                        if (!isGM)
                        {
                            std::string err;
                            uint64 const id = WarbandCamp::PlaceCampObject(player, ARG,
                                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(),
                                player->GetOrientation(), 1.0f, err);
                            if (!id)
                                handler->SendErrorMessage("{}", err);
                            else
                                handler->PSendSysMessage("Camp object placed.");
                        }
                        else
                        {
                            GOMove::SpawnGameObject(player,
                                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(),
                                player->GetOrientation(), player->GetPhaseMaskForSpawn(), ARG);
                        }
                    } break;
                    case SPAWNSPELL:
                    {
                        if (!isGM)
                        {
                            std::string err;
                            if (!WarbandCamp::IsEntryAllowedForCamp(ARG, false, err))
                            {
                                handler->SendErrorMessage("{}", err);
                                return true;
                            }
                        }
                        if (!player->HasSpell(GOMOVE_SPELL_PLACE))
                            player->learnSpell(GOMOVE_SPELL_PLACE, false);
                        GOMove::Store.SpawnQueAdd(player->GetGUID(), ARG);
                    } break;
                    case SELECTALLNEAR:
                    {
                        if (!isGM)
                        {
                            std::vector<uint64> const ids = WarbandCamp::FindNearbyCampObjects(player, static_cast<float>(ARG));
                            for (uint64 const propId : ids)
                                GOMove::SendAdd(player, propId);
                            handler->PSendSysMessage("Selected {} camp object(s).", ids.size());
                        }
                        else
                        {
                            for (GameObject const* go : GOMove::GetNearbyGameObjects(player, static_cast<float>(ARG)))
                            {
                                uint64 const campPropId = WarbandCamp::GetCampObjectIdFromGameObject(go);
                                uint32 const sendId = campPropId ? uint32(campPropId) : go->GetSpawnId();
                                GOMove::SendAdd(player, sendId);
                            }
                        }
                    } break;
                }
            }
        }
        else
            return false;

        return true;
    }
};

// ---------------------------------------------------------------------------
// Spell script — placed on a ground-target spell (ScriptName: "spell_gomove_place")
// Assign to spell 27651 or 897 via spell_script_names table.
// ---------------------------------------------------------------------------

class spell_gomove_place : public SpellScript
{
    PrepareSpellScript(spell_gomove_place);

    void HandleAfterCast()
    {
        if (!GetCaster())
            return;
        Player* player = GetCaster()->ToPlayer();
        if (!player)
            return;

        WorldLocation const* summonPos = GetExplTargetDest();
        if (!summonPos)
            return;

        uint32 const entry = GOMove::Store.SpawnQueGet(player->GetGUID());
        if (!entry)
            return;

        bool const isGM = (player->GetSession()->GetSecurity() >= SEC_GAMEMASTER);

        if (isGM)
        {
            GOMove::SpawnGameObject(player,
                summonPos->GetPositionX(), summonPos->GetPositionY(), summonPos->GetPositionZ(),
                player->GetOrientation(), player->GetPhaseMaskForSpawn(), entry);
            return;
        }

        // Camp Builder Mode
        std::string err;
        uint64 const propId = WarbandCamp::PlaceCampObject(player, entry,
            summonPos->GetPositionX(), summonPos->GetPositionY(), summonPos->GetPositionZ(),
            player->GetOrientation(), 1.0f, err);

        if (!propId)
            ChatHandler(player->GetSession()).SendErrorMessage("{}", err);
        else
            ChatHandler(player->GetSession()).PSendSysMessage("Camp object placed.");
    }

    void Register() override
    {
        AfterCast += SpellCastFn(spell_gomove_place::HandleAfterCast);
    }
};

// ---------------------------------------------------------------------------
// GameObject script — applies per-instance scale override on world add
// ---------------------------------------------------------------------------

class GOMove_gameobject_script : public AllGameObjectScript
{
public:
    GOMove_gameobject_script() : AllGameObjectScript("GOMove_gameobject_script") { }

    void OnGameObjectAddWorld(GameObject* go) override
    {
        ObjectGuid::LowType const spawnId = go->GetSpawnId();
        if (!spawnId)
            return;

        float scale;
        if (GOMove::ScaleCache.Get(uint32(spawnId), scale))
            go->SetObjectScale(scale);
    }
};

class GOMove_world_script : public WorldScript
{
public:
    GOMove_world_script() : WorldScript("GOMove_world_script", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        GOMove::ScaleCache.Load();
    }
};

// ---------------------------------------------------------------------------
// Player script — clears spawn queue on logout, learns placement spell on login
// ---------------------------------------------------------------------------

class GOMove_player_track : public PlayerScript
{
public:
    GOMove_player_track() : PlayerScript("GOMove_player_track", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT }) { }

    void OnPlayerLogin(Player* player) override
    {
        bool const isGM = (player->GetSession()->GetSecurity() >= SEC_GAMEMASTER);
        bool const hasCamp = WarbandCamp::HasCamp(player->GetSession()->GetAccountId());

        if (isGM || (hasCamp && WarbandCamp::IsGOMoveBuildingEnabled()))
        {
            if (!player->HasSpell(GOMOVE_SPELL_PLACE))
            {
                player->learnSpell(GOMOVE_SPELL_PLACE, false);
                ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00[Warband Camp]|r Ground placement spell (ID: {}) learned.", GOMOVE_SPELL_PLACE);
            }
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        GOMove::Store.SpawnQueRem(player->GetGUID());
    }
};

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

void AddSC_GOMove_commandscript()
{
    new GOMove_commandscript();
    RegisterSpellScript(spell_gomove_place);
    new GOMove_player_track();
    new GOMove_gameobject_script();
    new GOMove_world_script();
}
