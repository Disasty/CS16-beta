--[[
	The frame 1.6 puts every join menu in.

	Select Team and Choose A Class are the same screen with different contents:
	a title over a rule, a column of numbered buttons down the left, a framed
	panel on the right, and a paragraph underneath it. Building it once means
	the two cannot drift apart, and battle royale's model picker can wear it
	too.

	Everything is positioned in the design units below and scaled to whatever
	screen it lands on, so the proportions stay 1.6's at any resolution rather
	than a fixed pixel layout that only looks right on one monitor. The numbers
	are measured off the real thing.

	1.6 rounds the corners of these menus. Our other panels are square, which
	is right for the scoreboard and the HUD, and this deliberately differs.
]]

-- The size the offsets below are expressed in. Nothing draws at this size.
local DESIGN_W, DESIGN_H = 1350, 985

CS16.Menu = CS16.Menu or {}

-- Measured off 1.6, in design units.
CS16.Menu.Design = {
	TitleX   = 125, TitleY   = 43,
	RuleY    = 112,

	ListX    = 126, ListW    = 332,
	ButtonH  = 40,  ButtonGap = 32,
	ListY    = 220,

	-- The odd one out sits below a gap, the way Auto Select does in 1.6.
	FooterY  = 582,

	PanelX   = 505, PanelY   = 213,
	PanelW   = 675, PanelH   = 442,

	TextY    = 740,
}

--[[
	How big the menu is on this screen, and what one design unit is worth.

	Capped so it does not become absurd on an ultrawide, and floored so it stays
	usable on something small. 1.6's menu is close to full screen and shrinking
	it to a tidy box is most of what stopped ours reading like the original.
]]
function CS16.Menu.Metrics()
	local w = math.Clamp( ScrW() * 0.72, 900, 1500 )
	local h = w * ( DESIGN_H / DESIGN_W )

	-- A short screen decides the height instead, and the width follows it.
	if h > ScrH() * 0.9 then
		h = ScrH() * 0.9
		w = h * ( DESIGN_W / DESIGN_H )
	end

	return math.floor( w ), math.floor( h ), w / DESIGN_W
end

--[[
	A title is usually a language key, but the buy menu's carries the category
	in it ("Buy Shotguns"), which needs a value substituted. Passing a function
	covers that without every caller having to build a string it does not need.
]]
local function TitleText( title )
	if isfunction( title ) then return title() or "" end
	return CS16.L( title )
end

--[[
	The panel itself.

	A DPanel rather than a DFrame, for the reason the other menus give: DFrame
	reserves dock padding for a title bar it is not showing, and everything here
	is placed absolutely anyway.
]]
function CS16.Menu.Frame( titleKey )
	local w, h, s = CS16.Menu.Metrics()
	local d = CS16.Menu.Design

	local frame = vgui.Create( "DPanel" )
	frame:SetSize( w, h )
	frame:SetPos( ( ScrW() - w ) * 0.5, ( ScrH() - h ) * 0.5 )
	frame:MakePopup()

	frame.Scale = s

	frame.Paint = function( self, pw, ph )
		--[[
			An amber ring, drawn as a rounded box with the panel laid on top one
			pixel in. There is no rounded outline in the draw library, and
			DrawOutlinedRect squares off the corners this frame just rounded.
		]]
		draw.RoundedBox( 8, 0, 0, pw, ph, CS16.Colors.Amber )
		draw.RoundedBox( 8, 1, 1, pw - 2, ph - 2, CS16.Colors.Panel )

		CS16.DrawText( CS16.Upper( TitleText( titleKey ) ), "CS16.MenuTitle",
			d.TitleX * s, d.TitleY * s, CS16.Colors.Gold, TEXT_ALIGN_LEFT )

		surface.SetDrawColor( CS16.Colors.Amber )
		surface.DrawRect( 10 * s, d.RuleY * s, pw - 20 * s, 1 )
	end

	return frame
end

--[[
	One numbered button.

	1.6 numbers them and expects the number key to work, which is most of how
	the menu is actually driven: nobody clicks "1 Terrorist Forces" twice in a
	row for a year. The selected one is filled gold with dark text, the rest are
	an outline.
]]
function CS16.Menu.Button( frame, number, label, y, selected, onClick )
	local s = frame.Scale
	local d = CS16.Menu.Design

	local btn = frame:Add( "DButton" )
	btn:SetPos( d.ListX * s, y )
	btn:SetSize( d.ListW * s, d.ButtonH * s )
	btn:SetText( "" )

	btn.Paint = function( self, w, h )
		local on = selected() or self:IsHovered()

		if on then
			surface.SetDrawColor( CS16.Colors.Gold )
			surface.DrawRect( 0, 0, w, h )
		else
			surface.SetDrawColor( CS16.Colors.Amber )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		end

		CS16.DrawText( CS16.Upper( ("%d %s"):format( number, label() ) ), "CS16.MenuItem",
			12 * s, h * 0.5 - 9 * s,
			on and CS16.Colors.Panel or CS16.Colors.Amber, TEXT_ALIGN_LEFT )
	end

	btn.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )
		onClick()
	end

	btn.CS16Number = number
	btn.CS16Action = onClick

	return btn
end

--[[
	The framed box on the right, which 1.6 fills with a picture of the class.

	Ours holds a live model instead, so the preview is the character you will
	actually spawn as rather than a photograph of somebody else's. Callers put
	whatever they like inside it; this only draws the frame and hands back the
	rectangle.
]]
function CS16.Menu.PanelRect( frame )
	local s = frame.Scale
	local d = CS16.Menu.Design

	return d.PanelX * s, d.PanelY * s, d.PanelW * s, d.PanelH * s
end

function CS16.Menu.DrawPanelFrame( frame, pw, ph )
	local x, y, w, h = CS16.Menu.PanelRect( frame )

	surface.SetDrawColor( CS16.Colors.Amber )
	surface.DrawOutlinedRect( x, y, w, h, 1 )
end

--[[
	Number keys, the way 1.6 drives these menus.

	Bound on the frame rather than through the input library, because it only
	applies while the menu is up and dies with it. 0 closes, matching 1.6's
	"0 Cancel".
]]
function CS16.Menu.BindNumbers( frame, buttons, onCancel )
	frame.OnKeyCodePressed = function( self, key )
		--[[
			Not while somebody is typing.

			These menus take the keyboard, but so does the chat box, and a
			player who opens chat over an open menu is typing digits that would
			otherwise be spending their money.

			Matched on the base VGUI class, which is what GetClassName reports:
			a text field answers "TextEntry". Testing for a GetText method
			instead catches labels and buttons as well, which blocks every
			number key on the menu and stops it working at all.
		]]
		local focus = vgui.GetKeyboardFocus()

		if IsValid( focus ) and focus ~= self
			and focus.GetClassName and focus:GetClassName() == "TextEntry" then
			return
		end

		if key == KEY_0 or key == KEY_PAD_0 then
			if onCancel then onCancel() end
			return
		end

		for _, btn in ipairs( buttons ) do
			--[[
				Only single digits. A list can run past nine - the rifles are
				twelve entries for a developer - and KEY_0 plus ten is not the
				ten key, it is A. Without this the tenth rifle would answer to a
				letter nobody pressed on purpose.
			]]
			if btn.CS16Number >= 1 and btn.CS16Number <= 9
				and ( key == KEY_0 + btn.CS16Number or key == KEY_PAD_0 + btn.CS16Number ) then
				surface.PlaySound( "buttons/button14.wav" )
				btn.CS16Action()
				return
			end
		end
	end

	frame:SetKeyboardInputEnabled( true )
	frame:RequestFocus()
end

--[[
	Fit a model inside a panel, whatever shape either of them is.

	The class screen frames a standing figure in a wide box and only has to
	worry about height. A weapon is the opposite problem: long, thin, and turning,
	so the widest it ever gets is the larger of its two horizontal extents rather
	than whichever one happens to face the camera at the moment it is measured.

	Both axes are solved and the further of the two distances wins, which is
	what makes the same routine correct for a pistol in a letterbox and a rifle
	in a square.

	Bounds come from GetRenderBounds rather than GetModelBounds, because the
	weapon pack's pickup models report zero for GetModelBounds, OBBMins and
	GetModelRadius alike - a camera framed on those sits at the origin looking
	at the origin, and the box comes out empty. GetRenderBounds answers for
	both those models and the player models, so it is the one to ask.

	Render bounds are padded past the mesh so nothing pops out of view when a
	limb swings, which is why the margin sits below 1.
]]
function CS16.Menu.FitModel( panel, fov, margin )
	local ent = panel.Entity
	if not IsValid( ent ) then return end

	local mins, maxs = ent:GetRenderBounds()

	-- Degenerate bounds would divide the camera distance down to nothing.
	if not mins or not maxs or mins:Distance( maxs ) < 0.01 then
		mins, maxs = ent:GetModelBounds()
	end

	if not mins or not maxs or mins:Distance( maxs ) < 0.01 then return end

	local w, h = panel:GetSize()
	if not w or w <= 0 or not h or h <= 0 then return end

	--[[
		Measured after the model has been turned, not before.

		The caller may have tipped it to face the camera, and a weapon is nearly
		flat: forty-seven units long and two thick. Framing the untouched box
		would fit the two rather than the thirty-six it actually presents once
		it is stood up, and the gun would run out of the panel top and bottom.

		Eight corners rotated and re-bounded is exact, and eight of anything is
		cheap when it happens once per selection.
	]]
	local ang = ent:GetAngles()
	local rl, rh

	for i = 0, 7 do
		local corner = Vector(
			( i % 2 < 1 ) and mins.x or maxs.x,
			( i % 4 < 2 ) and mins.y or maxs.y,
			( i % 8 < 4 ) and mins.z or maxs.z )

		corner:Rotate( ang )

		if not rl then rl, rh = Vector( corner ), Vector( corner ) end

		rl.x = math.min( rl.x, corner.x ) rh.x = math.max( rh.x, corner.x )
		rl.y = math.min( rl.y, corner.y ) rh.y = math.max( rh.y, corner.y )
		rl.z = math.min( rl.z, corner.z ) rh.z = math.max( rh.z, corner.z )
	end

	local size   = rh - rl
	local centre = ( rh + rl ) * 0.5

	local halfH = math.tan( math.rad( fov ) * 0.5 )
	local halfV = halfH * ( h / w )

	-- The camera looks down -X, so Y is across the screen and Z is up it.
	local dist = math.max( ( size.y * 0.5 ) / halfH, ( size.z * 0.5 ) / halfV )

	panel:SetCamPos( centre + Vector( dist * ( margin or 1 ), 0, 0 ) )
	panel:SetLookAt( centre )
end
