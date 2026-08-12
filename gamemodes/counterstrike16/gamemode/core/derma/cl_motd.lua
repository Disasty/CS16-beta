--[[
	The message of the day, which is really the leaderboards.

	Shown once when you connect - which on this gamemode is once per match,
	since a match ends by reloading the map - and it cannot be reopened. It
	stands in front of the team menu: dismissing it is what lets you pick a
	side, the way 1.6 put its MOTD in front of everything else.

	Derma rather than the HTML panel 1.6 actually used. The boards are live
	server data, and generating a page to hand to a browser to display numbers
	we already have in a table would be a lot of machinery to arrive back where
	we started - with none of the theme the rest of the UI is built from.
]]

local W, H     = 760, 496
local ROW_H    = 26
local FOOTER_H = 52

-- Deep enough for the host name and a line under it. Server names run long, so
-- the mode and map sit beneath rather than beside - alongside, a name of any
-- real length simply ran straight through them.
local HEADER_H = 66

local shown = false

--[[
	Held back until the board has been dismissed.

	The server sends this a fraction before the team menu, so in practice the
	flag is already set by the time the menu arrives. If the message never
	comes at all - an older server, or a failure - the menu opens exactly as it
	used to, which is the right way for this to break.
]]
local pendingTeamMenu = false

-- Set from the message: whether this mode ranks on wins rather than level.
local showWins = false

local function ReadBoard()
	local rows = {}

	for i = 1, net.ReadUInt( 8 ) do
		rows[ i ] = {
			nick  = net.ReadString(),
			level = net.ReadUInt( 7 ),
			xp    = net.ReadUInt( 32 ),
			kills = net.ReadUInt( 32 ),
			wins  = net.ReadUInt( 16 ),
		}
	end

	return rows
end

--[[
	One leaderboard.

	Ranks are drawn rather than implied by position, because a board with four
	entries on a fresh server should still read as a top ten with six blanks -
	otherwise the first player to connect looks like they are winning something.
]]
--[[
	The gap between the two boards. The frame's own side padding is 16, which is
	what the OK bar below is aligned to, so anything here has to add up inside
	W - 32 or the pair sits narrower than the bar.
]]
local BOARD_GAP = 10

local function AddBoard( parent, title, rows, accent, fill )
	local panel = vgui.Create( "DPanel", parent )

	--[[
		The second board takes whatever is left rather than a second computed
		half.

		Both were ( W - 60 ) * 0.5 with a 10 margin each, which comes to W - 40
		inside a space of W - 32 - eight pixels of overhang that pushed the pair
		left of the OK bar and made the whole panel look off-centre. Docking the
		last one to FILL makes the arithmetic impossible to get wrong.
	]]
	if fill then
		panel:Dock( FILL )
	else
		panel:Dock( LEFT )
		panel:SetWide( ( W - 32 - BOARD_GAP ) * 0.5 )
		panel:DockMargin( 0, 0, BOARD_GAP, 0 )
	end

	panel.Paint = function( self, w, h )
		surface.SetDrawColor( 0, 0, 0, 160 )
		surface.DrawRect( 0, 0, w, h )

		surface.SetDrawColor( accent.r, accent.g, accent.b, 90 )
		surface.DrawOutlinedRect( 0, 0, w, h )

		CS16.DrawText( title, "CS16.Small", 10, 8, accent, TEXT_ALIGN_LEFT )

		-- The leading column is whatever the mode ranks on, so the board reads
		-- top to bottom in the order the numbers explain.
		CS16.DrawText( showWins and "WINS" or "LEVEL", "CS16.Small", w - 96, 8,
			CS16.Colors.Muted, TEXT_ALIGN_CENTER )
		CS16.DrawText( "KILLS", "CS16.Small", w - 40, 8, CS16.Colors.Muted, TEXT_ALIGN_CENTER )

		surface.SetDrawColor( accent.r, accent.g, accent.b, 60 )
		surface.DrawRect( 8, 28, w - 16, 1 )

		for i = 1, 10 do
			local row = rows[ i ]
			local y   = 36 + ( i - 1 ) * ROW_H

			CS16.DrawText( i .. ".", "CS16.Small", 12, y + 4,
				row and CS16.Colors.Muted or Color( 90, 90, 90 ), TEXT_ALIGN_LEFT )

			if row then
				CS16.DrawText( row.nick, "CS16.Text", 38, y, CS16.Colors.White, TEXT_ALIGN_LEFT )
				CS16.DrawText( showWins and row.wins or row.level, "CS16.Text", w - 96, y,
					CS16.Colors.Gold, TEXT_ALIGN_CENTER )
				CS16.DrawText( row.kills, "CS16.Small", w - 40, y + 4, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
			else
				CS16.DrawText( "-", "CS16.Text", 38, y, Color( 70, 70, 70 ), TEXT_ALIGN_LEFT )
			end
		end
	end

	return panel
end

function CS16.OpenMOTD( host, players, bots )
	if IsValid( CS16.MOTD ) then CS16.MOTD:Remove() end

	-- A popup DPanel rather than a DFrame, for the reason documented on the team
	-- menu: DFrame reserves dock padding for a title bar it may never draw.
	local frame = vgui.Create( "DPanel" )
	frame:SetSize( W, H )
	frame:Center()
	frame:MakePopup()
	frame:DockPadding( 16, HEADER_H, 16, FOOTER_H )

	frame.Paint = function( self, w, h )
		CS16.DrawPanel( 0, 0, w, h )

		--[[
			The server, then the mode, both down the middle - what this is and
			what is being played on it are the two things worth reading first.

			The map goes left on the mode's own line rather than getting a line
			of its own. It is reference rather than headline: you look it up
			when you want it, and it sits out of the way until then.
		]]
		CS16.DrawText( host, "CS16.Title", w * 0.5, 10, CS16.Colors.Gold, TEXT_ALIGN_CENTER )

		CS16.DrawText( CS16.Mode().label, "CS16.Small", w * 0.5, 38,
			CS16.Colors.Muted, TEXT_ALIGN_CENTER )

		CS16.DrawText( game.GetMap(), "CS16.Small", 16, 38,
			CS16.Colors.Muted, TEXT_ALIGN_LEFT )

		surface.SetDrawColor( CS16.Colors.Gold.r, CS16.Colors.Gold.g, CS16.Colors.Gold.b, 70 )
		surface.DrawRect( 16, HEADER_H - 10, w - 32, 1 )
	end

	CS16.MOTD = frame

	local body = vgui.Create( "DPanel", frame )
	body:Dock( FILL )
	body.Paint = nil

	AddBoard( body, "TOP PLAYERS", players, CS16.Colors.Gold )
	AddBoard( body, "TOP BOTS",    bots,    CS16.Colors.CT, true )

	local ok = vgui.Create( "DButton", frame )
	ok:Dock( BOTTOM )
	ok:DockMargin( 0, 12, 0, 0 )
	ok:SetTall( 30 )
	ok:SetText( "" )

	ok.Paint = function( self, w, h )
		local hovered = self:IsHovered()

		surface.SetDrawColor( 0, 0, 0, hovered and 220 or 160 )
		surface.DrawRect( 0, 0, w, h )

		surface.SetDrawColor( CS16.Colors.Gold.r, CS16.Colors.Gold.g, CS16.Colors.Gold.b, hovered and 200 or 90 )
		surface.DrawOutlinedRect( 0, 0, w, h )

		CS16.DrawText( "OK", "CS16.Text", w * 0.5, h * 0.5 - 8, CS16.Colors.Gold, TEXT_ALIGN_CENTER )
	end

	ok.DoClick = function()
		frame:Remove()

		--[[
			Straight into picking a side, which is the whole reason this stands
			in front of the team menu rather than beside it.
		]]
		if pendingTeamMenu then
			pendingTeamMenu = false

			-- Whichever of the two this mode uses: a side to pick, or a model.
			-- See cl_modelmenu.lua.
			CS16.OpenJoinMenu()
		end
	end
end

net.Receive( "CS16.MOTD", function()
	local host = net.ReadString()

	showWins = net.ReadBool()

	local players = ReadBoard()
	local bots    = ReadBoard()

	-- Once, and there is no way to ask for it again. Reconnecting or the next
	-- map is what brings it back.
	if shown then return end
	shown = true

	pendingTeamMenu = true
	CS16.OpenMOTD( host, players, bots )
end )

--[[
	Whether the team menu should wait.

	Called by the team menu when the server asks it to open. True means the MOTD
	is up and will open it on dismissal, so opening now would put the two on top
	of each other.
]]
function CS16.MOTDHolding()
	return IsValid( CS16.MOTD ) and pendingTeamMenu
end
