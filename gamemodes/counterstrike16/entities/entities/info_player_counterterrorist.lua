--[[
	Counter-Terrorist spawn marker. See info_player_terrorist for why these
	need registering at all.
]]

AddCSLuaFile()

ENT.Type              = "point"
ENT.Base              = "base_point"
ENT.DisableDuplicator = true
ENT.Spawnable         = false

function ENT:Initialize()
	self:SetNoDraw( true )
end

function ENT:KeyValue( key, value )
	if key:lower() ~= "angles" then return end

	local parts = string.Explode( " ", value )
	self:SetAngles( Angle(
		tonumber( parts[ 1 ] ) or 0,
		tonumber( parts[ 2 ] ) or 0,
		tonumber( parts[ 3 ] ) or 0 ) )
end
