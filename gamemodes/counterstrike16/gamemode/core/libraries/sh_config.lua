--[[
	Central tuning for the gamemode. Anything a server owner might reasonably
	want to change lives here rather than being scattered through the code.
]]

CS16.Config = CS16.Config or {}
local cfg = CS16.Config

-- Player models per team. One is picked at random on spawn, the same way 1.6
-- let you choose a model from your team's roster.
cfg.Models = {
	T = {
		"models/cs/playermodels/arctic.mdl",
		"models/cs/playermodels/guerilla.mdl",
		"models/cs/playermodels/leet.mdl",
		"models/cs/playermodels/terror.mdl",
	},
	CT = {
		"models/cs/playermodels/gign.mdl",
		"models/cs/playermodels/gsg9.mdl",
		"models/cs/playermodels/sas.mdl",
		"models/cs/playermodels/urban.mdl",
	},
}

--[[
	Everything the 1.6 pack ships, for the modes that let you pick.

	The eight side models above plus the two that belong to nobody: the VIP from
	the assassination maps, and the hostage, on the grounds that a mode with no
	sides has nothing to dress for and it is funnier.

	Ordered Terrorists, Counter-Terrorists, then the odd two, so the picker
	reads the way the 1.6 model list did.

	`key` is what the language files look the name and description up by, and is
	the reason the English name is still here: it is the fallback when a
	translation has not reached this class yet, and it keeps the list readable
	to anyone editing it. Nobody picked "guerilla.mdl".
]]
cfg.PickableModels = {
	{ key = "phoenix",   name = "Phoenix Connexion", model = "models/cs/playermodels/terror.mdl"   },
	{ key = "leet",      name = "Elite Crew",        model = "models/cs/playermodels/leet.mdl"     },
	{ key = "arctic",    name = "Arctic Avengers",   model = "models/cs/playermodels/arctic.mdl"   },
	{ key = "guerrilla", name = "Guerrilla Warfare", model = "models/cs/playermodels/guerilla.mdl" },
	{ key = "seal",      name = "Seal Team 6",       model = "models/cs/playermodels/urban.mdl"    },
	{ key = "gsg9",      name = "GSG-9",             model = "models/cs/playermodels/gsg9.mdl"     },
	{ key = "sas",       name = "SAS",               model = "models/cs/playermodels/sas.mdl"      },
	{ key = "gign",      name = "GIGN",              model = "models/cs/playermodels/gign.mdl"     },
	{ key = "vip",       name = "VIP",               model = "models/cs/playermodels/vip.mdl"      },
	{ key = "hostage",   name = "Hostage",           model = "models/cs/playermodels/hostage.mdl"  },
}

--[[
	The flashlight, which is Half-Life 1's rather than Source's.

	Source throws a cone from your view. Half-Life 1 did not: it lit the surface
	you were looking at, a pool of light that landed where you pointed rather
	than a beam that travelled to get there. Range is the falloff distance of
	that pool, in units.
]]
cfg.Flashlight = {
	Range      = 280,
	Brightness = 2,

	-- Very slightly warm. A pure white pool reads as a bug rather than a lamp.
	Color = Color( 255, 250, 235 ),

	-- Long enough that the light does not flicker when the key is held, short
	-- enough that a deliberate double tap still registers as two presses.
	PressGap = 0.25,
}

--[[
	What to load while the map is still loading.

	Source loads a model the first time something asks for one, so the first
	grenade thrown and the first prop spawned each cost a hitch at the worst
	moment. Doing it up front trades a longer wait nobody is playing through for
	no waits during the ones they are.

	Props are separate because they are the only part big enough to argue about
	- 742 models for a developer menu that players never open. Everything is
	already mounted either way, so this costs load time rather than downloads.
]]
cfg.Precache = {
	Weapons      = true,
	PlayerModels = true,
	Props        = true,
}

cfg.HandsModel = "models/weapons/c_arms_cs16.mdl"

--[[
	The knife everyone carries.

	Named once because six different things need to agree on it - the loadouts,
	the slot rules, what survives a drop, the melee-kill announcement and the
	developer kit - and a knife nobody can drop is a bad thing to have two
	spellings of.
]]
cfg.Knife = "weapon_cs16_knife_beta"

-- Default kit. The buy menu will add to this later; in 1.6 you always start a
-- round with your knife and your team's stock pistol.
cfg.Loadout = {
	T  = { cfg.Knife, "weapon_cs16_glock18" },
	CT = { cfg.Knife, "weapon_cs16_usp" },
}

cfg.Health = 100
cfg.Armor  = 0

-- 1.6 ran at 250 units/s. Individual weapons override this via the SWEP base's
-- GetMaxSpeed (an AWP drops you to 210), which sv_movement applies.
cfg.BaseSpeed = 250

-- Holding +speed walks quietly instead of sprinting, which is how CS behaves.
cfg.WalkSpeedMultiplier = 0.52

--[[
	Ducking, as a fraction of full pace.

	Garry's Mod ships 0.6, which put a crouching player at 150 against the 130
	of somebody walking quietly - so crouching was the faster way to move
	carefully, which is exactly backwards. 1.6 ducks at about a third, landing
	here on 85, comfortably the slowest way to travel.
]]
cfg.CrouchSpeedMultiplier = 0.34

--[[
	Falling, in the units per second you land at rather than the height you
	fell from, because that is what the engine reports.

	Half-Life's numbers, which 1.6 inherited: nothing under SafeSpeed hurts at
	all, FatalSpeed kills outright from full health, and everything between is a
	straight line. At the 600 gravity this runs at that makes a drop of about
	280 units free, and one of about 875 lethal - roughly four player heights
	and twelve.

	Garry's Mod's own answer is a flat 10 whatever you fell off, which is why a
	rooftop cost the same as a kerb.
]]
cfg.Fall = {
	SafeSpeed  = 580,
	FatalSpeed = 1024,
}

cfg.JumpPower = 220

-- Weapons that exist in the addon but we don't want in play. The shield's
-- item entities are broken upstream and nobody wants it anyway.
cfg.BlockedWeapons = {
	[ "weapon_cs16_shield" ]  = true,
	[ "weapon_cs_shield_ent" ] = true,
}

--[[ Voice ]]

cfg.Voice = {
	-- Counter-Strike voice was always team-only. Turn this off for a server
	-- that would rather everyone could hear everyone.
	TeamOnly = true,

	-- Warmup has no sides worth protecting, and people tend to be sorting
	-- themselves out.
	AllTalkInWarmup = true,
}

--[[ Rounds ]]

cfg.Round = {
	FreezeTime = 15,
	RoundTime  = 300,
	EndTime    = 5,

	-- Both sides need someone on them before a round can be contested. Set to
	-- 1 so a solo developer can still walk a live round on an empty server.
	MinPlayers = 1,

	-- Warmup is free-for-all, so death there is only a short wait.
	WarmupRespawn = 3,
}

--[[
	Match format: MR12, as CS2 plays it.

	Twelve rounds a half, sides swap at the break, first to thirteen takes the
	match. Twenty-four rounds without a winner is twelve all, which is a draw
	here rather than going to overtime.
]]
cfg.Match = {
	WinScore   = 13,
	HalfLength = 12,
	MaxRounds  = 24,

	-- Sides swap and everyone gets a breather before the second half.
	HalftimeLength = 60,

	--[[
		Twelve all after regulation goes to overtime: six rounds, first to four
		of them. Sides swap halfway through that too, or one team would play
		the whole decider on the same side.

		Another dead heat starts another overtime, so there's always a result.
	]]
	Overtime = {
		Rounds     = 6,
		WinsNeeded = 4,
	},

	-- Seconds on the final scoreboard before the map reloads.
	EndDelay = 15,
}

--[[
	Teams.

	Five a side, and you're committed once you pick one - no switching, and no
	coming back from spectator, until the map changes. That's what stops people
	hopping to whichever side is winning.
]]
cfg.Teams = {
	MaxPerTeam = 5,

	--[[
		How many the bots keep each side topped up to.

		Separate from the cap above because they answer different questions: the
		cap is how many people may play, this is how big a game the bots make of
		it when they don't. Gungame opens the cap to ten a side while still
		filling to five.
	]]
	BotFillPerTeam = 5,
}

--[[
	Quake announcer.

	Half the 1.6 servers in the wild ran these, so it's period-accurate as well
	as fun. It sits on top of the radio calls rather than replacing them: radio
	announces the round, this announces the killing.
]]

cfg.Announcer = {
	Enabled = true,

	-- "standard" or "female". The female set is missing several rungs of the
	-- multikill ladder, so anything absent falls back to standard.
	Set = "standard",

	-- Kills inside this many seconds of each other chain into a multikill.
	MultikillWindow = 3,
}

--[[ Bots ]]

cfg.Bots = {
	--[[
		The roster. Exactly ten, one per slot, and they keep their progression
		between maps - see core/modules/progression. These are the names that
		appear on the bot leaderboard, so they are meant to be recognisable
		rather than interchangeable.
	]]
	Names = {
		"Calvin", "Cornelius", "Dale", "Randy", "Brandon",
		"Ted", "Oswaldo", "Archibald", "Julia", "Amelia",
	},

	--[[
		Only drawn from when one of the ten is unavailable, which in practice
		means a human has connected using that name - PickName skips anything
		already taken, and ten names for ten slots leaves no slack, so without
		these you would quietly field nine bots.

		A reserve bot has no saved progression of its own and starts from
		nothing. That is the right trade for a case this rare: the alternative
		is letting a player claim a bot's levels by copying its name.
	]]
	ReserveNames = {
		"Marvin", "Gus", "Herbert", "Lorraine", "Delbert",
	},

	--[[
		Radians-per-second-ish turn rate onto a target. Higher snaps harder.

		Was 8.5, which turned onto somebody fast enough that coming round a
		corner behind a bot bought you almost nothing.
	]]
	AimSpeed = 6.5,

	--[[
		Seconds between seeing someone and pulling the trigger.

		Was 0.2. This is the knob a player feels most directly, because it is
		the whole of the opening moment of a fight - the difference between
		being shot as you appear and having time to shoot first.
	]]
	ReactionTime = 0.3,

	--[[
		How often a roaming bot walks toward an enemy rather than anywhere.

		This is the knob that decides how quickly a match plays out, and it
		matters far more than any of the aim settings: measured, bots were in
		contact only about a quarter of the time and spent the rest travelling,
		so sharpening their shooting improved the small half of the problem.

		Not 1. A side that always walks at its enemies collapses into a single
		rolling fight in the middle of the map and the rest of it never gets
		used, which is both duller to watch and worse to play against.

		HuntSpread is how near they aim for - the ground around somebody rather
		than the person, so they arrive where the fight is instead of tracking a
		player through walls.
	]]
	HuntChance = 0.7,
	HuntSpread = 600,

	-- Bots can't see behind themselves, same as you.
	FOV = 110,

	ViewDistance = 3500,

	--[[
		How long a bot keeps chasing somebody it can no longer see.

		Sight is the only thing that made an enemy exist, so losing it used to
		erase them outright - and because sight includes the FOV cone above,
		merely turning was enough. Two survivors would find each other at range,
		break line of sight, and both immediately go back to wandering.

		Memory is deliberately for *pursuit only*. A remembered enemy is walked
		toward, never shot at: a bot that kept firing on one would be shooting
		through walls at a position it cannot see.

		Long enough to round the corner somebody just went behind, short enough
		that a bot does not spend the match chasing a ghost.
	]]
	EnemyMemory = 6,

	--[[
		How close an enemy has to be before a bot holding only a knife will
		fight rather than keep looting.

		Only applies where there is a gun to go and fetch - battle royale. A
		knife against a rifle is a loss, so while there is still loot to reach,
		walking away is simply better play. Inside this range walking away just
		means being shot in the back, so it commits instead.

		This must not leak into gungame, where the knife is the last rung and
		bots are supposed to hunt with it. It cannot, because the condition is a
		live loot target, which only battle royale ever sets.
	]]
	MeleeAvoidRange = 550,

	--[[
		Maximum aim wobble in degrees, refreshed on the slow clock so it drifts
		like a hand rather than vibrating. Bigger is worse aim.

		Note this is only half of how dangerous they are - the other half is
		where they aim in the first place. They deliberately go for the chest,
		not the head; aiming at EyePos made them land headshots almost every
		time, which is lethal rather than difficult.
	]]
	AimError = 2.6,

	--[[
		Trigger discipline: 1.6 recoil punishes holding the trigger down.

		The pause is the half worth tuning. Reaction time only costs a bot the
		opening moment of a fight, but this is paid between every burst, so it
		sets how long an even exchange takes to resolve.
	]]
	BurstMin = 0.22, BurstMax = 0.55,

	-- Was 0.16 / 0.34. Longer gaps between bursts give the other side of an
	-- even exchange somewhere to fit an answer, which is most of what makes a
	-- fight winnable rather than simply lost on the draw.
	PauseMin = 0.22, PauseMax = 0.45,

	--[[
		Safety refresh only. A bot repaths when its goal changes or its path
		runs out, so this just catches a route going stale - it doesn't need to
		be frequent, and rebuilding constantly only burns CPU.
	]]
	RepathInterval = 3.0,

	-- How far Terrorists hold from a planted bomb rather than standing on it.
	BombHoldRadius = 700,

	-- The C4 kills well past the site, so bots clear this much room before it
	-- goes off, starting with this many seconds left on the timer.
	BlastRadius = 1100,
	FleeAt      = 10,

	-- Pitch limit while navigating. Bots were craning at the sky chasing
	-- waypoints above them; nothing they walk toward warrants more than this.
	NavPitchLimit = 25,

	--[[
		Grenades. Rolled once per engagement, so this is the share of fights a
		bot opens with an HE rather than a per-tick chance.

		The range window matters more than the odds: too close and they blow
		themselves up, too far and it lands nowhere near anybody.
	]]
	NadeChance   = 0.3,
	NadeMinRange = 500,
	NadeMaxRange = 1800,
	NadeCooldown = 15,

	-- How close a team-mate may be to the target before the throw is called
	-- off. A little wider than the blast, since neither the grenade nor the
	-- team-mate stands still.
	NadeSafeRange = 400,

	--[[
		How long a bot holds a bomb site with nothing happening before going to
		look at the other one.

		Random per bot and per rotation so a squad drifts across rather than
		turning on the spot together. Without any rotation at all, both sides
		settle at opposite ends of the map and stay there - which a bomb
		eventually forces the issue on, and a gungame never does.
	]]
	RotateAfterMin = 20,
	RotateAfterMax = 40,

	--[[
		How much a bot is allowed to disagree about the best way round, in units
		of extra path cost per area it steps through.

		A* is deterministic, so without this every bot heading for the same site
		walks the same line - all eighteen Terrorist spawns on dust2 produced a
		route through one corridor, not because the alternatives were worse but
		because nothing ever asked for a second opinion. Each bot has a fixed
		arbitrary preference for some areas over others, which tips a close
		decision between two corridors.

		Too low and they file along one route; too high and they take genuinely
		silly ones to satisfy a preference that means nothing. 0 turns it off.

		Measured on dust2, twenty-four seeds from a Terrorist spawn to site A,
		against an optimal route of 4821 units:

		    0-60   one corridor       - no effect at all
		    120    19 mid / 5 long    + 1.7% average
		    250    14 mid / 10 long   + 3.6% average
		    400     9 mid / 15 long   + 6.2% average

		250 is the knee. Three distinct approaches, a roughly even split, and a
		cost you would struggle to notice. By 400 most of them have abandoned
		mid, which is genuinely the shorter way, to satisfy a preference about
		nothing.
	]]
	RouteVariety = 250,

	--[[
		How close to the firing line a team-mate has to be before a bot holds
		fire, in units.

		A player is about 32 wide, so half of that is the point where a shot
		would genuinely hit them. Above it is margin for a team-mate who is
		moving; too much margin and a bot pushing a site with four others never
		gets to shoot at all.
	]]
	FriendlyClearance = 24,

	--[[
		And how much that margin widens per unit of distance.

		Everything that makes a shot miss is angular - a bot's aim wanders by a
		degree or two, and the weapon's cone opens with range - so a fixed
		margin is right at arm's length and far too tight down a long. 0.05 is
		about three degrees, which covers the aim wobble and most of the spread.
	]]
	FriendlySpread = 0.05,

	--[[
		Keep the two sides at a full 5v5 around whoever is actually here, so a
		match is always running to join. Starts once somebody picks a team and
		stops when the last person disconnects - see core/modules/bots/sv_autofill.lua.

		Naming a bot count by hand turns this off for the session, since
		otherwise it would undo you within half a second.
	]]
	AutoFill = true,
}

--[[
	Weapon spread multiplier.

	The SWEP pack's bloom is punishing enough that landing a shot on a moving
	target at range is mostly luck. Every weapon routes its spread through one
	function, so this scales all of them at once - see core/modules/weapons/sh_accuracy.lua.

	1 is the pack's own behaviour, lower is tighter. This is a deliberate
	departure from the addon's tuning rather than a fix, so it's a single
	obvious number to put back.
]]
cfg.SpreadScale = 0.5

--[[
	Damage.

	The pack's per-weapon figures are faithful to 1.6 almost throughout - AK 36,
	M4 33, Deagle 54, Glock 25 are all exactly right - but it applies no
	hitgroup scaling whatsoever. Hitgroup is read once, to size the knockback,
	and never touches the damage. That single omission is why everything felt
	weak: in 1.6 a rifle headshot is four times a chest shot, so an AK head hit
	should be 144 and was landing 36.

	Restoring the hitgroup table is therefore most of the "buff" on its own, and
	it's a restoration rather than an invention - these are 1.6's own numbers.
]]
cfg.Damage = {
	--[[
		Global multiplier applied on top of everything below. The knob to reach
		for when the whole game feels off; 1 is the pack's own damage, once
		hitgroups are accounted for.
	]]
	Scale = 1,

	Hitgroups = {
		[ HITGROUP_HEAD ]     = 4,
		[ HITGROUP_CHEST ]    = 1,
		[ HITGROUP_STOMACH ]  = 1.25,
		[ HITGROUP_LEFTARM ]  = 1,
		[ HITGROUP_RIGHTARM ] = 1,
		[ HITGROUP_LEFTLEG ]  = 0.75,
		[ HITGROUP_RIGHTLEG ] = 0.75,
	},

	--[[
		Per-weapon corrections, as multipliers on the pack's own damage.

		Only for weapons where the pack's number is plainly wrong against 1.6.
		The AWP is the obvious one - 75 in the pack against 115 in 1.6, which is
		exactly why it stopped being a one-shot and needed four or five hits.
		The G3SG1 has the same problem in the other calibre.
	]]
	Weapons = {
		[ "weapon_cs16_awp" ]   = 115 / 75,
		[ "weapon_cs16_g3sg1" ] = 80 / 30,
	},

	--[[
		Explosions, keyed on the entity that produced them rather than a weapon,
		because that is what an explosion actually comes from.

		The pack's numbers are far too low once armour is involved, and armour is
		what makes them feel broken rather than merely weak. Measured: body armour
		absorbs 80% of blast damage until it is used up, so 100 armour swallows
		the first 100 points of any explosion whole. The launcher's grenade deals
		50 at the centre, so an armoured target took *ten* damage from a direct
		hit - four point-blank shots left them standing on 60 health.

		Because the falloff was already applied before this runs, scaling here
		multiplies the whole curve without touching the blast radius. A grenade
		still reaches exactly as far as it did; it just means something when it
		gets there.

		The two are tuned separately because they are different weapons. The
		launcher's job is to kill what it hits directly; the thrown grenade's job
		is to hurt a group and finish the wounded, which is what it does in 1.6 -
		lethal at your feet, painful nearby.
	]]
	Explosives = {
		-- 50 -> 175. One direct hit kills an unarmoured player outright and
		-- takes 75 off an armoured one, so two land the kill.
		[ "ent_cs16_mk1_hegrenade" ] = 3.5,

		-- 100 -> 160. Standing on one is fatal without armour; with armour it
		-- takes 60 and leaves you needing help.
		[ "ent_cs16_hegrenade" ] = 1.6,

		--[[
			The LAW is deliberately absent. It already deals 600 over a 1500
			radius, which kills through full armour several times over - there is
			nothing here to fix, and a multiplier on it would only make the
			splash reach further into rooms nobody aimed at.
		]]
	},
}

--[[
	The developer team: a body to walk around a live round in, and nothing else.

	Knife only, on purpose - the point is watching the match, not joining it.
	Nothing here needs a price or a team restriction because none of the buying
	rules apply to a team that isn't playing.
]]
--[[
	The phaser is in the loadout rather than granted around it.

	CS16.CanPickupWeapon checks the class against this list, so anything handed
	to a developer that isn't in it gets refused on the way in. It used to be
	appended at runtime by the addon, hedged against the gamemode loading either
	side of it; the weapon ships with the gamemode now, so it can simply be
	declared here.
]]
cfg.Developer = {
	Model   = "models/player/charple.mdl",
	Loadout = { cfg.Knife, "weapon_cs16_phaser" },
}

--[[ Objective ]]

cfg.Bomb = {
	-- The addon hardcodes 35s; 1.6 used 45. We override it on plant.
	Timer = 45,

	PlantBonus  = 800,
	DefuseBonus = 300,

	-- 1.6's timings: ten seconds bare-handed, five with a kit.
	DefuseTime    = 10,
	DefuseTimeKit = 5,

	--[[
		How far you may stand from the bomb, checked the whole way through.

		The addon used two different numbers - you could begin a defuse from
		about 64 units away, but its completion check cancelled anything beyond
		32, silently, after the full bar had run. See core/modes/competitive/sv_defuse.lua.
	]]
	DefuseRange = 72,
}

--[[
	Hostage rescue, on maps authored with hostage spots. See sh_zones.

	1.6 paid $1000 for a rescue, plus the team bonus for winning the round -
	which the round money already covers.
]]
cfg.Hostage = {
	RescueBonus = 1000,

	--[[
		Deliberately below the 320 a player runs at.

		A hostage that keeps up perfectly is just a trailing prop; one that can
		be outrun makes escorting it a decision, which is the whole point of the
		mode. Slow enough to have to wait for, fast enough not to be tedious.
	]]
	FollowSpeed = 250,

	-- Close enough not to trail down a corridor, far enough not to stand in
	-- your line of fire.
	FollowDistance = 90,

	--[[
		What a hostage says when you take it, picked at random the way 1.6
		varies its lines.

		These are the originals, and they come from the sound pack rather than
		from this gamemode - the same place the radio and round cues come from,
		so nothing here is ours to ship and the Credits section stays true.
		Note the path: they sit under counterstrike16/hostages/ rather than at
		1.6's own sound/hostage/, which is empty on this install.

		There is deliberately no sound for leaving one behind. Nothing in the
		pack fits a hostage being told to wait, and the wrong voice saying the
		wrong thing is worse than a hostage that simply stops walking. The chat
		line already says what happened.
	]]
	FollowSounds = {
		"counterstrike16/hostages/hos1.wav",
		"counterstrike16/hostages/hos2.wav",
		"counterstrike16/hostages/hos3.wav",
		"counterstrike16/hostages/hos4.wav",
		"counterstrike16/hostages/hos5.wav",
	},

	StaySounds = {},
}

--[[
	Ammunition, bought with , and . as in 1.6 - one magazine per press for
	your primary and secondary respectively.

	These are the standard 1.6 prices per purchase. They're compiled into the
	original mod rather than living in any readable file, so they're set from
	the well-known values rather than verified against an install; adjust here
	if any look wrong.
]]
cfg.AmmoPrices = {
	CS16_9MM        = 20,
	CS16_45ACP      = 25,
	CS16_50AE       = 40,
	CS16_357SIG     = 50,
	CS16_57MM       = 50,
	CS16_556NATO    = 60,
	CS16_556NATOBOX = 60,
	CS16_BUCKSHOT   = 65,
	CS16_762NATO    = 80,
	CS16_338MAGNUM  = 125,
}

--[[ Economy ]]

cfg.Money = {
	Start    = 800,
	Max      = 16000,
	WinRound = 3250,
	Kill     = 300,

	--[[
		The loss bonus climbs while you keep losing, and drops back the moment
		you win a round. 1.6's ladder, and the reason a side that loses the
		pistol round isn't mathematically finished.

		A flat loss bonus is what produces the death spiral: broke, so you buy
		nothing, so you lose, so you stay broke. The escalation only ever helps
		the team that is actually struggling, which is why it can be this
		generous without making rounds cheap.
	]]
	LoseRound = { 1400, 1900, 2400, 2900, 3400 },
}

--[[ Team Deathmatch ]]

cfg.TDM = {
	--[[
		First side to this many kills takes it.

		A hundred is roughly fifteen to twenty minutes with ten players, which
		puts it alongside a gun game rather than a full MR12 - this is the mode
		you put on when nobody wants to commit to a match.
	]]
	ScoreLimit = 100,

	--[[
		And a clock, so a quiet server still finishes. Whoever is ahead when it
		runs out wins; level is a draw.
	]]
	TimeLimit = 1200,

	RespawnDelay = 3,

	--[[
		Reserve ammunition is refilled as fast as it is spent, so reloading costs
		time but never depletes you. Grenades are excluded - see the note in
		sv_tdm.lua.
	]]
	UnlimitedAmmo = true,

	-- Long enough to read the result before the map reloads for the next one.
	EndTime = 10,

	--[[
		What you start with before you have bought anything, and what you fall
		back to if your saved loadout is somehow unavailable. A pistol and a
		knife, the same opening competitive gives you.
	]]
	Starting = { "weapon_cs16_glock18" },

	--[[
		What bots turn up with, drawn fresh each time they spawn.

		They cannot use the buy menu here. Bots buy at the top of a round, and
		this mode has no rounds - left alone they would carry the starting pistol
		all game while every human ran a rifle.

		Picked at random from a list rather than bought, because with everything
		free the buying logic has nothing to weigh and would hand all ten of them
		whichever gun it rates highest. A spread is better to play against, and
		better to watch.
	]]
	BotPrimaries = {
		"weapon_cs16_ak47", "weapon_cs16_m4a1", "weapon_cs16_mp5navy",
		"weapon_cs16_famas", "weapon_cs16_galil", "weapon_cs16_aug",
		"weapon_cs16_sg552", "weapon_cs16_ump45", "weapon_cs16_p90",
		"weapon_cs16_m3", "weapon_cs16_scout",
	},

	BotSecondaries = {
		"weapon_cs16_glock18", "weapon_cs16_usp", "weapon_cs16_deagle",
		"weapon_cs16_p228",
	},
}

--[[ Battle Royale ]]

cfg.BR = {
	--[[
		What can appear on a loot point, drawn fresh each match.

		Weighted by repetition rather than by a weight field, which is cruder but
		reads at a glance: a pistol appears three times in this list and the AWP
		once, so pistols are common and the AWP is the thing you hope for.

		Deliberately no grenades. A grenade found on the floor is a coin flip
		rather than a fight, and with twenty-eight loot points there would be
		enough of them to decide the match.
	]]
	Loot = {
		"weapon_cs16_glock18", "weapon_cs16_glock18", "weapon_cs16_glock18",
		"weapon_cs16_usp", "weapon_cs16_usp", "weapon_cs16_usp",
		"weapon_cs16_p228", "weapon_cs16_deagle",
		"weapon_cs16_mp5navy", "weapon_cs16_mp5navy",
		"weapon_cs16_ump45", "weapon_cs16_mac10", "weapon_cs16_tmp",
		"weapon_cs16_m3", "weapon_cs16_xm1014",
		"weapon_cs16_galil", "weapon_cs16_famas",
		"weapon_cs16_ak47", "weapon_cs16_m4a1",
		"weapon_cs16_aug", "weapon_cs16_sg552",
		"weapon_cs16_scout", "weapon_cs16_awp",
	},

	--[[
		Magazines that come with a found gun, beyond the one already in it.

		Two is enough to fight with and not enough to stop caring where the next
		gun is, which is the tension the mode runs on.
	]]
	SpareMagazines = 2,

	--[[
		How long a bot chases one gun before writing it off.

		Generous, because crossing dust2 legitimately takes a while - this is
		meant to catch a bot standing under a crate it cannot climb, not one
		taking the long way round.
	]]
	LootGiveUp = 12,

	-- Long enough to find a gun before anybody can be eliminated.
	WarmupTime = 15,

	-- Long enough to read who won before the next round begins.
	EndTime = 12,

	-- Everyone starts in a full vest. Nothing is bought here, so there is no
	-- other way to have one, and without it the first rifle found wins.
	Armor = 100,

	--[[
		Rounds played before the map reloads.

		Every match used to end in a changelevel, which resets the loot, the
		spawns dealt out and every scrap of per-match state in one go - correct,
		and enormously heavy for something that happens every few minutes.
		Rounds restart in place the way competitive's do, and the reload comes
		round once per set instead.
	]]
	Rounds = 5,

	--[[
		A grace period once there are enough people, before the first shot.

		Without it the match begins the instant the numbers are met, which
		punishes whoever was slowest to load - they arrive to find everybody
		already armed and hunting. Long enough for a map load on a slow machine.
	]]
	StartCountdown = 30,

	--[[
		A match needs at least this many to be a match. Below it the mode sits in
		warmup rather than declaring somebody the last survivor of a field of one.
	]]
	MinPlayers = 2,
}

--[[ Progression ]]

--[[
	Experience. See core/modules/progression/ - the curve is RuneScape's, and
	levels are cosmetic, so these numbers set how long the grind is and nothing
	else.
]]
cfg.XP = {
	--[[
		Per kill, banded by the tens digit of your level: 1-9 pay the first
		entry, 10-19 the second, 90-99 the last.

		Against these rates 99 is roughly sixteen thousand kills, of which the
		last two bands are about eighty per cent - the curve's shape survives
		the escalating pay.
	]]
	KillBands = { 50, 100, 200, 300, 400, 500, 600, 700, 800, 900 },

	RoundWin  = 100,
	RoundLoss = 20,
	MatchWin  = 500,
	MatchLoss = 150,

	-- A plant, a defuse, or a hostage brought home. Flat, and not discounted
	-- for bots: the objective is the round, whoever happens to be doing it.
	Objective = 100,

	--[[
		Killing a bot pays half.

		There are always ten of them and they always die, so without this the
		optimal way to level is to play alone forever - which is the least
		interesting thing the server does. Round, match and objective experience
		are deliberately not scaled, so playing the game properly against bots
		is still worth something.
	]]
	BotKillScale = 0.5,

	--[[
		RuneScape's ceiling. Level 99 is 13,034,431, so this leaves fourteen
		times the whole journey there as headroom - which is what keeps the
		leaderboard meaningful once the top of it is all nines.
	]]
	Cap = 200000000,
}

--[[
	Round announcements, using the original CS 1.6 radio clips.

	These need to resolve under garrysmod/sound/, which means the files have to
	come from a properly-structured addon - see the note in the project readme
	about addons/Half-Life not being mountable as it stands. Any entry left
	empty is simply skipped, so a missing file is silent rather than an error.

	The defuse keeps the addon's own audio - weapons/bombdef.wav, played from
	the bomb, which is the right way round for a sound whose whole meaning is
	"somebody is standing over there doing this".

	The plant is different and is listed below. The addon plays it from the
	planter, so it reached only the handful of people already near enough to see
	them do it, while the side holding the other end of the map found out from
	the chat or not at all. We broadcast it flat as well - see
	core/modes/competitive/sv_objectives.lua, including why the addon's copy
	cannot be silenced from there.
]]
cfg.Sounds = {
	RoundStart = "radio/letsgo.wav",
	WinT       = "radio/terwin.wav",
	WinCT      = "radio/ctwin.wav",

	-- Heard by everyone, both sides, wherever they are.
	BombPlanted = "weapons/bombpl.wav",
	Draw       = "radio/rounddraw.wav",
}
