--[[
	Shipped zone defaults for de_dust2_classic.

	The parts this map doesn't carry in its BSP, placed by hand and committed so
	they travel with the gamemode. Hostage rescue and battle royale are unplayable
	without them, and nothing in a ported 1.6 map provides them.

	A server that wants different ones places them in-game with /hostagespot,
	/rescuezone, /brspawn and /brloot; that saves to data/cs16/zones/de_dust2_classic.json,
	which wins over this file from then on. /zonesreset goes back to these,
	/zonesexport writes a replacement for this file. See sv_authored.lua.
]]

return {
	-- Where the hostages stand at the start of a round.
	hostages = {},

	-- Walk one into here and it's saved.
	rescue = {},

	-- Spread across the whole map - ten people, no two in a room.
	brspawns = {
		{ pos = Vector( -2021.5, -1808.1, -32 ), yaw = -34.4 },
		{ pos = Vector( -1331.5, -1142.9, -160 ), yaw = 113.8 },
		{ pos = Vector( -597.7, 88.4, -272 ), yaw = 48.3 },
		{ pos = Vector( 625.5, 462.3, -160 ), yaw = -114.3 },
		{ pos = Vector( -546.9, -862.3, -160 ), yaw = 4 },
		{ pos = Vector( 1595.2, -1175.1, -352 ), yaw = 91 },
		{ pos = Vector( 91.6, 1005.5, -288 ), yaw = -67.5 },
		{ pos = Vector( 1918.5, 663.4, -104.3 ), yaw = 136.6 },
		{ pos = Vector( 885.3, -723.9, -160 ), yaw = -139 },
		{ pos = Vector( -327.7, -1472.3, -160 ), yaw = -65.6 },
	},

	-- One gun each, decided at match start rather than here.
	brloot = {
		{ pos = Vector( -1585.9, -1552.3, 32 ) },
		{ pos = Vector( -1603.4, -262.1, -128 ) },
		{ pos = Vector( -1020.3, -1, -112 ) },
		{ pos = Vector( -1020.2, 257.2, -208 ) },
		{ pos = Vector( -1650.3, 1132.3, -64 ) },
		{ pos = Vector( -1474.1, 393.6, -160 ) },
		{ pos = Vector( -1535.6, 410.4, -160 ) },
		{ pos = Vector( -1855.7, 1857.7, -128 ) },
		{ pos = Vector( -1911.5, 1670.5, -128 ) },
		{ pos = Vector( -1285.1, 1462.2, -160 ) },
		{ pos = Vector( -1465.8, 1610.4, -160 ) },
		{ pos = Vector( -755.8, 1299.5, -217.6 ) },
		{ pos = Vector( -1084.3, 1281, -64 ) },
		{ pos = Vector( 1814, -891.1, -96 ) },
		{ pos = Vector( 1945.1, -687.9, -80 ) },
		{ pos = Vector( 1280.5, -1022, -160 ) },
		{ pos = Vector( 1088.4, -65.6, -96 ) },
		{ pos = Vector( 1017.8, -79, -64 ) },
		{ pos = Vector( 767.4, 1118.9, -120 ) },
		{ pos = Vector( 1232.4, 1125.1, 64 ) },
		{ pos = Vector( 1236.7, 1184.8, 0 ) },
		{ pos = Vector( 410.4, -773.8, -144 ) },
		{ pos = Vector( 506, -2015, -160 ) },
		{ pos = Vector( 1391.8, 1266.3, 0 ) },
		{ pos = Vector( 1225.8, 1781.6, 32 ) },
		{ pos = Vector( -1924.4, 1231.5, -64 ) },
		{ pos = Vector( -1448.1, 1460.9, -160 ) },
		{ pos = Vector( -1157.6, 1414.5, -8.7 ) },
	},
}
