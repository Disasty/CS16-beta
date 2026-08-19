--[[
	Purchasing. Every check is repeated here regardless of what the client's
	menu allowed - the client decides what to grey out, the server decides what
	you actually get.
]]

util.AddNetworkString( "CS16.Buy" )
util.AddNetworkString( "CS16.BuyAmmo" )

--[[
	1.6's clip sound, which ships with the pack and is what its ammo boxes
	already play. Deliberately not items/gunpickup2.wav, which is the sound a
	weapon taken off the floor makes.

	Emitted on the player at a low level, so somebody beside you hears you top
	up and it does not carry down a corridor.
]]
local AMMO_SOUND       = "items/9mmclip1.wav"
local AMMO_SOUND_LEVEL = 60

--[[
	Whether the player is standing in a buy zone, mirrored to the client.

	The client can't reliably enumerate the map's brush entities, so rather
	than have it guess we tell it. Cheap: SetNWBool only sends on change.
]]
timer.Create( "CS16.BuyZoneCheck", 0.25, 0, function()
	for _, ply in ipairs( player.GetAll() ) do
		local inside = CS16.IsPlayingTeam( ply:Team() )
			and ply:Alive()
			and CS16.InBuyZone( ply )

		ply:SetNWBool( "CS16.InBuyZone", inside )
	end
end )

--[[ Giving ]]

local function GiveArmor( ply, item )
	-- Buying the same protection twice is just burning money.
	local hasArmor  = ply:Armor() >= ( item.armor or 0 )
	local hasHelmet = ply:GetNWBool( "CS16.Helmet", false )

	if hasArmor and ( not item.helmet or hasHelmet ) then
		return false, "You already have that."
	end

	ply:SetArmor( item.armor or 0 )
	if item.helmet then ply:SetNWBool( "CS16.Helmet", true ) end

	return true
end

local function GiveGrenade( ply, item )
	local carried  = ply:GetAmmoCount( item.ammo )
	local maxOwned = item.maxOwned or 1

	if carried >= maxOwned then
		return false, "You're carrying as many as you can."
	end

	if not ply:HasWeapon( item.class ) then
		ply:Give( item.class )
	end

	--[[
		Write the total we want, rather than adding one to it.

		The addon's grenade SWEP:Equip ends with an unconditional
		SetAmmo( 1, ... ), so Give has already handed over a grenade by the time
		we get here - and adding a second meant one purchase bought two throws.
		(Its author clearly meant to guard that: the line sits directly under an
		`if currentAmmo >= 1 then` with an empty body.)

		Setting the absolute count last is immune to whatever Equip decides to
		do, which is why it's done this way round instead of by patching the
		SWEP - a Workshop update can change that method freely and this still
		holds.
	]]
	ply:SetAmmo( math.min( carried + 1, maxOwned ), item.ammo )
	return true
end

local function GiveGear( ply, item )
	if item.armor then return GiveArmor( ply, item ) end

	if ply:HasWeapon( item.class ) then
		return false, "You already have that."
	end

	ply:Give( item.class )
	return true
end

-- Primaries and secondaries occupy one slot each, so the old one goes.
local function GiveWeapon( ply, item )
	local owned, ownedItem = CS16.GetOwnedOfKind( ply, item.kind )

	if ownedItem and ownedItem.id == item.id then
		return false, "You already have that."
	end

	if IsValid( owned ) then
		ply:StripWeapon( owned:GetClass() )
		if ownedItem.ammo then ply:RemoveAmmo( ply:GetAmmoCount( ownedItem.ammo ), ownedItem.ammo ) end
	end

	ply:Give( item.class )

	if item.ammo and item.ammoMax then
		ply:GiveAmmo( item.ammoMax, item.ammo, true )
	end

	ply:SelectWeapon( item.class )
	return true
end

--[[ Purchase ]]

function CS16.TryBuy( ply, id )
	local item = CS16.GetBuyItem( id )
	if not item then return end

	local allowed, reason = CS16.CanBuy( ply )
	if not allowed then
		ply:ChatPrint( reason )
		return
	end

	if not CS16.ItemAllowedForTeam( item, ply:Team() ) then
		ply:ChatPrint( "Your team can't buy that." )
		return
	end

	-- Zero for a developer, so the affordability check passes and the charge
	-- below takes nothing.
	local price = CS16.PriceFor( ply, item )

	if not CS16.CanAfford( ply, price ) then
		ply:ChatPrint( "You can't afford that." )
		return
	end

	--[[
		Direct grants bypass the pickup rules, so a purchase
		has to announce itself - otherwise the rule that stops them vacuuming up
		a live round's dropped guns would refuse the Give below as well. Cleared
		immediately after, so it covers the purchase and nothing else.
	]]
	ply.CS16Granting = true

	local given, failure
	if item.kind == "gear" then
		given, failure = GiveGear( ply, item )
	elseif item.kind == "grenade" then
		given, failure = GiveGrenade( ply, item )
	else
		given, failure = GiveWeapon( ply, item )
	end

	ply.CS16Granting = nil

	if not given then
		ply:ChatPrint( failure or "You can't buy that right now." )
		return
	end

	-- Only charge once the item is actually in their hands.
	CS16.TakeMoney( ply, price )

	--[[
		After the charge, so anything listening sees the finished state rather
		than a purchase that might still fail. Team deathmatch uses this to
		remember what you are carrying, which becomes what you respawn with.
	]]
	hook.Run( "CS16Bought", ply, item )
end

net.Receive( "CS16.Buy", function( len, ply )
	CS16.TryBuy( ply, net.ReadString() )
end )

--[[
	Ammunition.

	One magazine per press, charged at a flat rate for the calibre and capped
	at what that ammo type lets you carry - the same deal as 1.6's , and .
	keys. The gun you're holding decides nothing; it's your primary and
	secondary slots that get topped up.
]]
function CS16.BuyAmmo( ply, kind )
	local allowed, reason = CS16.CanBuy( ply )
	if not allowed then
		ply:ChatPrint( reason )
		return
	end

	local wep = CS16.GetOwnedOfKind( ply, kind )
	if not IsValid( wep ) then return end

	local item = CS16.BuyItemsByClass[ wep:GetClass() ]
	if not item or not item.ammo then return end

	local price = CS16.Config.AmmoPrices[ item.ammo ]
	if not price then return end

	local carried = ply:GetAmmoCount( item.ammo )
	local maximum = item.ammoMax or 0

	if carried >= maximum then
		ply:ChatPrint( "You're carrying all the ammo you can for that." )
		return
	end

	if not CS16.CanAfford( ply, price ) then
		ply:ChatPrint( "You can't afford that ammo." )
		return
	end

	-- A magazine at a time, never past the carry limit.
	local clip   = wep:GetMaxClip1()
	local amount = math.min( clip > 0 and clip or maximum, maximum - carried )

	CS16.TakeMoney( ply, price )
	ply:GiveAmmo( amount, item.ammo, true )

	--[[
		Only here, at the bottom, where a purchase has actually happened. Every
		way this can fail returns above, so , and . held down against a full
		pouch stay silent rather than chattering.

		The clip sound rather than the gun one that a floor pickup plays. Both
		ship with the pack, 1.6 uses this one for ammo, and the pack's own ammo
		boxes already do the same - a magazine and a rifle should not sound
		alike when the difference is what you can do next.
	]]
	ply:EmitSound( AMMO_SOUND, AMMO_SOUND_LEVEL, 100, 0.7 )
end

net.Receive( "CS16.BuyAmmo", function( len, ply )
	CS16.BuyAmmo( ply, net.ReadBool() and "primary" or "secondary" )
end )

-- Armour and the helmet are per-life, so clear them when a round respawns you.
hook.Add( "PlayerSpawn", "CS16.ResetHelmet", function( ply )
	ply:SetNWBool( "CS16.Helmet", false )
end )
