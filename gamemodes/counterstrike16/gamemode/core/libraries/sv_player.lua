--[[
	Player lifecycle: joining, team selection, spawning, loadout and death.
]]

util.AddNetworkString( "CS16.OpenTeamMenu" )
util.AddNetworkString( "CS16.JoinTeam" )
util.AddNetworkString( "CS16.PickModel" )

-- Everyone starts as a spectator and picks a side, the way CS does.
function GM:PlayerInitialSpawn( ply, transition )
	ply:SetTeam( TEAM_SPECTATOR )

	-- Bots are put on a side by CS16.AddBot and have nothing to show a menu to.
	if ply:IsBot() then return end

	-- The client isn't ready for net messages on the same tick it connects.
	timer.Simple( 1, function()
		if not IsValid( ply ) then return end
		CS16.OpenTeamMenu( ply )
	end )
end

function CS16.OpenTeamMenu( ply )
	net.Start( "CS16.OpenTeamMenu" )
	net.Send( ply )
end

function GM:PlayerSpawn( ply, transition )
	-- No body outside the top of a round: spectators, players who died this
	-- round, and anyone who joined mid-round all follow the play instead.
	if not CS16.CanTakeBody( ply ) then
		ply:StripWeapons()

		-- Only move genuine spectators onto the spectator team. Someone
		-- sitting out a round keeps the side they picked.
		if not CS16.IsPlayingTeam( ply:Team() ) then
			ply:SetTeam( TEAM_SPECTATOR )
		end

		CS16.BeginSpectating( ply )
		return
	end

	CS16.StopSpectating( ply )
	ply:UnSpectate()

	-- Model has to be set before hands, or the hands bind to the old skeleton.
	self:PlayerSetModel( ply )
	ply:SetupHands()

	ply:SetMoveType( MOVETYPE_WALK )
	ply:SetMaxHealth( CS16.Config.Health )
	ply:SetHealth( CS16.Config.Health )
	ply:SetArmor( CS16.Config.Armor )
	ply:SetJumpPower( CS16.Config.JumpPower )
	ply:AllowFlashlight( true )

	CS16.ApplySpeed( ply )
	self:PlayerLoadout( ply )
end

--[[
	The flashlight is handled in core/modules/flashlight, not here.

	AllowFlashlight above is still required and is half of why it appeared not
	to exist at all: with it off the engine never asks, so nothing downstream
	gets a chance to answer. What it asks - PlayerSwitchFlashlight - is answered
	by that module, which refuses Source's cone every time and lights a
	Half-Life 1 pool instead.

	Deliberately not a GM method here as well. A hook that returns a value stops
	the gamemode method being consulted at all, so a copy of the permission
	rules in this file would look authoritative and never once run.
]]

function GM:PlayerSetModel( ply )
	-- One fixed model, so a developer is instantly recognisable as not being
	-- part of the round they're walking through.
	if ply:Team() == TEAM_DEV then
		ply:SetModel( CS16.Config.Developer.Model )
		return
	end

	--[[
		A model the player chose for themselves.

		Only where the mode has no sides to dress for. In competitive the model
		is how you tell a team-mate from somebody about to shoot you, so it stays
		the side's business; in battle royale everyone is an enemy and it may as
		well be whoever you like, hostage included.

		Bots use the same field, dealt a fresh one each match. See sv_br.lua.
	]]
	if CS16.SoloTeam() and CS16.IsPlayingTeam( ply:Team() ) then
		--[[
			One at random for anyone who hasn't got one, and that fallback is
			not a nicety.

			TeamCode below has no answer for a team that isn't T or CT, so it
			returns nil and the whole function gives up - leaving the engine's
			own models/player.mdl on the body. Every bot added after the match
			had started was wearing it, because DealModels only runs at the top
			of a match and nothing else filled the gap.

			Stored rather than rolled per spawn, so a model stays put for as
			long as its owner does.
		]]
		if not ply.CS16PickedModel then
			local pool = CS16.Config.PickableModels
			ply.CS16PickedModel = pool[ math.random( #pool ) ].model
		end

		ply:SetModel( ply.CS16PickedModel )
		return
	end

	local code = CS16.TeamCode( ply:Team() )
	if not code then return end

	local roster = CS16.Config.Models[ code ]

	-- Keep a player's model stable until they switch sides.
	if not ply.CS16Model or ply.CS16ModelTeam ~= ply:Team() then
		ply.CS16Model     = roster[ math.random( #roster ) ]
		ply.CS16ModelTeam = ply:Team()
	end

	ply:SetModel( ply.CS16Model )
end

function GM:PlayerSetHandsModel( ply, ent )
	ent:SetModel( CS16.Config.HandsModel )
	ent:SetSkin( 0 )
	ent:SetBodyGroups( "00000000" )
end

--[[
	Surviving a round means keeping what you're holding.

	The round still respawns everyone - that's how they get moved back to spawn
	and unfrozen - so the kit has to be lifted off survivors beforehand and put
	back afterwards, otherwise PlayerLoadout hands them a pistol and bins the
	rifle they just won the round with.

	The C4 is deliberately excluded: sv_rounds hands it out fresh each round, so
	carrying one over would produce two.
]]
--[[
	Did this player actually survive the round, as opposed to merely not being
	dead?

	Being alive isn't enough. Anyone who joined mid-round - which is exactly
	what /bots does - was stripped and parked in a spectator camera by
	PlayerSpawn, and Spectate doesn't kill you. They're alive, holding nothing,
	and treating them as survivors carried an empty kit into the next round.
	The knife fallback in RestoreLoadout then left them with a knife and
	nothing else.
]]
function CS16.Survived( ply )
	return ply:Alive()
		and ply.CS16RoundTeam ~= nil
		and ply:GetObserverMode() == OBS_MODE_NONE
end

function CS16.CaptureLoadout( ply )
	local kit = {
		weapons = {},
		ammo    = {},
		armor   = ply:Armor(),
		helmet  = ply:GetNWBool( "CS16.Helmet", false ),
	}

	for _, wep in ipairs( ply:GetWeapons() ) do
		local class = wep:GetClass()
		if class == "weapon_cs16_c4" then continue end

		kit.weapons[ #kit.weapons + 1 ] = { class = class, clip = wep:Clip1() }

		local ammoType = wep:GetPrimaryAmmoType()
		if ammoType and ammoType >= 0 then
			kit.ammo[ ammoType ] = ply:GetAmmoCount( ammoType )
		end
	end

	return kit
end

function CS16.RestoreLoadout( ply, kit )
	for _, entry in ipairs( kit.weapons ) do
		local wep = ply:Give( entry.class )

		if IsValid( wep ) and entry.clip and entry.clip >= 0 then
			wep:SetClip1( entry.clip )
		end
	end

	-- After the weapons: Give hands out a default clip of reserve ammo, and
	-- these are the counts that should actually stand.
	for ammoType, count in pairs( kit.ammo ) do
		ply:SetAmmo( count, ammoType )
	end

	ply:SetArmor( kit.armor )
	ply:SetNWBool( "CS16.Helmet", kit.helmet )

	-- You never lose your knife, whatever else happened.
	if not ply:HasWeapon( CS16.KNIFE ) then
		ply:Give( CS16.KNIFE )
	end

	--[[
		Then a free reload, on everything you kept.

		Surviving a round with a part-empty magazine meant starting the next one
		unable to do anything about it: you are frozen through the buy period, so
		the reload cannot even begin until the round is already live, and the
		first thing you do with a new round is stand in the open pressing R.

		Ammunition is moved out of your reserve rather than conjured, so this
		costs exactly what reloading by hand would have - it only removes the
		waiting. A magazine you have no reserve to fill stays as it is, and
		buying more is the answer to that, as it always was.
	]]
	CS16.TopUpMagazines( ply )
end

--[[
	Fill every magazine from its own reserve, instantly.

	Deliberately not a loop over kit.weapons: by this point the knife and
	anything else granted along the way are in hand too, and "everything you are
	carrying" is both simpler to reason about and the thing that was actually
	meant.
]]
function CS16.TopUpMagazines( ply )
	for _, wep in ipairs( ply:GetWeapons() ) do
		local max = wep:GetMaxClip1()

		-- Weapons that don't use a magazine report -1, and the knife reports
		-- nothing worth filling.
		if not max or max <= 0 then continue end

		local clip = wep:Clip1()
		if clip >= max then continue end

		local ammoType = wep:GetPrimaryAmmoType()
		if not ammoType or ammoType < 0 then continue end

		local reserve = ply:GetAmmoCount( ammoType )
		if reserve <= 0 then continue end

		local moved = math.min( max - clip, reserve )

		wep:SetClip1( clip + moved )
		ply:SetAmmo( reserve - moved, ammoType )
	end
end

--[[
	Hand a player a weapon regardless of the pickup rules.

	CanPickupWeapon exists to stop you carrying four rifles off a firefight; it
	has no business refusing something the gamemode has decided to give you.
	Every direct grant goes through here - the buy menu, a gungame promotion -
	and the flag is cleared immediately, so it never covers walking over a gun
	on the floor.
]]
function CS16.GrantWeapon( ply, class )
	ply.CS16Granting = true

	local wep = ply:Give( class )

	ply.CS16Granting = nil
	return wep
end

function GM:PlayerLoadout( ply )
	--[[
		A mode may own the loadout outright. Gungame does: what you carry is
		whichever rung of the ladder you're on, so there's nothing here to
		decide.
	]]
	local loadout = CS16.ModeSetting( "Loadout" )

	if loadout and CS16.IsPlayingTeam( ply:Team() ) then
		ply:RemoveAllAmmo()
		ply:StripWeapons()

		loadout( ply )
		return true
	end

	if ply:Team() == TEAM_DEV then
		ply:RemoveAllAmmo()
		ply:StripWeapons()

		for _, class in ipairs( CS16.Config.Developer.Loadout ) do
			ply:Give( class )
		end

		return
	end

	local code = CS16.TeamCode( ply:Team() )
	if not code then return end

	ply:RemoveAllAmmo()
	ply:StripWeapons()

	local carried = ply.CS16Carry
	ply.CS16Carry = nil

	-- An empty kit is never worth restoring - falling through to the standard
	-- loadout is always better than spawning someone with nothing. Belt and
	-- braces on top of the Survived check that produces the kit.
	if carried and #carried.weapons > 0 then
		CS16.RestoreLoadout( ply, carried )

		local best = CS16.GetOwnedOfKind( ply, "primary" )
			or CS16.GetOwnedOfKind( ply, "secondary" )

		if IsValid( best ) then ply:SelectWeapon( best:GetClass() ) end

		CS16.StripForeignGear( ply )
		return true
	end

	for _, class in ipairs( CS16.Config.Loadout[ code ] ) do
		ply:Give( class )
	end

	ply:SelectWeapon( CS16.Config.Loadout[ code ][ 2 ] or CS16.Config.Loadout[ code ][ 1 ] )

	CS16.StripForeignGear( ply )
	return true
end

--[[ Team selection ]]

function CS16.SetTeam( ply, newTeam )
	if ply:Team() == newTeam then return end

	--[[
		The bomb stays in the round even if its carrier doesn't.

		Leaving a side kills the body with KillSilent below, which deliberately
		doesn't fire PlayerDeath - so the drop-on-death hook never ran and the
		bomb went with them. Nobody could win the round after that: the
		Terrorists had nothing to plant and no loose bomb to fetch.
	]]
	if CS16.IsPlayingTeam( ply:Team() ) and ply:HasWeapon( "weapon_cs16_c4" ) then
		CS16.DropWeaponItem( ply, ply:GetWeapon( "weapon_cs16_c4" ) )
	end

	ply:SetTeam( newTeam )

	-- Switching sides wipes your wallet, so you can't bank cash on one team
	-- and carry it to the other.
	CS16.ResetMoney( ply )

	-- Whatever round is in progress, you're no longer part of it.
	ply.CS16RoundTeam = nil

	if CS16.HasBody( newTeam ) then
		ply:Spawn()
	else
		-- Dropping to spectator kills the body so you can't hold a site by
		-- switching sides mid-round.
		if ply:Alive() then ply:KillSilent() end
		ply:Spawn()
	end
end

net.Receive( "CS16.JoinTeam", function( len, ply )
	local choice = net.ReadUInt( 3 )
	local class  = net.ReadUInt( 4 )

	local wanted
	if choice == 1 then wanted = TEAM_T
	elseif choice == 2 then wanted = TEAM_CT
	elseif choice == 3 then wanted = CS16.SmallestTeam()
	elseif choice == 5 then wanted = TEAM_DEV
	else wanted = TEAM_SPECTATOR end

	--[[
		One side means one answer.

		Battle royale's menu offers no side to pick, but this arrives as a net
		message and the old team menu is still bound to M - so anything asking
		to play lands on the team that is playing rather than on a side that
		isn't, where it would sit outside the match with no way back in.
	]]
	local solo = CS16.SoloTeam()
	if solo and ( wanted == TEAM_T or wanted == TEAM_CT ) then wanted = solo end

	--[[
		The class, checked against the side actually being joined rather than
		against the one the menu thought it was offering.

		This is a net message, so the index is whatever somebody chose to send.
		Looking it up in the side's own class list is what stops a Terrorist
		asking for a GIGN uniform: an index that is not on that side's list
		simply is not found, and the random roll the loadout would have made
		stands instead.

		Zero is Auto Select and means exactly that, so it never gets this far.
	]]
	if class > 0 then
		local entry = CS16.ClassesForTeam( wanted )[ class ]

		if entry then
			ply.CS16Model     = entry.model
			ply.CS16ModelTeam = wanted
		end
	end

	if wanted == ply:Team() then
		--[[
			Already on this side, so this is a change of clothes rather than a
			way in. Applied at once outside a live round, and left for the next
			spawn during one, because swapping model mid-fight moves the
			hitboxes of somebody being shot at.
		]]
		if class > 0 and ply.CS16Model and ply:Alive()
			and CS16.GetRoundState() ~= ROUND_LIVE then
			ply:SetModel( ply.CS16Model )
			ply:SetupHands()
		end

		return
	end

	-- JoinTeam owns the rules and reports its own refusals.
	CS16.JoinTeam( ply, wanted )
end )

--[[
	A model chosen from the picker, and with it a place in the match.

	Index 0 is the developer team rather than a model - one entry in the same
	grid, so the one person who uses it gets there in a click. The rank is
	checked here rather than trusted: the picker only draws that cell for
	developers, but this is a net message and anyone can send one.
]]
net.Receive( "CS16.PickModel", function( len, ply )
	local index = net.ReadUInt( 5 )

	if index == 0 then
		CS16.JoinTeam( ply, TEAM_DEV )
		return
	end

	local entry = CS16.Config.PickableModels[ index ]
	if not entry then return end

	--[[
		Only where the mode hands out models by choice. Otherwise this is a way
		to wear a Counter-Terrorist's face on the Terrorist side, which is the
		one thing the per-side rosters exist to prevent.
	]]
	local solo = CS16.SoloTeam()
	if not solo then return end

	ply.CS16PickedModel = entry.model

	if ply:Team() ~= solo then
		CS16.JoinTeam( ply, solo )
		return
	end

	--[[
		Already in, so this is a change of clothes rather than a way in. Applied
		at once outside a live round, and left for the next spawn during one -
		swapping model mid-fight would move the hitboxes of someone being shot
		at.
	]]
	if ply:Alive() and CS16.GetRoundState() ~= ROUND_LIVE then
		ply:SetModel( entry.model )
		ply:SetupHands()
	end
end )

--[[ Death ]]

function GM:PlayerDeath( ply, inflictor, attacker )
	--[[
		No CreateRagdoll here on purpose. The death-animation addon makes its
		own corpse - an animated entity that becomes a prop_ragdoll when the
		animation finishes - so calling it ourselves produced a second ragdoll
		that went flying off behind the body.

		Not the weapon pack: this is one of the other CS 1.6 items, which
		matters only because three of them ship under the same Workshop title.
	]]
	--[[
		Kills and deaths are not counted here.

		The engine already awards them on death, so adding our own on top
		doubled every figure on the scoreboard - which is why every number was
		an even one. Suicides are handled by the engine too.
	]]

	--[[
		Except for a team kill, which should cost a kill rather than pay one.

		Nothing upstream knows about sides: killing anybody who is not yourself
		is worth +1, and your own team-mate counts. So the correction is -2, and
		it is two things at once - taking back the kill that was just awarded,
		and then charging one on top. Five kills becomes four.

		The -2 is measured rather than reasoned about: the award has already
		landed by the time this runs, confirmed by watching an attacker go from
		5 to 6 across a deliberate team kill. Doing it here, after the fact,
		rather than by replacing whatever grants it, keeps ragdolls, deaths and
		weapon dropping in the hands of the base gamemode.

		Only for the playing sides. A developer cannot hurt anyone, and nothing
		in gun game can - friendly fire is off - so in practice this is a
		competitive rule, but it is written as a general one because that is
		what it is.
	]]
	--[[
		Except in a free-for-all, where there is no such thing as a team kill -
		everybody is an enemy, so every kill is worth what any other kill is.
	]]
	if IsValid( attacker ) and attacker:IsPlayer() and attacker ~= ply
		and attacker:Team() == ply:Team()
		and CS16.IsPlayingTeam( attacker:Team() )
		and not CS16.ModeSetting( "FreeForAll", false )
	then
		attacker:AddFrags( -2 )
	end

	-- Dying loses you everything you were carrying.
	ply.CS16Carry = nil

	-- When, not whether. PlayerDeathThink asks the mode how long death lasts.
	ply.CS16DiedAt = CurTime()
end

-- Suppress the HL2 death gasp; the CS 1.6 pain-sound addon plays its own
-- death screams.
function GM:PlayerDeathSound()
	return true
end

--[[
	Corpses don't block people.

	Ragdolls are solid to players by default, and with several bodies piling up
	on a bomb site a bot can end up wedged against one with no way out - it
	isn't geometry, so jumping and sidestepping don't help either. Debris still
	collides with the world, so bodies land properly; they just stop being
	walls.
]]
hook.Add( "OnEntityCreated", "CS16.CorpsesDontBlock", function( ent )
	if not IsValid( ent ) or ent:GetClass() ~= "prop_ragdoll" then return end

	timer.Simple( 0, function()
		if IsValid( ent ) then ent:SetCollisionGroup( COLLISION_GROUP_DEBRIS ) end
	end )
end )

--[[
	Coming back, or not.

	Whether death is temporary is the mode's business, not the framework's -
	competitive says only during warmup, gungame says always. The mode returns a
	delay in seconds, or nothing to mean "you're out until something else
	respawns you".

	Driven from a timer rather than from PlayerDeathThink, which the engine does
	not call for bots. Competitive never noticed, because the only thing that
	brings anyone back there is the start of the next round, and that respawns
	everybody explicitly. A mode with real respawns would have left every bot
	lying where it fell.
]]
timer.Create( "CS16.Respawn", 0.25, 0, function()
	local respawn = CS16.ModeSetting( "RespawnDelay" )
	if not respawn then return end

	for _, ply in ipairs( player.GetAll() ) do
		if not ply:Alive() and ply.CS16DiedAt then
			local delay = respawn( ply )

			if delay and CurTime() >= ply.CS16DiedAt + delay then
				ply.CS16DiedAt = nil
				ply:Spawn()
			end
		end
	end
end )

--[[
	The camera for anyone the mode isn't bringing back. People only - a bot has
	nothing to look through - which is why this half can stay where it is.
]]
function GM:PlayerDeathThink( ply )
	if not ply.CS16DiedAt then return false end

	local respawn = CS16.ModeSetting( "RespawnDelay" )
	if respawn and respawn( ply ) then return false end

	if CurTime() >= ply.CS16DiedAt + CS16.Config.Round.WarmupRespawn
		and ply:GetObserverMode() == OBS_MODE_NONE then
		CS16.BeginSpectating( ply )
	end

	return false
end

--[[ Sandbox behaviours we explicitly do not want ]]

--[[
	Noclip needs the rank *and* the developer team.

	The rank alone isn't enough: a developer playing a real round on T or CT
	would be one keypress from flying through a wall mid-match, and that is
	exactly the sort of thing you do by accident rather than on purpose.
	Requiring the team makes it deliberate - you have to have stepped out of
	the match before you can leave the floor.
]]
function GM:PlayerNoClip( ply )
	return ply:Team() == TEAM_DEV and CS16.IsDeveloper( ply )
end

function CS16.CanPickupWeapon( ply, wep )
	if not IsValid( wep ) then return false end
	if CS16.Config.BlockedWeapons[ wep:GetClass() ] then return false end

	--[[
		Something the gamemode is handing over deliberately - a purchase, a
		gungame promotion - rather than something being picked up off the floor.

		This has to come before every other rule: Player:Give runs through this
		hook too, so a rule meant to stop you hoarding guns off the ground would
		otherwise refuse the gun the gamemode is trying to give you. See
		CS16.GrantWeapon, which covers exactly that call and nothing longer.
	]]
	if ply.CS16Granting then return true end

	--[[
		Developers carry exactly what their loadout gives them and nothing else,
		so they can't pick a rifle off the floor of a round they aren't in.
	]]
	if ply:Team() == TEAM_DEV then
		if not ply:Alive() then return false end

		--[[
			Otherwise their own kit and nothing else. A developer wandering
			through a live round shouldn't vacuum up the guns dropped in it -
			they have the whole pack available for free and no reason to.
		]]
		return table.HasValue( CS16.Config.Developer.Loadout, wep:GetClass() )
	end

	if not CS16.IsPlayingTeam( ply:Team() ) or not ply:Alive() then return false end

	-- Only Terrorists have any use for the bomb.
	if wep:GetClass() == "weapon_cs16_c4" and ply:Team() ~= TEAM_T then return false end

	--[[
		One primary and one secondary, as CS always enforced. Without this you
		could walk over a firefight and come away carrying four rifles.

		Only weapons in the buy catalogue have a slot, so the knife, grenades
		and the C4 fall through and are picked up freely.
	]]
	local item = CS16.BuyItemsByClass[ wep:GetClass() ]
	if not item then return true end

	if item.kind == "primary" or item.kind == "secondary" then
		if IsValid( CS16.GetOwnedOfKind( ply, item.kind ) ) then return false end
	end

	--[[
		Team-restricted *equipment* stays with its side - a Terrorist has no
		use for a defusal kit and shouldn't be able to take one off a body.

		Weapons are deliberately exempt. Taking a dead CT's M4 is a part of how
		Counter-Strike plays, so the restriction only covers gear.
	]]
	if item.kind == "gear" and not CS16.ItemAllowedForTeam( item, ply:Team() ) then
		return false
	end

	return true
end

--[[
	The same rules, registered twice on purpose.

	The engine calls GM:PlayerCanPickupWeapon when you walk over a weapon, but
	the addon's dropped-item box asks through hook.Run instead - which consults
	the hook table. Registering only the gamemode method left that second route
	free to disagree, which is how a Terrorist could still take a defusal kit
	off a body.
]]
function GM:PlayerCanPickupWeapon( ply, wep )
	return CS16.CanPickupWeapon( ply, wep )
end

-- Refuses with false, abstains with nil, so anything else listening still gets
-- its say.
hook.Add( "PlayerCanPickupWeapon", "CS16.PickupRules", function( ply, wep )
	if not CS16.CanPickupWeapon( ply, wep ) then return false end
end )

--[[
	Anything a player shouldn't be holding, taken off them as they spawn.

	The rules above stop it arriving, but they can't undo a kit picked up
	before those rules existed - and survivor carryover would hand it straight
	back every round. This closes it off however it was acquired.
]]
function CS16.StripForeignGear( ply )
	for _, wep in ipairs( ply:GetWeapons() ) do
		local item = CS16.BuyItemsByClass[ wep:GetClass() ]

		if item and item.kind == "gear"
			and not CS16.ItemAllowedForTeam( item, ply:Team() ) then
			ply:StripWeapon( wep:GetClass() )
		end
	end
end

-- The shield's item entities are broken upstream and it isn't wanted in play,
-- so bin anything that tries to spawn one.
local BLOCKED_ENTITIES = {
	[ "cs16_item_shield" ]   = true,
	[ "cs16_item_shield_a" ] = true,
	[ "cs16_item_shield_s" ] = true,
}

hook.Add( "OnEntityCreated", "CS16.BlockShield", function( ent )
	if not IsValid( ent ) then return end
	if not BLOCKED_ENTITIES[ ent:GetClass() ] then return end

	-- Removing inside OnEntityCreated is unsafe; wait for the entity to settle.
	timer.Simple( 0, function()
		if IsValid( ent ) then ent:Remove() end
	end )
end )

function GM:PlayerShouldTakeDamage( ply, attacker )
	-- Spectators and developers are not in the round, so nothing touches them.
	if not CS16.IsPlayingTeam( ply:Team() ) then return false end

	-- Friendly fire is a mode's call: competitive keeps it, a gungame where you
	-- respawn in three seconds would just be an invitation to farm team-mates.
	if IsValid( attacker ) and attacker:IsPlayer() and attacker ~= ply
		and attacker:Team() == ply:Team()
		and not CS16.ModeSetting( "FriendlyFire", true )
	then
		return false
	end

	return true
end
