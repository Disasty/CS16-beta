--[[
	The buy menu, in the frame 1.6 puts it in.

	Two pages. The top level lists the categories under a "shop by category"
	heading; a category lists what you can buy in it, with the thing itself
	turning on the right and its price and description underneath. 0 goes back a
	level, and back again closes.

	It wears cl_menuframe.lua, the same frame as Select Team, Choose A Class and
	the battle royale picker, which is what makes four screens read as one menu
	rather than four.

	1.6 fills the panel on the right with a rendered picture of the gun. Those
	are Valve's and are not ours to ship, and they would be the wrong guns
	anyway - the picture would be of Valve's model and ours are the pack's. So
	it holds the actual thing you are about to buy, turning, the same way the
	class screen holds the character you are about to become.

	Driven by the number keys as 1.6's was, or by the mouse. Both routes go
	through the same Choose(), so they cannot disagree about what a number
	means.
]]

--[[ Layout, in the design units cl_menuframe scales. ]]

local HEADING_Y = 178

--[[
	Cancel sits far lower here than on the join menus.

	Those have four or five rows and a gap before the odd one out, so the frame
	puts their footer at 582. The buy menu has eight categories and up to twelve
	rifles, and 1.6 drops its cancel to the bottom of the panel to make room.
	Using the join menus' figure squeezed eight categories into the space four
	were drawn for.
]]
local FOOTER_Y = 832

--[[
	The preview box is a letterbox rather than the tall panel the class screen
	uses. A rifle is long and thin: given a square it would sit in the middle of
	a great deal of nothing.
]]
local PREVIEW = { x = 505, y = 213, w = 675, h = 185 }

-- Where price and description start, and where their values line up.
local TEXT_Y     = 436
local LABEL_X    = 530
local VALUE_X    = 850
local LINE_STEP  = 30

local PREVIEW_FOV = 40

--[[
	How a weapon is held in the preview box.

	These lie flat: forty-seven units long, thirty-six across, two thick. A
	level camera sees the two, which is a dark line. Pitching brings the broad
	face round to the front, and the yaw points the barrel down and to the
	right, the way 1.6's pictures do.

	The models do not agree with each other about which way is forward, so each
	one that needs it gets its own entry below. Everything else takes the
	default.

	These were dialled in by eye against the real thing rather than worked out,
	which is why they look arbitrary. They are.
]]
local PREVIEW_ANGLE  = Angle( -90, 180, 0 )
local PREVIEW_MARGIN = 0.92

--[[
	Every one that needed dialling in, and how far back the camera sits for it.

	Tuned by eye against the real thing rather than worked out, because these
	models disagree with each other about which way is forward and by how much.
	An entry left out takes the default above, which suits most of the rifles.

	Zoom is a camera distance multiplier: below 1 is closer, so 0.50 fills the
	box with a pistol that would otherwise sit in the middle of it.
]]
local PREVIEW_ANGLES = {
	-- Pistols
	glock18    = { ang = Angle(  162,  -85, -87 ), zoom = 0.59 },
	usp        = { ang = Angle( -153,  -85, -87 ), zoom = 0.50 },
	p228       = { ang = Angle( -150,  -91, -91 ), zoom = 0.50 },
	deagle     = { ang = Angle(  162, -101, -81 ), zoom = 0.55 },
	fiveseven  = { ang = Angle( -139,  -90, -90 ), zoom = 0.81 },
	elite      = { ang = Angle(  162,  -91, -91 ), zoom = 0.62 },
	python     = { ang = Angle(  101,   88, -91 ), zoom = 0.76 },

	-- Shotguns
	m3         = { ang = Angle(  147,  -91, -91 ), zoom = 0.50 },
	xm1014     = { ang = Angle(   -6,   90, -91 ) },
	sawn       = { ang = Angle(   75,  -91, -91 ), zoom = 0.65 },

	-- Sub-machine guns
	tmp        = { ang = Angle(  137,  -91, -91 ), zoom = 0.50 },
	mac10      = { ang = Angle(    0,   89, -91 ), zoom = 1.11 },
	mp5navy    = { ang = Angle(   97,   89, -91 ), zoom = 0.83 },
	ump45      = { ang = Angle( -158,  -91, -91 ), zoom = 0.58 },
	p90        = { ang = Angle(  148,  -91, -91 ), zoom = 0.50 },

	-- Rifles
	galil      = { ang = Angle(  -74,  -91, -91 ), zoom = 0.50 },
	famas      = { ang = Angle( -118,  -91, -91 ), zoom = 0.50 },
	ak47       = { ang = Angle(  167,  -91, -91 ), zoom = 0.62 },
	scout      = { ang = Angle( -160,  -91, -91 ), zoom = 0.50 },
	m4a1       = { ang = Angle( -145,  -91, -91 ), zoom = 0.50 },
	sg552      = { ang = Angle(  138,  -91, -92 ), zoom = 0.50 },
	aug        = { ang = Angle(  150,  -91, -91 ), zoom = 0.50 },
	sg550      = { ang = Angle(  155,  -91, -91 ), zoom = 0.50 },
	awp        = { ang = Angle(  164,  -91, -91 ), zoom = 0.50 },
	g3sg1      = { ang = Angle(  162,  -91, -91 ), zoom = 0.50 },
	asval      = { ang = Angle(  -27,   89, -91 ), zoom = 0.50 },
	winchester = { ang = Angle(  152,  -91, -91 ), zoom = 0.50 },

	-- Machine guns
	m249       = { ang = Angle(  175,  -91, -91 ), zoom = 0.81 },
	m135       = { ang = Angle(  160,  -91, -91 ), zoom = 0.50 },

	-- Explosives
	mgl        = { ang = Angle(   69,  -91, -91 ), zoom = 0.63 },
	law        = { ang = Angle(  162,  -91, -91 ), zoom = 0.50 },
	molotov    = { ang = Angle(  -90,  180,   0 ), zoom = 1.10 },
	flare      = { ang = Angle(  164,  -65, -15 ) },

	--[[
		The three thrown ones share a shape and so share a framing: the default
		turned about, and closer, because a grenade given a rifle's camera is a
		speck in the middle of a letterbox.
	]]
	flashbang  = { ang = Angle(  -90,    0,   0 ), zoom = 1.25 },
	hegrenade  = { ang = Angle(  -90,    0,   0 ), zoom = 1.25 },
	smoke      = { ang = Angle(  -90,    0,   0 ), zoom = 1.25 },

	-- Equipment
	nvg        = { ang = Angle(    0,    2,   0 ), zoom = 1.10 },
	defusekit  = { ang = Angle(   -5,  -91, -91 ) },
}

--[[
	How this item is held and how close the camera sits, falling back to the
	default for anything not tuned.
]]
local function PreviewFor( item )
	local entry = PREVIEW_ANGLES[ item.id ]
	if not entry then return PREVIEW_ANGLE, PREVIEW_MARGIN end

	return entry.ang or PREVIEW_ANGLE, entry.zoom or PREVIEW_MARGIN
end

--[[
	Where deriving a model name gets it wrong, or where there is no weapon to
	derive one from.

	Everything else follows from the SWEP: its WorldModel is the posed p_ model
	that sits in a player's hands, and the standalone pickup is the same name
	under models/cs16 with a w_ on it. These five are the exceptions. The pack
	calls the MP5's pickup w_mp3, the LAW's world model carries a suffix its
	pickup does not, and armour is not a weapon at all so there is nothing to
	ask - both vests show the same vest.
]]
local MODEL_OVERRIDE = {
	mp5navy    = "models/cs16/w_mp3.mdl",
	law        = "models/cs16/w_law.mdl",
	kevlar     = "models/cs16/w_kevlar.mdl",
	kevlarhelm = "models/cs16/w_kevlar.mdl",
	defusekit  = "models/cs16/w_thighpack.mdl",
}

local function PreviewModel( item )
	if MODEL_OVERRIDE[ item.id ] then return MODEL_OVERRIDE[ item.id ] end
	if not item.class then return nil end

	local stored = weapons.GetStored( item.class )
	if not stored or not stored.WorldModel then return nil end

	local guess = stored.WorldModel:gsub( "models/weapons/cs16/p_", "models/cs16/w_" )
	if file.Exists( guess, "GAME" ) then return guess end

	-- Better a posed model than an empty box.
	if file.Exists( stored.WorldModel, "GAME" ) then return stored.WorldModel end
end

--[[ State ]]

-- nil when closed, "root" at the top level, otherwise a category id.
local page

--[[
	Where a purchase returns you: "root" when opened with B, "equipment" when
	opened with O. Buying a grenade shouldn't throw you out to the categories
	when equipment is the menu you deliberately opened - you nearly always want
	a second one.
]]
local home

local frame

--[[ What is on each page ]]

--[[
	The top level, built from the catalogue rather than listed here.

	1.6's order is guns, then ammo, then equipment, and that falls out of
	walking the categories in order with equipment held back to the end. Doing
	it this way means a category only the developer team can see - explosives -
	appears in their menu and nobody else's without this file knowing which
	categories those are.

	Ammo isn't a set of things to browse, it's an action, so those two entries
	carry a slot to top up instead of a page to open.
]]
local function RootEntries()
	local teamID  = LocalPlayer():Team()
	local entries = {}
	local last

	for _, category in ipairs( CS16.BuyCategories ) do
		if CS16.CategoryAllowedForTeam( category, teamID ) then
			local entry = { label = category.name, category = category.id }

			if category.id == "equipment" then last = entry
			else entries[ #entries + 1 ] = entry end
		end
	end

	entries[ #entries + 1 ] = { label = CS16.L( "buy.primaryammo" ),   ammo = true }
	entries[ #entries + 1 ] = { label = CS16.L( "buy.secondaryammo" ), ammo = false }

	if last then entries[ #entries + 1 ] = last end

	return entries
end

local function CategoryById( id )
	for _, category in ipairs( CS16.BuyCategories ) do
		if category.id == id then return category end
	end
end

-- Only what this side may buy, so the numbering matches what's on screen.
local function VisibleItems( category )
	local ply     = LocalPlayer()
	local visible = {}

	for _, item in ipairs( category.items ) do
		if CS16.ItemAllowedForTeam( item, ply:Team() ) then
			visible[ #visible + 1 ] = item
		end
	end

	return visible
end

--[[
	1.6 says which slot a category fills: "Buy Shotguns (primary weapon)".

	Read off what is in the category rather than declared on it, so adding a
	weapon to the shop stays a one-line change. Only the two slots that can hold
	one thing at a time are worth saying: nobody needs telling that the grenades
	are grenades.
]]
local function CategorySuffix( category )
	local kind = category.items[ 1 ] and category.items[ 1 ].kind

	if kind ~= "primary" and kind ~= "secondary" then return "" end

	return " (" .. CS16.L( "buy.kind." .. kind ) .. ")"
end

--[[ Buying ]]

local function BuyAmmo( primary )
	net.Start( "CS16.BuyAmmo" )
		net.WriteBool( primary )
	net.SendToServer()
end

local Build -- defined below; Choose rebuilds the page it lands on

local function Choose( index )
	--[[
		0 steps back a level, and closes from whichever page you opened on.
		Opening with O means equipment *is* the top level, so 0 closes from
		there rather than dropping you somewhere you never asked to be.
	]]
	if index == 0 then
		if page == home then CS16.CloseBuyMenu() else page = "root" Build() end
		return
	end

	if page == "root" then
		local entry = RootEntries()[ index ]
		if not entry then return end

		surface.PlaySound( "buttons/button14.wav" )

		if entry.category then
			page = entry.category
			Build()
		else
			BuyAmmo( entry.ammo )
		end

		return
	end

	local category = CategoryById( page )
	if not category then return end

	local item = VisibleItems( category )[ index ]
	if not item then return end

	surface.PlaySound( "buttons/button14.wav" )

	net.Start( "CS16.Buy" )
		net.WriteString( item.id )
	net.SendToServer()

	--[[
		Back to wherever this menu started, as 1.6 did. From B that's the
		categories, which is what makes a full buy a handful of keystrokes; from
		O it's equipment, so a flash and a smoke are two keys and not six.
	]]
	page = home
	Build()
end

--[[ Drawing ]]

--[[
	The list has to fit between the first row and the cancel button, and a
	category can be longer than the frame's standard pitch allows: the rifles
	are twelve entries for a developer against the eight that pitch was drawn
	for. Rather than overflow, the pitch tightens until they fit.
]]
local function Pitch( count, d )
	local span    = FOOTER_Y - d.ListY - d.ButtonGap
	local natural = d.ButtonH + d.ButtonGap

	if count <= 1 then return natural end

	return math.min( natural, span / count )
end

local function AddPreview( item )
	local model = PreviewModel( item )
	if not model then return nil end

	local s = frame.Scale

	local mdl = frame:Add( "DModelPanel" )
	mdl:SetPos( PREVIEW.x * s + 1, PREVIEW.y * s + 1 )
	mdl:SetSize( PREVIEW.w * s - 2, PREVIEW.h * s - 2 )
	mdl:SetMouseInputEnabled( false )
	mdl:SetFOV( PREVIEW_FOV )
	mdl:SetModel( model )

	--[[
		Turned before it is measured, not after.

		FitModel reads the angles off the entity, and LayoutEntity does not run
		until the panel first paints - so fitting here without setting them
		first measures the model lying flat, decides it is two units tall, and
		puts the camera close enough to crop a rifle in half.
	]]
	local ang, zoom = PreviewFor( item )

	if IsValid( mdl.Entity ) then mdl.Entity:SetAngles( ang ) end

	CS16.Menu.FitModel( mdl, PREVIEW_FOV, zoom )

	--[[
		Held at an angle rather than turned.

		These models are almost flat - a rifle measures forty-seven units long
		and two deep - so a model left spinning presents its edge twice a
		revolution and briefly disappears. 1.6 shows a still picture at three
		quarters, which is the view that reads as a gun, so it is held there.
	]]
	mdl.LayoutEntity = function( self, ent )
		ent:SetAngles( ang )
	end

	return mdl
end


--[[ Pages ]]

local function BuildRoot()
	local s, d   = frame.Scale, CS16.Menu.Design
	local entries = RootEntries()

	local basePaint = frame.Paint

	frame.Paint = function( self, pw, ph )
		basePaint( self, pw, ph )

		CS16.DrawText( CS16.Upper( CS16.L( "buy.shopbycategory" ) ), "CS16.MenuItem",
			d.ListX * s, HEADING_Y * s, CS16.Colors.Amber, TEXT_ALIGN_LEFT )
	end

	local buttons = {}
	local pitch   = Pitch( #entries, d )

	for i, entry in ipairs( entries ) do
		buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, i,
			function() return entry.label end,
			( d.ListY * s ) + ( i - 1 ) * pitch * s,
			function() return false end,
			function() Choose( i ) end )
	end

	buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, 0,
		function() return CS16.L( "buy.cancel" ) end, FOOTER_Y * s,
		function() return false end,
		function() Choose( 0 ) end )

	CS16.Menu.BindNumbers( frame, buttons, function() Choose( 0 ) end )
end

local function BuildCategory( category )
	local s, d = frame.Scale, CS16.Menu.Design
	local items = VisibleItems( category )

	local selected = 1
	local preview

	local function Show( i )
		selected = i

		if IsValid( preview ) then preview:Remove() end
		preview = AddPreview( items[ i ] )
	end

	local basePaint = frame.Paint

	frame.Paint = function( self, pw, ph )
		basePaint( self, pw, ph )

		-- The box the model sits in, drawn whether or not there is a model.
		surface.SetDrawColor( CS16.Colors.Amber )
		surface.DrawOutlinedRect( PREVIEW.x * s, PREVIEW.y * s, PREVIEW.w * s, PREVIEW.h * s, 1 )

		local item = items[ selected ]
		if not item then return end

		local y = TEXT_Y * s

		local function Row( label, value )
			CS16.DrawText( CS16.Upper( label ), "CS16.MenuBody", LABEL_X * s, y,
				CS16.Colors.Amber, TEXT_ALIGN_LEFT )
			CS16.DrawText( ": " .. value, "CS16.MenuBody", VALUE_X * s, y,
				CS16.Colors.Gold, TEXT_ALIGN_LEFT )
			y = y + LINE_STEP * s
		end

		--[[
			A developer weapon costs nothing, and "$0" reads like a bug rather
			than like a thing the shop is giving away.
		]]
		Row( CS16.L( "buy.price" ),
			item.price > 0 and ( "$" .. item.price ) or CS16.L( "buy.free" ) )

		--[[
			The real designation, because the 1.6 codenames are cryptic if you
			did not grow up with them: "CV-47" tells you nothing, "AK-47" tells
			you everything.

			Guns only. On a grenade or a vest the same field carries a note
			rather than a name - "Max 2", "100 armour" - and a flashbang listed
			as also being known as "Max 2" reads like a mistake. The description
			says those things properly.
		]]
		if item.real and ( item.kind == "primary" or item.kind == "secondary" ) then
			Row( CS16.L( "buy.realname" ), item.real )
		end

		-- Wrapped, because a translated line is a different length from the
		-- English one and no hand-placed break survives that.
		local desc = CS16.L( "buy." .. item.id .. ".desc" )

		if desc ~= "buy." .. item.id .. ".desc" then
			CS16.DrawText( CS16.Upper( CS16.L( "buy.description" ) ), "CS16.MenuBody",
				LABEL_X * s, y, CS16.Colors.Amber, TEXT_ALIGN_LEFT )

			local wrap = ( PREVIEW.x + PREVIEW.w - VALUE_X ) * s

			for n, line in ipairs( CS16.WrapText( desc, "CS16.MenuBody", wrap ) ) do
				CS16.DrawText( ( n == 1 and ": " or "  " ) .. line, "CS16.MenuBody",
					VALUE_X * s, y, CS16.Colors.Gold, TEXT_ALIGN_LEFT )
				y = y + LINE_STEP * s
			end
		end
	end

	local buttons = {}
	local pitch   = Pitch( #items, d )

	for i, item in ipairs( items ) do
		buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, i,
			function() return item.name end,
			( d.ListY * s ) + ( i - 1 ) * pitch * s,
			function() return selected == i end,
			function()
				--[[
					First press shows it, second buys it. 1.6 buys on the first
					press, but 1.6 shows a picture that never changes; ours shows
					the thing itself and it would be a waste never to let anyone
					look at it before spending on it.
				]]
				if selected ~= i then Show( i ) return end
				Choose( i )
			end )
	end

	buttons[ #buttons + 1 ] = CS16.Menu.Button( frame, 0,
		function() return CS16.L( "buy.cancel" ) end, FOOTER_Y * s,
		function() return false end,
		function() Choose( 0 ) end )

	if items[ 1 ] then Show( 1 ) end

	CS16.Menu.BindNumbers( frame, buttons, function() Choose( 0 ) end )
end

--[[
	Rebuild for whatever page is current.

	The frame is thrown away and remade rather than edited, because the two
	pages have different contents and different paint, and a panel that has been
	half converted from one to the other is a worse thing to debug than one that
	is simply built again.
]]
function Build()
	if IsValid( frame ) then frame:Remove() end
	if not page then return end

	local category = page ~= "root" and CategoryById( page ) or nil

	--[[
		The title carries the category on a category page, the way 1.6's does:
		"Buy Shotguns (primary weapon)". Passed as a function because it needs a
		value substituted, which a bare key cannot carry.
	]]
	frame = CS16.Menu.Frame( category and function()
		return CS16.L( "buy.title.category", { category = category.name } )
			.. CategorySuffix( category )
	end or "buy.title" )

	CS16.BuyFrame = frame

	if category then BuildCategory( category ) else BuildRoot() end
end

--[[ Opening and closing ]]

function CS16.BuyMenuOpen()
	return page ~= nil
end

function CS16.CloseBuyMenu()
	page, home = nil, nil

	if IsValid( frame ) then frame:Remove() end
	frame = nil
	CS16.BuyFrame = nil
end

function CS16.OpenBuyMenu( startPage )
	local allowed, reason = CS16.CanBuy( LocalPlayer() )

	if not allowed then
		chat.AddText( CS16.Colors.Gold, "[CS 1.6] ", CS16.Colors.White, reason )
		return
	end

	home = startPage or "root"
	page = home

	Build()
end

function CS16.ToggleBuyMenu()
	if CS16.BuyMenuOpen() then CS16.CloseBuyMenu() else CS16.OpenBuyMenu() end
end

--[[
	Buy time running out closes it, rather than leaving a menu open that can no
	longer spend anything. Checked on a timer rather than every frame: this is a
	once-a-round event and the menu is usually shut.
]]
timer.Create( "CS16.BuyMenuGuard", 0.5, 0, function()
	if not CS16.BuyMenuOpen() then return end
	if not IsValid( LocalPlayer() ) then return end

	if not CS16.CanBuy( LocalPlayer() ) then CS16.CloseBuyMenu() end
end )

--[[ Input ]]

concommand.Add( "cs16_buymenu", CS16.ToggleBuyMenu )

CS16.WatchKey( "buymenu", KEY_B, function()
	if not CS16.BuyMenuOpen() then CS16.OpenBuyMenu() return end

	--[[
		From the equipment menu, B is how you reach the full buy menu rather
		than a second key that closes it. O is what closes equipment.
	]]
	if home == "equipment" then
		home, page = "root", "root"
		Build()
		return
	end

	CS16.CloseBuyMenu()
end )

-- 1.6's shortcut straight to equipment, and the key that closes it again.
CS16.WatchKey( "buyequipment", KEY_O, function()
	if CS16.BuyMenuOpen() and home == "equipment" then
		CS16.CloseBuyMenu()
		return
	end

	if CS16.BuyMenuOpen() then
		home, page = "equipment", "equipment"
		Build()
		return
	end

	CS16.OpenBuyMenu( "equipment" )
end )

-- , tops up your primary and . your secondary, without opening anything.
CS16.WatchKey( "buyammoprimary",   KEY_COMMA,  function() BuyAmmo( true ) end )
CS16.WatchKey( "buyammosecondary", KEY_PERIOD, function() BuyAmmo( false ) end )

-- Quiet prompt so players know buying is available without opening anything.
hook.Add( "HUDPaint", "CS16.BuyPrompt", function()
	if CS16.BuyMenuOpen() then return end
	if not CS16.CanBuy( LocalPlayer() ) then return end

	CS16.DrawText( CS16.L( "buy.prompt" ), "CS16.Text", ScrW() * 0.5, ScrH() - 96,
		CS16.Colors.Muted, TEXT_ALIGN_CENTER )
end )
