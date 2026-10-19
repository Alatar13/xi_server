-- Warp point persistence storage table
-- Each player can have multiple warp points (slots 1-10)
-- One row per slot, linked by player ID
-- Requires UNIQUE INDEX (player, slot) to prevent duplicate slots for same player

CREATE TABLE IF NOT EXISTS `cwp_warp_points` (
    id              TINYINT UNSIGNED AUTO_INCREMENT,
    player          INT UNSIGNED NOT NULL,
    slot            SMALLINT UNSIGNED NOT NULL,
    x_coord         FLOAT NOT NULL,
    y_coord         FLOAT NOT NULL,
    z_coord         FLOAT NOT NULL,
    zone_name       VARCHAR(255) CHARACTER SET ascii DEFAULT '',  -- If populated, uses the zone name lookup

    PRIMARY KEY     (id),
    UNIQUE INDEX    (player, slot),
    KEY            (player)
);