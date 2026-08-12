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
	brspawns = {},

	-- One gun each, decided at match start rather than here.
	brloot = {},
}
