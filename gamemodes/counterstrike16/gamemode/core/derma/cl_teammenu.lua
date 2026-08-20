--[[
	Picking a side, then picking who you are on it.

	Two screens, the way 1.6 does it: Select Team, then Choose A Class. Both
	wear the frame in cl_menuframe.lua, and both are driven by the number keys
	as much as by the mouse.

	1.6 fills the panel on the right of the class screen with a photograph of
	the class. Ours holds a live model instead, so what you are looking at is
	the character you will actually spawn as. Those photographs are Valve's and
	are not ours to ship; the models are already here.
]]

local CHOICE_T    = 1
local CHOICE_CT   = 2
local CHOICE_AUTO = 3
local CHOICE_SPEC = 4
local CHOICE_DEV  = 5

--[[
	A class index of 0 means "no preference", which is what Auto Select sends
	and what the server falls back to when a choice does not fit the side. The
	roster roll it already did stands in that case.
]]
local CLASS_AUTO = 0

local PREVIEW_FOV = 36

--[[
	Under 1.0 on purpose.

	GetModelBounds reports render bounds, which are padded well past the visible
	mesh so that nothing pops out of view when a limb swings. Framing to them
	exactly leaves a standing figure filling about half the panel with air all
	round it, so the fit is deliberately tighter than the numbers ask for.
]]
local PREVIEW_MARGIN = 0.86

local function SendChoice( choice, class )
	net.Start( "CS16.JoinTeam" )
		net.WriteUInt( choice, 3 )
		net.WriteUInt( class or CLASS_AUTO, 4 )
	net.SendToServer()
end

--[[ The model in the framed panel ]]

--[[
	Framed from the model's own bounds, the same measured fit the battle royale
	grid uses. A hand-picked camera distance suits one model and beheads the
	next; these run from 72 units tall to 81 and sit at different heights inside
	that.

	The aspect correction is the part the grid does not need. Its cells are
	portrait, so the vertical field of view is the wider of the two and a
	standing figure fits inside it. This panel is half again as wide as it is
	tall, which makes the vertical field of view much the narrower, and framing
	against the horizontal one crops the head and the boots off every class.
]]
local function FrameModel( panel, margin )
	local ent = panel.Entity
	if not IsValid( ent ) then return end

	local mins, maxs = ent:GetModelBounds()
	if not mins or not maxs then return end

	local w, h = panel:GetSize()
	if not w or w <= 0 or not h or h <= 0 then return end

	local height = maxs.z - mins.z
	local middle = ( maxs.z + mins.z ) * 0.5

	-- Half the model has to fit inside half the vertical field of view, which
	-- is the horizontal one narrowed by the panel's aspect.
	local half = math.tan( math.rad( PREVIEW_FOV ) * 0.5 ) * ( h / w )
	local dist = ( height * 0.5 ) / half * ( margin or PREVIEW_MARGIN )

	panel:SetCamPos( Vector( dist, 0, middle ) )
	panel:SetLookAt( Vector( 0, 0, middle ) )
end

local function AddPreview( frame )
	local x, y, w, h = CS16.Menu.PanelRect( frame )

	local mdl = frame:Add( "DModelPanel" )
	mdl:SetPos( x + 1, y + 1 )
	mdl:SetSize( w - 2, h - 2 )
	mdl:SetMouseInputEnabled( false )
	mdl:SetFOV( PREVIEW_FOV )

	--[[
		Facing front and staying there.

		It turned slowly at first, on the grounds that this is the only model on
		screen. That was a mistake: a figure that is always moving is never
		showing you the front, and the pose it is standing in was made to be
		looked at from there.
	]]
	mdl.LayoutEntity = function( self, ent )
		--[[
			A pose of ours where one exists, the standing idle otherwise. See
			core/modules/animations/sh_menuposes.lua: a model with no pose is
			not a problem, it just stands normally.
		]]
		local seq = CS16.MenuPoseFor( ent )
		if seq and ent:GetSequence() ~= seq then ent:ResetSequence( seq ) end

		ent:SetAngles( angle_zero )
		self:RunAnimation()
	end

	-- The gun the pose is holding, drawn inside the panel's own 3D pass.
	mdl.PostDrawModel = function( self, ent )
		CS16.DrawMenuProp( self, ent )
	end

	mdl.OnRemove = function( self )
		CS16.ClearMenuProp( self )
	end

	mdl.Show = function( self, model )
		self:SetModel( model )
		FrameModel( self )
	end

	return mdl
end

--[[ Screen two: choose a class ]]

local function OpenClassMenu( teamID, choice )
	if IsValid( CS16.TeamMenu ) then CS16.TeamMenu:Remove() end

	local classes = CS16.ClassesForTeam( teamID )

	--[[
		A side with no roster has nothing to ask, so the class screen is skipped
		rather than shown empty. Nothing configures that today, but a server
		owner emptying Config.Models is a two-line edit away from it.
	]]
	if #classes == 0 then
		SendChoice( choice, CLASS_AUTO )
		return
	end

	local frame = CS16.Menu.Frame( "menu.class.title" )
	CS16.TeamMenu = frame

	local s, d = frame.Scale, CS16.Menu.Design
	local selected = 1

	local preview = AddPreview( frame )
	preview:Show( classes[ 1 ].model )

	--[[
		The description under the panel, and the frame around it.

		Drawn in the frame's own Paint rather than as a label, so it re-reads
		the selection every frame and needs nothing told to it when the
		selection moves.
	]]
	local basePaint = frame.Paint

	frame.Paint = function( self, pw, ph )
		basePaint( self, pw, ph )
		CS16.Menu.DrawPanelFrame( self, pw, ph )

		local entry = classes[ selected ]
		if not entry then return end

		local text = CS16.L( "class." .. entry.key .. ".desc" )
		local wrap = d.PanelW * s

		local y = d.TextY * s
		for _, line in ipairs( CS16.WrapText( text, "CS16.MenuBody", wrap ) ) do
			CS16.DrawText( line, "CS16.MenuBody", d.PanelX * s, y, CS16.Colors.Amber, TEXT_ALIGN_LEFT )
			y = y + ScrH() / 58
		end
	end

	local buttons = {}

	for i, entry in ipairs( classes ) do
		local y = ( d.ListY + ( i - 1 ) * ( d.ButtonH + d.ButtonGap ) ) * s

		buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, i,
			function() return CS16.L( "class." .. entry.key .. ".name" ) end, y,
			function() return selected == i end,
			function()
				--[[
					First press previews, second commits. 1.6 joins on the first
					press, but 1.6 shows a photograph that never changes; ours
					shows the model you are about to become and it would be a
					waste to never let anyone look at it.
				]]
				if selected ~= i then
					selected = i
					preview:Show( entry.model )
					return
				end

				SendChoice( choice, i )
				frame:Remove()
			end )
	end

	local autoY = d.FooterY * s
	buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, #classes + 1,
		function() return CS16.L( "menu.autoselect" ) end, autoY,
		function() return false end,
		function()
			SendChoice( choice, CLASS_AUTO )
			frame:Remove()
		end )

	CS16.Menu.BindNumbers( frame, buttons, function() frame:Remove() end )
end

--[[ Screen one: select team ]]

function CS16.OpenTeamMenu()
	if IsValid( CS16.TeamMenu )  then CS16.TeamMenu:Remove()  end
	if IsValid( CS16.ModelMenu ) then CS16.ModelMenu:Remove() end

	local frame = CS16.Menu.Frame( "menu.team.title" )
	CS16.TeamMenu = frame

	local s, d  = frame.Scale, CS16.Menu.Design
	local isDev = CS16.IsDeveloper( LocalPlayer() )

	--[[
		The briefing panel, which 1.6 fills from a text file the map ships.

		None of ours carry one, so it is written from what the gamemode already
		knows: the mode being played and what each side has to do on this map.
		Telling somebody to defuse a bomb on a map that has not got one is a
		small lie, and it is the first thing they read.
	]]
	local basePaint = frame.Paint

	frame.Paint = function( self, pw, ph )
		basePaint( self, pw, ph )

		local x = d.PanelX * s
		local y = d.PanelY * s
		local wrap = d.PanelW * s

		local mode = CS16.Mode()
		local rescue = CS16.IsHostageMap()

		local lines = {
			{ CS16.L( "menu.brief.map",  { map = game.GetMap() } ), CS16.Colors.Gold },
			{ CS16.L( "menu.brief.mode", { mode = mode and mode.label or "?" } ), CS16.Colors.Amber },
			{ "", nil },
		}

		local objective = rescue and "menu.brief.rescue" or "menu.brief.defusal"
		for _, key in ipairs( { objective .. ".ct", objective .. ".t" } ) do
			for _, line in ipairs( CS16.WrapText( CS16.L( key ), "CS16.MenuBody", wrap ) ) do
				lines[ #lines + 1 ] = { line, CS16.Colors.Amber }
			end
			lines[ #lines + 1 ] = { "", nil }
		end

		for _, entry in ipairs( lines ) do
			if entry[ 1 ] ~= "" then
				CS16.DrawText( entry[ 1 ], "CS16.MenuBody", x, y, entry[ 2 ], TEXT_ALIGN_LEFT )
			end
			y = y + ScrH() / 52
		end
	end

	local buttons = {}
	local row = 0

	local function Add( key, onClick )
		local y = ( d.ListY + row * ( d.ButtonH + d.ButtonGap ) ) * s
		row = row + 1

		buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, #buttons + 1,
			function() return CS16.L( key ) end, y,
			function() return false end, onClick )
	end

	Add( "menu.team.t",  function() OpenClassMenu( TEAM_T,  CHOICE_T  ) end )
	Add( "menu.team.ct", function() OpenClassMenu( TEAM_CT, CHOICE_CT ) end )

	Add( "menu.team.auto", function()
		SendChoice( CHOICE_AUTO, CLASS_AUTO )
		frame:Remove()
	end )

	Add( "menu.team.spectate", function()
		SendChoice( CHOICE_SPEC, CLASS_AUTO )
		frame:Remove()
	end )

	--[[
		Below the sides and only for developers, matching where the team sits on
		the scoreboard. The server checks the rank when the choice arrives; this
		is a net message, so hiding the button is presentation rather than a
		permission.
	]]
	if isDev then
		local y = d.FooterY * s
		buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, #buttons + 1,
			function() return CS16.L( "menu.team.developer" ) end, y,
			function() return false end,
			function()
				SendChoice( CHOICE_DEV, CLASS_AUTO )
				frame:Remove()
			end )
	end

	--[[
		Cancel only exists once you are on a side. Offering it to somebody who
		has not joined yet leaves them looking at a map from nowhere with no way
		back to the menu except the key they do not know about yet.
	]]
	local canCancel = CS16.IsPlayingTeam( LocalPlayer():Team() )
		or LocalPlayer():Team() == TEAM_DEV

	CS16.Menu.BindNumbers( frame, buttons, function()
		if canCancel then frame:Remove() end
	end )
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
