--[[
	Shipped zone defaults for cs_cs16_assault.

	The parts this map doesn't carry in its BSP, placed by hand and committed so
	they travel with the gamemode. Hostage rescue and battle royale are unplayable
	without them, and nothing in a ported 1.6 map provides them.

	A server that wants different ones places them in-game with /hostagespot,
	/rescuezone, /brspawn and /brloot; that saves to data/cs16/zones/cs_cs16_assault.json,
	which wins over this file from then on. /zonesreset goes back to these,
	/zonesexport writes a replacement for this file. See sv_authored.lua.
]]

return {
	-- Where the hostages stand at the start of a round.
	hostages = {
		{ pos = Vector( -52.9, 1608, -432 ), yaw = -99.1 },
		{ pos = Vector( -163.7, 1559.5, -432 ), yaw = -59 },
		{ pos = Vector( -349.2, 1487.5, -432 ), yaw = -68.1 },
		{ pos = Vector( -336.3, 1333.5, -432 ), yaw = 21.1 },
	},

	-- Walk one into here and it's saved.
	rescue = {
		{ pos = Vector( 938.6, -883.3, -768 ), radius = 200 },
	},

	-- Spread across the whole map - ten people, no two in a room.
	brspawns = {
		{ pos = Vector( 1082.9, -769.1, -744 ), yaw = 0 },
		{ pos = Vector( -768.3, -1465.9, -768 ), yaw = 100.6 },
		{ pos = Vector( -333.8, 1515.9, -432 ), yaw = -59.4 },
		{ pos = Vector( 33.8, 1606.8, -640 ), yaw = -2.6 },
		{ pos = Vector( 1329.6, 663.1, -736 ), yaw = 86.6 },
		{ pos = Vector( 175.9, 563.3, -640 ), yaw = 1.3 },
		{ pos = Vector( 1392, -240, -768 ), yaw = 131.1 },
		{ pos = Vector( -894, 1659.8, -512 ), yaw = -88.4 },
		{ pos = Vector( -800, 816, -768 ), yaw = 39.2 },
		{ pos = Vector( -144, -432, -768 ), yaw = 143.4 },
	},

	-- One gun each, decided at match start rather than here.
	brloot = {
		{ pos = Vector( -1177.1, -592.5, -752 ) },
		{ pos = Vector( -1109.6, -593.3, -752 ) },
		{ pos = Vector( -184.3, -1222.9, -720 ) },
		{ pos = Vector( -331.2, -1218.7, -720 ) },
		{ pos = Vector( 985.2, -415.1, -719 ) },
		{ pos = Vector( 219.7, 1512.1, -432 ) },
		{ pos = Vector( 222.2, 1380.8, -432 ) },
		{ pos = Vector( 1097.9, 1894.3, -432 ) },
		{ pos = Vector( 1353.6, 1217.7, -736 ) },
		{ pos = Vector( 1568.9, 1105.3, -768 ) },
		{ pos = Vector( 100.9, 449.4, -768 ) },
		{ pos = Vector( -175.6, 442, -392 ) },
		{ pos = Vector( -81.9, 440.5, -392 ) },
		{ pos = Vector( -912.6, 404.4, -512 ) },
		{ pos = Vector( -962, 403.7, -512 ) },
		{ pos = Vector( -851.4, 405.3, -512 ) },
		{ pos = Vector( -30.8, 538, -768 ) },
		{ pos = Vector( -104.4, 542.4, -768 ) },
		{ pos = Vector( -477.8, 164.6, -768 ) },
		{ pos = Vector( -478.9, 228.4, -768 ) },
		{ pos = Vector( -13.4, 952.9, -768 ) },
		{ pos = Vector( 702.4, 1374.9, -332 ) },
		{ pos = Vector( 186.8, 1377.3, -240 ) },
	},
}
