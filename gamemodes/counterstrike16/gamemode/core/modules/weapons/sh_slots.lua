--[[
	Which slot a weapon lives in, and what's worth holding.

	Four separate things needed the same answer - what to switch to after a
	grenade, what a bot falls back to when it runs dry, what Q cycles through,
	and what counts as "still usable" - so the question is answered once here
	rather than four times slightly differently.

	Slots are ordered by preference, so a plain numeric comparison picks the
	better of two weapons.
]]

CS16.SLOT_PRIMARY   = 1
CS16.SLOT_SECONDARY = 2
CS16.SLOT_MELEE     = 3

-- Grenades, the bomb, the defuse kit. Things you carry, not things you fall
-- back to - nobody wants to be handed the C4 because their rifle ran out.
CS16.SLOT_OTHER     = 4

CS16.KNIFE = CS16.Config.Knife

-- The developer phaser. Named here because the slot rules below need it and it
-- is not in the buy list, being something no round can ever hand out.
CS16.PHASER = "weapon_cs16_phaser"

function CS16.WeaponSlot( wep )
	if not IsValid( wep ) then return nil end

	local class = wep:GetClass()
	if class == CS16.KNIFE then return CS16.SLOT_MELEE end

	--[[
		The phaser takes the primary slot, so a developer's 1 key reaches it and
		BestWeapon puts it in their hands.

		Without a case here it falls through to SLOT_OTHER along with the
		grenades and the bomb - the slot that is deliberately not selectable by
		number and that BestWeapon deliberately skips, which is right for a
		defuse kit and wrong for the only tool the developer team carries.

		Nothing else is affected, because nothing else can hold one.
	]]
	if class == CS16.PHASER then return CS16.SLOT_PRIMARY end

	-- The buy list already knows which slot every gun occupies; reading it here
	-- means adding a weapon to the shop is still a one-line change.
	local item = CS16.BuyItemsByClass[ class ]

	if item then
		if item.kind == "primary"   then return CS16.SLOT_PRIMARY end
		if item.kind == "secondary" then return CS16.SLOT_SECONDARY end
	end

	return CS16.SLOT_OTHER
end

function CS16.WeaponInSlot( ply, slot )
	for _, wep in ipairs( ply:GetWeapons() ) do
		if CS16.WeaponSlot( wep ) == slot then return wep end
	end
end

--[[
	Is there anything left to fire?

	Clip and reserve both have to be empty to count as dry. Grenades have no
	clip at all - Clip1 reports -1 - and carry their count purely as reserve
	ammo, which the second test covers.
]]
function CS16.WeaponHasAmmo( wep )
	if not IsValid( wep ) then return false end

	-- A knife never runs out, and reports no ammo of any kind. Nor does the
	-- phaser, which would otherwise read as empty and be skipped by BestWeapon
	-- the moment it was put in a slot that BestWeapon looks at.
	local class = wep:GetClass()
	if class == CS16.KNIFE or class == CS16.PHASER then return true end

	if wep:Clip1() > 0 then return true end

	local owner = wep:GetOwner()

	return IsValid( owner )
		and owner:GetAmmoCount( wep:GetPrimaryAmmoType() ) > 0
end

--[[
	The best thing this player could be holding: primary, else secondary, else
	the knife, skipping anything empty.

	`exclude` is a weapon to ignore. A thrown grenade asks this question while
	it is still in the player's inventory - it removes itself immediately
	afterwards - so without that it would cheerfully hand you back the grenade
	you just threw.
]]
function CS16.BestWeapon( ply, exclude )
	local best, bestSlot

	for _, wep in ipairs( ply:GetWeapons() ) do
		if wep ~= exclude and CS16.WeaponHasAmmo( wep ) then
			local slot = CS16.WeaponSlot( wep )

			if slot ~= CS16.SLOT_OTHER and ( not bestSlot or slot < bestSlot ) then
				best, bestSlot = wep, slot
			end
		end
	end

	return best
end
