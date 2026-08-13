--[[
	Shipped zone defaults for de_vertigo_csbeta.

	The parts this map doesn't carry in its BSP, placed by hand and committed so
	they travel with the gamemode. Hostage rescue and battle royale are unplayable
	without them, and nothing in a ported 1.6 map provides them.

	A server that wants different ones places them in-game with /hostagespot,
	/rescuezone, /brspawn and /brloot; that saves to data/cs16/zones/de_vertigo_csbeta.json,
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
		{ pos = Vector( -1185.3, 1176, 0 ), yaw = -72.5 },
		{ pos = Vector( -707.6, 700.2, 0 ), yaw = -45.7 },
		{ pos = Vector( 568.1, 1174.6, 0 ), yaw = -39.6 },
		{ pos = Vector( 579.2, 351.9, 0 ), yaw = 89.4 },
		{ pos = Vector( 335.8, -1082.2, -128 ), yaw = 43.8 },
		{ pos = Vector( -259, -51.9, -288 ), yaw = 85 },
		{ pos = Vector( -964.2, -418.9, 0 ), yaw = -66.7 },
		{ pos = Vector( 1153.2, 1148.1, -288 ), yaw = -140.9 },
		{ pos = Vector( -485.5, -6.2, -288 ), yaw = 122.7 },
		{ pos = Vector( 395.1, 734.9, -288 ), yaw = -91.1 },
	},

	-- One gun each, decided at match start rather than here.
	brloot = {
		{ pos = Vector( -862.6, 348.6, 0 ) },
		{ pos = Vector( -88.5, 927.3, 0 ) },
		{ pos = Vector( -304, 1232, 0 ) },
		{ pos = Vector( 451.2, 414.3, 50 ) },
		{ pos = Vector( 448, 475, 0 ) },
		{ pos = Vector( 1248, 438.3, 0 ) },
		{ pos = Vector( 1247.1, 482.7, 0 ) },
		{ pos = Vector( 1246.1, 537.6, 0 ) },
		{ pos = Vector( 1166.6, -563.6, 0 ) },
		{ pos = Vector( 857.6, -665.5, 0 ) },
		{ pos = Vector( 658.3, 184, -288 ) },
		{ pos = Vector( 646, 240.3, -240 ) },
		{ pos = Vector( 555.1, 219.6, -224 ) },
		{ pos = Vector( 380.8, 232.3, -160 ) },
		{ pos = Vector( 382.3, 296.1, -160 ) },
		{ pos = Vector( -634.6, -1083.8, -288 ) },
		{ pos = Vector( -695.6, -669.6, -288 ) },
		{ pos = Vector( -696, -729.6, -288 ) },
		{ pos = Vector( -294.5, 961.1, -288 ) },
		{ pos = Vector( 1226.7, 538.5, -288 ) },
		{ pos = Vector( 1186.5, 515.6, -288 ) },
		{ pos = Vector( -45.3, -138.4, 0 ) },
		{ pos = Vector( -52.9, -203.5, 0 ) },
		{ pos = Vector( -1015.5, 152, -288 ) },
	},
}
