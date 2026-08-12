--[[
	Money. Round rewards and kill rewards only for now - the buy menu is what
	will finally give it somewhere to go.
]]

function CS16.SetMoney( ply, amount )
	amount = math.Clamp( math.floor( amount ), 0, CS16.Config.Money.Max )
	ply:SetNWInt( "CS16.Money", amount )
end

function CS16.AddMoney( ply, amount )
	CS16.SetMoney( ply, CS16.GetMoney( ply ) + amount )
end

function CS16.CanAfford( ply, amount )
	return CS16.GetMoney( ply ) >= amount
end

function CS16.TakeMoney( ply, amount )
	if not CS16.CanAfford( ply, amount ) then return false end

	CS16.SetMoney( ply, CS16.GetMoney( ply ) - amount )
	return true
end

function CS16.ResetMoney( ply )
	CS16.SetMoney( ply, CS16.Config.Money.Start )
end

--[[
	Consecutive rounds lost, per side.

	Tracked against the side rather than the roster, so it resets when the sides
	swap - the people who are Terrorists after halftime are the ones who were
	just beating them, and handing them a losing side's accumulated bonus would
	be paying them for somebody else's bad half.
]]
local Streak = {}

--[[
	Nothing resets this at the start of a match, because a match ends by
	reloading the map - this file is loaded again and the table is new. The only
	reset that has to be explicit is halftime, below.
]]

-- Winners and losers both get paid; losing just pays less, and pays more the
-- longer it has been going on. See cfg.Money.LoseRound.
function CS16.AwardRoundMoney( winner )
	local money  = CS16.Config.Money
	local ladder = money.LoseRound

	--[[
		A draw counts as a loss for both sides. Nobody won it, so paying either
		of them a winner's round would be inventing a result.
	]]
	for _, side in ipairs( { TEAM_T, TEAM_CT } ) do
		if side == winner then
			Streak[ side ] = 0
		else
			Streak[ side ] = math.min( ( Streak[ side ] or 0 ) + 1, #ladder )
		end
	end

	for _, ply in ipairs( player.GetAll() ) do
		local side = ply:Team()
		if not CS16.IsPlayingTeam( side ) then continue end

		CS16.AddMoney( ply, side == winner
			and money.WinRound
			or  ladder[ math.max( Streak[ side ] or 1, 1 ) ] )
	end
end

-- Sides swap, so whatever either of them had been building up no longer belongs
-- to the people now standing there.
hook.Add( "CS16HalftimeStarted", "CS16.ResetLossStreaks", function()
	Streak = {}
end )

hook.Add( "PlayerDeath", "CS16.KillReward", function( ply, inflictor, attacker )
	if not IsValid( attacker ) or not attacker:IsPlayer() then return end
	if attacker == ply then return end

	-- No payout for shooting your own side.
	if attacker:Team() == ply:Team() then return end

	CS16.AddMoney( attacker, CS16.Config.Money.Kill )
end )

-- Starting cash when someone first takes a side, and again on a fresh match.
hook.Add( "PlayerInitialSpawn", "CS16.StartingMoney", function( ply )
	CS16.ResetMoney( ply )
end )
