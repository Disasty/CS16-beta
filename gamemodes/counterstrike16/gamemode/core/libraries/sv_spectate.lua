--[[
	Spectating, as 1.6 did it: die and you follow whoever is left.

	Mouse1 and mouse2 walk through your side, space swaps between the chase
	camera and their own eyes. Dying no longer parks you next to your corpse
	with nothing to look at.

	The one rule that matters is who you're allowed to watch. On a side you see
	your own team only - being able to follow the enemy while dead would hand
	your side live intelligence the moment anyone died, and voice chat is team
	based precisely so that can't happen. An actual spectator watches everyone,
	which is the point of being one.

	Nothing is networked: the client reads GetObserverTarget for the HUD, so the
	whole feature is this file plus the drawing.
]]

function CS16.CanSpectate( viewer, target )
	if not IsValid( target ) or target == viewer then return false end
	if not target:IsPlayer() or not target:Alive() then return false end
	if not CS16.IsPlayingTeam( target:Team() ) then return false end

	-- On a side: your own team, and nobody else.
	if CS16.IsPlayingTeam( viewer:Team() ) then
		return target:Team() == viewer:Team()
	end

	return true
end

--[[
	Everyone this player may watch, in a stable order.

	Sorted by entity index rather than left in whatever order player.GetAll
	happened to return, so that cycling forward twice and back twice puts you
	where you started.
]]
function CS16.SpectateTargets( viewer )
	local targets = {}

	for _, ply in ipairs( player.GetAll() ) do
		if CS16.CanSpectate( viewer, ply ) then targets[ #targets + 1 ] = ply end
	end

	table.sort( targets, function( a, b ) return a:EntIndex() < b:EntIndex() end )

	return targets
end

function CS16.SpectateTarget( viewer, target )
	viewer.CS16SpecTarget = target
	viewer.CS16SpecMode   = viewer.CS16SpecMode or OBS_MODE_CHASE

	viewer:Spectate( viewer.CS16SpecMode )
	viewer:SpectateEntity( target )
end

-- Nobody left to follow: a free camera is better than a black screen.
function CS16.SpectateFree( viewer )
	viewer.CS16SpecTarget = nil

	viewer:Spectate( OBS_MODE_ROAMING )
	viewer:SpectateEntity( NULL )
end

function CS16.CycleSpectate( viewer, dir )
	local targets = CS16.SpectateTargets( viewer )

	if #targets == 0 then
		CS16.SpectateFree( viewer )
		return
	end

	local index = 0

	for i, target in ipairs( targets ) do
		if target == viewer.CS16SpecTarget then
			index = i
			break
		end
	end

	-- index 0 means we weren't watching anyone, and lands on the first.
	index = ( ( index - 1 + dir ) % #targets ) + 1

	CS16.SpectateTarget( viewer, targets[ index ] )
end

function CS16.BeginSpectating( viewer )
	local targets = CS16.SpectateTargets( viewer )

	if #targets == 0 then
		CS16.SpectateFree( viewer )
		return
	end

	--[[
		Keep watching whoever we were following if they're still alive - dying,
		being respawned into the next round and dying again shouldn't shuffle
		you to a different team-mate each time.
	]]
	if CS16.CanSpectate( viewer, viewer.CS16SpecTarget ) then
		CS16.SpectateTarget( viewer, viewer.CS16SpecTarget )
		return
	end

	CS16.SpectateTarget( viewer, targets[ 1 ] )
end

function CS16.StopSpectating( viewer )
	viewer.CS16SpecTarget = nil
	viewer:SpectateEntity( NULL )
end

--[[ Input ]]

local function IsObserving( ply )
	return ply:GetObserverMode() ~= OBS_MODE_NONE
end

hook.Add( "KeyPress", "CS16.SpectateKeys", function( ply, key )
	if not IsObserving( ply ) then return end

	if key == IN_ATTACK then
		CS16.CycleSpectate( ply, 1 )
	elseif key == IN_ATTACK2 then
		CS16.CycleSpectate( ply, -1 )
	elseif key == IN_JUMP then
		-- Over the shoulder, or through their eyes.
		ply.CS16SpecMode = ( ply.CS16SpecMode == OBS_MODE_IN_EYE )
			and OBS_MODE_CHASE or OBS_MODE_IN_EYE

		if IsValid( ply.CS16SpecTarget ) then
			CS16.SpectateTarget( ply, ply.CS16SpecTarget )
		end
	end
end )

--[[
	Move watchers on when the person they're following dies.

	Driven off PlayerDeath rather than polled, so the camera moves at the moment
	it needs to. Anyone left with nobody alive to watch drops to a free camera.
]]
hook.Add( "PlayerDeath", "CS16.SpectateAdvance", function( victim )
	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16SpecTarget == victim and IsObserving( ply ) then
			CS16.CycleSpectate( ply, 1 )
		end
	end
end )

hook.Add( "PlayerDisconnected", "CS16.SpectateAdvance", function( leaver )
	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16SpecTarget == leaver and IsObserving( ply ) then
			CS16.CycleSpectate( ply, 1 )
		end
	end
end )
