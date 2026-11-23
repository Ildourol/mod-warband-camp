-- ============================================================================
-- Warband Camp Steward SQL Setup (Grenn Fastfuse <Camp Steward>)
-- Run against your acore_world database.
-- ============================================================================

INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES (990103, 0, 0, 0, 0, 0, 'Grenn Fastfuse', 'Camp Steward', NULL, 990103, 80, 80, 2, 35, 4097, 1, 1.14286, 1, 1, 20, 0, 0, 1, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_warband_camp_steward', 12340)
ON DUPLICATE KEY UPDATE `name` = 'Grenn Fastfuse', `subname` = 'Camp Steward', `ScriptName` = 'npc_warband_camp_steward';

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES (990103, 0, 28091, 1, 1, 12340)
ON DUPLICATE KEY UPDATE `CreatureDisplayID` = 28091;

INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `VerifiedBuild`)
VALUES (990103, 'Greetings, adventurer. The camp is peaceful today. How can I assist you and your warband?', 'Greetings, adventurer. The camp is peaceful today. How can I assist you and your warband?', 12340)
ON DUPLICATE KEY UPDATE `text0_0` = 'Greetings, adventurer. The camp is peaceful today. How can I assist you and your warband?';
