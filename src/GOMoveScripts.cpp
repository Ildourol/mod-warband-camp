/*
 * GOMove — AzerothCore port
 * Original by Rochet2 (TrinityCore 3.3.5)
 * Ported and adapted for AzerothCore
 *
 * Placement spell: assign ScriptName "spell_gomove_place" to a ground-target spell
 * (e.g. spell ID 27651 or 897) via the spell_script_names table or Spell.dbc ScriptName.
 * The SPAWNSPELL command queues a spawn without requiring the spell.
 */

#include "GOMove.h"
#include <cmath>
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
// Permission helper
// ---------------------------------------------------------------------------

// Minimum GM level required to use GOMove commands.
// Change this to match your server's security model (e.g. SEC_GAMEMASTER, SEC_MODERATOR).
static constexpr uint32 GOMOVE_MIN_SECURITY = SEC_GAMEMASTER;

static bool GOMoveHasPermission(ChatHandler* handler, Player* player)
{
    if (player->GetSession()->GetSecurity() >= GOMOVE_MIN_SECURITY)
        return true;

    handler->SendErrorMessage("You do not have permission to use GOMove commands.");
    return false;
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
        TEST         = 0,
        SELECTNEAR   = 1,
        DELET        = 2,
        X            = 3,
        Y            = 4,
        Z            = 5,
        O            = 6,
        GROUND       = 7,
        FLOOR        = 8,
        RESPAWN      = 9,
        GOTO         = 10,
        FACE         = 11,

        // Commands requiring an ARG (ID >= SPAWN)
        SPAWN        = 12,
        NORTH        = 13,
        EAST         = 14,
        SOUTH        = 15,
        WEST         = 16,
        NORTHEAST    = 17,
        NORTHWEST    = 18,
        SOUTHEAST    = 19,
        SOUTHWEST    = 20,
        UP           = 21,
        DOWN         = 22,
        LEFT         = 23,
        RIGHT        = 24,
        PHASE        = 25,
        SCALE        = 26,
        SELECTALLNEAR = 27,
        SPAWNSPELL   = 28,
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

        if (!GOMoveHasPermission(handler, player))
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

        // Ensure GM players have the placement spell learned
        if (player->GetSession()->GetSecurity() >= GOMOVE_MIN_SECURITY && !player->HasSpell(GOMOVE_SPELL_PLACE))
            player->learnSpell(GOMOVE_SPELL_PLACE, false);

        if (ID < SPAWN)
        {
            if (ID >= DELET && ID <= GOTO)
            {
                // Commands that need a target object
                GameObject* target = GOMove::GetGameObject(player, lowguid);
                if (!target)
                {
                    ChatHandler(session).PSendSysMessage("Object GUID: {} not found.", lowguid);
                    return true;
                }

                if (!GOMoveHasPermission(handler, player))
                    return true;

                float x, y, z, o;
                target->GetPosition(x, y, z, o);
                uint32 p = target->GetPhaseMask();

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
                    case RESPAWN:
                    {
                        GOMove::SpawnGameObject(player, x, y, z, o, p, target->GetEntry());
                    } break;
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
                        float ground = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, MAX_HEIGHT);
                        if (ground != INVALID_HEIGHT)
                            GOMove::MoveGameObject(player, x, y, ground, o, p, lowguid);
                    } break;
                    case FLOOR:
                    {
                        float floor = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, z);
                        if (floor != INVALID_HEIGHT)
                            GOMove::MoveGameObject(player, x, y, floor, o, p, lowguid);
                    } break;
                }
            }
            else
            {
                switch (ID)
                {
                    case TEST:
                        if (!GOMoveHasPermission(handler, player))
                            return true;
                        session->SendAreaTriggerMessage("{}", player->GetName());
                        break;
                    case FACE:
                    {
                        if (!GOMoveHasPermission(handler, player))
                            return true;
                        float const piper2   = float(M_PI) / 2.0f;
                        float const multi    = player->GetOrientation() / piper2;
                        float const multi_int = std::floor(multi);
                        float const new_ori  = (multi - multi_int > 0.5f)
                            ? (multi_int + 1) * piper2
                            : multi_int * piper2;
                        player->SetFacingTo(new_ori);
                    } break;
                    case SELECTNEAR:
                    {
                        if (!GOMoveHasPermission(handler, player))
                            return true;
                        GameObject* object = handler->GetNearbyGameObject();
                        if (!object)
                            ChatHandler(session).PSendSysMessage("No objects found");
                        else
                        {
                            GOMove::SendAdd(player, object->GetSpawnId());
                            session->SendAreaTriggerMessage("Selected {}", object->GetName());
                        }
                    } break;
                }
            }
        }
        else if (ARG && ID >= SPAWN)
        {
            if (ID >= NORTH && ID <= SCALE)
            {
                // Nudge/phase commands — need a target object
                GameObject* target = GOMove::GetGameObject(player, lowguid);
                if (!target)
                {
                    ChatHandler(session).PSendSysMessage("Object GUID: {} not found.", lowguid);
                    return true;
                }

                if (!GOMoveHasPermission(handler, player))
                    return true;

                float x, y, z, o;
                target->GetPosition(x, y, z, o);
                uint32 p = target->GetPhaseMask();
                float d  = static_cast<float>(ARG) / 100.0f;

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
                    case PHASE:
                    {
                        GOMove::MoveGameObject(player, x, y, z, o, ARG, lowguid);
                    } break;
                    case SCALE:
                    {
                        float s = static_cast<float>(ARG) / 100.0f;
                        if (s > 0.0f)
                            GOMove::ScaleGameObject(player, s, lowguid);
                    } break;
                }
            }
            else
            {
                switch (ID)
                {
                    case SPAWN:
                    {
                        if (!GOMoveHasPermission(handler, player))
                            return true;
                        GOMove::SpawnGameObject(player,
                            player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(),
                            player->GetOrientation(), player->GetPhaseMaskForSpawn(), ARG);
                    } break;
                    case SPAWNSPELL:
                    {
                        if (!GOMoveHasPermission(handler, player))
                            return true;
                        if (!player->HasSpell(GOMOVE_SPELL_PLACE))
                            player->learnSpell(GOMOVE_SPELL_PLACE, false);
                        GOMove::Store.SpawnQueAdd(player->GetGUID(), ARG);
                    } break;
                    case SELECTALLNEAR:
                    {
                        if (!GOMoveHasPermission(handler, player))
                            return true;
                        for (GameObject const* go : GOMove::GetNearbyGameObjects(player, static_cast<float>(ARG)))
                            GOMove::SendAdd(player, go->GetSpawnId());
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
        if (player->GetSession()->GetSecurity() < GOMOVE_MIN_SECURITY)
            return;
        WorldLocation const* summonPos = GetExplTargetDest();
        if (!summonPos)
            return;
        if (uint32 entry = GOMove::Store.SpawnQueGet(player->GetGUID()))
        {
            GOMove::SpawnGameObject(player,
                summonPos->GetPositionX(), summonPos->GetPositionY(), summonPos->GetPositionZ(),
                player->GetOrientation(), player->GetPhaseMaskForSpawn(), entry);
        }
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
        ObjectGuid::LowType spawnId = go->GetSpawnId();
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
    GOMove_world_script() : WorldScript("GOMove_world_script") { }

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
    GOMove_player_track() : PlayerScript("GOMove_player_track") { }

    void OnPlayerLogin(Player* player) override
    {
        if (player->GetSession()->GetSecurity() >= GOMOVE_MIN_SECURITY)
        {
            if (!player->HasSpell(GOMOVE_SPELL_PLACE))
            {
                player->learnSpell(GOMOVE_SPELL_PLACE, false);
                ChatHandler(player->GetSession()).PSendSysMessage("|cff00ff00[GOMove]|r Ground placement spell (ID: {}) learned.", GOMOVE_SPELL_PLACE);
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
