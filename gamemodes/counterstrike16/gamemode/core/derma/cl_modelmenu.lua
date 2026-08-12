--[[
	Pick who you are, in the modes with nobody to be.

	Battle royale has one team, so the team menu has nothing to ask: choosing a
	side you cannot choose is a menu with one button on it. What is worth
	choosing there is what you look like, so this stands in its place - the ten
	models the 1.6 pack ships, shown as models rather than named in a list,
	because nobody remembers which of four Terrorists "guerilla" is.

	Same panel, border and gold as everything else. See cl_teammenu.lua, which
	this replaces under battle royale and only under battle royale.
]]

local CELL_W   = 150
local CELL_H   = 205
local LABEL_H  = 30
local GAP      = 8
local COLS     = 5
local PAD      = 14
local TITLE_H  = 50
local FOOTER_H = 46

local PREVIEW_FOV = 34

--[[
	A little room around the edges. 1.0 fits the model to the frame exactly;
	above that pushes the camera back and leaves more air around it.

	Rotation costs nothing vertically - yaw doesn't change a standing figure's
	height - and these cells are portrait while the models are narrow, so there
	is width to spare for the one that turns. Which leaves this free to be set
	by how it looks rather than by what might clip.
]]
local PREVIEW_MARGIN = 0.95

--[[
	Framed from the model's own bounds rather than a fixed camera.

	One hand-picked distance suits one model and crops the next. These run from
	72 units tall to 81 and sit at different heights inside that, and the first
	attempt was close enough to cut the head off every one of them. Measuring
	means each cell frames whatever it was handed - charple included, which is
	shaped like nothing else in the list.

	Level with the middle of the model rather than angled down at it: a tilted
	view of a standing figure mostly shows you the top of its head.
]]
local function FrameModel( panel )
	local ent = panel.Entity
	if not IsValid( ent ) then return end

	local mins, maxs = ent:GetModelBounds()
	if not mins or not maxs then return end

	local height = maxs.z - mins.z
	local middle = ( maxs.z + mins.z ) * 0.5

	-- Half the height has to fit within half the field of view.
	local dist = ( height * 0.5 ) / math.tan( math.rad( PREVIEW_FOV ) * 0.5 ) * PREVIEW_MARGIN

	panel:SetCamPos( Vector( dist, 0, middle ) )
	panel:SetLookAt( Vector( 0, 0, middle ) )
end

--[[
	Index 0 is the developer team rather than a model.

	It is a team change wearing a model's clothes, and putting it in the grid
	means the one person who uses it can get to it in a click instead of going
	the long way round through the old menu. The server checks the rank when it
	arrives; this is a net message like any other.
]]
local DEVELOPER = 0

local function Send( index )
	net.Start( "CS16.PickModel" )
		net.WriteUInt( index, 5 )
	net.SendToServer()
end

--[[
	One model in the grid.

	The DModelPanel takes no mouse input, or it would swallow every click before
	the button underneath it ever saw one - the model is the button's face, not
	a control of its own.
]]
local function AddCell( menu, parent, index, name, model, x, y )
	local cell = parent:Add( "DButton" )
	cell:SetPos( x, y )
	cell:SetSize( CELL_W, CELL_H )
	cell:SetText( "" )

	local icon = cell:Add( "DModelPanel" )
	icon:SetPos( 1, 1 )
	icon:SetSize( CELL_W - 2, CELL_H - LABEL_H - 2 )
	icon:SetModel( model )
	icon:SetMouseInputEnabled( false )
	icon:SetFOV( PREVIEW_FOV )

	-- After SetModel, which is what creates the entity the bounds come from.
	FrameModel( icon )

	--[[
		Standing rather than in the reference pose, which is a T-shape with its
		arms out - unrecognisable as any of these characters. They're player
		models, so they carry the player animation set and idle_all_01 is the
		same standing idle the hostages use.

		Only the one under the cursor turns. Ten of them revolving at once is a
		fairground, and each costs a bone rebuild every frame it moves.
	]]
	icon.LayoutEntity = function( self, ent )
		local seq = ent:LookupSequence( "idle_all_01" )
		if seq and seq > 0 and ent:GetSequence() ~= seq then ent:ResetSequence( seq ) end

		if cell:IsHovered() then
			ent:SetAngles( Angle( 0, RealTime() * 45 % 360, 0 ) )
			self:RunAnimation()
		else
			ent:SetAngles( angle_zero )
		end
	end

	cell.Paint = function( self, w, h )
		local on = self:IsHovered()

		surface.SetDrawColor( on and CS16.Colors.Hover or CS16.Colors.PanelLight )
		surface.DrawRect( 0, 0, w, h )

		surface.SetDrawColor( on and CS16.Colors.Gold or CS16.Colors.GoldDim )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
	end

	-- Over the top, because the model panel is drawn as a child and would
	-- otherwise cover a label painted in Paint.
	cell.PaintOver = function( self, w, h )
		CS16.DrawText( name, "CS16.Small", w * 0.5, h - LABEL_H + 9,
			self:IsHovered() and CS16.Colors.Gold or CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	end

	cell.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )
		Send( index )
		menu:Remove()
	end

	return cell
end

-- The plain row along the bottom, for the one choice that isn't a model.
local function AddFooterButton( menu, parent, label, x, y, w, onClick )
	local btn = parent:Add( "DButton" )
	btn:SetPos( x, y )
	btn:SetSize( w, 28 )
	btn:SetText( "" )

	btn.Paint = function( self, bw, bh )
		surface.SetDrawColor( self:IsHovered() and CS16.Colors.Hover or CS16.Colors.PanelLight )
		surface.DrawRect( 0, 0, bw, bh )
		surface.SetDrawColor( self:IsHovered() and CS16.Colors.Gold or CS16.Colors.GoldDim )
		surface.DrawOutlinedRect( 0, 0, bw, bh, 1 )

		CS16.DrawText( label, "CS16.Small", bw * 0.5, 8,
			self:IsHovered() and CS16.Colors.Gold or CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	end

	btn.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )
		onClick()
		menu:Remove()
	end

	return btn
end

function CS16.OpenModelMenu()
	if IsValid( CS16.ModelMenu ) then CS16.ModelMenu:Remove() end
	if IsValid( CS16.TeamMenu )  then CS16.TeamMenu:Remove()  end

	local models = CS16.Config.PickableModels
	local isDev  = CS16.IsDeveloper( LocalPlayer() )

	--[[
		The developer entry is a cell like any other, shown only to developers.
		Their model is drawn too - there is exactly one person who ever sees
		this button and it costs nothing to show them what they'll be wearing.
	]]
	local count = #models + ( isDev and 1 or 0 )
	local rows  = math.ceil( count / COLS )

	local w = PAD * 2 + COLS * CELL_W + ( COLS - 1 ) * GAP
	local h = TITLE_H + rows * CELL_H + ( rows - 1 ) * GAP + FOOTER_H + PAD

	-- A DPanel rather than a DFrame, for the same reason as the team and
	-- developer menus: DFrame reserves dock padding for a title bar it isn't
	-- showing, which eats the bottom row of anything sized to fit exactly.
	local frame = vgui.Create( "DPanel" )
	CS16.ModelMenu = frame

	frame:SetSize( w, h )
	frame:SetPos( ( ScrW() - w ) * 0.5, ( ScrH() - h ) * 0.5 )
	frame:MakePopup()

	frame.Paint = function( self, pw, ph )
		CS16.DrawPanel( 0, 0, pw, ph )
		CS16.DrawText( "CHOOSE YOUR MODEL", "CS16.Title", pw * 0.5, 15, CS16.Colors.Gold, TEXT_ALIGN_CENTER )

		surface.SetDrawColor( CS16.Colors.GoldDim )
		surface.DrawRect( 12, TITLE_H - 9, pw - 24, 1 )
	end

	local function Place( i )
		local col = ( i - 1 ) % COLS
		local row = math.floor( ( i - 1 ) / COLS )

		return PAD + col * ( CELL_W + GAP ), TITLE_H + row * ( CELL_H + GAP )
	end

	for i, entry in ipairs( models ) do
		local x, y = Place( i )
		AddCell( frame, frame, i, entry.name, entry.model, x, y )
	end

	if isDev then
		local x, y = Place( #models + 1 )
		AddCell( frame, frame, DEVELOPER, "DEVELOPER", CS16.Config.Developer.Model, x, y )
	end

	--[[
		Spectate stays reachable. The team menu it replaces had it, and without
		it there is no way out of the match short of disconnecting.
	]]
	local footerY = TITLE_H + rows * CELL_H + ( rows - 1 ) * GAP + 10

	-- Exactly one cell wide, so it lines up with the column above it rather
	-- than sitting slightly narrow and looking like a mistake.
	AddFooterButton( frame, frame, "SPECTATE", PAD, footerY, CELL_W, function()
		net.Start( "CS16.JoinTeam" )
			net.WriteUInt( 4, 3 )
		net.SendToServer()
	end )
end

--[[
	Which menu a mode gets.

	Anything with one team has no side to pick, so it gets the model grid;
	everything else keeps the side menu it has always had.
]]
function CS16.OpenJoinMenu()
	if CS16.SoloTeam() then
		CS16.OpenModelMenu()
		return
	end

	CS16.OpenTeamMenu()
end

concommand.Add( "cs16_modelmenu", function()
	CS16.OpenModelMenu()
end )
