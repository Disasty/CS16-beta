--[[
	Phase state, shared.

	Only the accessor lives here - sv_phase owns everything that makes it true.
	It's shared because the client needs the same answer in two places: the
	developer menu's toggle, and hiding a phased developer from other people's
	scoreboards.
]]

function CS16.IsPhased( ply )
	return IsValid( ply ) and ply:GetNWBool( "CS16.Phased", false )
end
