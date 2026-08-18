--[[
	Pick who you are, in the modes with nobody to be.

	Battle royale has one team, so the team menu has nothing to ask: choosing a
	side you cannot choose is a menu with one button on it. What is worth
	choosing there is what you look like, so this stands in its place - the ten
	models the 1.6 pack ships, shown as models rather than named in a list,
	because nobody remembers which of four Terrorists "guerilla" is.

	It wears the frame from cl_menuframe.lua, the same one Select Team and
	Choose A Class use, so the three read as one menu with different contents.
	What it does not do is become a numbered list: ten characters shown at once
	is the whole point of it, and a column of names would be a worse menu drawn
	more faithfully.
]]

--[[
	Six across, not five.

	Ten models fit two rows either way, but a developer sees eleven cells and
	five columns pushes the last one onto a third row that does not fit inside
	the frame - it overhung the bottom edge and landed on top of the spectate
	button. Six columns keeps every case to two rows.
]]
local COLS = 6

-- Design units, scaled by the frame. See cl_menuframe.lua.
local GRID_X, GRID_Y = 126, 180
local CELL_W, CELL_H = 169, 290
local CELL_GAP       = 16
local LABEL_H        = 34
local FOOTER_GAP     = 26
local FOOTER_H       = 40

local PREVIEW_FOV = 34

--[[
	A little room around the edges. These cells are portrait and the models are
	narrow, so there is width to spare for the one that turns, which leaves this
	free to be set by how it looks rather than by what might clip.
]]
local PREVIEW_MARGIN = 0.95

--[[
	Framed from the model's own bounds rather than a fixed camera.

	One hand-picked distance suits one model and crops the next. These run from
	72 units tall to 81 and sit at different heights inside that, charple
	included, which is shaped like nothing else in the list.

	The aspect term matters even here, where the cells are portrait and forgiving:
	it is what makes the same routine correct in the wide panel on the class
	screen, and one framing rule beats two that disagree.
]]
local function FrameModel( panel )
	local ent = panel.Entity
	if not IsValid( ent ) then return end

	local mins, maxs = ent:GetModelBounds()
	if not mins or not maxs then return end

	local w, h = panel:GetSize()
	if not w or w <= 0 or not h or h <= 0 then return end

	local height = maxs.z - mins.z
	local middle = ( maxs.z + mins.z ) * 0.5

	local half = math.tan( math.rad( PREVIEW_FOV ) * 0.5 ) * math.min( 1, h / w )
	local dist = ( height * 0.5 ) / half * PREVIEW_MARGIN

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
local function AddCell( menu, index, label, model, x, y, w, h )
	local cell = menu:Add( "DButton" )
	cell:SetPos( x, y )
	cell:SetSize( w, h )
	cell:SetText( "" )

	local labelH = LABEL_H * menu.Scale

	local icon = cell:Add( "DModelPanel" )
	icon:SetPos( 1, 1 )
	icon:SetSize( w - 2, h - labelH - 2 )
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
		fairground, and each costs a bone rebuild every frame it moves. The
		class screen does the opposite for the opposite reason: one model, and
		it is the thing being chosen.
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

	--[[
		An outline rather than a fill. The class screen fills its selected button
		gold because the button is only words; filling one of these would paint
		over the model that is the reason to click it.
	]]
	cell.Paint = function( self, cw, ch )
		surface.SetDrawColor( self:IsHovered() and CS16.Colors.Gold or CS16.Colors.Amber )
		surface.DrawOutlinedRect( 0, 0, cw, ch, 1 )
	end

	-- Over the top, because the model panel is drawn as a child and would
	-- otherwise cover a label painted in Paint.
	cell.PaintOver = function( self, cw, ch )
		CS16.DrawText( CS16.Upper( label ), "CS16.MenuLabel", cw * 0.5, ch - labelH * 0.72,
			self:IsHovered() and CS16.Colors.Gold or CS16.Colors.Amber, TEXT_ALIGN_CENTER )
	end

	cell.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )
		Send( index )
		menu:Remove()
	end

	return cell
end

function CS16.OpenModelMenu()
	if IsValid( CS16.ModelMenu ) then CS16.ModelMenu:Remove() end
	if IsValid( CS16.TeamMenu )  then CS16.TeamMenu:Remove()  end

	local frame = CS16.Menu.Frame( "menu.class.title" )
	CS16.ModelMenu = frame

	local s      = frame.Scale
	local models = CS16.Config.PickableModels
	local isDev  = CS16.IsDeveloper( LocalPlayer() )

	local cw, ch = CELL_W * s, CELL_H * s
	local gap    = CELL_GAP * s

	local function Place( i )
		local col = ( i - 1 ) % COLS
		local row = math.floor( ( i - 1 ) / COLS )

		return GRID_X * s + col * ( cw + gap ), GRID_Y * s + row * ( ch + gap )
	end

	for i, entry in ipairs( models ) do
		local x, y = Place( i )
		AddCell( frame, i, CS16.L( "class." .. entry.key .. ".name" ), entry.model, x, y, cw, ch )
	end

	--[[
		The developer entry is a cell like any other, shown only to developers.
		Their model is drawn too - there is exactly one person who ever sees this
		button and it costs nothing to show them what they'll be wearing.
	]]
	if isDev then
		local x, y = Place( #models + 1 )
		AddCell( frame, DEVELOPER, CS16.L( "menu.team.developer" ),
			CS16.Config.Developer.Model, x, y, cw, ch )
	end

	--[[
		Spectate stays reachable. The team menu this replaces had it, and without
		it there is no way out of the match short of disconnecting.
	]]
	--[[
		Placed under whatever the grid actually came to rather than at a fixed
		height, so the developer's extra cell pushes it down instead of being
		drawn on top of it.
	]]
	local rows     = math.ceil( ( #models + ( isDev and 1 or 0 ) ) / COLS )
	local gridEnd  = GRID_Y * s + rows * ch + ( rows - 1 ) * gap

	local spec = frame:Add( "DButton" )
	spec:SetPos( GRID_X * s, gridEnd + FOOTER_GAP * s )
	spec:SetSize( cw, FOOTER_H * s )
	spec:SetText( "" )

	spec.Paint = function( self, bw, bh )
		local on = self:IsHovered()

		if on then
			surface.SetDrawColor( CS16.Colors.Gold )
			surface.DrawRect( 0, 0, bw, bh )
		else
			surface.SetDrawColor( CS16.Colors.Amber )
			surface.DrawOutlinedRect( 0, 0, bw, bh, 1 )
		end

		CS16.DrawText( CS16.Upper( CS16.L( "menu.team.spectate" ) ), "CS16.MenuItem",
			12 * s, bh * 0.5 - 9 * s,
			on and CS16.Colors.Panel or CS16.Colors.Amber, TEXT_ALIGN_LEFT )
	end

	spec.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )

		net.Start( "CS16.JoinTeam" )
			net.WriteUInt( 4, 3 )
			net.WriteUInt( 0, 4 )
		net.SendToServer()

		frame:Remove()
	end

	--[[
		No numbered rows here, so the digits have nothing to select - but 0 still
		closes, and only once there is something to go back to. Offering it to
		somebody who has not joined yet leaves them looking at the map from
		nowhere with no way back except a key they do not know about.
	]]
	local ply = LocalPlayer()
	local canCancel = CS16.IsPlayingTeam( ply:Team() ) or ply:Team() == TEAM_DEV

	CS16.Menu.BindNumbers( frame, {}, function()
		if canCancel then frame:Remove() end
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
