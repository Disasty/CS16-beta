--[[
	Team selection. Opens on join and can be reopened with M, matching the
	1.6 flow of picking a side before you ever see the map from a body.
]]

local CHOICE_T    = 1
local CHOICE_CT   = 2
local CHOICE_AUTO = 3
local CHOICE_SPEC = 4
local CHOICE_DEV  = 5

local MENU_W  = 340
local ROW_H   = 46
local ROW_GAP = 6
local PAD     = 12
local TITLE_H = 48

local function SendChoice( choice )
	net.Start( "CS16.JoinTeam" )
		net.WriteUInt( choice, 3 )
	net.SendToServer()
end

-- One row of the menu: a framed button that lights up on hover.
local function AddChoice( parent, label, subtitle, colour, choice, menu )
	local btn = parent:Add( "DButton" )
	btn:Dock( TOP )
	btn:DockMargin( 0, 0, 0, ROW_GAP )
	btn:SetTall( ROW_H )
	btn:SetText( "" )

	btn.Paint = function( self, w, h )
		surface.SetDrawColor( self:IsHovered() and CS16.Colors.Hover or CS16.Colors.PanelLight )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( self:IsHovered() and CS16.Colors.Gold or CS16.Colors.GoldDim )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )

		-- Team colour flash down the left edge.
		surface.SetDrawColor( colour )
		surface.DrawRect( 0, 0, 3, h )

		CS16.DrawText( label, "CS16.Heading", 14, 10, CS16.Colors.Gold, TEXT_ALIGN_LEFT )
		CS16.DrawText( subtitle, "CS16.Small", 14, 28, CS16.Colors.Muted, TEXT_ALIGN_LEFT )
	end

	btn.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )
		SendChoice( choice )

		-- Remove, not Close: this is a plain panel now, and Close is a DFrame
		-- method that wouldn't exist on it.
		menu:Remove()
	end

	return btn
end

--[[
	A popup panel rather than a DFrame, for the same reason as the developer
	menu: DFrame sets its own dock padding in PerformLayout to leave room for a
	title bar and close button, whether or not it's showing either. Sized to fit
	its rows exactly, that padding eats the bottom one. Nothing here uses a
	DFrame feature, so the height below is the height the rows actually get.
]]
function CS16.OpenTeamMenu()
	if IsValid( CS16.TeamMenu ) then CS16.TeamMenu:Remove() end

	-- The developer row only exists for developers, so the panel grows to fit
	-- it rather than leaving a gap for everyone else.
	local isDev = CS16.IsDeveloper( LocalPlayer() )
	local rows  = isDev and 5 or 4

	local h     = TITLE_H + rows * ( ROW_H + ROW_GAP ) + PAD
	local frame = vgui.Create( "DPanel" )

	CS16.TeamMenu = frame

	frame:SetSize( MENU_W, h )
	frame:SetPos( ( ScrW() - MENU_W ) * 0.5, ( ScrH() - h ) * 0.5 )
	frame:MakePopup()
	frame:DockPadding( PAD, TITLE_H, PAD, PAD )

	frame.Paint = function( self, w, ph )
		CS16.DrawPanel( 0, 0, w, ph )
		CS16.DrawText( "CHOOSE YOUR TEAM", "CS16.Title", w * 0.5, 14, CS16.Colors.Gold, TEXT_ALIGN_CENTER )

		surface.SetDrawColor( CS16.Colors.GoldDim )
		surface.DrawRect( 12, TITLE_H - 8, w - 24, 1 )
	end

	--[[
		Above the sides, and only for developers - the same order as the
		scoreboard, so the two agree about where the team sits.

		The server checks the rank again when the choice arrives: this is a net
		message, so hiding the button is presentation rather than a permission.
	]]
	if isDev then
		AddChoice( frame, "DEVELOPER", "Walk the map without joining the match.",
			CS16.TeamColors[ TEAM_DEV ], CHOICE_DEV, frame )
	end

	--[[
		What each side is actually for, which depends on the map's objective.
		Telling somebody to defuse a bomb on a map that hasn't got one is a
		small lie, and it's the first thing they read.
	]]
	local rescue = CS16.IsHostageMap()

	AddChoice( frame, "TERRORISTS",
		rescue and "Guard the hostages. Stop the rescue." or "Plant the bomb. Hold the site.",
		CS16.Colors.T, CHOICE_T, frame )

	AddChoice( frame, "COUNTER-TERRORISTS",
		rescue and "Escort the hostages to safety." or "Stop the plant. Defuse the bomb.",
		CS16.Colors.CT, CHOICE_CT, frame )
	AddChoice( frame, "AUTO-SELECT",        "Join whichever side needs you.",   CS16.Colors.Gold,  CHOICE_AUTO, frame )
	AddChoice( frame, "SPECTATE",           "Watch without playing.",           CS16.Colors.Muted, CHOICE_SPEC, frame )
end

net.Receive( "CS16.OpenTeamMenu", function()
	--[[
		The message of the day gets first refusal. It stands in front of this
		menu on connect and opens it itself when dismissed, so opening here as
		well would stack the two.
	]]
	if CS16.MOTDHolding and CS16.MOTDHolding() then return end

	-- OpenJoinMenu, not OpenTeamMenu: a mode with one team gets the model
	-- picker in place of a side menu that has nothing to ask. See
	-- cl_modelmenu.lua.
	CS16.OpenJoinMenu()
end )

concommand.Add( "cs16_teammenu", function()
	CS16.OpenJoinMenu()
end )

-- M is the CS team-menu key.
CS16.WatchKey( "teammenu", KEY_M, function()
	if IsValid( CS16.TeamMenu ) then
		CS16.TeamMenu:Remove()
		return
	end

	if IsValid( CS16.ModelMenu ) then
		CS16.ModelMenu:Remove()
		return
	end

	CS16.OpenJoinMenu()
end )
