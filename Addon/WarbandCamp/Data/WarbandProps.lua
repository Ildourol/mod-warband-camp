-- WarbandCamp/Data/WarbandProps.lua
-- The Warband Camp prop & NPC catalogue: category -> { key, label } pairs.
-- key = what `.camp place <key>` expects · label = what the player sees.

local addonName, WBC = ...

WBC.WarbandProps = {
    catalogueVersion = "1.4.0",
    categories = {
        { name = "Shelter", props = {
            { "tent", "Tent" }, { "tent-a", "Alliance Tent" }, { "tent-h", "Horde Tent" },
            { "foodtent", "Food Tent" }, { "tent-dwarf", "Dwarven Tent" }, { "tent-orc", "Orc Scout Tent" },
            { "tent-undead", "Forsaken Tent" }, { "tent-scourge", "Scourge Tent" }, { "canopy", "Open Canopy" },
            { "tent-carnival", "Carnival Tent" }, { "tent-shattrath", "Shattrath Pavilion Tent" }, { "tent-shadow", "Shadow Council Tent" },
            { "tent-goblin", "Goblin Striped Tent" }, { "tent-forsaken-large", "Forsaken Pavilion Tent" }, { "tent-shadow-large", "Shadow Council Pavilion" },
            { "tent-wotlk-light", "Argent Light Tent" }, { "tent-orc-war", "Orc War Camp Tent" }, { "tent-nelf", "Night Elven Pavilion" },
            { "tent-excavation", "Excavation Canopy Tent" }, { "tent-souvenir", "Festival Fair Tent" }, { "tent-fortune", "Fortune Teller Tent" },
            { "tent-argent-outpost", "Argent Outpost Tent" }, { "tent-durotar-large", "Durotar Large Tent" }, { "tent-goblin-dome", "Goblin Domed Tent" },
        } },
        { name = "Fire & Light", props = {
            { "campfire", "Campfire" }, { "bonfire", "Bonfire" }, { "brazier", "Brazier" },
            { "lantern", "Lantern" }, { "bonfire-blue", "Blue Fire Bonfire" }, { "bonfire-orc", "Orc Bonfire" },
            { "brazier-festival", "Festival Brazier" }, { "brazier-ogre", "Purple Ogre Brazier" }, { "brazier-legion", "Legion Brazier" },
            { "bowl-fire", "Elven Fire Bowl" }, { "fire-soul", "Green Soulfire" }, { "fire-soul-large", "Large Soulfire Pit" },
            { "brazier-brewfest", "Brewfest Fire Basin" }, { "brazier-midsummer", "Grand Midsummer Brazier" },
        } },
        { name = "Furniture", props = {
            { "table", "Table" }, { "chair", "Chair" }, { "bench", "Bench" },
            { "rug", "Rug" }, { "bookshelf", "Bookshelf" }, { "bookcase", "Bookcase" },
            { "bunkbed", "Bunkbed" }, { "bed-stone", "Stone Bed" }, { "chair-dalaran", "Dalaran Chair" },
            { "stool-elven", "Elven Stool" }, { "bench-orc", "Orc Bench" }, { "bench-wood", "Duskwood Bench" },
            { "table-elven", "Elven Table" }, { "table-orc", "Orc Table" }, { "table-dwarf", "Dwarven Table" },
            { "throne", "Chieftain Throne" }, { "wardrobe", "Wardrobe" }, { "rug-sw", "Stormwind Rug" },
            { "rug-tauren", "Tauren Rug" }, { "rug-fur", "Vrykul Fur Rug" }, { "chair-westfall", "Rustic Wood Chair" },
            { "table-party", "Small Tavern Table" }, { "table-dwarf-small", "Small Dwarven Table" }, { "table-duskwood", "Carved Oak Table" },
            { "rug-bearskin", "Bearskin Rug" }, { "table-round", "Round Ironridge Table" }, { "table-bloodelf", "Blood Elf Table" },
        } },
        { name = "Storage & Amenities", props = {
            { "crate", "Supply Crate" }, { "crate-h", "Horde Crate" }, { "barrel", "Barrel" },
            { "keg", "Keg" }, { "cauldron", "Cauldron" }, { "cookpot", "Cook Pot" },
            { "mailbox", "Mailbox" }, { "chest-ornate", "Ornate Chest" }, { "chest-reinforced", "Reinforced Chest" },
            { "keg-brewfest", "Brewfest Ale Keg" }, { "tub", "Washing Tub" }, { "basin", "Water Basin" },
            { "crate-orc", "Orc Crate" }, { "crate-grain", "Grain Crate" }, { "barrel-plague", "Plague Barrel" },
            { "barrel-broken", "Broken Barrel" }, { "powderkeg", "Dwarven Powder Keg" }, { "crate-replace", "Reinforced Cargo Crate" },
            { "crate-brewfest", "Brewfest Crate" }, { "chest-treasure", "Treasure Chest" },
        } },
        { name = "Yard", props = {
            { "wagon", "Wagon" }, { "haystack", "Haystack" }, { "haybale", "Hay Bale" },
            { "woodpile", "Wood Pile" }, { "logpile", "Log Pile" }, { "fence", "Fence" },
            { "rockwall", "Rockwall Fence" }, { "pumpkin", "Pumpkin" }, { "wheelbarrow", "Wheelbarrow" },
            { "target-archery", "Archery Target" }, { "target-dwarf", "Dwarf Target Dummy" }, { "target-ogre", "Ogre Target Dummy" },
            { "barricade", "Trench Barricade" }, { "cart-broken", "Broken Cart" }, { "cart-rocket", "Rocket Cart" },
            { "fence-spiked", "Spiked Iron Fence" }, { "lightwell", "Holy Light Well" }, { "fountain-elven", "Elven Fountain" },
            { "rowboat", "Wooden Rowboat" }, { "haypile-large", "Vrykul Straw Pile" }, { "target-human", "Straw Archery Target" },
            { "cannonball-stack", "Iron Cannonball Stack" },
        } },
        { name = "Craft", props = {
            { "anvil", "Anvil" }, { "forge", "Forge" }, { "coals", "Forge Coals" },
            { "weaponrack", "Weapon Rack" }, { "toolbox", "Blacksmith Toolbox" }, { "rack-scourge", "Scourge Weapon Rack" },
            { "rack-blades", "Scourge Blade Rack" }, { "grinder", "Gem Grinder" }, { "runeforge", "Scourge Runeforge" },
            { "hammer", "Smithing Hammer" }, { "armorstand", "Armor Display Stand" }, { "armorstand-mail", "Mail Armor Mannequin" },
            { "steamtank", "Gnomish Steam Tank" },
        } },
        { name = "Defenses & Fortifications", props = {
            { "barricade-wood", "Reinforced Wooden Barricade" }, { "barricade-spikes", "Spiked Defensive Barricade" }, { "siege-catapult", "Horde Catapult" },
            { "siege-cannon", "Ironclad Field Cannon" }, { "gate-portcullis", "Cemetery Portcullis Gate" }, { "wall-palisade-orc", "Orc Palisade Wall" },
            { "wall-spike-defensive", "Spiked Defensive Palisade" }, { "spike-heavy", "Heavy Defensive Ground Spike" }, { "gate-pvp", "Fortified Iron Gate" },
            { "cannon-base", "Heavy Siege Mount" },
        } },
        { name = "Banners", props = {
            { "banner", "Banner" }, { "banner-a", "Alliance Banner" }, { "banner-h", "Horde Banner" },
            { "banner-sw", "Stormwind Banner" }, { "banner-org", "Orgrimmar Banner" }, { "banner-if", "Ironforge Banner" },
            { "banner-dar", "Darnassus Banner" }, { "banner-gnome", "Gnomeregan Banner" }, { "banner-exo", "Exodar Banner" },
            { "banner-tb", "Thunder Bluff Banner" }, { "banner-uc", "Undercity Banner" }, { "banner-smc", "Silvermoon Banner" },
            { "banner-senjin", "Sen'jin Banner" }, { "banner-sun", "Shattered Sun Banner" }, { "banner-fk", "Forsaken Banner" },
            { "banner-argent", "Argent Crusade Standing Banner" }, { "banner-maghar", "Mag'har Clan Battle Standard" }, { "banner-ogre-boar", "Bladespire Clan Standard" },
            { "banner-ogre-tiger", "Bloodmaul Clan Standard" }, { "banner-warrior", "Warrior Crest Banner" },
        } },
        { name = "Lights", props = {
            { "torch", "Torch" }, { "candle", "Candle" }, { "candelabra", "Candelabra" },
            { "torch-stand", "Standing Torch" }, { "lamp-alliance", "Alliance Street Lantern" }, { "lamp-horde", "Horde Street Lantern" },
            { "lamp-draenei", "Crystal Lamppost" }, { "torch-fel", "Fel Torch" }, { "candle-val", "Decorated Festive Candle" },
            { "lantern-vrykul", "Vrykul Carved Lantern Post" },
        } },
        { name = "Food & Provisions", props = {
            { "sack", "Grain Sack" }, { "basket", "Basket" }, { "corn", "Basket of Corn" },
            { "bucket", "Bucket" }, { "bottle", "Bottle" }, { "bread", "Bread" },
            { "food", "Spread of Food" }, { "turkey-leg", "Roast Turkey Leg" }, { "roastboar", "Roast Boar Platter" },
            { "fishplatter", "Fish Platter" }, { "fruitbowl", "Fruit Bowl" }, { "apples", "Basket of Apples" },
            { "campjug", "Camp Jug" }, { "campmug", "Camp Mug" }, { "breadslice", "Sliced Bread" },
            { "tacklebox", "Tackle Box" }, { "meat-haunch", "Roast Game Haunch" }, { "bread-baked", "Oven Baked Hearth Bread" },
            { "bottle-orc", "Orcish Flagon Bottle" },
        } },
        { name = "Trophies & The Hunt", props = {
            { "carcass-fresh", "Hanging Hunt Carcass" }, { "trophy-ogre-head", "Mounted Ogre Trophy Head" }, { "fur-quality", "High Quality Fur Hide" },
            { "meat-wagon-grill", "Smoker & Roasting Grill" }, { "cage-bear", "Reinforced Beast Cage" }, { "trophy-horn", "Great Reaver Trophy Horn" },
            { "leather-stand", "Tanned Leather Display" },
        } },
        { name = "Graveyard & Dark Arts", props = {
            { "coffin-musty", "Musty Coffin" }, { "skeleton-hanging", "Hanging Crypt Skeleton" }, { "gravestone-moss", "Mossy Gravestone" },
            { "skull-candle", "Ritual Skull Candle" }, { "skull-hanging", "Hanging Skull Lantern" }, { "skull-voodoo", "Voodoo Skull Pile" },
            { "bones-frozen", "Frozen Scourge Remains" }, { "bones-pile", "Bone Pile" }, { "bones-blasted", "Ancient Blasted Bone Pile" },
            { "skull-lamp-tall", "Hanging Crypt Skull Lamp" },
        } },
        { name = "Treasures & Curios", props = {
            { "gold-sack", "Sack of Gold" }, { "gem-heart", "Heart of Fury Precious Gem" }, { "goblet-golden", "Ornate Golden Goblet" },
            { "orb-magic-blue", "Nexus Arcane Orb" }, { "orb-invention", "Gnomish Invention Orb" }, { "orb-apothecary", "Apothecary Glowing Orb" },
            { "incense-burner", "Ornate Incense Burner" }, { "crystal-moon", "Night Elf Moon Crystal" }, { "crystal-sholazar", "Sholazar Crystal Geode" },
            { "statuette-ancient", "Ancient Relic Figurine" }, { "orb-dragon", "Dragon Crystalline Orb" }, { "crystal-crimson", "Crimson Crystal Shard" },
        } },
        { name = "Atmosphere", props = {
            { "skull", "Skull" }, { "totem", "Totem" }, { "gong", "Gong" },
            { "drum", "Drum" }, { "statue", "Jade Statue" }, { "grave", "Grave" },
            { "cage", "Cage" }, { "anchor", "Anchor" }, { "signpost", "Signpost" },
            { "scroll", "Scroll" }, { "shovel", "Shovel" }, { "warmap", "Tactical War Map" },
            { "skeleton", "Human Skeleton" }, { "tombstone", "Stone Tombstone" }, { "totem-tauren", "Great Tauren Totem" },
            { "totem-small", "Small Totem" }, { "crystal-red", "Glowing Red Crystal" }, { "altar", "Stone Altar" },
            { "spellbook", "Open Spellbook" }, { "crystal-yellow", "Glowing Yellow Crystal" }, { "weather-vane", "Goblin Weather Vane" },
        } },
        { name = "Nature", props = {
            { "mushroom", "Giant Mushroom" }, { "flower", "Flowers" }, { "bush", "Bush" },
            { "plant-potted", "Potted Plant" }, { "flowers-tribute", "Flower Bouquet" }, { "wreath", "Flower Wreath" },
            { "vine-purple", "Purple Celebrian Vine" }, { "plant-fern", "Wild Fern" }, { "tree-pine", "Camp Pine Tree" },
            { "pumpkinpatch", "Pumpkin Patch" }, { "plant-bogbean", "Swamp Lily Plant" }, { "bush-barrens", "Barrens Shrub" },
            { "tree-xmas-large", "Festive Conifer Tree" }, { "plant-gloomweed", "Tirisfal Gloomweed" },
        } },
        { name = "Professions", props = {
            { "alchemy", "Alchemy Table" }, { "fishing-post", "Master Angler Fishing Post" }, { "alchemy-undead", "Forsaken Alchemy Bench" },
            { "alchemy-round", "Apothecary Chemistry Set" }, { "cauldron-boiling", "Bubbling Cauldron" }, { "mortar", "Mortar and Pestle" },
            { "herbsack", "Herb Sacks" }, { "herbrack", "Herb Drying Rack" }, { "engineering-gizmo", "Engineering Gizmo" },
            { "ore-gold", "Gold Vein Deposit" }, { "table-scribe", "Scribe Drafting Table" }, { "table-apprentice-alchemy", "Apprentice Alchemy Station" },
            { "machinery-gnome", "Gnomish Field Machinery" },
        } },
        { name = "Buildings", props = {
            { "cottage", "Cottage" }, { "beertent", "Beer Tent" }, { "pavilion", "Pavilion" },
            { "bigtent", "Large Tent" }, { "stable", "Stable" }, { "doghouse", "Doghouse" },
            { "outhouse", "Outhouse" }, { "pavilion-food", "Festival Food Canopy" }, { "pavilion-orc", "Orc War Pavilion" },
            { "hut-murloc", "Tribal Thatched Hut" }, { "hut-stilt", "Stilt Water Hut" }, { "booth", "Carnival Booth" },
            { "building-moonwell", "Night Elf Moon Well" }, { "building-holding-pen", "Bamboo Holding Pen" }, { "building-landing-pad", "Aviation Landing Pad" },
            { "building-mine", "Underground Mine Cavern" }, { "tower-guard", "Alliance Guard Tower" }, { "tower-orc", "Horde Watch Tower" },
            { "pavilion-menagerie", "Menagerie Shelter Pavilion" }, { "booth-ticket", "Carnival Ticket Gazebo" }, { "arch-festival", "Grand Festival Arch" },
            { "pavilion-royal", "Grand Royal Pavilion" },
        } },
        { name = "Portals", props = {
            { "portal-sw", "Stormwind Portal" }, { "portal-org", "Orgrimmar Portal" }, { "portal-dal", "Dalaran Portal" },
            { "portal-shatt", "Shattrath Portal" }, { "portal-dark", "Dark Portal" }, { "portal-green", "Emerald Instance Portal" },
            { "portal-nether", "Nether Rift Portal" }, { "portal-teleporter", "Legion Gateway Teleporter" }, { "portal-bloodmyst", "Sunstrider Gateway Portal" },
        } },
        { name = "Trainers & NPCs", props = {
            { "npc-banker", "Banker" }, { "npc-vendor", "General Goods & Repairs" }, { "npc-reagents", "Reagents & Poisons" },
            { "npc-innkeeper", "Innkeeper (Hearthstone)" }, { "npc-auctioneer", "Auctioneer" }, { "npc-stablemaster", "Stable Master (Pet Care)" },
            { "npc-poisons", "Poison & Alchemy Specialist" }, { "npc-guard-sw", "Stormwind Camp Guard" }, { "npc-guard-org", "Orgrimmar Camp Guard" },
            { "trainer-warrior", "Warrior Trainer" }, { "trainer-paladin", "Paladin Trainer" }, { "trainer-hunter", "Hunter Trainer" },
            { "trainer-rogue", "Rogue Trainer" }, { "trainer-priest", "Priest Trainer" }, { "trainer-deathknight", "Death Knight Trainer" },
            { "trainer-shaman", "Shaman Trainer" }, { "trainer-mage", "Mage Trainer" }, { "trainer-warlock", "Warlock Trainer" },
            { "trainer-druid", "Druid Trainer" }, { "trainer-alchemy", "Alchemy Trainer" }, { "trainer-blacksmith", "Blacksmithing Trainer" },
            { "trainer-enchanting", "Enchanting Trainer" }, { "trainer-engineering", "Engineering Trainer" }, { "trainer-inscription", "Inscription Trainer" },
            { "trainer-jewelcrafting", "Jewelcrafting Trainer" }, { "trainer-leatherworking", "Leatherworking Trainer" }, { "trainer-tailoring", "Tailoring Trainer" },
            { "trainer-cooking", "Cooking Trainer" }, { "trainer-firstaid", "First Aid Trainer" }, { "trainer-fishing", "Fishing Trainer" },
            { "trainer-mining", "Mining Trainer" }, { "trainer-herbalism", "Herbalism Trainer" }, { "trainer-skinning", "Skinning Trainer" },
            { "trainer-flying", "Flying Trainer" },
        } },
    },
}

-- Category names for the first dropdown.
function WBC.WarbandProps.CategoryNames()
    local out = {}
    for i, cat in ipairs(WBC.WarbandProps.categories) do out[i] = cat.name end
    return out
end

-- {text=label, value=key} choices for one category name (nil if unknown).
function WBC.WarbandProps.PropChoices(catName)
    for _, cat in ipairs(WBC.WarbandProps.categories) do
        if cat.name == catName then
            local out = {}
            for i, p in ipairs(cat.props) do out[i] = { text = p[2], value = p[1] } end
            return out
        end
    end
    return nil
end
