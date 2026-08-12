--[[
	Buy zone volume. Registered so the map's own buy areas survive; the buy
	menu will test against these rather than needing hand-placed zones.
]]

AddCSLuaFile()

ENT.Type              = "brush"
ENT.Base              = "base_brush"
ENT.DisableDuplicator = true

function ENT:Initialize()
	self:SetNotSolid( true )
	self:DrawShadow( false )
end
