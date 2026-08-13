--[[
	Shipped zone defaults for cs16_italy.

	The parts this map doesn't carry in its BSP, placed by hand and committed so
	they travel with the gamemode. Hostage rescue and battle royale are unplayable
	without them, and nothing in a ported 1.6 map provides them.

	A server that wants different ones places them in-game with /hostagespot,
	/rescuezone, /brspawn and /brloot; that saves to data/cs16/zones/cs16_italy.json,
	which wins over this file from then on. /zonesreset goes back to these,
	/zonesexport writes a replacement for this file. See sv_authored.lua.
]]

return {
	-- Where the hostages stand at the start of a round.
	hostages = {
		{ pos = Vector( 914.6, 2326, 0 ), yaw = 117.6 },
		{ pos = Vector( 969.2, 2408.5, 0 ), yaw = -173.6 },
		{ pos = Vector( 819.4, 2342.4, 128 ), yaw = 51.1 },
		{ pos = Vector( 927.3, 2342.6, 128 ), yaw = 128.3 },
	},

	-- Walk one into here and it's saved.
	rescue = {
		{ pos = Vector( -684.3, -2096, -240 ), radius = 250 },
	},

	-- Spread across the whole map - ten people, no two in a room.
	brspawns = {
		{ pos = Vector( 1008, 1872, 128 ), yaw = 138.4 },
		{ pos = Vector( 1029.2, 765.3, -192 ), yaw = -179.8 },
		{ pos = Vector( 1051.8, -698.4, -152 ), yaw = 176.8 },
		{ pos = Vector( -694.3, 419, 8 ), yaw = -69.6 },
		{ pos = Vector( -1085.2, -1601.6, -152 ), yaw = -91.3 },
		{ pos = Vector( -1152, -201.3, -152 ), yaw = 0.2 },
		{ pos = Vector( -1214.8, 1303.5, -152 ), yaw = -88.5 },
		{ pos = Vector( -1301.7, 1955.1, -152 ), yaw = -3.6 },
		{ pos = Vector( -110.1, 2467.8, -64 ), yaw = -87 },
		{ pos = Vector( 152, 98.2, -152 ), yaw = 2.5 },
	},

	-- One gun each, decided at match start rather than here.
	brloot = {
		{ pos = Vector( 746.1, 2326.7, 176 ) },
		{ pos = Vector( 966.4, 2366.3, 128 ) },
		{ pos = Vector( 919.4, 994.6, -96 ) },
		{ pos = Vector( 919, 1041, -96 ) },
		{ pos = Vector( 1055.7, -157.4, -152 ) },
		{ pos = Vector( 1058.5, -105.3, -152 ) },
		{ pos = Vector( -351.8, -128.6, -152 ) },
		{ pos = Vector( -296.1, -128, -152 ) },
		{ pos = Vector( -660.2, -1299.5, -240 ) },
		{ pos = Vector( -232.7, -882.9, -152 ) },
		{ pos = Vector( -233.3, -938.6, -152 ) },
		{ pos = Vector( -1082.5, -609.1, -152 ) },
		{ pos = Vector( -511, 633, 57 ) },
		{ pos = Vector( -472.4, 631.2, 8 ) },
		{ pos = Vector( -743.4, 903.2, -160 ) },
		{ pos = Vector( -1520, 1287.4, 8 ) },
		{ pos = Vector( -1520, 1217.7, 8 ) },
		{ pos = Vector( -386.2, 1899.7, -120 ) },
		{ pos = Vector( -390.4, 1864.6, -120 ) },
		{ pos = Vector( -41.3, 1250.1, -160 ) },
		{ pos = Vector( 482.6, -448.8, -152 ) },
		{ pos = Vector( 543, -362, -152 ) },
		{ pos = Vector( 608.8, -440, -152 ) },
		{ pos = Vector( 253.9, -776, -152 ) },
	},
}
