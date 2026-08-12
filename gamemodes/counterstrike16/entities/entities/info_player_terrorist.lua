--[[
	CS maps carry these spawn markers, but the class doesn't exist in GMod so
	the engine would normally discard them. Registering it as a scripted entity
	makes the map's own spawn layout - positions and facing angles - available
	to PlayerSelectSpawn.
]]

AddCSLuaFile()

ENT.Type              = "point"
ENT.Base              = "base_point"
ENT.DisableDuplicator = true
ENT.Spawnable         = false

function ENT:Initialize()
	self:SetNoDraw( true )
end

-- Map angles arrive as a "p y r" string; parse them so players spawn facing
-- the direction the level designer intended.
function ENT:KeyValue( key, value )
	if key:lower() ~= "angles" then return end

	local parts = string.Explode( " ", value )
	self:SetAngles( Angle(
		tonumber( parts[ 1 ] ) or 0,
		tonumber( parts[ 2 ] ) or 0,
		tonumber( parts[ 3 ] ) or 0 ) )
end
