--[[
	Gungame: climb the ladder, finish with the knife.

	Terrorists against Counter-Terrorists as usual, but there is no bomb and no
	sides worth protecting - the winner is a person, not a team. Two kills move
	you up a rung, your old weapon goes and the new one lands in your hands, and
	the last rung is a knife that needs a single kill to take the match.

	Friendly fire is off, because with a three second respawn it would only be
	an invitation to farm your own side.

	The ladder is one list, deliberately: it's the whole design of the mode, and
	trimming it is how you make a shorter game. As written it runs 34 rungs -
	sixty-seven kills to win - which is a long evening. Cut whole categories out
	of the middle to taste.

	Weapons are named by class alone because the buy catalogue already knows
	their ammo type and how much of it to carry, so the two can't disagree about
	what a P90 takes.
]]

CS16.GunGame = {
	--[[
		Kills to leave a rung, and to finish the last one.

		KillsPerLevel is only the default - the live value is a convar, so it
		can be changed without a restart. See below.
	]]
	KillsPerLevel = 2,
	KnifeKills    = 1,

	RespawnDelay = 3,

	-- Long enough that it never bites in practice; short enough that a match
	-- nobody can finish still ends. Highest rung wins if it expires.
	RoundTime = 1800,

	-- A moment to spread out at the start rather than spawning into a fight.
	FreezeTime = 5,
}

--[[
	Worst to best, category by category, exactly as 1.6 ordered its buy menu -
	with the pack's extras slotted in where they belong rather than where their
	price says, since several of them are free.
]]
CS16.GunGame.Ladder = {
	-- Pistols
	"weapon_cs16_glock18",
	"weapon_cs16_usp",
	"weapon_cs16_p228",
	"weapon_cs16_deagle",
	"weapon_cs16_fiveseven",
	"weapon_cs16_elite",
	"weapon_cs16_python",

	-- Shotguns
	"weapon_cs16_sawn",
	"weapon_cs16_m3",
	"weapon_cs16_xm1014",

	-- Sub-machine guns
	"weapon_cs16_tmp",
	"weapon_cs16_mac10",
	"weapon_cs16_mp5navy",
	"weapon_cs16_ump45",
	"weapon_cs16_p90",

	-- Rifles
	"weapon_cs16_winchester",
	"weapon_cs16_asval",
	"weapon_cs16_galil",
	"weapon_cs16_famas",
	"weapon_cs16_ak47",
	"weapon_cs16_scout",
	"weapon_cs16_m4a1",
	"weapon_cs16_sg552",
	"weapon_cs16_aug",
	"weapon_cs16_sg550",
	"weapon_cs16_awp",
	"weapon_cs16_g3sg1",

	-- Machine guns
	"weapon_cs16_m249",

	--[[
		Explosives, which were never in 1.6 and are here because this mode is
		meant to be daft.

		The launchers only. A rung has to be one you can leave, and neither of
		the thrown ones qualifies: the flare does no damage at all, and the
		molotov's fire kills without crediting anyone - the victim dies to the
		world, so nobody advances and whoever drew that rung is stuck on it for
		the rest of the game. Fire is expensive to run besides.
	]]
	"weapon_cs16_mgl_mk1",
	"weapon_cs16_law",

	--[[
		Then the knife that ends it.

		No minigun. It doesn't fire reliably, and a rung you can't count on
		leaving is the one thing this ladder can't have - the same reason the
		flare and the molotov aren't here either. It's still in the developer
		buy menu, where a weapon misbehaving is the point of picking it up.
	]]
	CS16.Config.Knife,
}

-- What to call a rung. The catalogue knows every weapon on the ladder except
-- the knife, which was never for sale.
function CS16.GunGameWeaponName( class )
	if class == CS16.Config.Knife then return "Knife" end

	local item = CS16.BuyItemsByClass[ class ]
	return item and item.name or class
end

function CS16.GunGameLevel( ply )
	return math.Clamp( ply:GetNWInt( "CS16.GGLevel", 1 ), 1, #CS16.GunGame.Ladder )
end

function CS16.GunGameKills( ply )
	return ply:GetNWInt( "CS16.GGKills", 0 )
end

--[[
	The pace of the ladder: one kill a rung, two, or more.

	A replicated convar rather than a plain setting, because the HUD counts your
	kills toward the next rung - so the client has to know the same number the
	server is scoring against, and a convar replicates for free rather than
	needing a message of its own.

	Archived, so a server set to 1x stays that way through the map reload that
	ends every game. The knife is always one kill whatever this says: it's the
	finish, not a rung.
]]
--[[
	Created on both realms, deliberately, and not wrapped in `if SERVER`.

	FCVAR_REPLICATED replicates the *value*, not the convar's existence: the
	client still has to declare it or GetConVar there finds nothing at all. This
	was guarded to the server, so the client had no convar, GunGamePace fell
	through to the default below, and the HUD told everybody they needed two
	kills a rung while the server was promoting them after one.

	The same mistake put the client on the wrong game mode earlier in this
	project. A replicated convar is declared by both and set by one.
]]
CreateConVar( "cs16_gungame_kills", CS16.GunGame.KillsPerLevel,
	{ FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE },
	"Kills needed per rung of the gungame ladder. The knife always needs one." )

function CS16.GunGamePace()
	local convar = GetConVar( "cs16_gungame_kills" )
	local kills  = convar and convar:GetInt() or CS16.GunGame.KillsPerLevel

	return math.max( 1, kills )
end

-- How many kills this rung asks for. Only the last one is different.
function CS16.GunGameKillsNeeded( level )
	if level >= #CS16.GunGame.Ladder then return CS16.GunGame.KnifeKills end
	return CS16.GunGamePace()
end

CS16.RegisterMode( "gungame", {
	label       = "Gun Game",
	description = "Climb the weapon ladder. Two kills a rung, and the knife wins it.",
	aliases     = { "gg" },

	--[[
		Nothing is bought - the ladder decides what you carry - so the buy menu
		refuses politely rather than opening onto an empty shop, and the bots
		skip their buy step for the same reason.
	]]
	Buying       = false,
	FriendlyFire = false,

	--[[
		Nothing hits the floor. The rung you're on is the whole scoring system,
		so a scattering of other people's guns would let you skip half the
		ladder by killing with whatever you picked up.
	]]
	Dropping = false,

	--[[
		Bots cross the map looking for people rather than holding ground.

		There is nothing to hold: the ladder is decided by kills wherever they
		happen, so a bot sat on a bomb site is a bot in the wrong place by
		definition. Stated explicitly even though roaming is the default,
		because it's a rule of the mode rather than an omission.
	]]
	BotGoal = function( bot )
		return CS16.BotRoamGoal( bot )
	end,

	--[[
		Ten a side rather than five, so a full server can have a proper
		free-for-all. The bots still only fill to five a side; the rest of the
		room is for people, and every person who joins puts a bot out of a job.
	]]
	MaxPerTeam = 10,

	--[[
		No side to lock anyone to. The winner is an individual, so switching
		teams gains you nothing worth preventing.
	]]
	TeamLocks = false,

	-- Three seconds and you're back in it, while there's a game to be back in.
	RespawnDelay = function( ply )
		local state = CS16.GetRoundState()

		if state == ROUND_LIVE or state == ROUND_WARMUP then
			return CS16.GunGame.RespawnDelay
		end
	end,

	--[[
		Whatever rung you're on, and nothing else - no knife until you've earned
		it. Defined on the server; this only names the call.
	]]
	Loadout = function( ply )
		CS16.GunGameEquip( ply )
	end,

	server = {
		"core/modes/gungame/sv_gungame.lua",
	},

	client = {
		"core/modes/gungame/cl_gungame.lua",
	},
} )
