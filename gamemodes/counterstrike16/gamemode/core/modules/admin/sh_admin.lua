--[[
	Ranks and permissions.

	Two staff ranks, as agreed: Developer holds everything, Administrator holds
	moderation only. Rank is mirrored onto the player as a networked string so
	client UI can gate itself without asking the server.

	Nothing here grants anything by itself - the only way to mint the first
	Developer is cs16_setrank from the server console (see sv_admin.lua).
]]

CS16.Ranks = {
	user = {
		name        = "User",
		level       = 0,
		permissions = {},
	},
	admin = {
		name        = "Administrator",
		level       = 1,

		--[[
			Bot management included so an admin can fill an empty server
			without needing a developer around, and mode switching so they can
			put the server on deathmatch for the evening. Note "debug" is
			deliberately absent - diagnostics stay a developer tool.
		]]
		permissions = { kick = true, ban = true, mute = true, bots = true, mode = true },
	},
	developer = {
		name        = "Developer",
		level       = 2,
		-- Developers bypass the permission table entirely.
		permissions = {},
		root        = true,
	},
}

CS16.DefaultRank = "user"

function CS16.GetRank( ply )
	if not IsValid( ply ) then return CS16.DefaultRank end

	local rank = ply:GetNWString( "CS16Rank", CS16.DefaultRank )
	if not CS16.Ranks[ rank ] then return CS16.DefaultRank end

	return rank
end

function CS16.GetRankInfo( ply )
	return CS16.Ranks[ CS16.GetRank( ply ) ]
end

function CS16.HasPermission( ply, permission )
	local rank = CS16.Ranks[ CS16.GetRank( ply ) ]
	if not rank then return false end
	if rank.root then return true end

	return rank.permissions[ permission ] == true
end

function CS16.IsStaff( ply )
	return CS16.Ranks[ CS16.GetRank( ply ) ].level > 0
end

function CS16.IsDeveloper( ply )
	return CS16.GetRank( ply ) == "developer"
end

-- A staff member may only act on someone of a strictly lower rank, so
-- administrators cannot kick each other or a developer.
function CS16.CanTarget( ply, target )
	if not IsValid( target ) then return false end
	if ply == target then return false end

	return CS16.Ranks[ CS16.GetRank( ply ) ].level > CS16.Ranks[ CS16.GetRank( target ) ].level
end
