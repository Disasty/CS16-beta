--[[
	The Half-Life 1 flashlight.

	Source's flashlight is a cone thrown from your eye, and it moves with your
	view whether or not it lands on anything. Half-Life 1's did not work that
	way: it lit the surface you were looking at - a pool of light that appeared
	where you pointed rather than a beam that travelled to get there. On a map
	made of long dark corridors that is a different tool, and it is the one this
	gamemode wants.

	Rebuilt rather than adapted from the addon it replaces. That one worked, and
	got there by letting the engine flashlight turn on, noticing it was on, and
	turning it off again as an edge trigger - while running as many as four eye
	traces per player per tick whether or not anybody had a light on, and
	carrying seven convars named Half_life_1_Flashlight_*.
]]

local lights = {}

local function Extinguish( ply )
	local light = lights[ ply ]
	if IsValid( light ) then light:Remove() end

	lights[ ply ] = nil
end

local function Ignite( ply )
	Extinguish( ply )

	local cfg   = CS16.Config.Flashlight
	local light = ents.Create( "light_dynamic" )

	if not IsValid( light ) then return end

	light:SetKeyValue( "distance",   cfg.Range )
	light:SetKeyValue( "brightness", cfg.Brightness )
	light:SetKeyValue( "_light", ("%d %d %d"):format( cfg.Color.r, cfg.Color.g, cfg.Color.b ) )
	light:SetPos( ply:GetEyeTrace().HitPos )
	light:Spawn()

	lights[ ply ] = light
end

function CS16.FlashlightIsOn( ply )
	return IsValid( lights[ ply ] )
end

function CS16.ToggleFlashlight( ply )
	if CS16.FlashlightIsOn( ply ) then
		Extinguish( ply )
	else
		Ignite( ply )
	end

	-- The click is half of what makes it feel like a torch rather than a
	-- lighting effect. It is Half-Life's own, and is already mounted.
	ply:EmitSound( "items/flashlight1.wav" )
end

--[[
	F, and the engine's own flashlight refused every time.

	Returning false is what keeps Source's cone off - the whole point is to
	replace it, not to have both. The permission rules live here too, because a
	hook that returns a value stops GM:PlayerSwitchFlashlight from ever being
	consulted; splitting the two would leave that one looking authoritative and
	never running.

	Measured rather than assumed: this fires every tick the key is *held*, not
	once per press - 39 calls for four presses. So the gap since the last call
	is what separates one press from the next, and without it a light would
	flicker on and off for as long as a finger rested on the key.
]]
hook.Add( "PlayerSwitchFlashlight", "CS16.Flashlight", function( ply, on )
	if not IsValid( ply ) then return false end

	-- The dead may not. A spectator's light would land wherever the person
	-- they were watching happened to be looking.
	if not ply:Alive() or ply:Team() == TEAM_SPECTATOR then return false end

	local now = CurTime()

	if now - ( ply.CS16FlashlightAt or 0 ) > CS16.Config.Flashlight.PressGap then
		CS16.ToggleFlashlight( ply )
	end

	ply.CS16FlashlightAt = now

	return false
end )

--[[
	The pool follows where you look.

	Only for players who actually have one lit, which is the difference between
	one trace each and one for everybody on the server. GetEyeTrace is cached
	per tick per player, so this is a single trace per lit flashlight.
]]
hook.Add( "Think", "CS16.FlashlightFollow", function()
	for ply, light in pairs( lights ) do
		if not IsValid( ply ) or not ply:Alive() or not IsValid( light ) then
			Extinguish( ply )
			continue
		end

		light:SetPos( ply:GetEyeTrace().HitPos )
	end
end )

--[[
	Out on death, on respawn, and on the way off the server.

	Death alone is not enough: the light entity outlives the body and would sit
	burning where somebody was last looking for the rest of the round.
]]
hook.Add( "PostPlayerDeath", "CS16.FlashlightOut", Extinguish )
hook.Add( "PlayerSpawn",     "CS16.FlashlightOut", Extinguish )

hook.Add( "PlayerDisconnected", "CS16.FlashlightOut", function( ply )
	Extinguish( ply )
	lights[ ply ] = nil
end )
