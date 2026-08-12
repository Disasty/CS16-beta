--[[
	Flashbangs, for bots.

	The pack's flashbang is purely a client-side overlay: the entity works out
	who has line of sight to the blast and sends them a net message to draw
	white over their screen. That's the entire effect - there is no server-side
	blinded state anywhere. A bot has no client to send that message to, so
	flashbangs did nothing to them at all. They'd play the flinch animation and
	keep shooting straight through it.

	So the blindness is computed here instead, server-side, and the bots read it
	when deciding what they can see.

	The entity's Explode method is wrapped rather than the addon being edited,
	so a Workshop update can't undo it - and because we only wrap, the pack's
	own effect, sound and damage all still happen exactly as before.
]]

local RANGE = 1500

--[[
	How thoroughly this player is caught, from 0 to 1.

	Distance and line of sight come from the pack's own rules so bots and people
	are flashed by the same blast. Facing is ours: the addon blinds you fully
	regardless of which way you were looking, and a bot that gets blinded while
	staring at a wall behind it just reads as broken.
]]
local function FlashStrength( ply, pos )
	local dist = ply:EyePos():Distance( pos )
	if dist > RANGE then return 0 end

	local tr = util.TraceLine( {
		start  = pos,
		endpos = ply:EyePos(),
		mask   = MASK_VISIBLE_AND_NPCS,
		filter = ply,
	} )

	if tr.Fraction < 1 then return 0 end

	-- 1 looking straight at it, 0 side on or behind.
	local facing = ply:EyeAngles():Forward():Dot( ( pos - ply:EyePos() ):GetNormalized() )
	if facing <= 0 then return 0 end

	return ( 1 - dist / RANGE ) * facing
end

--[[
	Blind time in seconds. Roughly 1.6's range: a glance costs you a moment, a
	flash straight in the face costs you the fight.
]]
local MAX_BLIND = 4

function CS16.FlashBots( pos )
	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16Bot and ply:Alive() then
			local strength = FlashStrength( ply, pos )

			if strength > 0.1 then
				local blindFor = MAX_BLIND * strength
				local until_   = CurTime() + blindFor

				-- Never shorten an existing flash: a second grenade landing
				-- badly shouldn't rescue them.
				if until_ > ( ply.CS16BlindUntil or 0 ) then
					ply.CS16BlindUntil = until_
				end
			end
		end
	end
end

function CS16.IsBlinded( ply )
	return ( ply.CS16BlindUntil or 0 ) > CurTime()
end

hook.Add( "Initialize", "CS16.FlashbangBlindsBots", function()
	local stored = scripted_ents.GetStored( "ent_cs16_flashbang" )
	if not stored or not stored.t or not stored.t.Explode then return end

	local ent = stored.t

	-- Guard against wrapping our own wrapper on a map change.
	if ent.CS16Wrapped then return end
	ent.CS16Wrapped = true

	local original = ent.Explode

	function ent:Explode( ... )
		-- Read before the original runs: it removes the entity at the end.
		local pos = self:GetPos()

		CS16.FlashBots( pos )

		return original( self, ... )
	end
end )
