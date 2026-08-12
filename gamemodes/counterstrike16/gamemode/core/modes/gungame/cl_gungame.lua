--[[
	Gungame's HUD: which rung you're on, and how close the next one is.

	Loaded whatever mode is running - client files are, since drawing has no
	state to conflict with - so every hook here checks it's actually gungame
	before it draws anything. See CS16.IsMode.
]]

local function DrawProgress( ply )
	local level  = CS16.GunGameLevel( ply )
	local total  = #CS16.GunGame.Ladder
	local kills  = CS16.GunGameKills( ply )
	local needed = CS16.GunGameKillsNeeded( level )

	local x = ScrW() * 0.5
	local y = ScrH() - 108

	local final = level >= total

	CS16.DrawText(
		("LEVEL %d / %d   %s"):format( level, total,
			string.upper( CS16.GunGameWeaponName( CS16.GunGame.Ladder[ level ] ) ) ),
		"CS16.Heading", x, y,
		final and CS16.Colors.Danger or CS16.Colors.Gold, TEXT_ALIGN_CENTER )

	CS16.DrawText(
		final and "One kill to win" or ("%d / %d kills"):format( kills, needed ),
		"CS16.Text", x, y + 22, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "CS16.GunGameHUD", function()
	if not CS16.IsMode( "gungame" ) then return end

	local ply = LocalPlayer()
	if not IsValid( ply ) or not CS16.IsPlayingTeam( ply:Team() ) then return end
	if CS16.MatchIsOver() then return end

	DrawProgress( ply )
end )
