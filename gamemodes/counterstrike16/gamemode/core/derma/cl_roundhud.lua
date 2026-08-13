--[[
	Round furniture: the clock and score at the top, money top-right, and the
	centre banner that announces the result.
]]

local TIMER_W, TIMER_H = 240, 42

-- Round announcements: played flat rather than positioned in the world.
net.Receive( "CS16.Sound", function()
	surface.PlaySound( net.ReadString() )
end )

local function DrawTimer()
	local x = ( ScrW() - TIMER_W ) * 0.5
	local y = 12

	CS16.DrawPanel( x, y, TIMER_W, TIMER_H )

	local state = CS16.GetRoundState()
	local timeText, timeCol

	if CS16.IsBombPlanted() then
		-- The bomb clock replaces the round clock the moment it goes down.
		timeText = CS16.FormatTime( CS16.GetBombRemaining() )
		timeCol  = CS16.Colors.Danger
	elseif state == ROUND_WARMUP then
		--[[
			Warmup usually has no clock and says so. Battle royale's start
			countdown runs in warmup and is a real one, so show it when there is
			something to show - a countdown nobody can see is just a wait.
		]]
		if CS16.GetPhaseEnd() > 0 then
			local remaining = CS16.GetPhaseRemaining()

			timeText = CS16.FormatTime( remaining )
			timeCol  = remaining <= 10 and CS16.Colors.Danger or CS16.Colors.Gold
		else
			timeText, timeCol = "--:--", CS16.Colors.Muted
		end
	else
		local remaining = CS16.GetPhaseRemaining()
		timeText = CS16.FormatTime( remaining )

		-- The clock turns red under ten seconds, as it did in 1.6.
		timeCol = ( state == ROUND_LIVE and remaining <= 10 )
			and CS16.Colors.Danger or CS16.Colors.Gold
	end

	CS16.DrawText( timeText, "CS16.Title", x + TIMER_W * 0.5, y + 9, timeCol, TEXT_ALIGN_CENTER )

	-- Scores flank the clock, coloured by side.
	CS16.DrawText( CS16.GetScore( TEAM_T ), "CS16.Title", x + 26, y + 9,
		CS16.Colors.T, TEXT_ALIGN_CENTER )
	CS16.DrawText( CS16.GetScore( TEAM_CT ), "CS16.Title", x + TIMER_W - 26, y + 9,
		CS16.Colors.CT, TEXT_ALIGN_CENTER )

	--[[
		Nothing for warmup here on purpose. The banner in the middle of the
		screen already says WAITING FOR PLAYERS, and a clock reading --:-- says
		the round isn't running either - three separate things telling you the
		same fact. The states below have no banner of their own, so this is
		where they're announced.
	]]
	local label
	if CS16.IsBombPlanted() then
		label = "BOMB PLANTED"
	elseif state == ROUND_FREEZE then
		label = "GET READY"
	elseif state == ROUND_HALFTIME then
		label = ( CS16.GetOvertime() > 0 ) and "OVERTIME NEXT" or "HALFTIME"
	end

	if label then
		-- A planted bomb is the one thing here worth shouting about.
		local labelCol = CS16.IsBombPlanted() and CS16.Colors.Danger or CS16.Colors.Muted

		CS16.DrawText( label, "CS16.Small", x + TIMER_W * 0.5, y + TIMER_H + 4,
			labelCol, TEXT_ALIGN_CENTER )
	end
end

--[[
	How the rescue is going, on the maps that have one.

	Read from the replicated count rather than from CS16.IsHostageMap, because
	the authored hostage positions are only sent to developers - the count is a
	global, so it reaches everybody for free. A map with no hostages never sets
	it, reads zero, and draws nothing, the same way the bomb readout stays quiet
	on a map with no bomb.
]]
local function DrawHostages()
	local total = GetGlobalInt( "CS16.HostagesTotal", 0 )
	if total == 0 then return end

	local rescued = GetGlobalInt( "CS16.HostagesRescued", 0 )
	local x = ScrW() * 0.5
	local y = 12 + TIMER_H + 4

	-- Shifted down when the timer already has something to say, so the two
	-- lines never land on top of each other.
	local state = CS16.GetRoundState()
	if state == ROUND_FREEZE or state == ROUND_HALFTIME then y = y + 18 end

	CS16.DrawText( ("HOSTAGES  %d / %d"):format( rescued, total ), "CS16.Small", x, y,
		rescued >= total and CS16.Colors.CT or CS16.Colors.Gold, TEXT_ALIGN_CENTER )
end

--[[
	The counterpart to the bomb-site hint: standing next to a hostage as a
	Counter-Terrorist is the one moment worth prompting for.
]]
local HINT_RANGE_SQR = 120 * 120

local function DrawHostageHint( ply )
	if not ply:Alive() or ply:Team() ~= TEAM_CT then return end

	local pos = ply:GetPos()

	for _, ent in ipairs( ents.FindByClass( "cs16_hostage" ) ) do
		if IsValid( ent ) and pos:DistToSqr( ent:GetPos() ) < HINT_RANGE_SQR then
			local text = ( ent:GetFollower() == ply )
				and "Press USE to leave the hostage here"
				or  "Press USE to move the hostage"

			CS16.DrawText( text, "CS16.Text", ScrW() * 0.5, ScrH() - 120,
				CS16.Colors.Gold, TEXT_ALIGN_CENTER )
			return
		end
	end
end

--[[
	Money, in the same sprites as everything else.

	It was the last thing on screen still drawn in a font, and next to the health
	and ammo it read as though it had been pasted in from another game. The
	dollar sign is on the status sheet beside the cross and shield - see
	CS16.HUDIcons in cl_hud.

	Right-aligned to the margin, so the figure grows leftward and the last digit
	stays put as the numbers change.
]]
local function DrawMoney( ply )
	local scale = CS16.HUDScale()
	local money = CS16.GetMoney( ply )
	local icon  = CS16.HUDIcons.dollar
	local y     = 16

	local x = ScrW() - 24 - CS16.HUDNumberWidth( money, scale )
	CS16.DrawHUDNumber( money, x, y, scale, CS16.Colors.Gold )

	--[[
		The sign is nudged down by the difference in cell heights, so a 24-tall
		icon sits level with the 25-tall digits rather than a pixel proud of
		them. Same correction the health cross gets.
	]]
	CS16.DrawHUDSprite( icon, x - icon[ 3 ] * scale - 4 * scale,
		y + ( 25 - icon[ 4 ] ) * scale, scale, CS16.Colors.Gold )
end

local function DrawBanner( ply )
	--[[
		Nothing behind the team menu.

		The HUD is drawn under VGUI, always, so a banner sitting where a panel
		is renders as a sliver of text poking out from behind it - which is
		exactly the situation during warmup, when the menu is open by default.
		Better to say nothing than to say it through a panel.
	]]
	if IsValid( CS16.TeamMenu ) or IsValid( CS16.MOTD ) then return end

	local state = CS16.GetRoundState()
	local y     = ScrH() * 0.34

	--[[
		What happens after the result is read out.

		It used to say "Changing map" unconditionally, because every mode ended
		a match by reloading. Battle royale plays rounds in place now and only
		reloads once a set is done, so it said the map was changing five times
		out of six when it wasn't. The server is the only thing that knows which
		it is, so it says.

		Defaults to true, which keeps every other mode reading exactly as it did.
	]]
	local function EndingText()
		return GetGlobalBool( "CS16.MapChanging", true ) and "Changing map" or "Next round"
	end

	-- The match result outranks anything a round has to say.
	if CS16.MatchIsOver() then
		local winner = CS16.GetMatchWinner()

		--[[
			Some modes are won by a person rather than a side. Preferring the
			name when there is one lets this handle both without knowing which
			mode is running - the colour still comes from their team.
		]]
		local name = CS16.GetMatchWinnerName()

		if name ~= "" then
			CS16.DrawText( string.upper( name ) .. " WINS", "CS16.Title", ScrW() * 0.5, y,
				CS16.TeamColors[ winner ] or CS16.Colors.Gold, TEXT_ALIGN_CENTER )
			CS16.DrawText( EndingText(), "CS16.Text", ScrW() * 0.5, y + 26,
				CS16.Colors.Muted, TEXT_ALIGN_CENTER )
			return
		end

		local text, col
		if winner == TEAM_T then
			text, col = "TERRORISTS WIN THE MATCH", CS16.Colors.T
		elseif winner == TEAM_CT then
			text, col = "COUNTER-TERRORISTS WIN THE MATCH", CS16.Colors.CT
		else
			text, col = "MATCH DRAWN", CS16.Colors.Muted
		end

		CS16.DrawText( text, "CS16.Title", ScrW() * 0.5, y, col, TEXT_ALIGN_CENTER )
		CS16.DrawText( "Changing map", "CS16.Text", ScrW() * 0.5, y + 26,
			CS16.Colors.Muted, TEXT_ALIGN_CENTER )
		return
	end

	if state == ROUND_END then
		local winner = CS16.GetRoundWinner()

		local text, col
		if winner == TEAM_T then
			text, col = "TERRORISTS WIN", CS16.Colors.T
		elseif winner == TEAM_CT then
			text, col = "COUNTER-TERRORISTS WIN", CS16.Colors.CT
		else
			text, col = "ROUND DRAW", CS16.Colors.Muted
		end

		CS16.DrawText( text, "CS16.Title", ScrW() * 0.5, y, col, TEXT_ALIGN_CENTER )
		CS16.DrawText( CS16.GetRoundEndReason(), "CS16.Text", ScrW() * 0.5, y + 26,
			CS16.Colors.Muted, TEXT_ALIGN_CENTER )
		return
	end

	if state == ROUND_WARMUP then
		CS16.DrawText( "WAITING FOR PLAYERS", "CS16.Heading", ScrW() * 0.5, y,
			CS16.Colors.Muted, TEXT_ALIGN_CENTER )

		--[[
			And why, when the mode has said.

			"Waiting for players" on a server full of players is a dead end: the
			real answer is usually that the map has nothing authored onto it, and
			battle royale sets exactly that reason and had nowhere to put it. It
			cost an evening working out why vertigo never started.
		]]
		local reason = CS16.GetRoundEndReason()

		if reason and reason ~= "" and reason ~= "Waiting for players" then
			CS16.DrawText( reason, "CS16.Small", ScrW() * 0.5, y + 24,
				CS16.Colors.Gold, TEXT_ALIGN_CENTER )
		end

		return
	end

	-- Somebody is on the bomb. Worth shouting about: shoving them off it
	-- cancels the defuse outright.
	local defuser = CS16.GetDefuser()

	if IsValid( defuser ) then
		local label = ( defuser == ply ) and "DEFUSING"
			or ( defuser:Nick() .. " IS DEFUSING" )

		CS16.DrawText( label, "CS16.Heading", ScrW() * 0.5, y,
			CS16.Colors.CT, TEXT_ALIGN_CENTER )
		return
	end

	-- Dead players sit the round out, so tell them that rather than leaving
	-- them wondering why they aren't respawning.
	if not ply:Alive() and CS16.IsPlayingTeam( ply:Team() ) then
		CS16.DrawText( "WAITING FOR NEXT ROUND", "CS16.Heading", ScrW() * 0.5, y,
			CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	end
end

--[[
	The addon announces the bomb itself with its own centre-screen text, which
	landed directly on top of our round banner. Re-registering a net receiver
	replaces the addon's, so its announcement hooks are simply never added -
	no fork, and its defuse progress bar (BombDefuseStatus) is left alone.
]]
hook.Add( "Initialize", "CS16.SilenceAddonBombText", function()
	for _, message in ipairs( { "BombPlanted", "BombDefuse", "Bombexplode" } ) do
		net.Receive( message, function()
			net.ReadString() -- drained, then discarded
		end )
	end
end )

-- Standing on a site with the bomb is the one moment a prompt really helps.
local function DrawBombHint( ply )
	if CS16.IsBombPlanted() then return end
	if not ply:Alive() or ply:Team() ~= TEAM_T then return end
	if not ply:GetNWBool( "CS16.AtBombSite", false ) then return end
	if not ply:HasWeapon( "weapon_cs16_c4" ) then return end

	CS16.DrawText( "Bomb site - hold ATTACK with the C4 out to plant", "CS16.Text",
		ScrW() * 0.5, ScrH() - 120, CS16.Colors.Gold, TEXT_ALIGN_CENTER )
end

--[[
	Says so when a developer has stopped the game.

	Everybody sees it, not just the person who pressed it. Ten players frozen
	solid with a clock that has stopped and nothing on screen to explain it is
	indistinguishable from the server having died.
]]
local function DrawPaused()
	if not GetGlobalBool( "CS16.Paused", false ) then return end

	CS16.DrawText( "PAUSED", "CS16.Title", ScrW() * 0.5, ScrH() * 0.28,
		CS16.Colors.Gold, TEXT_ALIGN_CENTER )

	CS16.DrawText( "A developer has stopped the match", "CS16.Small",
		ScrW() * 0.5, ScrH() * 0.28 + 26, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "CS16.RoundHUD", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end

	DrawPaused()
	DrawTimer()
	DrawHostages()
	DrawBanner( ply )
	DrawBombHint( ply )
	DrawHostageHint( ply )

	if CS16.IsPlayingTeam( ply:Team() ) then
		DrawMoney( ply )
	end
end )
