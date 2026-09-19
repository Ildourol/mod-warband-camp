/*
 * Copyright (C) 2025+ WOW Legends / Standalone Port
 * Released under GNU AGPL v3 license, you may redistribute it and/or modify
 * it under version 3 of the License, or (at your option), any later version.
 *
 * Warband Camp Standalone Module.
 *
 * A camp is a patch of ground that belongs to your ACCOUNT, not to one
 * character. You claim it WHERE YOU ARE STANDING, anywhere in the open world,
 * and you furnish it yourself out of ordinary WotLK scenery.
 *
 * PHASING BEHAVIOR:
 * Props are spawned with the camp's phase bit alone (1..31). A player within
 * CAMP_RADIUS of the camp is phased into (PHASEMASK_NORMAL | campBit). They
 * continue seeing the normal world, NPCs, and other players, while gaining
 * visibility of their camp props.
 */

#include "ScriptMgr.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Player.h"
#include "WorldSession.h"
#include "Configuration/Config.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "Creature.h"
#include "Group.h"
#include "Map.h"
#include "MapMgr.h"
#include "CharacterCache.h"
#include "Object.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "DBCStores.h"
#include "GridTerrainData.h"
#include "Log.h"

#if defined(MOD_PLAYERBOTS)
#include "PlayerbotAI.h"
#include "PlayerbotAIConfig.h"
#include "PlayerbotMgr.h"
#endif

#include <algorithm>
#include <atomic>
#include <cctype>
#include <cmath>
#include <ctime>
#include <mutex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    std::atomic<bool> g_enabled{true};

    // ---------------------------------------------------------------------
    // Tunables
    // ---------------------------------------------------------------------

    constexpr float CAMP_RADIUS = 40.0f;
    constexpr float CAMP_PROP_RADIUS = 32.0f;
    constexpr float CAMP_MIN_SEPARATION = 150.0f;
    constexpr float PHASE_REUSE_RADIUS = 600.0f;

    constexpr uint8 CAMP_PHASE_BIT_MIN = 1;
    constexpr uint8 CAMP_PHASE_BIT_MAX = 31;

    std::atomic<uint32> g_maxProps{200};
    constexpr uint32 CAMP_GO_COOLDOWN_SECONDS = 300;
    constexpr uint32 CAMP_PROP_COOLDOWN_SECONDS = 3;

    constexpr uint32 CAMP_PROXIMITY_INTERVAL_MS = 1000;
    constexpr uint32 CAMP_LOGIN_PHASE_DELAY_MS  = 3000;

    // Feature toggles
    std::atomic<bool> g_enableRestedXP{true};
    std::atomic<bool> g_enableMailbox{true};
    std::atomic<bool> g_enableTrainingDummy{true};
    std::atomic<uint32> g_inactivityDays{90};

    std::unordered_set<uint32> g_blacklistedMaps;
    std::unordered_set<uint32> g_blacklistedZones;

    // ---------------------------------------------------------------------
    // Prop catalogue (Generic inert type-5 and Mailbox type-19 gameobjects)
    // ---------------------------------------------------------------------
    struct PropDef
    {
        char const* key;
        uint32 entry;
        char const* label;
        float clearance;
        bool isCreature = false;
    };

PropDef const g_propCatalogue[] =
    {
        // shelter
        { "tent", 184592, "Tent", 6.0f },
        { "tent-a", 201868, "Alliance Tent", 7.0f },
        { "tent-h", 201886, "Horde Tent", 7.0f },
        { "foodtent", 186681, "Food Tent", 7.0f },
        { "tent-dwarf", 184696, "Dwarven Tent", 5.0f },
        { "tent-orc", 193127, "Orc Tent", 5.5f },
        { "tent-undead", 190213, "Forsaken Tent", 6.5f },
        { "tent-scourge", 190666, "Scourge Tent", 6.5f },
        { "canopy", 186680, "Open Canopy", 6.0f },
        { "tent-carnival", 179966, "Carnival Tent", 9.0f },
        // fire & light
        { "campfire", 182059, "Campfire", 3.0f },
        { "bonfire", 180434, "Bonfire", 3.5f },
        { "brazier", 180473, "Brazier", 2.5f },
        { "lantern", 179977, "Lantern", 2.0f },
        { "bonfire-blue", 181289, "Blue Fire Bonfire", 3.5f },
        { "bonfire-orc", 184866, "Orc Bonfire", 3.5f },
        { "brazier-festival", 181355, "Festival Brazier", 2.5f },
        { "brazier-purple", 176326, "Purple Brazier", 2.5f },
        { "brazier-legion", 184613, "Legion Brazier", 2.5f },
        { "bowl-fire", 182078, "Elven Fire Bowl", 3.0f },
        { "hearth-fire", 151952, "Great Hearth Fire", 3.0f },
        // furniture
        { "table", 181075, "Table", 3.5f },
        { "chair", 193949, "Chair", 2.5f },
        { "bench", 190694, "Bench", 3.0f },
        { "rug", 181077, "Rug", 3.0f },
        { "bookshelf", 183268, "Bookshelf", 3.0f },
        { "bookcase", 190693, "Bookcase", 3.0f },
        { "bunkbed", 193167, "Bunkbed", 3.5f },
        { "bed-stone", 185475, "Stone Bed", 3.0f },
        { "chair-dalaran", 192842, "Dalaran Chair", 2.0f },
        { "stool-elven", 182077, "Elven Stool", 2.0f },
        { "bench-orc", 180326, "Orc Bench", 3.5f },
        { "bench-wood", 193522, "Duskwood Bench", 3.0f },
        { "table-elven", 180879, "Elven Table", 3.0f },
        { "table-orc", 180888, "Orc Table", 3.0f },
        { "table-dwarf", 180324, "Dwarven Table", 3.5f },
        { "throne", 188481, "Chieftain Throne", 4.0f },
        { "wardrobe", 183267, "Wardrobe", 3.0f },
        { "rug-sw", 180334, "Stormwind Rug", 3.0f },
        { "rug-tauren", 182257, "Tauren Rug", 3.0f },
        { "rug-fur", 186933, "Vrykul Fur Rug", 3.0f },
        // storage & amenities
        { "crate", 178646, "Supply Crate", 2.5f },
        { "crate-h", 178442, "Horde Crate", 2.5f },
        { "barrel", 180779, "Barrel", 2.5f },
        { "keg", 180575, "Keg", 2.5f },
        { "cauldron", 180414, "Cauldron", 2.5f },
        { "cookpot", 184670, "Cook Pot", 2.5f },
        { "mailbox", 142103, "Mailbox", 2.5f },
        { "chest-ornate", 188225, "Ornate Chest", 2.5f },
        { "chest-reinforced", 186658, "Reinforced Chest", 2.5f },
        { "keg-brewfest", 186709, "Brewfest Ale Keg", 2.0f },
        { "tub", 200296, "Washing Tub", 2.5f },
        { "basin", 201774, "Water Basin", 2.5f },
        { "crate-orc", 184856, "Orc Crate", 2.5f },
        { "crate-grain", 190094, "Grain Crate", 2.5f },
        { "barrel-plague", 193414, "Plague Barrel", 2.5f },
        { "barrel-broken", 190881, "Broken Barrel", 2.5f },
        // yard
        { "wagon", 188696, "Wagon", 8.0f },
        { "haystack", 179968, "Haystack", 3.5f },
        { "haybale", 180700, "Hay Bale", 3.0f },
        { "woodpile", 190687, "Wood Pile", 3.5f },
        { "logpile", 194393, "Log Pile", 3.0f },
        { "fence", 180035, "Fence", 4.0f },
        { "rockwall", 211064, "Rockwall Fence", 4.0f },
        { "pumpkin", 195164, "Pumpkin", 2.0f },
        { "wheelbarrow", 190859, "Wheelbarrow", 2.5f },
        { "target-archery", 183440, "Archery Target", 2.5f },
        { "target-dwarf", 193157, "Dwarf Target Dummy", 2.5f },
        { "target-ogre", 186597, "Ogre Target Dummy", 2.5f },
        { "barricade", 193612, "Trench Barricade", 4.0f },
        { "cart-broken", 186807, "Broken Cart", 3.5f },
        { "cart-rocket", 190227, "Rocket Cart", 3.5f },
        { "fence-spiked", 180742, "Spiked Iron Fence", 3.5f },
        { "lightwell", 190746, "Holy Light Well", 3.0f },
        { "fountain-elven", 185493, "Elven Fountain", 3.5f },
        // craft
        { "anvil", 201771, "Anvil", 3.0f },
        { "forge", 201772, "Forge", 3.5f },
        { "coals", 201773, "Forge Coals", 2.5f },
        { "weaponrack", 183269, "Weapon Rack", 3.0f },
        { "toolbox", 193151, "Blacksmith Toolbox", 2.0f },
        { "rack-scourge", 190576, "Scourge Weapon Rack", 3.0f },
        { "rack-blades", 190577, "Scourge Blade Rack", 3.0f },
        { "grinder", 188190, "Gem Grinder", 2.5f },
        { "runeforge", 191746, "Scourge Runeforge", 5.0f },
        { "hammer", 186623, "Smithing Hammer", 2.0f },
        // banners
        { "banner", 180773, "Banner", 2.5f },
        { "banner-a", 192252, "Alliance Banner", 2.5f },
        { "banner-h", 192254, "Horde Banner", 2.5f },
        { "banner-sw", 194274, "Stormwind Banner", 2.5f },
        { "banner-org", 194278, "Orgrimmar Banner", 2.5f },
        { "banner-if", 194277, "Ironforge Banner", 2.5f },
        { "banner-dar", 194282, "Darnassus Banner", 2.5f },
        { "banner-gnome", 194279, "Gnomeregan Banner", 2.5f },
        { "banner-exo", 194280, "Exodar Banner", 2.5f },
        { "banner-tb", 194283, "Thunder Bluff Banner", 2.5f },
        { "banner-uc", 194276, "Undercity Banner", 2.5f },
        { "banner-smc", 194275, "Silvermoon Banner", 2.5f },
        { "banner-senjin", 194281, "Sen'jin Banner", 2.5f },
        { "banner-sun", 187123, "Shattered Sun Banner", 2.5f },
        { "banner-fk", 190670, "Forsaken Banner", 2.5f },
        // lights
        { "torch", 180352, "Torch", 2.5f },
        { "candle", 1558, "Candle", 2.0f },
        { "candelabra", 2697, "Candelabra", 2.5f },
        { "torch-stand", 180043, "Standing Torch", 2.0f },
        { "lamp-alliance", 180766, "Alliance Street Lantern", 2.5f },
        { "lamp-horde", 180768, "Horde Street Lantern", 2.5f },
        { "lamp-draenei", 184284, "Crystal Lamppost", 2.5f },
        { "torch-fel", 185003, "Fel Torch", 2.0f },
        // food & provisions
        { "sack", 195197, "Grain Sack", 2.5f },
        { "basket", 195196, "Basket", 2.5f },
        { "corn", 195192, "Basket of Corn", 2.0f },
        { "bucket", 2696, "Bucket", 2.0f },
        { "bottle", 2687, "Bottle", 2.0f },
        { "bread", 180051, "Bread", 2.0f },
        { "food", 56903, "Spread of Food", 2.0f },
        { "chest", 185503, "Chest", 3.0f },
        { "roastboar", 181145, "Roast Boar Platter", 2.0f },
        { "fishplatter", 181143, "Fish Platter", 2.0f },
        { "fruitbowl", 181144, "Fruit Bowl", 2.0f },
        { "apples", 183995, "Basket of Apples", 2.0f },
        { "campjug", 181306, "Camp Jug", 2.0f },
        { "campmug", 181307, "Camp Mug", 1.5f },
        { "breadslice", 180050, "Sliced Bread", 1.5f },
        { "tacklebox", 180403, "Tackle Box", 2.0f },
        // atmosphere
        { "skull", 2371, "Skull", 2.5f },
        { "totem", 187890, "Totem", 2.0f },
        { "gong", 180386, "Gong", 3.0f },
        { "drum", 186865, "Drum", 2.5f },
        { "statue", 192948, "Jade Statue", 3.0f },
        { "grave", 211065, "Grave", 3.0f },
        { "cage", 181379, "Cage", 3.0f },
        { "anchor", 177791, "Anchor", 2.5f },
        { "signpost", 180026, "Signpost", 2.5f },
        { "scroll", 182005, "Scroll", 2.0f },
        { "shovel", 180651, "Shovel", 2.5f },
        { "warmap", 180852, "Tactical War Map", 3.0f },
        { "skeleton", 176745, "Human Skeleton", 2.5f },
        { "tombstone", 177239, "Stone Tombstone", 2.5f },
        { "totem-tauren", 177268, "Great Tauren Totem", 3.0f },
        { "totem-small", 180209, "Small Totem", 2.0f },
        { "crystal-red", 164838, "Glowing Red Crystal", 2.5f },
        { "altar", 180875, "Stone Altar", 3.0f },
        { "spellbook", 152098, "Open Spellbook", 2.0f },
        // nature
        { "mushroom", 182073, "Giant Mushroom", 7.0f },
        { "flower", 181103, "Flowers", 2.0f },
        { "bush", 181824, "Bush", 2.5f },
        { "plant-potted", 181019, "Potted Plant", 2.0f },
        { "flowers-tribute", 180210, "Flower Bouquet", 2.0f },
        { "wreath", 181063, "Flower Wreath", 2.0f },
        { "vine-purple", 178904, "Purple Celebrian Vine", 2.5f },
        { "plant-fern", 178908, "Wild Fern", 2.0f },
        { "tree-pine", 178557, "Camp Pine Tree", 5.0f },
        { "pumpkinpatch", 180219, "Pumpkin Patch", 3.0f },
        // professions
        { "alchemy", 187114, "Alchemy Table", 3.0f },
        { "fishing", 173086, "Fishing Gear", 3.0f },
        { "alchemy-undead", 176561, "Forsaken Alchemy Bench", 3.0f },
        { "alchemy-round", 190689, "Apothecary Chemistry Set", 2.5f },
        { "cauldron-boiling", 188468, "Bubbling Cauldron", 2.5f },
        { "mortar", 190229, "Mortar and Pestle", 1.5f },
        { "herbsack", 184798, "Herb Sacks", 2.0f },
        { "herbrack", 180801, "Herb Drying Rack", 3.0f },
        { "engineering-gizmo", 188091, "Engineering Gizmo", 2.0f },
        { "ore-gold", 211032, "Gold Vein Deposit", 3.0f },
        // buildings
        { "cottage", 183493, "Cottage", 14.0f },
        { "beertent", 186682, "Beer Tent", 10.0f },
        { "pavilion", 188021, "Pavilion", 10.0f },
        { "bigtent", 184593, "Large Tent", 8.0f },
        { "stable", 180719, "Stable", 10.0f },
        { "doghouse", 180033, "Doghouse", 4.0f },
        { "outhouse", 180006, "Outhouse", 5.0f },
        { "pavilion-dwarf", 181301, "Dwarven Pavilion", 7.0f },
        { "pavilion-orc", 191784, "Orc War Pavilion", 8.0f },
        { "hut-murloc", 186742, "Tribal Thatched Hut", 7.0f },
        { "hut-stilt", 186743, "Stilt Water Hut", 8.0f },
        { "booth", 180042, "Carnival Booth", 6.0f },
        // portals
        { "portal-sw", 193956, "Stormwind Portal", 3.0f },
        { "portal-org", 193427, "Orgrimmar Portal", 3.0f },
        { "portal-dal", 194481, "Dalaran Portal", 3.0f },
        { "portal-shatt", 187335, "Shattrath Portal", 3.0f },
        { "portal-dark", 185103, "Dark Portal", 8.0f },
        { "portal-green", 181623, "Emerald Instance Portal", 3.5f },
        // trainers & npcs
        { "npc-banker", 5060, "Banker", 2.5f, true },
        { "npc-vendor", 32477, "General Goods & Repairs", 2.5f, true },
        { "npc-reagents", 29537, "Reagents & Poisons", 2.5f, true },
        { "npc-innkeeper", 29532, "Innkeeper (Hearthstone)", 2.5f, true },
        { "npc-auctioneer", 9858, "Auctioneer", 2.5f, true },
        { "trainer-warrior", 26332, "Warrior Trainer", 2.5f, true },
        { "trainer-paladin", 26327, "Paladin Trainer", 2.5f, true },
        { "trainer-hunter", 26325, "Hunter Trainer", 2.5f, true },
        { "trainer-rogue", 26329, "Rogue Trainer", 2.5f, true },
        { "trainer-priest", 26328, "Priest Trainer", 2.5f, true },
        { "trainer-deathknight", 29195, "Death Knight Trainer", 2.5f, true },
        { "trainer-shaman", 26330, "Shaman Trainer", 2.5f, true },
        { "trainer-mage", 26326, "Mage Trainer", 2.5f, true },
        { "trainer-warlock", 26331, "Warlock Trainer", 2.5f, true },
        { "trainer-druid", 26324, "Druid Trainer", 2.5f, true },
        { "trainer-alchemy", 28703, "Alchemy Trainer", 2.5f, true },
        { "trainer-blacksmith", 28694, "Blacksmithing Trainer", 2.5f, true },
        { "trainer-enchanting", 28693, "Enchanting Trainer", 2.5f, true },
        { "trainer-engineering", 28697, "Engineering Trainer", 2.5f, true },
        { "trainer-inscription", 28702, "Inscription Trainer", 2.5f, true },
        { "trainer-jewelcrafting", 28701, "Jewelcrafting Trainer", 2.5f, true },
        { "trainer-leatherworking", 28700, "Leatherworking Trainer", 2.5f, true },
        { "trainer-tailoring", 28699, "Tailoring Trainer", 2.5f, true },
        { "trainer-cooking", 28705, "Cooking Trainer", 2.5f, true },
        { "trainer-firstaid", 28706, "First Aid Trainer", 2.5f, true },
        { "trainer-fishing", 28742, "Fishing Trainer", 2.5f, true },
        { "trainer-mining", 28698, "Mining Trainer", 2.5f, true },
        { "trainer-herbalism", 28704, "Herbalism Trainer", 2.5f, true },
        { "trainer-skinning", 28696, "Skinning Trainer", 2.5f, true },
        { "trainer-flying", 31238, "Flying Trainer", 2.5f, true },
    };

    std::vector<PropDef> g_props;
    bool g_propsBuilt = false;

    void BuildPropCatalogue()
    {
        if (g_propsBuilt)
            return;
        g_propsBuilt = true;

        for (PropDef const& def : g_propCatalogue)
        {
            if (def.isCreature)
            {
                CreatureTemplate const* ctpl = sObjectMgr->GetCreatureTemplate(def.entry);
                if (!ctpl)
                {
                    LOG_WARN("server", "[warbandcamp] npc '{}' entry {} has no creature_template - dropped",
                        def.key, def.entry);
                    continue;
                }
                g_props.push_back(def);
                continue;
            }

            GameObjectTemplate const* tpl =
                sObjectMgr->GetGameObjectTemplate(def.entry);
            if (!tpl)
            {
                LOG_WARN("server", "[warbandcamp] prop '{}' entry {} has no gameobject_template - dropped",
                    def.key, def.entry);
                continue;
            }

            if (!tpl->displayId || !sGameObjectDisplayInfoStore.LookupEntry(tpl->displayId))
            {
                LOG_WARN("server", "[warbandcamp] prop '{}' entry {} has invalid displayId {} - dropped",
                    def.key, def.entry, tpl->displayId);
                continue;
            }

            // Generic inert objects and Mailbox are supported
            if (tpl->type != GAMEOBJECT_TYPE_GENERIC && tpl->type != GAMEOBJECT_TYPE_MAILBOX)
            {
                LOG_WARN("server", "[warbandcamp] prop '{}' entry {} is type {}, not GENERIC or MAILBOX - dropped",
                    def.key, def.entry, tpl->type);
                continue;
            }

            g_props.push_back(def);
        }

        LOG_INFO("server", "[warbandcamp] {} of {} props available",
            g_props.size(), std::size(g_propCatalogue));
    }

    PropDef const* FindProp(std::string const& key)
    {
        for (PropDef const& def : g_props)
            if (key == def.key)
                return &def;
        return nullptr;
    }

    // ---------------------------------------------------------------------
    // Camp State
    // ---------------------------------------------------------------------

    std::mutex g_campMutex;

    enum CampPrivacy : uint8
    {
        PRIVACY_PUBLIC  = 0,
        PRIVACY_PARTY   = 1,
        PRIVACY_GUILD   = 2,
        PRIVACY_PRIVATE = 3
    };

    struct Camp
    {
        uint32 accountId = 0;
        uint32 map = 0;
        float x = 0.0f, y = 0.0f, z = 0.0f, o = 0.0f;
        uint8 phaseBit = 0;
        uint32 zoneId = 0;
        uint8 privacy = PRIVACY_PUBLIC;
        std::string greeting;
        uint32 lastActive = 0;
    };

    std::vector<Camp> g_camps;
    std::unordered_map<uint64, ObjectGuid> g_liveProps;
    std::unordered_map<uint64, ObjectGuid> g_liveCreatures;

    struct PlayerCampState
    {
        uint32 timer = 0;
        uint32 campAccount = 0;
        bool ownsPhase = false;
        bool ownsRestFlag = false;
        uint32 lastGreetedCamp = 0;
    };
    std::unordered_map<ObjectGuid, PlayerCampState> g_playerState;

    std::unordered_map<uint32, time_t> g_goCooldown;
    std::unordered_map<uint32, time_t> g_propCooldown;
    struct LastPlaced
    {
        uint64 id = 0;
        bool isCreature = false;
    };
    std::unordered_map<uint32, LastPlaced> g_lastPlacedProp;

    // ---------------------------------------------------------------------
    // Warband Alts
    // ---------------------------------------------------------------------

    constexpr uint32 CAMP_MAX_ALTS = 8;
    constexpr float CAMP_ALT_RING = 8.0f;

    std::atomic<bool> g_autoAlts{true};
    std::atomic<float> g_viewDist{40.0f};
    std::atomic<bool> g_altsSameFactionOnly{true};

    std::unordered_map<uint32, uint32> g_parkedAlts;

    struct AltGather
    {
        uint32 accountId = 0;
        ObjectGuid owner;
        std::vector<std::string> names;
        time_t wakeAt = 0;
        time_t deadline = 0;
        uint32 seated = 0;
        bool announced = false;
    };
    std::vector<AltGather> g_altGathers;

    bool IsWarbandRealPlayer(Player* p)
    {
        return p && p->GetSession() && !p->GetSession()->IsBot();
    }

    Camp* FindCamp(uint32 accountId)
    {
        for (Camp& c : g_camps)
            if (c.accountId == accountId)
                return &c;
        return nullptr;
    }

    float Dist2D(float ax, float ay, float bx, float by)
    {
        float const dx = ax - bx;
        float const dy = ay - by;
        return std::sqrt(dx * dx + dy * dy);
    }

    std::string GetCampOwnerName(uint32 accountId)
    {
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT name FROM characters WHERE account = {} ORDER BY logout_time DESC LIMIT 1", accountId))
            return r->Fetch()[0].Get<std::string>();
        return "Someone";
    }

    bool CanPlayerAccessCamp(Player* p, Camp const& c)
    {
        if (p->GetSession()->GetAccountId() == c.accountId)
            return true;

        if (c.privacy == PRIVACY_PUBLIC)
            return true;

        if (c.privacy == PRIVACY_PRIVATE)
            return false;

        if (c.privacy == PRIVACY_PARTY)
        {
            if (Group* grp = p->GetGroup())
            {
                for (GroupReference* itr = grp->GetFirstMember(); itr != nullptr; itr = itr->next())
                {
                    if (Player* member = itr->GetSource())
                        if (member->GetSession() && member->GetSession()->GetAccountId() == c.accountId)
                            return true;
                }
            }
            return false;
        }

        if (c.privacy == PRIVACY_GUILD)
        {
            uint32 const guildId = p->GetGuildId();
            if (!guildId)
                return false;

            QueryResult r = CharacterDatabase.Query(
                "SELECT 1 FROM characters WHERE account = {} AND guildid = {} LIMIT 1",
                c.accountId, guildId);
            return r != nullptr;
        }

        return true;
    }

    void ParseCommaDelimitedSet(std::string const& input, std::unordered_set<uint32>& outSet)
    {
        outSet.clear();
        std::stringstream ss(input);
        std::string token;
        while (std::getline(ss, token, ','))
        {
            token.erase(std::remove_if(token.begin(), token.end(), ::isspace), token.end());
            if (!token.empty())
            {
                try
                {
                    outSet.insert(std::stoul(token));
                }
                catch (...) { }
            }
        }
    }

    // ---------------------------------------------------------------------
    // Phase bit allocation
    // ---------------------------------------------------------------------
    uint8 PickPhaseBit(uint32 map, float x, float y)
    {
        uint32 used = 0;
        for (Camp const& c : g_camps)
        {
            if (c.map != map)
                continue;
            if (Dist2D(c.x, c.y, x, y) > PHASE_REUSE_RADIUS)
                continue;
            used |= (1u << c.phaseBit);
        }

        for (uint8 bit = CAMP_PHASE_BIT_MIN; bit <= CAMP_PHASE_BIT_MAX; ++bit)
            if (!(used & (1u << bit)))
                return bit;

        return 0;
    }

    // ---------------------------------------------------------------------
    // Spawning (Props & Phased Creatures)
    // ---------------------------------------------------------------------

    ObjectGuid SpawnProp(Map* map, uint32 entry, float x, float y, float z, float o, uint32 phaseMask)
    {
        GameObjectTemplate const* tpl = sObjectMgr->GetGameObjectTemplate(entry);
        if (!tpl)
            return ObjectGuid::Empty;

        GameObject* go = new GameObject();
        ObjectGuid::LowType const guidLow = map->GenerateLowGuid<HighGuid::GameObject>();

        G3D::Quat const rot = G3D::Quat::fromAxisAngleRotation(G3D::Vector3::unitZ(), o);

        if (!go->Create(guidLow, entry, map, phaseMask, x, y, z, o, rot, 0, GO_STATE_READY))
        {
            delete go;
            return ObjectGuid::Empty;
        }

        go->SetRespawnTime(0);

        if (!map->AddToMap(go))
        {
            delete go;
            return ObjectGuid::Empty;
        }

        return go->GetGUID();
    }

    ObjectGuid SpawnCampCreature(Map* map, uint32 entry, float x, float y, float z, float o, uint32 phaseMask)
    {
        CreatureTemplate const* tpl = sObjectMgr->GetCreatureTemplate(entry);
        if (!tpl)
            return ObjectGuid::Empty;

        Creature* cr = new Creature();
        ObjectGuid::LowType const guidLow = map->GenerateLowGuid<HighGuid::Unit>();

        if (!cr->Create(guidLow, map, phaseMask, entry, 0, x, y, z, o))
        {
            delete cr;
            return ObjectGuid::Empty;
        }

        cr->SetRespawnTime(0);

        if (!map->AddToMap(cr))
        {
            delete cr;
            return ObjectGuid::Empty;
        }

        return cr->GetGUID();
    }

    void MaterialiseCamp(Camp const& camp, Map* map)
    {
        uint32 const phaseMask = 1u << camp.phaseBit;

        // Props
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id, entry, pos_x, pos_y, pos_z, orientation "
                "FROM mod_warband_camp_object WHERE account_id = {}",
                camp.accountId))
        {
            uint32 spawned = 0;
            do
            {
                Field* f = r->Fetch();
                uint64 const id = f[0].Get<uint64>();

                auto const it = g_liveProps.find(id);
                if (it != g_liveProps.end())
                {
                    if (map->GetGameObject(it->second))
                        continue;
                    g_liveProps.erase(it);
                }

                ObjectGuid const guid = SpawnProp(map, f[1].Get<uint32>(),
                    f[2].Get<float>(), f[3].Get<float>(), f[4].Get<float>(),
                    f[5].Get<float>(), phaseMask);

                if (guid)
                {
                    g_liveProps[id] = guid;
                    ++spawned;
                }
            }
            while (r->NextRow());

            if (spawned)
                LOG_DEBUG("server", "[warbandcamp] materialised {} props for account {}", spawned, camp.accountId);
        }

        // Phased Creatures (e.g. Training Dummies)
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id, entry, pos_x, pos_y, pos_z, orientation "
                "FROM mod_warband_camp_creature WHERE account_id = {}",
                camp.accountId))
        {
            do
            {
                Field* f = r->Fetch();
                uint64 const id = f[0].Get<uint64>();

                auto const it = g_liveCreatures.find(id);
                if (it != g_liveCreatures.end())
                {
                    if (map->GetCreature(it->second))
                        continue;
                    g_liveCreatures.erase(it);
                }

                ObjectGuid const guid = SpawnCampCreature(map, f[1].Get<uint32>(),
                    f[2].Get<float>(), f[3].Get<float>(), f[4].Get<float>(),
                    f[5].Get<float>(), phaseMask);

                if (guid)
                    g_liveCreatures[id] = guid;
            }
            while (r->NextRow());
        }
    }

    void DespawnProp(Map* map, uint64 id)
    {
        auto const it = g_liveProps.find(id);
        if (it == g_liveProps.end())
            return;

        if (GameObject* go = map->GetGameObject(it->second))
        {
            go->SetRespawnTime(0);
            go->Delete();
        }
        g_liveProps.erase(it);
    }

    void DespawnCampCreature(Map* map, uint64 id)
    {
        auto const it = g_liveCreatures.find(id);
        if (it == g_liveCreatures.end())
            return;

        if (Creature* cr = map->GetCreature(it->second))
        {
            cr->SetRespawnTime(0);
            cr->DespawnOrUnsummon();
        }
        g_liveCreatures.erase(it);
    }

    // ---------------------------------------------------------------------
    // Placement and Travel Blockers
    // ---------------------------------------------------------------------

    char const* CampSiteBlocker(Player* p)
    {
        Map* map = p->GetMap();
        if (!map)
            return "You cannot build here.";

        uint32 const mapId = map->GetId();
        uint32 const zoneId = p->GetZoneId();

        if (g_blacklistedMaps.count(mapId))
            return "Building a camp is prohibited on this map.";

        if (g_blacklistedZones.count(zoneId))
            return "Building a camp is prohibited in this zone.";

        if (map->Instanceable())
            return "Not inside an instance. Find yourself a patch of the open world.";
        if (p->InBattleground() || p->InArena())
            return "Not in a battleground.";

        if (p->IsInWater() || p->IsUnderWater())
            return "Not in the water.";
        if (p->IsFlying() || p->IsInFlight())
            return "Come down to the ground first.";
        if (p->IsFalling())
            return "Not in mid-air.";
        if (!p->IsAlive() || p->HasPlayerFlag(PLAYER_FLAGS_GHOST))
            return "Not while you are dead.";
        if (p->IsInCombat())
            return "Not while you are in combat.";

        if (p->GetTransport())
            return "Not aboard a ship or a zeppelin.";

        AreaTableEntry const* area = sAreaTableStore.LookupEntry(p->GetAreaId());
        if (!area)
            return "This ground is too strange to build on.";

        if (area->flags & (AREA_FLAG_CAPITAL | AREA_FLAG_SLAVE_CAPITAL | AREA_FLAG_SLAVE_CAPITAL2))
            return "Not inside a capital city. Somewhere quieter.";
        if (area->IsSanctuary())
            return "Not in a sanctuary.";
        if (area->flags & (AREA_FLAG_ARENA | AREA_FLAG_ARENA_INSTANCE))
            return "Not in an arena.";

        if (!p->IsOutdoors())
            return "Camps go under open sky. Step outside.";

        float const groundZ = map->GetHeight(p->GetPhaseMask(),
            p->GetPositionX(), p->GetPositionY(), p->GetPositionZ(), true,
            MAX_FALL_DISTANCE);
        if (groundZ <= INVALID_HEIGHT)
            return "There is no solid ground here.";
        if (std::fabs(p->GetPositionZ() - groundZ) > 3.0f)
            return "Stand on the ground itself, not above it.";

        return nullptr;
    }

    char const* CampTravelBlocker(Player* p)
    {
        if (p->IsInCombat())
            return "Not while you are in combat.";
        if (p->HasUnitState(UNIT_STATE_STUNNED | UNIT_STATE_FLEEING |
                            UNIT_STATE_CONFUSED | UNIT_STATE_ROOT))
            return "You cannot concentrate well enough to travel.";
        if (!p->IsAlive())
            return "Not while you are dead.";
        if (p->HasPlayerFlag(PLAYER_FLAGS_GHOST))
            return "Not while you are a ghost - find your body first.";
        if (p->IsBeingTeleported())
            return "You are already travelling.";
        if (p->IsInFlight())
            return "Not while you are in flight.";
        if (p->IsFalling())
            return "Not in mid-air.";
        if (p->InBattleground())
            return "Not from a battleground.";
        if (p->InArena())
            return "Not from an arena.";
        if (p->IsSpectator())
            return "Not while spectating.";
        if (p->GetMap() && p->GetMap()->Instanceable())
            return "Not from inside an instance.";
        return nullptr;
    }

    // ---------------------------------------------------------------------
    // Proximity Phasing & Rested XP
    // ---------------------------------------------------------------------

    void ApplyPhase(Player* p, uint32 mask)
    {
        if (p->GetPhaseMask() != mask)
            p->SetPhaseMask(mask, true);
    }

    void ClearCampPhase(Player* p, PlayerCampState& st)
    {
        st.campAccount = 0;
        st.lastGreetedCamp = 0;

        if (st.ownsRestFlag)
        {
            p->RemoveRestFlag(REST_FLAG_IN_TAVERN);
            st.ownsRestFlag = false;
        }

        if (!st.ownsPhase)
            return;
        st.ownsPhase = false;

        if (p->IsGameMaster() || p->GetPhaseByAuras())
            return;

        ApplyPhase(p, PHASEMASK_NORMAL);
    }

    void UpdatePlayerCampPhase(Player* p, PlayerCampState& st)
    {
        if (p->IsGameMaster() || p->GetPhaseByAuras())
        {
            st.campAccount = 0;
            st.ownsPhase = false;
            return;
        }

        Map* map = p->GetMap();
        if (!map)
            return;

        uint32 const mapId = map->GetId();
        float const px = p->GetPositionX();
        float const py = p->GetPositionY();

        float const viewConf = g_viewDist.load();
        float const view = viewConf > 0.0f ? viewConf : 250.0f;

        Camp const* best = nullptr;
        float bestDist = view;
        uint32 wantMask = PHASEMASK_NORMAL;

        Camp const* inRange[31];
        uint32 inRangeCount = 0;
        for (Camp const& c : g_camps)
        {
            if (c.map != mapId)
                continue;

            // Privacy check
            if (!CanPlayerAccessCamp(p, c))
                continue;

            float const d = Dist2D(c.x, c.y, px, py);
            if (d > view)
                continue;
            wantMask |= (1u << c.phaseBit);
            if (inRangeCount < 31)
                inRange[inRangeCount++] = &c;
            if (d < bestDist)
            {
                bestDist = d;
                best = &c;
            }
        }

        if (!best)
        {
            ClearCampPhase(p, st);
            return;
        }

        // Rested XP & instant logout
        if (g_enableRestedXP.load() && !st.ownsRestFlag)
        {
            p->SetRestFlag(REST_FLAG_IN_TAVERN);
            st.ownsRestFlag = true;
        }

        // Welcome greeting message for visitors
        if (!best->greeting.empty() && p->GetSession()->GetAccountId() != best->accountId && st.lastGreetedCamp != best->accountId)
        {
            std::string const ownerName = GetCampOwnerName(best->accountId);
            ChatHandler(p->GetSession()).PSendSysMessage(
                "|cff00ff00[Camp]|r Welcome to |cffffff00{}'s|r camp: \"{}\"", ownerName, best->greeting);
            st.lastGreetedCamp = best->accountId;
        }

        if (st.campAccount == best->accountId && p->GetPhaseMask() == wantMask)
            return;

        for (uint32 i = 0; i < inRangeCount; ++i)
            MaterialiseCamp(*inRange[i], map);

        st.campAccount = best->accountId;
        st.ownsPhase = true;
        ApplyPhase(p, wantMask);
    }

    // ---------------------------------------------------------------------
    // Alts seating and gather helpers
    // ---------------------------------------------------------------------

    bool SeatAltAtCamp(Player* alt, Camp const& camp, uint32 slot)
    {
        float const angle = (2.0f * float(M_PI) * float(slot)) / float(CAMP_MAX_ALTS);
        float const x = camp.x + std::cos(angle) * CAMP_ALT_RING;
        float const y = camp.y + std::sin(angle) * CAMP_ALT_RING;
        float z = camp.z;
        if (Map* map = sMapMgr->FindBaseMap(camp.map))
        {
            float const g = map->GetHeight(PHASEMASK_NORMAL, x, y,
                camp.z + 10.0f, true, MAX_FALL_DISTANCE);
            if (g > INVALID_HEIGHT && std::fabs(g - camp.z) < 15.0f)
                z = g;
        }

        bool const wasAtCamp = alt->GetMapId() == camp.map &&
            Dist2D(camp.x, camp.y, alt->GetPositionX(), alt->GetPositionY()) < CAMP_RADIUS + 20.0f;
        if (!wasAtCamp)
            CharacterDatabase.Execute(
                "INSERT IGNORE INTO mod_warband_alt_origin "
                "(guid, map, pos_x, pos_y, pos_z, orientation, parked_at) "
                "VALUES ({}, {}, {}, {}, {}, {}, {})",
                alt->GetGUID().GetCounter(), alt->GetMapId(),
                alt->GetPositionX(), alt->GetPositionY(),
                alt->GetPositionZ(), alt->GetOrientation(),
                uint32(time(nullptr)));

        if (!alt->TeleportTo(camp.map, x, y, z, std::atan2(camp.y - y, camp.x - x)))
            return false;

        if (alt->GetGroup())
            alt->RemoveFromGroup();

#if defined(MOD_PLAYERBOTS)
        if (PlayerbotAI* botAI = sPlayerbotsMgr.GetPlayerbotAI(alt))
            botAI->ChangeStrategy("-follow", BOT_STATE_NON_COMBAT);
#endif

        g_parkedAlts[alt->GetGUID().GetCounter()] = camp.accountId;
        return true;
    }

    void EnqueueAltGather(Player* owner, uint32 accountId, time_t wakeDelay)
    {
        g_altGathers.erase(
            std::remove_if(g_altGathers.begin(), g_altGathers.end(),
                [accountId](AltGather const& g) { return g.accountId == accountId; }),
            g_altGathers.end());

        AltGather g;
        g.accountId = accountId;
        g.owner = owner->GetGUID();
        g.wakeAt = time(nullptr) + wakeDelay;
        g.deadline = g.wakeAt + 45;

        bool const sameOnly = g_altsSameFactionOnly.load();
        TeamId const ownerTeam = owner->GetTeamId();
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT name, race FROM characters WHERE account = {} "
                "AND guid <> {} AND deleteInfos_Account IS NULL",
                accountId, owner->GetGUID().GetCounter()))
        {
            do
            {
                Field* f = r->Fetch();
                if (sameOnly && Player::TeamIdForRace(f[1].Get<uint8>()) != ownerTeam)
                    continue;
                g.names.push_back(f[0].Get<std::string>());
                if (g.names.size() >= CAMP_MAX_ALTS)
                    break;
            }
            while (r->NextRow());
        }

        if (!g.names.empty())
            g_altGathers.push_back(std::move(g));
    }
}

// -------------------------------------------------------------------------
// Parked alt query hooks (C-linkage for cross-module compatibility)
// -------------------------------------------------------------------------
extern "C" bool WarbandCampParked(uint32 lowGuid, float& cx, float& cy, float& cz)
{
    std::lock_guard<std::mutex> lock(g_campMutex);
    auto const it = g_parkedAlts.find(lowGuid);
    if (it == g_parkedAlts.end())
        return false;
    for (Camp const& c : g_camps)
    {
        if (c.accountId == it->second)
        {
            cx = c.x;
            cy = c.y;
            cz = c.z;
            return true;
        }
    }
    return false;
}

// Legacy alias for mod-playerbots idle stroll integration:
extern "C" bool WlWarbandCampParked(uint32 lowGuid, float& cx, float& cy, float& cz)
{
    return WarbandCampParked(lowGuid, cx, cy, cz);
}

// -------------------------------------------------------------------------
// Command Script
// -------------------------------------------------------------------------
class WarbandCampCommand : public CommandScript
{
public:
    WarbandCampCommand() : CommandScript("WarbandCampCommand") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable campTable =
        {
            { "claim",     HandleCampClaimCommand,     SEC_PLAYER,        Console::No },
            { "go",        HandleCampGoCommand,        SEC_PLAYER,        Console::No },
            { "leave",     HandleCampLeaveCommand,     SEC_PLAYER,        Console::No },
            { "props",     HandleCampPropsCommand,     SEC_PLAYER,        Console::No },
            { "place",     HandleCampPlaceCommand,     SEC_PLAYER,        Console::No },
            { "undo",      HandleCampUndoCommand,      SEC_PLAYER,        Console::No },
            { "remove",    HandleCampRemoveCommand,    SEC_PLAYER,        Console::No },
            { "dummy",     HandleCampDummyCommand,     SEC_PLAYER,        Console::No },
            { "message",   HandleCampMessageCommand,   SEC_PLAYER,        Console::No },
            { "privacy",   HandleCampPrivacyCommand,   SEC_PLAYER,        Console::No },
            { "diag",      HandleCampDiagCommand,      SEC_ADMINISTRATOR, Console::Yes },
            { "reload",    HandleCampReloadCommand,    SEC_ADMINISTRATOR, Console::Yes },
            { "alts",      HandleCampAltsCommand,      SEC_PLAYER,        Console::No },
            { "visit",     HandleCampVisitCommand,     SEC_PLAYER,        Console::No },
            { "list",      HandleCampListCommand,      SEC_PLAYER,        Console::No },
            { "catalogue", HandleCampCatalogueCommand, SEC_GAMEMASTER,    Console::No },
            { "",          HandleCampStatusCommand,    SEC_PLAYER,        Console::No },
        };

        static ChatCommandTable baseTable =
        {
            { "camp", campTable },
        };

        return baseTable;
    }

    static bool Gate(ChatHandler* handler, Player*& me)
    {
        me = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!IsWarbandRealPlayer(me))
            return false;

        if (!g_enabled.load())
        {
            handler->SendSysMessage("Warband Camps are not enabled on this realm.");
            return false;
        }
        return true;
    }

    static void DescribeCamp(ChatHandler* handler, Camp const& c)
    {
        char const* zone = "somewhere";
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(c.zoneId))
            zone = area->area_name[0];

        uint32 props = 0;
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM mod_warband_camp_object WHERE account_id = {}", c.accountId))
            props = r->Fetch()[0].Get<uint32>();
        if (QueryResult rc = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM mod_warband_camp_creature WHERE account_id = {}", c.accountId))
            props += rc->Fetch()[0].Get<uint32>();

        char const* privStr = "Public";
        if (c.privacy == PRIVACY_PARTY)
            privStr = "Party Only";
        else if (c.privacy == PRIVACY_GUILD)
            privStr = "Guild Only";
        else if (c.privacy == PRIVACY_PRIVATE)
            privStr = "Private";

        uint32 const maxProps = g_maxProps.load();
        if (maxProps)
            handler->PSendSysMessage("Your Warband Camp is in |cffffff00{}|r (Privacy: |cffffff00{}|r), with {} of {} things set up.",
                zone, privStr, props, maxProps);
        else
            handler->PSendSysMessage("Your Warband Camp is in |cffffff00{}|r (Privacy: |cffffff00{}|r), with {} things set up.",
                zone, privStr, props);

        if (!c.greeting.empty())
            handler->PSendSysMessage("Greeting message: \"|cff00ff00{}|r\"", c.greeting);
    }

    static bool HandleCampStatusCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        Camp const* c = FindCamp(me->GetSession()->GetAccountId());
        if (!c)
        {
            handler->SendSysMessage("You have no Warband Camp yet. Stand somewhere you like and use |cffffff00.camp claim|r.");
            handler->SendSysMessage("A camp belongs to your account, so every character you own shares it.");
            return true;
        }

        DescribeCamp(handler, *c);
        handler->SendSysMessage("|cffffff00.camp go|r to travel there, |cffffff00.camp props|r to see what you can put up.");
        return true;
    }

    static bool HandleCampClaimCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        if (Camp const* existing = FindCamp(accountId))
        {
            DescribeCamp(handler, *existing);
            handler->SendSysMessage("Give it up with |cffffff00.camp leave|r first if you want to move.");
            return true;
        }

        if (char const* blocked = CampSiteBlocker(me))
        {
            handler->SendSysMessage(blocked);
            return true;
        }

        uint32 const mapId = me->GetMapId();
        float const x = me->GetPositionX();
        float const y = me->GetPositionY();

        for (Camp const& c : g_camps)
        {
            if (c.map != mapId)
                continue;
            if (Dist2D(c.x, c.y, x, y) < CAMP_MIN_SEPARATION)
            {
                handler->SendSysMessage("Somebody else is camped too close to here. Walk a little further and try again.");
                return true;
            }
        }

        uint8 const bit = PickPhaseBit(mapId, x, y);
        if (!bit)
        {
            handler->SendSysMessage("This corner of the world is crowded with camps. Try somewhere further out.");
            return true;
        }

        Camp c;
        c.accountId = accountId;
        c.map = mapId;
        c.x = x;
        c.y = y;
        c.z = me->GetPositionZ();
        c.o = me->GetOrientation();
        c.phaseBit = bit;
        c.zoneId = me->GetZoneId();
        c.privacy = PRIVACY_PUBLIC;
        c.lastActive = uint32(time(nullptr));

        CharacterDatabase.DirectExecute(
            "INSERT IGNORE INTO mod_warband_camp "
            "(account_id, map, pos_x, pos_y, pos_z, orientation, phase_bit, zone_id, privacy, greeting, last_active) "
            "VALUES ({}, {}, {:.4f}, {:.4f}, {:.4f}, {:.4f}, {}, {}, {}, '', {})",
            c.accountId, c.map, c.x, c.y, c.z, c.o, c.phaseBit, c.zoneId, c.privacy, c.lastActive);

        QueryResult r = CharacterDatabase.Query(
            "SELECT phase_bit FROM mod_warband_camp WHERE account_id = {}", accountId);
        if (!r)
        {
            handler->SendSysMessage("Your claim could not be recorded. Please tell an administrator.");
            LOG_ERROR("server", "[warbandcamp] claim write failed for account {}", accountId);
            return true;
        }
        c.phaseBit = r->Fetch()[0].Get<uint8>();

        g_camps.push_back(c);

        char const* zone = "here";
        if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(c.zoneId))
            zone = area->area_name[0];

        handler->PSendSysMessage("This ground is yours. Your Warband Camp stands in |cffffff00{}|r.", zone);
        handler->SendSysMessage("Put something up with |cffffff00.camp place campfire|r - |cffffff00.camp props|r lists the rest.");
        LOG_INFO("server", "[warbandcamp] account {} ({}) claimed map {} ({:.1f}, {:.1f}) zone {} phase bit {}",
            accountId, me->GetName(), c.map, c.x, c.y, c.zoneId, c.phaseBit);
        return true;
    }

    static bool HandleCampGoCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp yet. Stand somewhere you like and use |cffffff00.camp claim|r.");
            return true;
        }
        Camp const camp = *found;

        if (char const* blocked = CampTravelBlocker(me))
        {
            handler->SendSysMessage(blocked);
            return true;
        }

        time_t const now = time(nullptr);
        auto const it = g_goCooldown.find(accountId);
        if (it != g_goCooldown.end() && now < it->second)
        {
            handler->PSendSysMessage("You must rest before travelling again ({} seconds).",
                uint32(it->second - now));
            return true;
        }

        if (!me->TeleportTo(camp.map, camp.x, camp.y, camp.z, camp.o))
        {
            handler->SendSysMessage("Something is keeping you here - you cannot travel right now.");
            return true;
        }

        g_goCooldown[accountId] = now + CAMP_GO_COOLDOWN_SECONDS;
        return true;
    }

    static bool HandleCampLeaveCommand(ChatHandler* handler, Optional<std::string> confirm)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp to give up.");
            return true;
        }
        Camp const camp = *found;

        if (!confirm || *confirm != "confirm")
        {
            DescribeCamp(handler, camp);
            handler->SendSysMessage("|cffff2020This cannot be undone|r - everything you set up there is lost.");
            handler->SendSysMessage("Type |cffffff00.camp leave confirm|r if you are sure.");
            return true;
        }

        Map* campMap = sMapMgr->FindBaseMap(camp.map);
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id FROM mod_warband_camp_object WHERE account_id = {}", accountId))
        {
            do
            {
                uint64 const id = r->Fetch()[0].Get<uint64>();
                if (campMap)
                    DespawnProp(campMap, id);
                else
                    g_liveProps.erase(id);
            }
            while (r->NextRow());
        }

        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id FROM mod_warband_camp_creature WHERE account_id = {}", accountId))
        {
            do
            {
                uint64 const id = r->Fetch()[0].Get<uint64>();
                if (campMap)
                    DespawnCampCreature(campMap, id);
                else
                    g_liveCreatures.erase(id);
            }
            while (r->NextRow());
        }

        CharacterDatabase.DirectExecute(
            "DELETE FROM mod_warband_camp_object WHERE account_id = {}", accountId);
        CharacterDatabase.DirectExecute(
            "DELETE FROM mod_warband_camp_creature WHERE account_id = {}", accountId);
        CharacterDatabase.DirectExecute(
            "DELETE FROM mod_warband_camp WHERE account_id = {}", accountId);

        g_lastPlacedProp.erase(accountId);

        g_camps.erase(std::remove_if(g_camps.begin(), g_camps.end(),
            [accountId](Camp const& e) { return e.accountId == accountId; }),
            g_camps.end());

        for (auto it = g_parkedAlts.begin(); it != g_parkedAlts.end();)
        {
            if (it->second == accountId)
                it = g_parkedAlts.erase(it);
            else
                ++it;
        }
        g_altGathers.erase(
            std::remove_if(g_altGathers.begin(), g_altGathers.end(),
                [accountId](AltGather const& g) { return g.accountId == accountId; }),
            g_altGathers.end());

        for (auto& [guid, st] : g_playerState)
            if (st.campAccount == accountId)
                if (Player* other = ObjectAccessor::FindPlayer(guid))
                    ClearCampPhase(other, st);

        handler->SendSysMessage("You have struck camp. The ground is free again.");
        LOG_INFO("server", "[warbandcamp] account {} ({}) released its camp", accountId, me->GetName());
        return true;
    }

    static bool HandleCampPropsCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        handler->SendSysMessage("Things you can put up at your camp:");

        std::string line;
        uint32 n = 0;
        for (PropDef const& def : g_props)
        {
            line += "|cffffff00";
            line += def.key;
            line += "|r ";
            if (++n % 3 == 0)
            {
                handler->SendSysMessage(line);
                line.clear();
            }
        }
        if (!line.empty())
            handler->SendSysMessage(line);

        handler->SendSysMessage("Stand where you want it and use |cffffff00.camp place <name> [angle]|r.");
        return true;
    }

    static bool HandleCampPlaceCommand(ChatHandler* handler, Optional<std::string> what, Optional<int32> angleDeg)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp yet. Stand somewhere you like and use |cffffff00.camp claim|r.");
            return true;
        }
        Camp const camp = *found;
        uint32 const campMap = camp.map;
        uint8 const campPhaseBit = camp.phaseBit;

        if (!what || what->empty())
        {
            handler->SendSysMessage("Place what? |cffffff00.camp props|r lists everything.");
            return true;
        }

        std::string key = *what;
        std::transform(key.begin(), key.end(), key.begin(),
            [](unsigned char ch) { return char(std::tolower(ch)); });

        PropDef const* def = FindProp(key);
        if (!def)
        {
            handler->PSendSysMessage("There is no '{}'. Try |cffffff00.camp props|r.", key);
            return true;
        }

        // Mailbox checks
        if (def->entry == 142103)
        {
            if (!g_enableMailbox.load())
            {
                handler->SendSysMessage("Mailboxes are disabled on this realm.");
                return true;
            }

            if (QueryResult mr = CharacterDatabase.Query(
                    "SELECT id FROM mod_warband_camp_object WHERE account_id = {} AND entry = 142103 LIMIT 1", accountId))
            {
                handler->SendSysMessage("You already have a mailbox in your camp. (Limit: 1)");
                return true;
            }
        }

        // NPC single-instance check per camp
        if (def->isCreature)
        {
            if (QueryResult cr = CharacterDatabase.Query(
                    "SELECT id FROM mod_warband_camp_creature WHERE account_id = {} AND entry = {} LIMIT 1", accountId, def->entry))
            {
                handler->PSendSysMessage("You already have |cffffff00{}|r in your camp. (Limit: 1)", def->label);
                return true;
            }
        }

        if (me->GetMapId() != campMap ||
            Dist2D(camp.x, camp.y, me->GetPositionX(), me->GetPositionY()) > CAMP_PROP_RADIUS)
        {
            handler->SendSysMessage("You have to be standing in your camp. |cffffff00.camp go|r will take you there.");
            return true;
        }

        if (me->IsInWater() || me->IsFlying() || me->IsInFlight() || me->IsFalling())
        {
            handler->SendSysMessage("Put your feet on the ground first.");
            return true;
        }

        uint32 count = 0;
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM mod_warband_camp_object WHERE account_id = {}", accountId))
            count = r->Fetch()[0].Get<uint32>();
        if (QueryResult rc = CharacterDatabase.Query(
                "SELECT COUNT(*) FROM mod_warband_camp_creature WHERE account_id = {}", accountId))
            count += rc->Fetch()[0].Get<uint32>();

        uint32 const maxProps = g_maxProps.load();
        if (maxProps && count >= maxProps)
        {
            handler->PSendSysMessage("Your camp is full ({} things). Take something down with |cffffff00.camp remove|r.",
                maxProps);
            return true;
        }

        time_t const now = time(nullptr);
        auto const cd = g_propCooldown.find(accountId);
        if (cd != g_propCooldown.end() && now < cd->second)
        {
            handler->SendSysMessage("Steady on - one thing at a time.");
            return true;
        }

        Map* map = me->GetMap();
        float o = me->GetOrientation();
        if (def->isCreature)
            o += float(M_PI);

        // Apply custom rotation offset if supplied
        if (angleDeg)
        {
            float const rad = float(*angleDeg) * float(M_PI) / 180.0f;
            o += rad;
            while (o >= 2.0f * float(M_PI)) o -= 2.0f * float(M_PI);
            while (o < 0.0f) o += 2.0f * float(M_PI);
        }

        float x = me->GetPositionX() + std::cos(me->GetOrientation()) * def->clearance;
        float y = me->GetPositionY() + std::sin(me->GetOrientation()) * def->clearance;

        if (Dist2D(camp.x, camp.y, x, y) > CAMP_RADIUS)
        {
            x = me->GetPositionX();
            y = me->GetPositionY();
            handler->SendSysMessage("That is right on the edge of your camp, so it went down at your feet.");
        }

        float z = me->GetPositionZ();
        float const underMe = map->GetHeight(PHASEMASK_NORMAL,
            me->GetPositionX(), me->GetPositionY(), z + 2.0f, true, MAX_FALL_DISTANCE);
        bool const onStructure = underMe > INVALID_HEIGHT && (z - underMe) > 0.5f;
        if (!onStructure)
        {
            float const groundZ = map->GetHeight(PHASEMASK_NORMAL, x, y,
                z + 2.0f, true, MAX_FALL_DISTANCE);
            if (groundZ > INVALID_HEIGHT && std::fabs(z - groundZ) < 15.0f)
                z = groundZ;
        }

        if (def->isCreature)
        {
            CharacterDatabase.DirectExecute(
                "INSERT INTO mod_warband_camp_creature "
                "(account_id, entry, pos_x, pos_y, pos_z, orientation) "
                "VALUES ({}, {}, {:.4f}, {:.4f}, {:.4f}, {:.4f})",
                accountId, def->entry, x, y, z, o);

            uint64 id = 0;
            if (QueryResult r = CharacterDatabase.Query(
                    "SELECT id FROM mod_warband_camp_creature WHERE account_id = {} ORDER BY id DESC LIMIT 1", accountId))
                id = r->Fetch()[0].Get<uint64>();

            if (!id)
            {
                handler->SendSysMessage("That could not be saved. Please tell an administrator.");
                return true;
            }

            ObjectGuid const guid = SpawnCampCreature(map, def->entry, x, y, z, o, 1u << campPhaseBit);
            if (!guid)
            {
                CharacterDatabase.DirectExecute(
                    "DELETE FROM mod_warband_camp_creature WHERE id = {}", id);
                handler->SendSysMessage("That would not stand up here. Try a step to one side.");
                return true;
            }

            g_liveCreatures[id] = guid;
            g_lastPlacedProp[accountId] = { id, true };
            g_propCooldown[accountId] = now + CAMP_PROP_COOLDOWN_SECONDS;
            if (maxProps)
                handler->PSendSysMessage("|cffffff00{}|r stationed ({} of {}).", def->label, count + 1, maxProps);
            else
                handler->PSendSysMessage("|cffffff00{}|r stationed ({} so far).", def->label, count + 1);
            return true;
        }

        CharacterDatabase.DirectExecute(
            "INSERT INTO mod_warband_camp_object "
            "(account_id, entry, pos_x, pos_y, pos_z, orientation) "
            "VALUES ({}, {}, {:.4f}, {:.4f}, {:.4f}, {:.4f})",
            accountId, def->entry, x, y, z, o);

        uint64 id = 0;
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id FROM mod_warband_camp_object WHERE account_id = {} ORDER BY id DESC LIMIT 1", accountId))
            id = r->Fetch()[0].Get<uint64>();

        if (!id)
        {
            handler->SendSysMessage("That could not be saved. Please tell an administrator.");
            LOG_ERROR("server", "[warbandcamp] prop insert failed for account {} (entry {})",
                accountId, def->entry);
            return true;
        }

        ObjectGuid const guid = SpawnProp(map, def->entry, x, y, z, o, 1u << campPhaseBit);
        if (!guid)
        {
            CharacterDatabase.DirectExecute(
                "DELETE FROM mod_warband_camp_object WHERE id = {}", id);
            handler->SendSysMessage("That would not stand up here. Try a step to one side.");
            return true;
        }

        g_liveProps[id] = guid;
        g_lastPlacedProp[accountId] = { id, false };
        g_propCooldown[accountId] = now + CAMP_PROP_COOLDOWN_SECONDS;
        if (maxProps)
            handler->PSendSysMessage("|cffffff00{}|r set up ({} of {}).", def->label, count + 1, maxProps);
        else
            handler->PSendSysMessage("|cffffff00{}|r set up ({} so far).", def->label, count + 1);
        return true;
    }

    static bool HandleCampUndoCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp.");
            return true;
        }

        uint64 targetId = 0;
        bool isCreature = false;
        auto const it = g_lastPlacedProp.find(accountId);
        if (it != g_lastPlacedProp.end() && it->second.id != 0)
        {
            targetId = it->second.id;
            isCreature = it->second.isCreature;
        }

        if (!targetId)
        {
            uint64 objId = 0;
            uint64 crId = 0;
            if (QueryResult r = CharacterDatabase.Query(
                    "SELECT id FROM mod_warband_camp_object WHERE account_id = {} ORDER BY id DESC LIMIT 1", accountId))
                objId = r->Fetch()[0].Get<uint64>();
            if (QueryResult rc = CharacterDatabase.Query(
                    "SELECT id FROM mod_warband_camp_creature WHERE account_id = {} ORDER BY id DESC LIMIT 1", accountId))
                crId = rc->Fetch()[0].Get<uint64>();

            if (crId > objId)
            {
                targetId = crId;
                isCreature = true;
            }
            else
            {
                targetId = objId;
                isCreature = false;
            }
        }

        if (!targetId)
        {
            handler->SendSysMessage("There are no recent items to undo.");
            return true;
        }

        uint32 entry = 0;
        if (isCreature)
        {
            if (QueryResult r = CharacterDatabase.Query(
                    "SELECT entry FROM mod_warband_camp_creature WHERE id = {}", targetId))
                entry = r->Fetch()[0].Get<uint32>();

            DespawnCampCreature(me->GetMap(), targetId);
            CharacterDatabase.DirectExecute(
                "DELETE FROM mod_warband_camp_creature WHERE id = {}", targetId);
        }
        else
        {
            if (QueryResult r = CharacterDatabase.Query(
                    "SELECT entry FROM mod_warband_camp_object WHERE id = {}", targetId))
                entry = r->Fetch()[0].Get<uint32>();

            DespawnProp(me->GetMap(), targetId);
            CharacterDatabase.DirectExecute(
                "DELETE FROM mod_warband_camp_object WHERE id = {}", targetId);
        }

        g_lastPlacedProp.erase(accountId);

        char const* label = "Last placed item";
        for (PropDef const& def : g_props)
            if (def.entry == entry)
                label = def.label;

        handler->PSendSysMessage("|cffffff00{}|r packed away.", label);
        return true;
    }

    static bool HandleCampRemoveCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp.");
            return true;
        }
        Camp const camp = *found;

        if (me->GetMapId() != camp.map ||
            Dist2D(camp.x, camp.y, me->GetPositionX(), me->GetPositionY()) > CAMP_RADIUS)
        {
            handler->SendSysMessage("You have to be standing in your camp.");
            return true;
        }

        QueryResult ro = CharacterDatabase.Query(
            "SELECT id, entry, pos_x, pos_y FROM mod_warband_camp_object WHERE account_id = {}", accountId);
        QueryResult rc = CharacterDatabase.Query(
            "SELECT id, entry, pos_x, pos_y FROM mod_warband_camp_creature WHERE account_id = {}", accountId);

        if (!ro && !rc)
        {
            handler->SendSysMessage("There is nothing set up here yet.");
            return true;
        }

        uint64 bestId = 0;
        uint32 bestEntry = 0;
        bool bestIsCreature = false;
        float bestDist = 10.0f;

        if (ro)
        {
            do
            {
                Field* f = ro->Fetch();
                float const d = Dist2D(f[2].Get<float>(), f[3].Get<float>(),
                    me->GetPositionX(), me->GetPositionY());
                if (d < bestDist)
                {
                    bestDist = d;
                    bestId = f[0].Get<uint64>();
                    bestEntry = f[1].Get<uint32>();
                    bestIsCreature = false;
                }
            }
            while (ro->NextRow());
        }

        if (rc)
        {
            do
            {
                Field* f = rc->Fetch();
                float const d = Dist2D(f[2].Get<float>(), f[3].Get<float>(),
                    me->GetPositionX(), me->GetPositionY());
                if (d < bestDist)
                {
                    bestDist = d;
                    bestId = f[0].Get<uint64>();
                    bestEntry = f[1].Get<uint32>();
                    bestIsCreature = true;
                }
            }
            while (rc->NextRow());
        }

        if (!bestId)
        {
            handler->SendSysMessage("Stand closer to whatever you want to take down.");
            return true;
        }

        if (bestIsCreature)
        {
            DespawnCampCreature(me->GetMap(), bestId);
            CharacterDatabase.DirectExecute(
                "DELETE FROM mod_warband_camp_creature WHERE id = {}", bestId);
        }
        else
        {
            DespawnProp(me->GetMap(), bestId);
            CharacterDatabase.DirectExecute(
                "DELETE FROM mod_warband_camp_object WHERE id = {}", bestId);
        }

        auto const it = g_lastPlacedProp.find(accountId);
        if (it != g_lastPlacedProp.end() && it->second.id == bestId)
            g_lastPlacedProp.erase(accountId);

        char const* label = "It";
        for (PropDef const& def : g_props)
            if (def.entry == bestEntry)
                label = def.label;

        handler->PSendSysMessage("|cffffff00{}|r packed away.", label);
        return true;
    }

    static bool HandleCampDummyCommand(ChatHandler* handler, Optional<std::string> mode)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        if (!g_enableTrainingDummy.load())
        {
            handler->SendSysMessage("Training Dummies are disabled on this realm.");
            return true;
        }

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp. Stand somewhere you like and use |cffffff00.camp claim|r.");
            return true;
        }
        Camp const camp = *found;

        if (me->GetMapId() != camp.map ||
            Dist2D(camp.x, camp.y, me->GetPositionX(), me->GetPositionY()) > CAMP_PROP_RADIUS)
        {
            handler->SendSysMessage("You have to be standing in your camp.");
            return true;
        }

        std::string action = mode ? *mode : "normal";
        std::transform(action.begin(), action.end(), action.begin(),
            [](unsigned char ch) { return char(std::tolower(ch)); });

        if (action == "remove")
        {
            if (QueryResult r = CharacterDatabase.Query(
                    "SELECT id FROM mod_warband_camp_creature WHERE account_id = {} AND entry IN (31143, 31144, 31146)", accountId))
            {
                do
                {
                    DespawnCampCreature(me->GetMap(), r->Fetch()[0].Get<uint64>());
                }
                while (r->NextRow());
            }

            CharacterDatabase.DirectExecute(
                "DELETE FROM mod_warband_camp_creature WHERE account_id = {} AND entry IN (31143, 31144, 31146)", accountId);
            handler->SendSysMessage("Training Dummy packed away.");
            return true;
        }

        uint32 entry = 31143; // Reinforced Training Dummy (Normal)
        char const* label = "Reinforced Training Dummy";
        if (action == "80")
        {
            entry = 31144; // Grandmaster's Training Dummy (Level 80)
            label = "Grandmaster's Training Dummy (Lvl 80)";
        }
        else if (action == "boss")
        {
            entry = 31146; // Raider's Training Dummy (Boss)
            label = "Raider's Training Dummy (Boss)";
        }

        // Despawn existing dummy if any
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id FROM mod_warband_camp_creature WHERE account_id = {} AND entry IN (31143, 31144, 31146)", accountId))
        {
            do
            {
                DespawnCampCreature(me->GetMap(), r->Fetch()[0].Get<uint64>());
            }
            while (r->NextRow());
        }
        CharacterDatabase.DirectExecute(
            "DELETE FROM mod_warband_camp_creature WHERE account_id = {} AND entry IN (31143, 31144, 31146)", accountId);

        float const x = me->GetPositionX() + std::cos(me->GetOrientation()) * 3.0f;
        float const y = me->GetPositionY() + std::sin(me->GetOrientation()) * 3.0f;
        float const z = me->GetPositionZ();
        float const o = me->GetOrientation() + float(M_PI); // face the player

        CharacterDatabase.DirectExecute(
            "INSERT INTO mod_warband_camp_creature "
            "(account_id, entry, pos_x, pos_y, pos_z, orientation) "
            "VALUES ({}, {}, {:.4f}, {:.4f}, {:.4f}, {:.4f})",
            accountId, entry, x, y, z, o);

        uint64 id = 0;
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id FROM mod_warband_camp_creature WHERE account_id = {} ORDER BY id DESC LIMIT 1", accountId))
            id = r->Fetch()[0].Get<uint64>();

        ObjectGuid const guid = SpawnCampCreature(me->GetMap(), entry, x, y, z, o, 1u << camp.phaseBit);
        if (guid && id)
            g_liveCreatures[id] = guid;

        handler->PSendSysMessage("|cffffff00{}|r stationed.", label);
        return true;
    }

    static bool HandleCampMessageCommand(ChatHandler* handler, Optional<std::string> message)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp. Use |cffffff00.camp claim|r first.");
            return true;
        }

        if (!message || message->empty())
        {
            if (found->greeting.empty())
                handler->SendSysMessage("Your camp has no greeting message. Use |cffffff00.camp message <text>|r.");
            else
                handler->PSendSysMessage("Current greeting: \"|cff00ff00{}|r\". (Use |cffffff00.camp message clear|r to remove)",
                    found->greeting);
            return true;
        }

        if (*message == "clear")
        {
            found->greeting.clear();
            CharacterDatabase.DirectExecute(
                "UPDATE mod_warband_camp SET greeting = '' WHERE account_id = {}", accountId);
            handler->SendSysMessage("Greeting message cleared.");
            return true;
        }

        std::string text = *message;
        if (text.length() > 120)
            text = text.substr(0, 120);

        found->greeting = text;
        CharacterDatabase.Execute(
            "UPDATE mod_warband_camp SET greeting = '{}' WHERE account_id = {}",
            text, accountId);

        handler->PSendSysMessage("Greeting set to: \"|cff00ff00{}|r\"", text);
        return true;
    }

    static bool HandleCampPrivacyCommand(ChatHandler* handler, Optional<std::string> mode)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp. Use |cffffff00.camp claim|r first.");
            return true;
        }

        if (!mode || mode->empty())
        {
            char const* privStr = "Public";
            if (found->privacy == PRIVACY_PARTY)
                privStr = "Party Only";
            else if (found->privacy == PRIVACY_GUILD)
                privStr = "Guild Only";
            else if (found->privacy == PRIVACY_PRIVATE)
                privStr = "Private";

            handler->PSendSysMessage("Current camp privacy: |cffffff00{}|r. Options: |cffffff00public|r, |cffffff00party|r, |cffffff00guild|r, |cffffff00private|r.", privStr);
            return true;
        }

        std::string m = *mode;
        std::transform(m.begin(), m.end(), m.begin(),
            [](unsigned char ch) { return char(std::tolower(ch)); });

        uint8 newPriv = PRIVACY_PUBLIC;
        char const* label = "Public (visible to everyone)";
        if (m == "party")
        {
            newPriv = PRIVACY_PARTY;
            label = "Party Only (visible only to your group)";
        }
        else if (m == "guild")
        {
            newPriv = PRIVACY_GUILD;
            label = "Guild Only (visible only to guild members)";
        }
        else if (m == "private")
        {
            newPriv = PRIVACY_PRIVATE;
            label = "Private (visible only to your account characters)";
        }
        else if (m != "public")
        {
            handler->SendSysMessage("Invalid privacy mode. Choose from: public, party, guild, private.");
            return true;
        }

        found->privacy = newPriv;
        CharacterDatabase.DirectExecute(
            "UPDATE mod_warband_camp SET privacy = {} WHERE account_id = {}",
            newPriv, accountId);

        handler->PSendSysMessage("Camp privacy updated to: |cffffff00{}|r.", label);
        return true;
    }

    static bool HandleCampVisitCommand(ChatHandler* handler, Optional<std::string> who)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        if (!who || who->empty())
        {
            handler->SendSysMessage("Visit whose camp? |cffffff00.camp visit <name>|r, and |cffffff00.camp list|r shows who is camped nearby.");
            return true;
        }

        std::string name = *who;
        if (!normalizePlayerName(name))
        {
            handler->SendSysMessage("That is not a name.");
            return true;
        }

        ObjectGuid const targetGuid = sCharacterCache->GetCharacterGuidByName(name);
        uint32 const targetAccount = targetGuid ? sCharacterCache->GetCharacterAccountIdByGuid(targetGuid) : 0;

        if (!targetAccount)
        {
            handler->PSendSysMessage("No character called {} on this realm.", name);
            return true;
        }

        Camp const* found = FindCamp(targetAccount);
        if (!found)
        {
            handler->PSendSysMessage("{} has not claimed a camp.", name);
            return true;
        }
        Camp const camp = *found;

        if (camp.accountId == me->GetSession()->GetAccountId())
        {
            handler->SendSysMessage("That is your own camp - |cffffff00.camp go|r.");
            return true;
        }

        if (!CanPlayerAccessCamp(me, camp))
        {
            handler->PSendSysMessage("{}'s camp is set to private access.", name);
            return true;
        }

        if (char const* blocked = CampTravelBlocker(me))
        {
            handler->SendSysMessage(blocked);
            return true;
        }

        uint32 const accountId = me->GetSession()->GetAccountId();
        time_t const now = time(nullptr);
        auto const it = g_goCooldown.find(accountId);
        if (it != g_goCooldown.end() && now < it->second)
        {
            handler->PSendSysMessage("You must rest before travelling again ({} seconds).",
                uint32(it->second - now));
            return true;
        }

        float const ax = camp.x + std::cos(camp.o + float(M_PI)) * 12.0f;
        float const ay = camp.y + std::sin(camp.o + float(M_PI)) * 12.0f;
        float az = camp.z;
        if (Map* map = sMapMgr->FindBaseMap(camp.map))
        {
            float const g = map->GetHeight(PHASEMASK_NORMAL, ax, ay,
                camp.z + 10.0f, true, MAX_FALL_DISTANCE);
            if (g > INVALID_HEIGHT && std::fabs(g - camp.z) < 15.0f)
                az = g;
        }

        if (!me->TeleportTo(camp.map, ax, ay, az, std::atan2(camp.y - ay, camp.x - ax)))
        {
            handler->SendSysMessage("Something is keeping you here - you cannot travel right now.");
            return true;
        }

        g_goCooldown[accountId] = now + CAMP_GO_COOLDOWN_SECONDS;
        handler->PSendSysMessage("Travelling to {}'s camp.", name);
        return true;
    }

    static bool HandleCampListCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        if (g_camps.empty())
        {
            handler->SendSysMessage("Nobody has claimed a camp yet. You could be first - |cffffff00.camp claim|r.");
            return true;
        }

        uint32 const mapId = me->GetMapId();
        std::vector<std::pair<float, Camp>> nearby;
        for (Camp const& c : g_camps)
        {
            if (c.map != mapId)
                continue;

            if (!CanPlayerAccessCamp(me, c))
                continue;

            nearby.emplace_back(Dist2D(c.x, c.y, me->GetPositionX(), me->GetPositionY()), c);
        }

        std::sort(nearby.begin(), nearby.end(),
            [](auto const& a, auto const& b) { return a.first < b.first; });

        handler->PSendSysMessage("{} camps accessible on this continent, {} in the world:",
            uint32(nearby.size()), uint32(g_camps.size()));

        uint32 shown = 0;
        for (auto const& [dist, c] : nearby)
        {
            if (shown++ >= 8)
                break;

            std::string const owner = GetCampOwnerName(c.accountId);

            char const* zone = "somewhere";
            if (AreaTableEntry const* area = sAreaTableStore.LookupEntry(c.zoneId))
                zone = area->area_name[0];

            handler->PSendSysMessage("  |cffffff00{}|r in {} ({} yards away)",
                owner, zone, uint32(dist));
        }

        if (nearby.size() > shown)
            handler->PSendSysMessage("  ...and {} more.", uint32(nearby.size() - shown));

        handler->SendSysMessage("|cffffff00.camp visit <name>|r to go and have a look.");
        return true;
    }

    static bool HandleCampCatalogueCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("Claim a camp first, somewhere flat and open.");
            return true;
        }
        Camp const camp = *found;

        if (me->GetMapId() != camp.map ||
            Dist2D(camp.x, camp.y, me->GetPositionX(), me->GetPositionY()) > CAMP_RADIUS)
        {
            handler->SendSysMessage("Stand in your camp first - |cffffff00.camp go|r.");
            return true;
        }

        Map* map = me->GetMap();

        if (QueryResult r = CharacterDatabase.Query(
                "SELECT id FROM mod_warband_camp_object WHERE account_id = {}", accountId))
        {
            do
            {
                DespawnProp(map, r->Fetch()[0].Get<uint64>());
            }
            while (r->NextRow());
        }
        CharacterDatabase.DirectExecute(
            "DELETE FROM mod_warband_camp_object WHERE account_id = {}", accountId);

        constexpr float SPACING = 7.0f;
        constexpr int COLS = 8;
        constexpr float CATALOGUE_MAX_DROP = 6.0f;

        struct Slot { float x, y, z, d; };
        std::vector<Slot> slots;
        for (int gx = 0; gx < COLS; ++gx)
        {
            for (int gy = 0; gy < COLS; ++gy)
            {
                float const x = camp.x + (float(gx) - 3.5f) * SPACING;
                float const y = camp.y + (float(gy) - 3.5f) * SPACING;

                float const z = map->GetHeight(PHASEMASK_NORMAL, x, y,
                    camp.z + 20.0f, true, MAX_FALL_DISTANCE);
                if (z <= INVALID_HEIGHT)
                    continue;
                if (std::fabs(z - camp.z) > CATALOGUE_MAX_DROP)
                    continue;

                slots.push_back({ x, y, z, Dist2D(camp.x, camp.y, x, y) });
            }
        }

        std::sort(slots.begin(), slots.end(),
            [](Slot const& a, Slot const& b) { return a.d < b.d; });

        uint32 placed = 0, skipped = 0;
        for (size_t i = 0; i < g_props.size(); ++i)
        {
            if (i >= slots.size())
            {
                ++skipped;
                continue;
            }

            float const x = slots[i].x;
            float const y = slots[i].y;
            float const z = slots[i].z;

            CharacterDatabase.DirectExecute(
                "INSERT INTO mod_warband_camp_object "
                "(account_id, entry, pos_x, pos_y, pos_z, orientation) "
                "VALUES ({}, {}, {:.4f}, {:.4f}, {:.4f}, 0)",
                accountId, g_props[i].entry, x, y, z);

            uint64 id = 0;
            if (QueryResult r = CharacterDatabase.Query(
                    "SELECT id FROM mod_warband_camp_object WHERE account_id = {} ORDER BY id DESC LIMIT 1", accountId))
                id = r->Fetch()[0].Get<uint64>();

            ObjectGuid const guid = SpawnProp(map, g_props[i].entry, x, y, z, 0.0f, 1u << camp.phaseBit);
            if (guid && id)
            {
                g_liveProps[id] = guid;
                ++placed;
            }
            else
            {
                ++skipped;
            }
        }

        handler->PSendSysMessage("Catalogue laid out: {} placed, {} skipped ({} slots passed flatness check).",
            placed, skipped, uint32(slots.size()));

        if (skipped)
            handler->SendSysMessage("Not enough level ground here for all of them - try somewhere flatter.");

        handler->SendSysMessage("In order, from where you stand outwards:");
        std::string line;
        uint32 n = 0;
        for (size_t i = 0; i < g_props.size() && i < slots.size(); ++i)
        {
            line += g_props[i].label;
            if (++n % 5 == 0 || i + 1 == g_props.size() || i + 1 == slots.size())
            {
                handler->SendSysMessage(line);
                line.clear();
            }
            else
            {
                line += ", ";
            }
        }

        LOG_INFO("server", "[warbandcamp] account {} ({}) laid out the catalogue: {} placed, {} skipped",
            accountId, me->GetName(), placed, skipped);
        return true;
    }

    static bool HandleCampAltsCommand(ChatHandler* handler)
    {
        Player* me = nullptr;
        if (!Gate(handler, me))
            return true;

#if !defined(MOD_PLAYERBOTS)
        handler->SendSysMessage("The warband alts feature requires mod-playerbots to be installed.");
        return true;
#else
        std::lock_guard<std::mutex> lock(g_campMutex);

        uint32 const accountId = me->GetSession()->GetAccountId();
        Camp const* found = FindCamp(accountId);
        if (!found)
        {
            handler->SendSysMessage("You have no camp for them to gather at. |cffffff00.camp claim|r first.");
            return true;
        }
        Camp const camp = *found;

        if (me->GetMapId() != camp.map ||
            Dist2D(camp.x, camp.y, me->GetPositionX(), me->GetPositionY()) > CAMP_RADIUS)
        {
            handler->SendSysMessage("Stand in your camp first - |cffffff00.camp go|r.");
            return true;
        }

        EnqueueAltGather(me, accountId, 0);

        if (g_altGathers.empty() || g_altGathers.back().accountId != accountId)
        {
            handler->SendSysMessage("You have no other characters on this realm.");
            return true;
        }

        handler->SendSysMessage("Your warband is being roused - they will gather at the fire over the next few moments.");
        LOG_INFO("server", "[warbandcamp] account {} ({}) queued an alt gathering ({} names)",
            accountId, me->GetName(), g_altGathers.back().names.size());
        return true;
#endif
    }

    static bool HandleCampReloadCommand(ChatHandler* handler)
    {
        g_enabled = sConfigMgr->GetOption<bool>("WarbandCamp.Enabled", true);
        g_maxProps = sConfigMgr->GetOption<uint32>("WarbandCamp.MaxProps", 200);
        g_enableRestedXP = sConfigMgr->GetOption<bool>("WarbandCamp.EnableRestedXP", true);
        g_enableMailbox = sConfigMgr->GetOption<bool>("WarbandCamp.EnableMailbox", true);
        g_enableTrainingDummy = sConfigMgr->GetOption<bool>("WarbandCamp.EnableTrainingDummy", true);
        g_inactivityDays = sConfigMgr->GetOption<uint32>("WarbandCamp.InactivityDays", 90);

        float view = sConfigMgr->GetOption<float>("WarbandCamp.ViewDistance", 40.0f);
        if (view != 0.0f)
            view = std::clamp(view, 20.0f, 250.0f);
        g_viewDist = view;

        ParseCommaDelimitedSet(sConfigMgr->GetOption<std::string>("WarbandCamp.BlacklistedMaps", ""), g_blacklistedMaps);
        ParseCommaDelimitedSet(sConfigMgr->GetOption<std::string>("WarbandCamp.BlacklistedZones", ""), g_blacklistedZones);

        handler->SendSysMessage("Warband Camp configuration reloaded.");
        LOG_INFO("server", "[warbandcamp] Configuration reloaded by admin.");
        return true;
    }

    static bool HandleCampDiagCommand(ChatHandler* handler, std::string name)
    {
        Player* target = ObjectAccessor::FindPlayerByName(name, true);
        if (!target)
        {
            handler->PSendSysMessage("No online character called '{}'.", name);
            return true;
        }

        Map* map = target->GetMap();
        if (!map)
        {
            handler->SendSysMessage("That character has no map.");
            return true;
        }

        float const x = target->GetPositionX();
        float const y = target->GetPositionY();
        float const z = target->GetPositionZ();

        handler->PSendSysMessage("--- warband diag: {} ---", target->GetName());
        handler->PSendSysMessage("map {} zone {} area {} at {:.1f} {:.1f} {:.1f}",
            map->GetId(), target->GetZoneId(), target->GetAreaId(), x, y, z);

        char const* zoneName = "?";
        if (AreaTableEntry const* a = sAreaTableStore.LookupEntry(target->GetZoneId()))
            zoneName = a->area_name[0];
        handler->PSendSysMessage("zone name: {}", zoneName);

        float const groundZ = map->GetHeight(target->GetPhaseMask(), x, y, z, true, MAX_FALL_DISTANCE);
        handler->PSendSysMessage("outdoors {} | ground {:.2f} (delta {:.2f}) | water {} | phase {}",
            target->IsOutdoors() ? "yes" : "no", groundZ, z - groundZ,
            target->IsInWater() ? "yes" : "no", target->GetPhaseMask());

        std::lock_guard<std::mutex> lock(g_campMutex);

        char const* blocked = CampSiteBlocker(target);
        handler->PSendSysMessage("claim here: {}", blocked ? blocked : "ALLOWED");

        uint8 const bit = PickPhaseBit(map->GetId(), x, y);
        handler->PSendSysMessage("phase bit offered: {} | camps on realm: {}", bit, g_camps.size());

        uint32 const testEntry = g_props.empty() ? 0 : g_props[0].entry;
        if (!testEntry)
        {
            handler->SendSysMessage("prop spawn: SKIPPED (empty catalogue)");
            return true;
        }

        ObjectGuid const guid = SpawnProp(map, testEntry, x, y, z, 0.0f, 1u << CAMP_PHASE_BIT_MAX);
        if (!guid)
        {
            handler->PSendSysMessage("prop spawn: |cffff2020FAILED|r - GameObject::Create or AddToMap rejected entry {}", testEntry);
            LOG_ERROR("server", "[warbandcamp] diag: spawn of {} FAILED on map {}", testEntry, map->GetId());
            return true;
        }

        GameObject* go = map->GetGameObject(guid);
        handler->PSendSysMessage("prop spawn: |cff20ff20OK|r entry {} guid {} | in map: {} | visible-phase {}",
            testEntry, guid.GetCounter(), go ? "yes" : "NO", go ? go->GetPhaseMask() : 0);

        if (go)
        {
            go->SetRespawnTime(0);
            go->Delete();
        }

        uint32 const beforeMask = target->GetPhaseMask();
        Camp probe;
        probe.accountId = 0xFFFFFFFF;
        probe.map = map->GetId();
        probe.x = x;
        probe.y = y;
        probe.z = z;
        probe.phaseBit = bit ? bit : CAMP_PHASE_BIT_MIN;
        probe.zoneId = target->GetZoneId();
        g_camps.push_back(probe);

        PlayerCampState st;
        UpdatePlayerCampPhase(target, st);
        uint32 const inCampMask = target->GetPhaseMask();
        uint32 const wantMask = PHASEMASK_NORMAL | (1u << probe.phaseBit);

        ClearCampPhase(target, st);
        uint32 const afterMask = target->GetPhaseMask();

        g_camps.pop_back();

        bool const phasedIn = (inCampMask == wantMask);
        bool const restored = (afterMask == beforeMask);
        handler->PSendSysMessage("phase in:  {} (mask {} -> {}, wanted {})",
            phasedIn ? "|cff20ff20OK|r" : "|cffff2020FAILED|r", beforeMask, inCampMask, wantMask);
        handler->PSendSysMessage("phase out: {} (mask back to {})",
            restored ? "|cff20ff20OK|r" : "|cffff2020FAILED|r", afterMask);

        if (!phasedIn || !restored)
            LOG_ERROR("server", "[warbandcamp] diag: phase pipeline broken for {} ({} -> {} -> {}, wanted {})",
                target->GetName(), beforeMask, inCampMask, afterMask, wantMask);

        handler->SendSysMessage("done. nothing was changed.");
        return true;
    }
};

// -------------------------------------------------------------------------
// Player Script
// -------------------------------------------------------------------------
class WarbandCampPlayer : public PlayerScript
{
public:
    WarbandCampPlayer()
        : PlayerScript("WarbandCampPlayer",
            { PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_LOGOUT,
              PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_LOGIN })
    {
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!g_enabled.load() || !IsWarbandRealPlayer(player))
            return;

        std::lock_guard<std::mutex> lock(g_campMutex);

        PlayerCampState& st = g_playerState[player->GetGUID()];
        if (st.timer > diff)
        {
            st.timer -= diff;
            return;
        }
        st.timer = CAMP_PROXIMITY_INTERVAL_MS;

        UpdatePlayerCampPhase(player, st);
    }

    void OnPlayerMapChanged(Player* player) override
    {
        if (!IsWarbandRealPlayer(player))
            return;

        std::lock_guard<std::mutex> lock(g_campMutex);
        auto const it = g_playerState.find(player->GetGUID());
        if (it != g_playerState.end())
            ClearCampPhase(player, it->second);
    }

    void OnPlayerLogout(Player* player) override
    {
        std::lock_guard<std::mutex> lock(g_campMutex);
        g_playerState.erase(player->GetGUID());
        g_parkedAlts.erase(player->GetGUID().GetCounter());
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!g_enabled.load() || !IsWarbandRealPlayer(player))
            return;

        uint32 const accountId = player->GetSession()->GetAccountId();

        // Update camp activity timestamp
        {
            std::lock_guard<std::mutex> lock(g_campMutex);
            g_playerState[player->GetGUID()].timer = CAMP_LOGIN_PHASE_DELAY_MS;
            if (Camp* c = FindCamp(accountId))
            {
                c->lastActive = uint32(time(nullptr));
                CharacterDatabase.DirectExecute(
                    "UPDATE mod_warband_camp SET last_active = {} WHERE account_id = {}",
                    c->lastActive, accountId);
            }
        }

        uint32 const lowGuid = player->GetGUID().GetCounter();
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT map, pos_x, pos_y, pos_z, orientation "
                "FROM mod_warband_alt_origin WHERE guid = {}", lowGuid))
        {
            bool restore = false;
            {
                std::lock_guard<std::mutex> lock(g_campMutex);
                g_parkedAlts.erase(lowGuid);
                if (Camp const* c = FindCamp(accountId))
                    restore = c->map == player->GetMapId() &&
                        Dist2D(c->x, c->y, player->GetPositionX(), player->GetPositionY()) < CAMP_RADIUS + 20.0f;
            }
            CharacterDatabase.Execute(
                "DELETE FROM mod_warband_alt_origin WHERE guid = {}", lowGuid);

            if (restore)
            {
                Field* f = r->Fetch();
                uint32 const map = f[0].Get<uint32>();
                float const x = f[1].Get<float>();
                float const y = f[2].Get<float>();
                float const z = f[3].Get<float>();
                float const o = f[4].Get<float>();
                ObjectGuid const pg = player->GetGUID();
                player->m_Events.AddEventAtOffset([pg, map, x, y, z, o]()
                {
                    Player* p = ObjectAccessor::FindPlayer(pg);
                    if (!p || !p->IsInWorld() || p->IsBeingTeleported())
                        return;
                    if (p->TeleportTo(map, x, y, z, o))
                        ChatHandler(p->GetSession()).SendSysMessage(
                            "Back where you left off - the camp kept your seat warm.");
                }, Milliseconds(2500));
            }
        }

#if defined(MOD_PLAYERBOTS)
        if (!g_autoAlts.load())
            return;

        std::lock_guard<std::mutex> lock(g_campMutex);
        if (!FindCamp(accountId))
            return;

        EnqueueAltGather(player, accountId, 5);
#endif
    }
};

// -------------------------------------------------------------------------
// World Script
// -------------------------------------------------------------------------
class WarbandCampWorld : public WorldScript
{
public:
    WarbandCampWorld()
        : WorldScript("WarbandCampWorld",
            { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP,
              WORLDHOOK_ON_UPDATE })
    {
    }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        g_enabled = sConfigMgr->GetOption<bool>(
            "WarbandCamp.Enabled",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.Enabled", true));

        g_autoAlts = sConfigMgr->GetOption<bool>(
            "WarbandCamp.AutoAlts",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.AutoAlts", true));

        g_maxProps = sConfigMgr->GetOption<uint32>(
            "WarbandCamp.MaxProps",
            sConfigMgr->GetOption<uint32>("WowLegends.WarbandCamp.MaxProps", 200));

        float view = sConfigMgr->GetOption<float>(
            "WarbandCamp.ViewDistance",
            sConfigMgr->GetOption<float>("WowLegends.WarbandCamp.ViewDistance", 40.0f));
        if (view != 0.0f)
            view = std::clamp(view, 20.0f, 250.0f);
        g_viewDist = view;

        g_altsSameFactionOnly = sConfigMgr->GetOption<bool>(
            "WarbandCamp.AltsSameFactionOnly",
            sConfigMgr->GetOption<bool>("WowLegends.WarbandCamp.AltsSameFactionOnly", true));

        g_enableRestedXP = sConfigMgr->GetOption<bool>("WarbandCamp.EnableRestedXP", true);
        g_enableMailbox = sConfigMgr->GetOption<bool>("WarbandCamp.EnableMailbox", true);
        g_enableTrainingDummy = sConfigMgr->GetOption<bool>("WarbandCamp.EnableTrainingDummy", true);
        g_inactivityDays = sConfigMgr->GetOption<uint32>("WarbandCamp.InactivityDays", 90);

        ParseCommaDelimitedSet(sConfigMgr->GetOption<std::string>("WarbandCamp.BlacklistedMaps", ""), g_blacklistedMaps);
        ParseCommaDelimitedSet(sConfigMgr->GetOption<std::string>("WarbandCamp.BlacklistedZones", ""), g_blacklistedZones);
    }

    void OnUpdate(uint32 diff) override
    {
#if defined(MOD_PLAYERBOTS)
        m_seaterTimer += diff;
        if (m_seaterTimer < 2000)
            return;
        m_seaterTimer = 0;

        if (!g_enabled.load())
            return;

        std::lock_guard<std::mutex> lock(g_campMutex);
        if (g_altGathers.empty())
            return;

        time_t const now = time(nullptr);
        for (auto it = g_altGathers.begin(); it != g_altGathers.end();)
        {
            AltGather& g = *it;
            Player* owner = ObjectAccessor::FindPlayer(g.owner);
            Camp const* camp = FindCamp(g.accountId);

            if (!owner || !camp || now > g.deadline)
            {
                it = g_altGathers.erase(it);
                continue;
            }

            if (g.wakeAt)
            {
                if (now < g.wakeAt)
                {
                    ++it;
                    continue;
                }

                uint32 woken = 0;
                for (std::string const& name : g.names)
                {
                    if (!ObjectAccessor::FindPlayerByName(name, true))
                    {
                        ChatHandler(owner->GetSession()).ParseCommands(".playerbots bot add " + name);
                        ++woken;
                    }
                }
                g.wakeAt = 0;

                if (!g.announced && woken)
                {
                    ChatHandler(owner->GetSession()).SendSysMessage("Your warband stirs...");
                    g.announced = true;
                }
                ++it;
                continue;
            }

            for (auto nameIt = g.names.begin(); nameIt != g.names.end();)
            {
                Player* alt = ObjectAccessor::FindPlayerByName(*nameIt, true);
                if (!alt)
                {
                    ++nameIt;
                    continue;
                }

                if (!alt->GetSession() || !alt->GetSession()->IsBot())
                {
                    nameIt = g.names.erase(nameIt);
                    continue;
                }

                if (SeatAltAtCamp(alt, *camp, g.seated))
                    ++g.seated;
                nameIt = g.names.erase(nameIt);
            }

            if (g.names.empty())
            {
                if (g.seated)
                    ChatHandler(owner->GetSession()).PSendSysMessage(
                        "{} of your warband are settled at the fire.", g.seated);
                it = g_altGathers.erase(it);
                continue;
            }
            ++it;
        }
#else
        (void)diff;
#endif
    }

    void OnStartup() override
    {
        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS mod_warband_camp ("
            "account_id INT UNSIGNED NOT NULL, "
            "map SMALLINT UNSIGNED NOT NULL, "
            "pos_x FLOAT NOT NULL, "
            "pos_y FLOAT NOT NULL, "
            "pos_z FLOAT NOT NULL, "
            "orientation FLOAT NOT NULL, "
            "phase_bit TINYINT UNSIGNED NOT NULL, "
            "zone_id INT UNSIGNED NOT NULL DEFAULT 0, "
            "privacy TINYINT UNSIGNED NOT NULL DEFAULT 0, "
            "greeting VARCHAR(255) NOT NULL DEFAULT '', "
            "last_active INT UNSIGNED NOT NULL DEFAULT 0, "
            "claimed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
            "PRIMARY KEY (account_id), "
            "KEY idx_map (map)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 "
            "COLLATE=utf8mb4_unicode_ci");

        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS mod_warband_alt_origin ("
            "  guid INT UNSIGNED NOT NULL PRIMARY KEY,"
            "  map INT UNSIGNED NOT NULL,"
            "  pos_x FLOAT NOT NULL, pos_y FLOAT NOT NULL,"
            "  pos_z FLOAT NOT NULL, orientation FLOAT NOT NULL,"
            "  parked_at INT UNSIGNED NOT NULL"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS mod_warband_camp_object ("
            "id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, "
            "account_id INT UNSIGNED NOT NULL, "
            "entry INT UNSIGNED NOT NULL, "
            "pos_x FLOAT NOT NULL, "
            "pos_y FLOAT NOT NULL, "
            "pos_z FLOAT NOT NULL, "
            "orientation FLOAT NOT NULL, "
            "placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
            "PRIMARY KEY (id), "
            "KEY idx_account (account_id)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 "
            "COLLATE=utf8mb4_unicode_ci");

        CharacterDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS mod_warband_camp_creature ("
            "id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, "
            "account_id INT UNSIGNED NOT NULL, "
            "entry INT UNSIGNED NOT NULL, "
            "pos_x FLOAT NOT NULL, "
            "pos_y FLOAT NOT NULL, "
            "pos_z FLOAT NOT NULL, "
            "orientation FLOAT NOT NULL, "
            "spawned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
            "PRIMARY KEY (id), "
            "KEY idx_account (account_id)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 "
            "COLLATE=utf8mb4_unicode_ci");

        // Self-healing column additions for existing tables
        if (!CharacterDatabase.Query("SHOW COLUMNS FROM mod_warband_camp LIKE 'privacy'"))
            CharacterDatabase.DirectExecute("ALTER TABLE mod_warband_camp ADD COLUMN privacy TINYINT UNSIGNED NOT NULL DEFAULT 0");

        if (!CharacterDatabase.Query("SHOW COLUMNS FROM mod_warband_camp LIKE 'greeting'"))
            CharacterDatabase.DirectExecute("ALTER TABLE mod_warband_camp ADD COLUMN greeting VARCHAR(255) NOT NULL DEFAULT ''");

        if (!CharacterDatabase.Query("SHOW COLUMNS FROM mod_warband_camp LIKE 'last_active'"))
            CharacterDatabase.DirectExecute("ALTER TABLE mod_warband_camp ADD COLUMN last_active INT UNSIGNED NOT NULL DEFAULT 0");

        // Backward compatibility migration from legacy wowlegends tables if present:
        if (CharacterDatabase.Query("SHOW TABLES LIKE 'wowlegends_warband_camp'"))
        {
            QueryResult checkNew = CharacterDatabase.Query("SELECT COUNT(*) FROM mod_warband_camp");
            if (checkNew && checkNew->Fetch()[0].Get<uint64>() == 0)
            {
                LOG_INFO("server", "[warbandcamp] Migrating camps from legacy wowlegends_warband_camp table...");
                CharacterDatabase.DirectExecute(
                    "INSERT IGNORE INTO mod_warband_camp "
                    "(account_id, map, pos_x, pos_y, pos_z, orientation, phase_bit, zone_id, claimed_at) "
                    "SELECT account_id, map, pos_x, pos_y, pos_z, orientation, phase_bit, zone_id, claimed_at "
                    "FROM wowlegends_warband_camp");
            }
        }
        if (CharacterDatabase.Query("SHOW TABLES LIKE 'wowlegends_warband_camp_object'"))
        {
            QueryResult checkNew = CharacterDatabase.Query("SELECT COUNT(*) FROM mod_warband_camp_object");
            if (checkNew && checkNew->Fetch()[0].Get<uint64>() == 0)
            {
                LOG_INFO("server", "[warbandcamp] Migrating objects from legacy wowlegends_warband_camp_object table...");
                CharacterDatabase.DirectExecute(
                    "INSERT IGNORE INTO mod_warband_camp_object "
                    "(id, account_id, entry, pos_x, pos_y, pos_z, orientation, placed_at) "
                    "SELECT id, account_id, entry, pos_x, pos_y, pos_z, orientation, placed_at "
                    "FROM wowlegends_warband_camp_object");
            }
        }

        // Prune abandoned camps past inactivity threshold
        uint32 const inactDays = g_inactivityDays.load();
        if (inactDays > 0)
        {
            uint32 const cutoff = uint32(time(nullptr)) - (inactDays * 86400);
            QueryResult expired = CharacterDatabase.Query(
                "SELECT account_id FROM mod_warband_camp WHERE last_active > 0 AND last_active < {}", cutoff);
            if (expired)
            {
                uint32 pruned = 0;
                do
                {
                    uint32 const expAcc = expired->Fetch()[0].Get<uint32>();
                    CharacterDatabase.DirectExecute(
                        "DELETE FROM mod_warband_camp_object WHERE account_id = {}", expAcc);
                    CharacterDatabase.DirectExecute(
                        "DELETE FROM mod_warband_camp_creature WHERE account_id = {}", expAcc);
                    CharacterDatabase.DirectExecute(
                        "DELETE FROM mod_warband_camp WHERE account_id = {}", expAcc);
                    ++pruned;
                }
                while (expired->NextRow());

                if (pruned)
                    LOG_INFO("server", "[warbandcamp] Pruned {} abandoned camps inactive for >{} days", pruned, inactDays);
            }
        }

        BuildPropCatalogue();

        std::lock_guard<std::mutex> lock(g_campMutex);
        g_camps.clear();
        if (QueryResult r = CharacterDatabase.Query(
                "SELECT account_id, map, pos_x, pos_y, pos_z, orientation, phase_bit, zone_id, privacy, greeting, last_active "
                "FROM mod_warband_camp"))
        {
            do
            {
                Field* f = r->Fetch();
                Camp c;
                c.accountId = f[0].Get<uint32>();
                c.map = f[1].Get<uint16>();
                c.x = f[2].Get<float>();
                c.y = f[3].Get<float>();
                c.z = f[4].Get<float>();
                c.o = f[5].Get<float>();
                c.phaseBit = f[6].Get<uint8>();
                c.zoneId = f[7].Get<uint32>();
                c.privacy = f[8].Get<uint8>();
                c.greeting = f[9].Get<std::string>();
                c.lastActive = f[10].Get<uint32>();
                g_camps.push_back(c);
            }
            while (r->NextRow());
        }

        LOG_INFO("server", "[warbandcamp] {} camps loaded", g_camps.size());
    }

private:
    uint32 m_seaterTimer = 0;
};

void AddWarbandCampScripts()
{
    new WarbandCampCommand();
    new WarbandCampPlayer();
    new WarbandCampWorld();
}
