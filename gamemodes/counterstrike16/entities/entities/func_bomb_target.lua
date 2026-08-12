--[[
	Bomb site volume. Same story as the spawn markers - the class is CS-only,
	so without this the engine logs "Attempted to create unknown entity type"
	and discards the map's sites.

	Brush entities take their shape from the map, so there is nothing to set up
	here beyond staying invisible and non-solid.
]]

AddCSLuaFile()

ENT.Type              = "brush"
ENT.Base              = "base_brush"
ENT.DisableDuplicator = true

function ENT:Initialize()
	self:SetNotSolid( true )
	self:DrawShadow( false )
end
