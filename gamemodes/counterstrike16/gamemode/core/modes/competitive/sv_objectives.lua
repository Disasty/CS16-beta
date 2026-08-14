--[[
	The bomb: where it may be planted, what happens when it goes off, and who
	wins as a result.

	The addon already owns the good parts - the model, the beeping, the
	explosion, and defusing on +use with a kit discount. What it has no concept
	of is a round, so it will happily let you plant in the middle of a corridor
	and it never tells anyone who won. That's what this adds.

	Rather than fork the addon we sit on either side of it: gate the plant going
	in, and read the planted entity's own state coming out.
]]

CS16.Bomb = nil

--[[
	The addon's planted C4 calls a global CheckWinConditions() on one of its
	defuse paths but never defines it anywhere - a latent Lua error. Give it a
	harmless one; the real decision is made from EntityRemoved below.
]]
if not CheckWinConditions then
	function CheckWinConditions() end
end

-- CS16.IsBombPlanted lives in sh_roundstate and reads the networked flag, so both
-- realms agree; this is only ever set from here.
local function SetBombNetworked( planted, explodeAt )
	SetGlobalBool( "CS16.BombPlanted", planted )
	SetGlobalFloat( "CS16.BombExplodeAt", explodeAt or 0 )
end

local function AnnounceAll( text )
	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( "[CS 1.6] " .. text )
	end
end

--[[ Planting ]]

-- Give the C4 back to someone whose plant we rejected.
local function RefundBomb( ply )
	if not IsValid( ply ) then return end

	if not ply:HasWeapon( "weapon_cs16_c4" ) then
		ply:Give( "weapon_cs16_c4" )
	end

	if ply:GetAmmoCount( "CS16_C4" ) < 1 then
		ply:GiveAmmo( 1, "CS16_C4", true )
	end
end

local function OnBombPlanted( ent )
	local planter = ent:GetOwner()

	-- Anything planted outside a live round is scenery.
	if CS16.GetRoundState() ~= ROUND_LIVE then
		ent:Remove()
		return
	end

	local site = CS16.GetBombSiteAt( ent:GetPos() )
	if not site then
		if IsValid( planter ) then
			CS16.Msg( planter, "bomb.plant.notsite" )
			RefundBomb( planter )
		end

		ent:Remove()
		return
	end

	CS16.Bomb = ent

	-- Retime it from the addon's hardcoded 35s to whatever we're configured
	-- for. m_flNextFreqInterval drives how quickly the beeping tightens up, so
	-- it has to be rescaled alongside or the beeps finish before the bomb does.
	local seconds = CS16.Config.Bomb.Timer
	ent.m_flC4Blow            = CurTime() + seconds
	ent.m_flNextFreqInterval  = seconds / 4

	SetBombNetworked( true, ent.m_flC4Blow )

	if IsValid( planter ) then
		CS16.AddMoney( planter, CS16.Config.Bomb.PlantBonus )
	end

	AnnounceAll( ("The bomb has been planted at site %s."):format( site.letter ) )

	--[[
		And heard by everyone, on both sides, wherever they are standing.

		The addon plays this from the planter, which means only the few people
		close enough to watch it happen ever hear it - and those are exactly the
		people who least need telling. Everybody holding the other site learned
		from a line of chat, or missed it entirely and kept playing the round as
		though nothing had changed.

		This plays *alongside* the addon's positional one rather than replacing
		it, and that is a deliberate concession rather than an oversight.
		Suppressing it turns out not to be possible from here: EntityEmitSound
		does not fire for a sound the server emits and networks - measured on
		both realms, and the client logs hundreds of other sounds in the same
		window without ever seeing this one. The only remaining lever is the
		addon's plant routine itself, which emits this in the middle of spawning
		the bomb, so wrapping it would mean owning the whole plant.

		The cost is that whoever is stood beside the planter hears the same file
		twice at the same instant, which reads as one slightly louder sound
		rather than an echo. That is a better trade than half the server not
		knowing the round has changed.
	]]
	CS16.BroadcastSound( CS16.Config.Sounds.BombPlanted )

	hook.Run( "CS16BombPlanted", ent, planter, site )
end

hook.Add( "OnEntityCreated", "CS16.BombPlanted", function( ent )
	if not IsValid( ent ) then return end
	if ent:GetClass() ~= "ent_cs16_planted_c4" then return end

	-- Its position and owner aren't settled inside OnEntityCreated.
	timer.Simple( 0, function()
		if IsValid( ent ) then OnBombPlanted( ent ) end
	end )
end )

--[[
	Blocking the plant before it starts.

	The C4's PrimaryAttack begins a three-stage plant in its Think and never
	asks where it is. Wrapping the stored SWEP table means new instances pick
	this up without touching the addon's files. The OnEntityCreated check above
	still stands as the guarantee - this is just so players get told before
	they've stood still for three seconds.
]]
hook.Add( "InitPostEntity", "CS16.GatePlanting", function()
	local c4 = weapons.GetStored( "weapon_cs16_c4" )
	if not c4 or c4.CS16Gated then return end

	c4.CS16Gated = true

	local original = c4.PrimaryAttack

	c4.PrimaryAttack = function( self )
		--[[
			The addon opens with `if not (self.Plant == 0) then return end`, but
			self.Plant is only initialised inside Think - so on a fresh weapon
			it's nil, nil == 0 is false, and the very first press is thrown
			away. A human never notices because they press again. A bot holding
			the button never gets a second press, so it stands there with the
			bomb out doing nothing.
		]]
		self.Plant = self.Plant or 0

		local owner = self:GetOwner()

		-- Reads the networked flag rather than the zone list directly, so the
		-- client reaches the same verdict and doesn't start a plant animation
		-- the server is going to refuse.
		if IsValid( owner ) and not owner:GetNWBool( "CS16.AtBombSite", false ) then
			if SERVER and ( self.CS16NextWarn or 0 ) < CurTime() then
				-- Throttled, or holding attack spams the chat.
				self.CS16NextWarn = CurTime() + 2
				CS16.Msg( owner, "bomb.plant.away" )
			end
			return
		end

		return original( self )
	end
end )

--[[
	Whether a Terrorist is stood in a bomb site, mirrored to the client for the
	plant check and the HUD hint. Same pattern as the buy zones: the server
	owns the answer, SetNWBool only sends on change.
]]
timer.Create( "CS16.BombSiteCheck", 0.25, 0, function()
	for _, ply in ipairs( player.GetAll() ) do
		local atSite = ply:Team() == TEAM_T
			and ply:Alive()
			and CS16.GetBombSiteAt( ply:GetPos() ) ~= nil

		ply:SetNWBool( "CS16.AtBombSite", atSite )
	end
end )

--[[
	Defusing.

	The addon's planted C4 defuses for whoever presses +use on it, with no
	notion of sides - so a Terrorist could quietly defuse their own bomb.
	PlayerUse runs before the entity's own Use, so blocking it here keeps the
	fix in the gamemode instead of in the addon.
]]
hook.Add( "PlayerUse", "CS16.DefuseTeamCheck", function( ply, ent )
	if not IsValid( ent ) or ent:GetClass() ~= "ent_cs16_planted_c4" then return end

	if ply:Team() ~= TEAM_CT then
		-- Throttled: holding E would otherwise flood the chat.
		if ( ply.CS16NextDefuseWarn or 0 ) < CurTime() then
			ply.CS16NextDefuseWarn = CurTime() + 3
			CS16.Msg( ply, "bomb.defuse.ctonly" )
		end

		return false
	end

	--[[
		One defuser at a time.

		The addon tracks the defuser and the countdown on the bomb entity
		itself, but never blocks a second player from starting - its own guard
		reads a flag it sets to false a line later, so it never fires. A
		team mate pressing use therefore overwrites m_pBombDefuser and restarts
		the shared countdown out from under whoever was already working, which
		is one of the ways a completed defuse quietly does nothing.
	]]
	local current = ent.m_pBombDefuser

	if IsValid( current ) and current ~= ply and current.m_bIsDefusing then
		if ( ply.CS16NextDefuseWarn or 0 ) < CurTime() then
			ply.CS16NextDefuseWarn = CurTime() + 3
			CS16.Msg( ply, "bomb.defuse.busy", { player = current:Nick() } )
		end

		return false
	end
end )

--[[
	Publish who is defusing. The accessor lives in sh_roundstate so the HUD and the
	bots can read it too; this is the only thing that writes it.
]]
timer.Create( "CS16.DefuseWatch", 0.25, 0, function()
	local bomb = CS16.Bomb

	local defuser = IsValid( bomb ) and bomb.m_pBombDefuser or nil
	local active  = IsValid( defuser ) and defuser.m_bIsDefusing and true or false

	local known = CS16.GetDefuser()

	if active and known ~= defuser then
		SetGlobalEntity( "CS16.Defuser", defuser )

		-- Tell the rest of the team so nobody shoves them off it.
		for _, ply in ipairs( player.GetAll() ) do
			if ply:Team() == TEAM_CT and ply ~= defuser then
				CS16.Msg( ply, "bomb.defuse.cover", { player = defuser:Nick() } )
			end
		end
	elseif not active and IsValid( known ) then
		SetGlobalEntity( "CS16.Defuser", NULL )
	end
end )

--[[ Resolution ]]

--[[
	Detonate sets m_bHasExploded before removing itself, while a successful
	defuse just removes the entity. That difference is how we tell which
	happened without touching the addon's code.
]]
hook.Add( "EntityRemoved", "CS16.BombResolved", function( ent )
	if ent ~= CS16.Bomb then return end

	local defuser  = ent.m_pBombDefuser
	local exploded = ent.m_bHasExploded == true

	CS16.Bomb = nil
	SetBombNetworked( false )

	if CS16.GetRoundState() ~= ROUND_LIVE then return end

	if exploded then
		CS16.EndRound( TEAM_T, "round.end.bomb.detonated" )
		return
	end

	if IsValid( defuser ) then
		CS16.AddMoney( defuser, CS16.Config.Bomb.DefuseBonus )
	end

	CS16.EndRound( TEAM_CT, "round.end.bomb.defused" )
end )

-- Nothing survives into the next round.
function CS16.ClearBomb()
	if IsValid( CS16.Bomb ) then
		local bomb = CS16.Bomb
		CS16.Bomb = nil
		bomb:Remove()
	end

	CS16.Bomb = nil
	SetBombNetworked( false )

	for _, ent in ipairs( ents.FindByClass( "ent_cs16_planted_c4" ) ) do
		ent:Remove()
	end
end

--[[ Carrying ]]

-- The bomb drops where you die along with everything else, handled in
-- core/modules/weapons/sv_drop.lua. It is deliberately left as a plain weapon entity there
-- rather than an item box, because DroppedBomb below searches by class.

-- Who may pick the bomb up is decided with every other pickup rule, in
-- CS16.CanPickupWeapon. Keeping a second copy here meant two places to keep in
-- step and only one of them being consulted on some routes.
