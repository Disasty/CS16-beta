--[[
	The camera.

	First person by default - this is a shooter, not a sandbox - with a third
	person mode developers can switch on from the C menu to look at animations,
	player models and map geometry from outside their own head.

	Purely a client-side view decision. Nothing about the player changes, so
	there is no server state to keep in step and nothing to network: what you
	can shoot, where your bullets come from and where other people see you are
	all exactly as they were.
]]

CS16.ThirdPerson = false

local DISTANCE = 90
local HEIGHT   = 12

-- Kept off the wall behind you rather than clipping through it.
local HULL = Vector( 8, 8, 8 )

function CS16.SetThirdPerson( on )
	CS16.ThirdPerson = on and true or false
end

function CS16.CanThirdPerson()
	local ply = LocalPlayer()

	return IsValid( ply )
		and CS16.IsDeveloper( ply )
		and ply:Alive()
		and ply:GetObserverMode() == OBS_MODE_NONE
end

local function Active()
	return CS16.ThirdPerson and CS16.CanThirdPerson()
end

function GM:ShouldDrawLocalPlayer( ply )
	return Active()
end

function GM:CalcView( ply, pos, angles, fov )
	--[[
		Returning nil hands the view back to the engine untouched, which is what
		keeps first person, spectating and the observer chase camera all working
		exactly as they did.
	]]
	if not Active() then return end

	local eye    = pos + Vector( 0, 0, HEIGHT )
	local wanted = eye - angles:Forward() * DISTANCE

	local tr = util.TraceHull( {
		start  = eye,
		endpos = wanted,
		mins   = -HULL,
		maxs   = HULL,
		filter = ply,
		mask   = MASK_SOLID_BRUSHONLY,
	} )

	return {
		origin     = tr.HitPos,
		angles     = angles,
		fov        = fov,
		drawviewer = true,
	}
end

--[[
	Losing the rank, dying or starting to spectate all drop you back to first
	person rather than leaving the camera stuck behind a body you no longer
	control. CanThirdPerson already covers the view itself; this clears the
	setting so the menu doesn't keep claiming it's on.
]]
hook.Add( "Think", "CS16.ThirdPersonGuard", function()
	if CS16.ThirdPerson and not CS16.CanThirdPerson() then
		CS16.SetThirdPerson( false )
	end
end )
