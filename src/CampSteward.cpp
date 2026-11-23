/*
 * Copyright (C) 2025+ WOW Legends / Standalone Port
 * Released under GNU AGPL v3 license.
 *
 * Warband Camp Steward service creature (Grenn Fastfuse)
 * Offers repairs, personal mailbox, cures resurrection sickness,
 * resets 5-man dungeon instances, and clears raid/heroic lockouts.
 */

#include "CampSteward.h"
#include "ScriptMgr.h"
#include "Chat.h"
#include "Configuration/Config.h"
#include "Creature.h"
#include "GameTime.h"
#include "Group.h"
#include "InstanceSaveMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "WorldSession.h"

#include <atomic>

namespace
{
    std::atomic<bool> g_repair{true};
    std::atomic<bool> g_mailbox{true};
    std::atomic<bool> g_sickness{true};
    std::atomic<bool> g_resetInstances{true};
    std::atomic<bool> g_clearLockouts{false};

    constexpr uint32 NPC_TEXT_STEWARD = 990103;
    constexpr uint32 SPELL_RESURRECTION_SICKNESS = 15007;

    enum StewardAction : uint32
    {
        ACT_REPAIR = 1,
        ACT_MAIL,
        ACT_SICKNESS,
        ACT_RESET,
        ACT_LOCKOUTS,
    };

    uint32 ClearLockouts(Player* p)
    {
        uint32 n = 0;
        for (uint8 i = 0; i < MAX_DIFFICULTY; ++i)
        {
            BoundInstancesMap const& binds = sInstanceSaveMgr->PlayerGetBoundInstances(p->GetGUID(), Difficulty(i));
            for (BoundInstancesMap::const_iterator itr = binds.begin(); itr != binds.end();)
            {
                if (itr->first != p->GetMapId())
                {
                    sInstanceSaveMgr->PlayerUnbindInstance(p->GetGUID(), itr->first, Difficulty(i), true, p);
                    itr = binds.begin();
                    ++n;
                }
                else
                    ++itr;
            }
        }
        return n;
    }
}

class npc_warband_camp_steward : public CreatureScript
{
public:
    npc_warband_camp_steward() : CreatureScript("npc_warband_camp_steward") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        ClearGossipMenuFor(player);
        if (g_repair.load())
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "I need my gear repaired.", GOSSIP_SENDER_MAIN, ACT_REPAIR);
        if (g_mailbox.load())
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Any mail for me?", GOSSIP_SENDER_MAIN, ACT_MAIL);
        if (g_sickness.load() && player->HasAura(SPELL_RESURRECTION_SICKNESS))
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Shake off this resurrection sickness.", GOSSIP_SENDER_MAIN, ACT_SICKNESS);
        if (g_resetInstances.load())
            AddGossipItemFor(player, GOSSIP_ICON_INTERACT_1, "Reset my dungeons.", GOSSIP_SENDER_MAIN, ACT_RESET,
                "Reset every dungeon you are saved to that nobody is inside?", 0, false);
        if (g_clearLockouts.load())
            AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Clear my raid and heroic lockouts.", GOSSIP_SENDER_MAIN, ACT_LOCKOUTS,
                "Clear ALL your raid and heroic lockouts? This cannot be undone.", 0, false);
        SendGossipMenuFor(player, NPC_TEXT_STEWARD, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        ClearGossipMenuFor(player);
        ChatHandler ch(player->GetSession());
        switch (action)
        {
            case ACT_REPAIR:
                if (g_repair.load())
                    player->GetSession()->SendListInventory(creature->GetGUID());
                else
                    CloseGossipMenuFor(player);
                return true;
            case ACT_MAIL:
                if (g_mailbox.load())
                    player->GetSession()->SendShowMailBox(creature->GetGUID());
                CloseGossipMenuFor(player);
                return true;
            case ACT_SICKNESS:
                CloseGossipMenuFor(player);
                if (g_sickness.load() && player->HasAura(SPELL_RESURRECTION_SICKNESS))
                {
                    player->RemoveAurasDueToSpell(SPELL_RESURRECTION_SICKNESS);
                    creature->Whisper("There. Walk it off.", LANG_UNIVERSAL, player);
                }
                return true;
            case ACT_RESET:
                CloseGossipMenuFor(player);
                if (!g_resetInstances.load())
                    return true;
                if (Group* group = player->GetGroup())
                {
                    if (group->IsLeader(player->GetGUID()))
                        group->ResetInstances(INSTANCE_RESET_ALL, false, player);
                    else
                        ch.SendSysMessage("Only your group leader can reset the group's dungeons.");
                }
                else
                    Player::ResetInstances(player->GetGUID(), INSTANCE_RESET_ALL, false);
                return true;
            case ACT_LOCKOUTS:
                CloseGossipMenuFor(player);
                if (g_clearLockouts.load())
                    ch.PSendSysMessage("Lockouts cleared: {}.", ClearLockouts(player));
                return true;
            default:
                CloseGossipMenuFor(player);
                return true;
        }
    }
};

class WarbandCampStewardWorld : public WorldScript
{
public:
    WarbandCampStewardWorld() : WorldScript("WarbandCampStewardWorld", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        g_repair = sConfigMgr->GetOption<bool>("WarbandCamp.Steward.Repair",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.Steward.Repair", true));
        g_mailbox = sConfigMgr->GetOption<bool>("WarbandCamp.Steward.Mailbox",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.Steward.Mailbox", true));
        g_sickness = sConfigMgr->GetOption<bool>("WarbandCamp.Steward.Sickness",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.Steward.Sickness", true));
        g_resetInstances = sConfigMgr->GetOption<bool>("WarbandCamp.Steward.ResetInstances",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.Steward.ResetInstances", true));
        g_clearLockouts = sConfigMgr->GetOption<bool>("WarbandCamp.Steward.ClearLockouts",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.Steward.ClearLockouts", false));
    }
};

void AddCampStewardScripts()
{
    new npc_warband_camp_steward();
    new WarbandCampStewardWorld();
}
