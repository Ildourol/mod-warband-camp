-- QOLAddon/Data/WarbandProps.lua
-- The Warband Camp prop & NPC catalogue: category -> { key, label } pairs.
-- key = what `.camp place <key>` expects · label = what the player sees.

local addonName, QOL = ...

QOL.WarbandProps = {
    catalogueVersion = "1.2.0",
    categories = {
        { name = "Shelter", props = {
            { "tent", "Tent" }, { "tent-a", "Alliance Tent" }, { "tent-h", "Horde Tent" },
            { "foodtent", "Food Tent" }, { "tent-dwarf", "Dwarven Tent" }, { "tent-orc", "Orc Tent" },
            { "tent-undead", "Forsaken Tent" }, { "tent-scourge", "Scourge Tent" }, { "canopy", "Open Canopy" },
            { "tent-carnival", "Carnival Tent" },
        } },
        { name = "Fire & Light", props = {
            { "campfire", "Campfire" }, { "bonfire", "Bonfire" }, { "brazier", "Brazier" },
            { "lantern", "Lantern" }, { "bonfire-blue", "Blue Fire Bonfire" }, { "bonfire-orc", "Orc Bonfire" },
            { "brazier-festival", "Festival Brazier" }, { "brazier-purple", "Purple Brazier" }, { "brazier-legion", "Legion Brazier" },
            { "bowl-fire", "Elven Fire Bowl" }, { "hearth-fire", "Great Hearth Fire" },
        } },
        { name = "Furniture", props = {
            { "table", "Table" }, { "chair", "Chair" }, { "bench", "Bench" },
            { "rug", "Rug" }, { "bookshelf", "Bookshelf" }, { "bookcase", "Bookcase" },
            { "bunkbed", "Bunkbed" }, { "bed-stone", "Stone Bed" }, { "chair-dalaran", "Dalaran Chair" },
            { "stool-elven", "Elven Stool" }, { "bench-orc", "Orc Bench" }, { "bench-wood", "Duskwood Bench" },
            { "table-elven", "Elven Table" }, { "table-orc", "Orc Table" }, { "table-dwarf", "Dwarven Table" },
            { "throne", "Chieftain Throne" }, { "wardrobe", "Wardrobe" }, { "rug-sw", "Stormwind Rug" },
            { "rug-tauren", "Tauren Rug" }, { "rug-fur", "Vrykul Fur Rug" },
        } },
        { name = "Storage & Amenities", props = {
            { "crate", "Supply Crate" }, { "crate-h", "Horde Crate" }, { "barrel", "Barrel" },
            { "keg", "Keg" }, { "cauldron", "Cauldron" }, { "cookpot", "Cook Pot" },
            { "mailbox", "Mailbox" }, { "chest-ornate", "Ornate Chest" }, { "chest-reinforced", "Reinforced Chest" },
            { "keg-brewfest", "Brewfest Ale Keg" }, { "tub", "Washing Tub" }, { "basin", "Water Basin" },
            { "crate-orc", "Orc Crate" }, { "crate-grain", "Grain Crate" }, { "barrel-plague", "Plague Barrel" },
            { "barrel-broken", "Broken Barrel" },
        } },
        { name = "Yard", props = {
            { "wagon", "Wagon" }, { "haystack", "Haystack" }, { "haybale", "Hay Bale" },
            { "woodpile", "Wood Pile" }, { "logpile", "Log Pile" }, { "fence", "Fence" },
            { "rockwall", "Rockwall Fence" }, { "pumpkin", "Pumpkin" }, { "wheelbarrow", "Wheelbarrow" },
            { "target-archery", "Archery Target" }, { "target-dwarf", "Dwarf Target Dummy" }, { "target-ogre", "Ogre Target Dummy" },
            { "barricade", "Trench Barricade" }, { "cart-broken", "Broken Cart" }, { "cart-rocket", "Rocket Cart" },
            { "fence-spiked", "Spiked Iron Fence" }, { "lightwell", "Holy Light Well" }, { "fountain-elven", "Elven Fountain" },
        } },
        { name = "Craft", props = {
            { "anvil", "Anvil" }, { "forge", "Forge" }, { "coals", "Forge Coals" },
            { "weaponrack", "Weapon Rack" }, { "toolbox", "Blacksmith Toolbox" }, { "rack-scourge", "Scourge Weapon Rack" },
            { "rack-blades", "Scourge Blade Rack" }, { "grinder", "Gem Grinder" }, { "runeforge", "Scourge Runeforge" },
            { "hammer", "Smithing Hammer" },
        } },
        { name = "Banners", props = {
            { "banner", "Banner" }, { "banner-a", "Alliance Banner" }, { "banner-h", "Horde Banner" },
            { "banner-sw", "Stormwind Banner" }, { "banner-org", "Orgrimmar Banner" }, { "banner-if", "Ironforge Banner" },
            { "banner-dar", "Darnassus Banner" }, { "banner-gnome", "Gnomeregan Banner" }, { "banner-exo", "Exodar Banner" },
            { "banner-tb", "Thunder Bluff Banner" }, { "banner-uc", "Undercity Banner" }, { "banner-smc", "Silvermoon Banner" },
            { "banner-senjin", "Sen'jin Banner" }, { "banner-sun", "Shattered Sun Banner" }, { "banner-fk", "Forsaken Banner" },
        } },
        { name = "Lights", props = {
            { "torch", "Torch" }, { "candle", "Candle" }, { "candelabra", "Candelabra" },
            { "torch-stand", "Standing Torch" }, { "lamp-alliance", "Alliance Street Lantern" }, { "lamp-horde", "Horde Street Lantern" },
            { "lamp-draenei", "Crystal Lamppost" }, { "torch-fel", "Fel Torch" },
        } },
        { name = "Food & Provisions", props = {
            { "sack", "Grain Sack" }, { "basket", "Basket" }, { "corn", "Basket of Corn" },
            { "bucket", "Bucket" }, { "bottle", "Bottle" }, { "bread", "Bread" },
            { "food", "Spread of Food" }, { "chest", "Chest" }, { "roastboar", "Roast Boar Platter" },
            { "fishplatter", "Fish Platter" }, { "fruitbowl", "Fruit Bowl" }, { "apples", "Basket of Apples" },
            { "campjug", "Camp Jug" }, { "campmug", "Camp Mug" }, { "breadslice", "Sliced Bread" },
            { "tacklebox", "Tackle Box" },
        } },
        { name = "Atmosphere", props = {
            { "skull", "Skull" }, { "totem", "Totem" }, { "gong", "Gong" },
            { "drum", "Drum" }, { "statue", "Jade Statue" }, { "grave", "Grave" },
            { "cage", "Cage" }, { "anchor", "Anchor" }, { "signpost", "Signpost" },
            { "scroll", "Scroll" }, { "shovel", "Shovel" }, { "warmap", "Tactical War Map" },
            { "skeleton", "Human Skeleton" }, { "tombstone", "Stone Tombstone" }, { "totem-tauren", "Great Tauren Totem" },
            { "totem-small", "Small Totem" }, { "crystal-red", "Glowing Red Crystal" }, { "altar", "Stone Altar" },
            { "spellbook", "Open Spellbook" },
        } },
        { name = "Nature", props = {
            { "mushroom", "Giant Mushroom" }, { "flower", "Flowers" }, { "bush", "Bush" },
            { "plant-potted", "Potted Plant" }, { "flowers-tribute", "Flower Bouquet" }, { "wreath", "Flower Wreath" },
            { "vine-purple", "Purple Celebrian Vine" }, { "plant-fern", "Wild Fern" }, { "tree-pine", "Camp Pine Tree" },
            { "pumpkinpatch", "Pumpkin Patch" },
        } },
        { name = "Professions", props = {
            { "alchemy", "Alchemy Table" }, { "fishing", "Fishing Gear" }, { "alchemy-undead", "Forsaken Alchemy Bench" },
            { "alchemy-round", "Apothecary Chemistry Set" }, { "cauldron-boiling", "Bubbling Cauldron" }, { "mortar", "Mortar and Pestle" },
            { "herbsack", "Herb Sacks" }, { "herbrack", "Herb Drying Rack" }, { "engineering-gizmo", "Engineering Gizmo" },
            { "ore-gold", "Gold Vein Deposit" },
        } },
        { name = "Buildings", props = {
            { "cottage", "Cottage" }, { "beertent", "Beer Tent" }, { "pavilion", "Pavilion" },
            { "bigtent", "Large Tent" }, { "stable", "Stable" }, { "doghouse", "Doghouse" },
            { "outhouse", "Outhouse" }, { "pavilion-dwarf", "Dwarven Pavilion" }, { "pavilion-orc", "Orc War Pavilion" },
            { "hut-murloc", "Tribal Thatched Hut" }, { "hut-stilt", "Stilt Water Hut" }, { "booth", "Carnival Booth" },
        } },
        { name = "Portals", props = {
            { "portal-sw", "Stormwind Portal" }, { "portal-org", "Orgrimmar Portal" }, { "portal-dal", "Dalaran Portal" },
            { "portal-shatt", "Shattrath Portal" }, { "portal-dark", "Dark Portal" }, { "portal-green", "Emerald Instance Portal" },
        } },
        { name = "Trainers & NPCs", props = {
            { "npc-banker", "Banker" }, { "npc-vendor", "General Goods & Repairs" }, { "npc-reagents", "Reagents & Poisons" },
            { "npc-innkeeper", "Innkeeper (Hearthstone)" }, { "npc-auctioneer", "Auctioneer" }, { "trainer-warrior", "Warrior Trainer" },
            { "trainer-paladin", "Paladin Trainer" }, { "trainer-hunter", "Hunter Trainer" }, { "trainer-rogue", "Rogue Trainer" },
            { "trainer-priest", "Priest Trainer" }, { "trainer-deathknight", "Death Knight Trainer" }, { "trainer-shaman", "Shaman Trainer" },
            { "trainer-mage", "Mage Trainer" }, { "trainer-warlock", "Warlock Trainer" }, { "trainer-druid", "Druid Trainer" },
            { "trainer-alchemy", "Alchemy Trainer" }, { "trainer-blacksmith", "Blacksmithing Trainer" }, { "trainer-enchanting", "Enchanting Trainer" },
            { "trainer-engineering", "Engineering Trainer" }, { "trainer-inscription", "Inscription Trainer" }, { "trainer-jewelcrafting", "Jewelcrafting Trainer" },
            { "trainer-leatherworking", "Leatherworking Trainer" }, { "trainer-tailoring", "Tailoring Trainer" }, { "trainer-cooking", "Cooking Trainer" },
            { "trainer-firstaid", "First Aid Trainer" }, { "trainer-fishing", "Fishing Trainer" }, { "trainer-mining", "Mining Trainer" },
            { "trainer-herbalism", "Herbalism Trainer" }, { "trainer-skinning", "Skinning Trainer" }, { "trainer-flying", "Flying Trainer" },
        } },
    },
}

-- Category names for the first dropdown.
function QOL.WarbandProps.CategoryNames()
    local out = {}
    for i, cat in ipairs(QOL.WarbandProps.categories) do out[i] = cat.name end
    return out
end

-- {text=label, value=key} choices for one category name (nil if unknown).
function QOL.WarbandProps.PropChoices(catName)
    for _, cat in ipairs(QOL.WarbandProps.categories) do
        if cat.name == catName then
            local out = {}
            for i, p in ipairs(cat.props) do out[i] = { text = p[2], value = p[1] } end
            return out
        end
    end
    return nil
end
