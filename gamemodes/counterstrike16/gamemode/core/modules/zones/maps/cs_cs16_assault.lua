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
		{ pos = Vector( 1455.1, -857.4, -768 ), radius = 200 },
	},

	-- Spread across the whole map - ten people, no two in a room.
	brspawns = {},

	-- One gun each, decided at match start rather than here.
	brloot = {},
}
