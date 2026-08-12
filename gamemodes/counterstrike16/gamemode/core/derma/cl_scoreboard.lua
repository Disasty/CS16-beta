--[[
	Scoreboard, split into Terrorists / Counter-Terrorists / Spectators.

	One of the CS 1.6 addons ships a flat scoreboard ("SandBoxers - N player")
	registered through named hooks, so we retire those rather than editing it.
	Not the weapon pack - it's the addon that also brings the death animations -
	which matters only because three of them share a Workshop title.

	Rows are built once and then read their numbers live in Paint, so scores
	tick over while you hold TAB without the avatars flickering. We only rebuild
	when the roster or someone's team actually changes.
]]

local PANEL_W       = 760
local ROW_H         = 26
local SECTION_H     = 28
local HEADER_H      = 46

--[[
	Order on the board. Developers sit above the sides, and are hidden entirely
	unless somebody is on the team - an empty header on every scoreboard would
	be clutter on a server with no developer in.

	Worked out per draw rather than fixed once, because how many sides there are
	is the mode's business. Battle royale has one team and used to be shown as
	two: a free-for-all reading "Counter-Terrorists" against "Terrorists", with
	a score line each, described a match nobody was playing.
]]
local function Sections()
	local solo = CS16.SoloTeam()

	if solo then
		return {
			{ team = TEAM_DEV,       title = "Developers", hideWhenEmpty = true },
			{ team = solo,           title = string.upper( team.GetName( solo ) ) },
			{ team = TEAM_SPECTATOR, title = "Spectators" },
		}
	end

	return {
		{ team = TEAM_DEV,       title = "Developers", hideWhenEmpty = true },
		{ team = TEAM_T,         title = "Terrorists" },
		{ team = TEAM_CT,        title = "Counter-Terrorists" },
		{ team = TEAM_SPECTATOR, title = "Spectators" },
	}
end

local board

-- Column positions, measured from the right edge of a row.
local COL_LEVEL, COL_SCORE, COL_DEATHS, COL_PING = 290, 210, 130, 50

local function PaintColumnHeaders( w, y )
	CS16.DrawText( "Level",  "CS16.Small", w - COL_LEVEL,  y, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	CS16.DrawText( "Kills",  "CS16.Small", w - COL_SCORE,  y, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	CS16.DrawText( "Deaths", "CS16.Small", w - COL_DEATHS, y, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	CS16.DrawText( "Ping",   "CS16.Small", w - COL_PING,   y, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
end

--[[ Rows ]]

local function AddPlayerRow( parent, ply, zpos )
	local row = parent:Add( "DPanel" )
	row:Dock( TOP )
	row:DockMargin( 0, 1, 0, 0 )
	row:SetTall( ROW_H )
	row:SetZPos( zpos )

	local avatar = row:Add( "AvatarImage" )
	avatar:SetSize( 20, 20 )
	avatar:SetPos( 6, 3 )
	avatar:SetPlayer( ply, 32 )

	row.Paint = function( self, w, h )
		if not IsValid( ply ) then return end

		local isMe = ply == LocalPlayer()

		surface.SetDrawColor( isMe and CS16.Colors.Hover or CS16.Colors.PanelLight )
		surface.DrawRect( 0, 0, w, h )

		local nameCol = isMe and CS16.Colors.Gold or CS16.Colors.White
		local name    = ply:Nick()

		local x = 32

		--[[
			One tag before the name, so you can see who is who at a glance:
			[BOT] for the filler, [DEV] or [ADMIN] for staff.

			Chosen in one place rather than drawn one after another. A bot is
			never staff so the two can't collide today, but deciding it here
			means that stays true by construction rather than by luck, and the
			name only ever has one thing in front of it.
		]]
		local tag, tagCol

		if ply:IsBot() then
			-- Dimmer than a staff tag: it's information, not status.
			tag, tagCol = "[BOT] ", CS16.Colors.Muted
		elseif CS16.IsStaff( ply ) then
			tag    = "[" .. ( CS16.IsDeveloper( ply ) and "DEV" or "ADMIN" ) .. "] "
			tagCol = CS16.Colors.Gold
		end

		if tag then
			CS16.DrawText( tag, "CS16.Small", x, h * 0.5 - 6, tagCol, TEXT_ALIGN_LEFT )

			surface.SetFont( "CS16.Small" )
			x = x + surface.GetTextSize( tag )
		end

		CS16.DrawText( name, "CS16.Text", x, h * 0.5 - 7, nameCol, TEXT_ALIGN_LEFT )

		--[[
			Dead players are marked rather than hidden, so you can still see the
			full roster and read who is left at a glance.

			Only on a playing team: a spectator never spawned, so calling them
			dead would be wrong. This sits in Paint with everything else that
			changes during a round, so it updates without a rebuild.
		]]
		if CS16.IsPlayingTeam( ply:Team() ) and not ply:Alive() then
			surface.SetFont( "CS16.Text" )
			local nameW = surface.GetTextSize( name )

			CS16.DrawText( "(DEAD)", "CS16.Small", x + nameW + 8, h * 0.5 - 6,
				CS16.Colors.Danger, TEXT_ALIGN_LEFT )
		end

		local y = h * 0.5 - 7

		--[[
			Level is career progress, not this match's, so it's drawn in gold to
			read as a different kind of number from the three beside it. A
			developer has none - they aren't playing - so the column is blank
			for them rather than showing a misleading 1.
		]]
		local level = ply:GetNWInt( "CS16.Level", 0 )

		CS16.DrawText( level > 0 and level or "-", "CS16.Text", w - COL_LEVEL, y,
			level > 0 and CS16.Colors.Gold or CS16.Colors.Muted, TEXT_ALIGN_CENTER )

		CS16.DrawText( ply:Frags(),  "CS16.Text", w - COL_SCORE,  y, CS16.Colors.White, TEXT_ALIGN_CENTER )
		CS16.DrawText( ply:Deaths(), "CS16.Text", w - COL_DEATHS, y, CS16.Colors.White, TEXT_ALIGN_CENTER )
		CS16.DrawText( ply:Ping(),   "CS16.Text", w - COL_PING,   y, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	end

	return row
end

--[[
	baseZ fixes where this section and its rows sit in the docked order.

	Ordering was previously left to the order panels were added, which is not
	reliable here: Clear defers its removals to the end of the frame, so a
	rebuild adds the new rows behind panels that haven't gone yet and the
	layout is computed from the mixture. Declaring the position with SetZPos
	removes the guesswork - dock order follows it regardless of when anything
	was added or removed.
]]
local function AddSection( parent, info, players, baseZ )
	local header = parent:Add( "DPanel" )
	header:Dock( TOP )
	header:DockMargin( 0, 8, 0, 2 )
	header:SetTall( SECTION_H )
	header:SetZPos( baseZ )

	local colour = CS16.TeamColors[ info.team ] or CS16.Colors.Gold
	local count  = #players

	header.Paint = function( self, w, h )
		surface.SetDrawColor( CS16.Colors.Panel )
		surface.DrawRect( 0, 0, w, h )

		surface.SetDrawColor( colour )
		surface.DrawRect( 0, 0, 3, h )
		surface.DrawRect( 0, h - 1, w, 1 )

		local label = ("%s - %d player%s"):format( info.title, count, count == 1 and "" or "s" )
		CS16.DrawText( label, "CS16.Heading", 12, h * 0.5 - 9, colour, TEXT_ALIGN_LEFT )

		PaintColumnHeaders( w, h * 0.5 - 6 )
	end

	-- Ranked below their own header, in the order handed to us.
	for i, ply in ipairs( players ) do
		AddPlayerRow( parent, ply, baseZ + i )
	end
end

--[[ Board ]]

--[[
	Each section's players, in the order they should appear: most kills first,
	fewest deaths breaking a tie.

	The name is a third tiebreak, and it isn't decorative. table.sort is not
	stable, so two players on identical figures could come back in either order
	from one call to the next - which would make the signature below flip-flop
	and rebuild the board every frame.
]]
local function SortedSections()
	local sections = {}

	for _, info in ipairs( Sections() ) do
		local players = {}

		for _, ply in ipairs( player.GetAll() ) do
			-- A phased developer is off the board as well as out of the world.
			-- You still see yourself, or there'd be no way to tell it's on.
			if CS16.IsPhased( ply ) and ply ~= LocalPlayer() then continue end

			--[[
				Anyone with no team of their own on the board is shown with the
				spectators, including players who haven't picked a side yet.
				Developers have their own section, so they aren't folded in.
			]]
			local plyTeam = ply:Team()

			if not CS16.IsPlayingTeam( plyTeam ) and plyTeam ~= TEAM_DEV then
				plyTeam = TEAM_SPECTATOR
			end

			if plyTeam == info.team then players[ #players + 1 ] = ply end
		end

		table.sort( players, function( a, b )
			if a:Frags()  ~= b:Frags()  then return a:Frags() > b:Frags() end
			if a:Deaths() ~= b:Deaths() then return a:Deaths() < b:Deaths() end

			return a:Nick() < b:Nick()
		end )

		sections[ #sections + 1 ] = { info = info, players = players }
	end

	return sections
end

--[[
	What the board currently shows, in order.

	This deliberately includes the ordering rather than just who is present.
	The old signature was name-and-team only, so a kill never triggered a
	rebuild and the sort stayed frozen at whatever it was when the rows were
	first laid out - which on a fresh round is everyone on zero. Keying on the
	order means a rebuild happens exactly when someone actually moves position,
	and not on every kill that doesn't reshuffle anything.
]]
local function Signature( sections )
	local parts = {}

	for _, section in ipairs( sections ) do
		for _, ply in ipairs( section.players ) do
			--[[
				Entity index, not SteamID.

				Every bot returns the literal string "BOT" from SteamID, so a
				board of ten of them signed as "BOT,BOT,BOT,BOT,BOT" on each
				side - identical whatever happened. Two things then never
				triggered a rebuild, because neither could change the signature:
				the sides swapping at halftime, and any reshuffle of the order
				among bots. The board sat in whatever arrangement it was first
				built in, which is alphabetical, and stayed there all match while
				the numbers beside the names moved.

				The index is unique per connected player and changes if somebody
				reconnects, which is a rebuild worth having anyway.
			]]
			parts[ #parts + 1 ] = ply:EntIndex()
		end

		parts[ #parts + 1 ] = "|"
	end

	return table.concat( parts, "," )
end

local function Rebuild( sections )
	if not IsValid( board ) then return end

	sections = sections or SortedSections()

	board.Roster = Signature( sections )
	board.List:Clear()

	-- Wide spacing between sections so a section's rows can never collide with
	-- the next section's header.
	for i, section in ipairs( sections ) do
		if #section.players > 0 or not section.info.hideWhenEmpty then
			AddSection( board.List, section.info, section.players, i * 1000 )
		end
	end

	-- Lay out now rather than next frame, so the new order is what gets drawn
	-- rather than whatever was on screen before.
	board.List:InvalidateLayout( true )
end

local function Create()
	board = vgui.Create( "DPanel" )
	board:SetSize( PANEL_W, math.min( ScrH() - 120, 620 ) )
	board:SetPos( ( ScrW() - PANEL_W ) * 0.5, 60 )
	board:SetVisible( false )

	board.Paint = function( self, w, h )
		CS16.DrawPanel( 0, 0, w, h )

		CS16.DrawText( GetHostName(), "CS16.Title", 16, 12, CS16.Colors.Gold, TEXT_ALIGN_LEFT )

		local info = ("%s   %d/%d players"):format(
			game.GetMap(), #player.GetAll(), game.MaxPlayers() )
		CS16.DrawText( info, "CS16.Small", w - 16, 20, CS16.Colors.Muted, TEXT_ALIGN_RIGHT )

		surface.SetDrawColor( CS16.Colors.GoldDim )
		surface.DrawRect( 12, HEADER_H - 6, w - 24, 1 )
	end

	board.List = board:Add( "DScrollPanel" )
	board.List:Dock( FILL )
	board.List:DockMargin( 12, HEADER_H, 12, 12 )

	Rebuild()
end

function GM:ScoreboardShow()
	if not IsValid( board ) then Create() end

	local sections = SortedSections()
	if board.Roster ~= Signature( sections ) then Rebuild( sections ) end

	board:SetVisible( true )
end

function GM:ScoreboardHide()
	if IsValid( board ) then board:SetVisible( false ) end
end

--[[
	Reorder while the board is open, so a kill moves someone up in front of
	you. Only fires when the order actually changed - the sorting is done once
	here and handed to Rebuild rather than repeated inside it.
]]
hook.Add( "Think", "CS16.ScoreboardRefresh", function()
	if not IsValid( board ) or not board:IsVisible() then return end

	local sections = SortedSections()
	if board.Roster == Signature( sections ) then return end

	Rebuild( sections )
end )

-- Retire the addon's own scoreboard rather than forking the addon to remove it.
hook.Add( "Initialize", "CS16.DisableAddonScoreboard", function()
	hook.Remove( "ScoreboardShow", "CustomOrDefaultScoreboardShow" )
	hook.Remove( "ScoreboardHide", "CustomOrDefaultScoreboardHide" )
	hook.Remove( "VGUIMousePressed", "PlayerNameClick" )
end )
