--[[
	Chat, as 1.6 did it.

	Counter-Strike never had a chat *box*. No panel, no border, no filter
	button, no scrollbar - just lines of coloured text over the world and a
	yellow "Say :" prompt while you type. Restyling Garry's Mod's chatbox can't
	get there, because the panel furniture is the thing being objected to, so
	this replaces it outright:

	  - CHudChat is hidden, taking the panel with it
	  - chat.AddText is redirected into our own log
	  - StartChat returns true, so we own the input line as well

	The one thing not copied is 1.6 putting the prompt in the top left. It sits
	bottom left here, where Garry's Mod players expect it.
]]

local MARGIN     = 28
local LINE_H     = 19
local MAX_LINES  = 10
local LIFETIME   = 12
local FADE       = 2
local BOTTOM_GAP = 220 -- clear of the health and ammo readouts

local COLOUR_TEXT   = Color( 235, 235, 235 )
local COLOUR_DEAD   = Color( 160, 160, 160 )
local COLOUR_PROMPT = Color( 255, 215, 0 )

local log   = {}
local panel, entry
local open  = false

--[[ Log ]]

local function AddLine( parts )
	log[ #log + 1 ] = { parts = parts, time = CurTime() }

	while #log > MAX_LINES do table.remove( log, 1 ) end
end

--[[
	Everything that would have gone to the chatbox comes through here instead.
	Other addons calling chat.AddText keep working; they just land in our log.
]]
chat.AddText = function( ... )
	AddLine( { ... } )
end

local function TeamLabel( teamID )
	if teamID == TEAM_T then return "Terrorist" end
	if teamID == TEAM_CT then return "Counter-Terrorist" end
	return "Spectator"
end

hook.Add( "OnPlayerChat", "CS16.Chat", function( ply, text, teamChat, isDead )
	if not IsValid( ply ) then return end

	local colour = CS16.TeamColors[ ply:Team() ] or COLOUR_TEXT
	local parts  = {}

	if isDead then
		parts[ #parts + 1 ] = COLOUR_DEAD
		parts[ #parts + 1 ] = "*DEAD* "
	end

	if teamChat then
		parts[ #parts + 1 ] = colour
		parts[ #parts + 1 ] = "(" .. TeamLabel( ply:Team() ) .. ") "
	end

	parts[ #parts + 1 ] = colour
	parts[ #parts + 1 ] = ply:Nick()
	parts[ #parts + 1 ] = COLOUR_TEXT
	parts[ #parts + 1 ] = " : " .. text

	AddLine( parts )
	return true
end )

-- Joins, disconnects, server messages and anything sent with ChatPrint.
hook.Add( "ChatText", "CS16.ChatText", function( index, name, text, msgType )
	AddLine( { COLOUR_TEXT, text } )
	return true
end )

--[[ Drawing ]]

local function DrawParts( parts, x, y, alpha )
	surface.SetFont( "CS16.Text" )

	local colour = COLOUR_TEXT

	for _, part in ipairs( parts ) do
		if IsColor( part ) then
			colour = part
		else
			local str = tostring( part )

			surface.SetTextColor( 0, 0, 0, alpha )
			surface.SetTextPos( x + 1, y + 1 )
			surface.DrawText( str )

			surface.SetTextColor( colour.r, colour.g, colour.b, alpha )
			surface.SetTextPos( x, y )
			surface.DrawText( str )

			x = x + surface.GetTextSize( str )
		end
	end
end

hook.Add( "HUDPaint", "CS16.ChatDraw", function()
	local now    = CurTime()
	local bottom = ScrH() - BOTTOM_GAP

	-- Oldest first, drawn upward from the prompt line.
	for i = #log, 1, -1 do
		local line = log[ i ]
		local age  = now - line.time

		-- While typing, everything stays fully visible - same as 1.6.
		local alpha = 255

		if not open then
			if age > LIFETIME + FADE then continue end
			if age > LIFETIME then
				alpha = 255 * ( 1 - ( age - LIFETIME ) / FADE )
			end
		end

		local y = bottom - ( #log - i + 1 ) * LINE_H
		DrawParts( line.parts, MARGIN, y, math.Clamp( alpha, 0, 255 ) )
	end
end )

--[[ Input ]]

local function CloseChat()
	if IsValid( panel ) then panel:Remove() end

	panel, entry = nil, nil
	open = false

	-- cl_input watches this to stop menu keys firing while you type. Set here
	-- as well as from the hook, because we own the lifecycle now and a stuck
	-- flag would silently disable B and M.
	CS16.ChatOpen = false
end

local function OpenChat( teamChat )
	CloseChat()

	open = true

	-- Set both ways round for the same reason CloseChat does: we own this
	-- lifecycle, so nothing else is guaranteed to fire.
	CS16.ChatOpen = true

	local prompt = teamChat and "Say Team :" or "Say :"

	surface.SetFont( "CS16.Text" )
	local promptW = surface.GetTextSize( prompt .. " " )

	panel = vgui.Create( "EditablePanel" )
	panel:SetSize( ScrW(), ScrH() )
	panel:SetPos( 0, 0 )
	panel:MakePopup()
	panel:SetKeyboardInputEnabled( true )
	panel:SetMouseInputEnabled( false )

	-- The panel itself is invisible; it exists to hold keyboard focus and to
	-- draw the prompt beside the entry.
	panel.Paint = function()
		CS16.DrawText( prompt, "CS16.Text", MARGIN, ScrH() - BOTTOM_GAP + 2,
			COLOUR_PROMPT, TEXT_ALIGN_LEFT )
	end

	entry = panel:Add( "DTextEntry" )
	entry:SetPos( MARGIN + promptW, ScrH() - BOTTOM_GAP )
	entry:SetSize( ScrW() - MARGIN * 2 - promptW, LINE_H + 4 )
	entry:SetFont( "CS16.Text" )
	entry:RequestFocus()

	-- Painting the text ourselves and nothing else is what strips the box,
	-- border and highlight - there is no background left to hide.
	entry.Paint = function( self, w, h )
		self:DrawTextEntryText( COLOUR_TEXT, CS16.Colors.Hover, COLOUR_PROMPT )
	end

	entry.OnEnter = function( self )
		local text = string.Trim( self:GetValue() or "" )

		if text ~= "" then
			RunConsoleCommand( teamChat and "say_team" or "say", text )
		end

		CloseChat()
	end

	-- DTextEntry swallows escape, so close on it explicitly.
	entry.OnKeyCodePressed = function( self, code )
		if code == KEY_ESCAPE then
			CloseChat()
			return true
		end
	end

	--[[
		And escape at the panel too, which is not belt and braces.

		The handler above only ever runs while the entry holds the keyboard
		focus, and losing that focus is exactly the state this needs an exit
		from. The panel keeps the keyboard whatever the entry is doing, so it
		can always be heard.
	]]
	panel.OnKeyCodePressed = function( self, code )
		if code == KEY_ESCAPE then
			CloseChat()
			return true
		end
	end

	--[[
		Make sure the focus actually landed, and let go entirely if it never
		does.

		RequestFocus above is asked once, and whether it takes depends on what
		else is being created or destroyed in the same frame. When it does not,
		everything looks right and nothing works: the prompt draws, the panel
		holds the keyboard so the engine's own chat stays suppressed - StartChat
		returned true - and the entry hears neither the typing nor the escape.
		That is the "stuck in the chatbox" nobody could reproduce, and it would
		be intermittent exactly like this.

		Asking each frame removes the race. The give-up is the important half:
		a chat box that cannot be typed into or closed is worse than no chat
		box, so after about a second and a half of never having held focus it
		closes itself and hands the keyboard back.

		Once focus has landed even once this stops watching, so nobody gets the
		box shut on them mid-sentence for looking at something else.
	]]
	local tries, everFocused = 0, false

	panel.Think = function( self )
		if not IsValid( entry ) or everFocused then return end

		if entry:HasFocus() then
			everFocused = true
			return
		end

		if tries < 90 then
			tries = tries + 1
			entry:RequestFocus()
			return
		end

		CloseChat()
	end

	-- Keep anything listening to the typed text in the loop.
	entry.OnChange = function( self )
		hook.Run( "ChatTextChanged", self:GetValue() )
	end
end

--[[
	The flag must never outlive the panel.

	cl_input reads CS16.ChatOpen to keep B and M from firing while you type, so
	if the panel goes away by any route that isn't CloseChat - removed by
	something else, lost across a state change - the flag sticks and the buy and
	team menus quietly stop opening for the rest of the map. There is nothing on
	screen to explain that, and nothing a player can do about it.
]]
hook.Add( "Think", "CS16.ChatFlagGuard", function()
	if CS16.ChatOpen and not IsValid( panel ) then
		CS16.ChatOpen = false
		open = false
	end
end )

function GM:StartChat( teamChat )
	OpenChat( teamChat )
	return true
end

function GM:FinishChat()
	CloseChat()
	return true
end

function GM:ChatTextChanged() end
