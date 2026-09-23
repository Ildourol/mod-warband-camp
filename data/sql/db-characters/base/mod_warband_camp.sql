--
-- Copyright (C) 2025+ WOW Legends / Standalone Port
-- Released under GNU AGPL v3 license.
--

CREATE TABLE IF NOT EXISTS `mod_warband_camp` (
  `account_id` int unsigned NOT NULL,
  `map` smallint unsigned NOT NULL,
  `pos_x` float NOT NULL,
  `pos_y` float NOT NULL,
  `pos_z` float NOT NULL,
  `orientation` float NOT NULL,
  `phase_bit` tinyint unsigned NOT NULL,
  `zone_id` int unsigned NOT NULL DEFAULT '0',
  `privacy` tinyint unsigned NOT NULL DEFAULT '0',
  `greeting` varchar(255) NOT NULL DEFAULT '',
  `last_active` int unsigned NOT NULL DEFAULT '0',
  `claimed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`),
  KEY `idx_map` (`map`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mod_warband_camp_object` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `account_id` int unsigned NOT NULL,
  `spawn_guid` int unsigned NOT NULL DEFAULT '0',
  `entry` int unsigned NOT NULL,
  `pos_x` float NOT NULL,
  `pos_y` float NOT NULL,
  `pos_z` float NOT NULL,
  `orientation` float NOT NULL,
  `scale` float NOT NULL DEFAULT '1',
  `placed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_account` (`account_id`),
  KEY `idx_spawn_guid` (`spawn_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mod_warband_camp_creature` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `account_id` int unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `pos_x` float NOT NULL,
  `pos_y` float NOT NULL,
  `pos_z` float NOT NULL,
  `orientation` float NOT NULL,
  `spawned_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mod_warband_alt_origin` (
  `guid` int unsigned NOT NULL,
  `map` int unsigned NOT NULL,
  `pos_x` float NOT NULL,
  `pos_y` float NOT NULL,
  `pos_z` float NOT NULL,
  `orientation` float NOT NULL,
  `parked_at` int unsigned NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
