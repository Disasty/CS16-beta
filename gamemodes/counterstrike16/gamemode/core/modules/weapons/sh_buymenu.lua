--[[
	The buy catalogue, shared so the client can draw it and the server can
	validate against the exact same table.

	Names are the 1.6 in-game codenames ("CV-47", "Magnum Sniper Rifle") with
	the real designation kept alongside, since the codenames are cryptic if you
	didn't grow up with them. Prices are the 1.6 originals.

	The addon ships extras that were never in 1.6 - the AS VAL, LAW, Molotov,
	Python and so on. They're marked `dev = true` and only appear for the
	developer team, so the match keeps an authentic 1.6 arsenal while everything
	in the pack is still reachable for testing.
]]

-- kind drives the slot rules: one primary and one secondary at a time.
local PRIMARY   = "primary"
local SECONDARY = "secondary"
local GRENADE   = "grenade"
local GEAR      = "gear"

CS16.BuyCategories = {
	{
		id   = "pistols",
		name = "Pistols",
		items = {
			{ id = "glock18",   name = "9x19mm Sidearm",   real = "Glock 18C",     class = "weapon_cs16_glock18",   price = 400,  kind = SECONDARY, ammo = "CS16_9MM",      ammoMax = 120 },
			{ id = "usp",       name = "KM .45 Tactical",  real = "USP .45",       class = "weapon_cs16_usp",       price = 500,  kind = SECONDARY, ammo = "CS16_45ACP",    ammoMax = 100 },
			{ id = "p228",      name = "228 Compact",      real = "SIG P228",      class = "weapon_cs16_p228",      price = 600,  kind = SECONDARY, ammo = "CS16_357SIG",   ammoMax = 52 },
			{ id = "deagle",    name = "Night Hawk .50C",  real = "Desert Eagle",  class = "weapon_cs16_deagle",    price = 650,  kind = SECONDARY, ammo = "CS16_50AE",     ammoMax = 35 },
			{ id = "python",    name = "Python .357",      real = "Colt Python",   class = "weapon_cs16_python",    price = 0,    kind = SECONDARY, ammo = "357",           ammoMax = 36,  dev = true },
			{ id = "fiveseven", name = "ES Five-Seven",    real = "FN Five-seveN", class = "weapon_cs16_fiveseven", price = 750,  kind = SECONDARY, ammo = "CS16_57MM",     ammoMax = 100, teams = { TEAM_CT } },
			{ id = "elite",     name = ".40 Dual Elites",  real = "Dual Berettas", class = "weapon_cs16_elite",     price = 800,  kind = SECONDARY, ammo = "CS16_9MM",      ammoMax = 120, teams = { TEAM_T } },
		},
	},
	{
		id   = "shotguns",
		name = "Shotguns",
		items = {
			{ id = "m3",      name = "Leone 12 Gauge Super",      real = "Benelli M3",    class = "weapon_cs16_m3",      price = 1700, kind = PRIMARY, ammo = "CS16_BUCKSHOT", ammoMax = 32 },
			{ id = "xm1014",  name = "Leone YG1265 Auto Shotgun", real = "Benelli XM1014", class = "weapon_cs16_xm1014", price = 3000, kind = PRIMARY, ammo = "CS16_BUCKSHOT", ammoMax = 32 },
			{ id = "sawn",    name = "Sawn-off Shotgun",         real = "Sawn-off .12",   class = "weapon_cs16_sawn",   price = 0,    kind = PRIMARY, ammo = "CS16_BUCKSHOT", ammoMax = 32, dev = true },
		},
	},
	{
		id   = "smgs",
		name = "Sub-Machine Guns",
		items = {
			{ id = "tmp",     name = "Schmidt Machine Pistol", real = "Steyr TMP",  class = "weapon_cs16_tmp",     price = 1250, kind = PRIMARY, ammo = "CS16_9MM",   ammoMax = 120, teams = { TEAM_CT } },
			{ id = "mac10",   name = "Ingram MAC-10",          real = "MAC-10",     class = "weapon_cs16_mac10",   price = 1400, kind = PRIMARY, ammo = "CS16_45ACP", ammoMax = 100, teams = { TEAM_T } },
			{ id = "mp5navy", name = "KM Sub-Machine Gun",     real = "MP5 Navy",   class = "weapon_cs16_mp5navy", price = 1500, kind = PRIMARY, ammo = "CS16_9MM",   ammoMax = 120 },
			{ id = "ump45",   name = "KM UMP45",               real = "H&K UMP45",  class = "weapon_cs16_ump45",   price = 1700, kind = PRIMARY, ammo = "CS16_45ACP", ammoMax = 100 },
			{ id = "p90",     name = "ES C90",                 real = "FN P90",     class = "weapon_cs16_p90",     price = 2350, kind = PRIMARY, ammo = "CS16_57MM",  ammoMax = 100 },
		},
	},
	{
		id   = "rifles",
		name = "Rifles",
		items = {
			{ id = "galil", name = "IDF Defender",          real = "IMI Galil",     class = "weapon_cs16_galil", price = 2000, kind = PRIMARY, ammo = "CS16_556NATO",   ammoMax = 90, teams = { TEAM_T } },
			{ id = "famas", name = "Clarion 5.56",          real = "FAMAS",         class = "weapon_cs16_famas", price = 2250, kind = PRIMARY, ammo = "CS16_556NATO",   ammoMax = 90, teams = { TEAM_CT } },
			{ id = "ak47",  name = "CV-47",                 real = "AK-47",         class = "weapon_cs16_ak47",  price = 2500, kind = PRIMARY, ammo = "CS16_762NATO",   ammoMax = 90, teams = { TEAM_T } },
			{ id = "scout", name = "Schmidt Scout",         real = "Steyr Scout",   class = "weapon_cs16_scout", price = 2750, kind = PRIMARY, ammo = "CS16_762NATO",   ammoMax = 90 },
			{ id = "m4a1",  name = "Maverick M4A1 Carbine", real = "Colt M4A1",     class = "weapon_cs16_m4a1",  price = 3100, kind = PRIMARY, ammo = "CS16_556NATO",   ammoMax = 90, teams = { TEAM_CT } },
			{ id = "sg552", name = "Krieg 552",             real = "SIG SG 552",    class = "weapon_cs16_sg552", price = 3500, kind = PRIMARY, ammo = "CS16_556NATO",   ammoMax = 90, teams = { TEAM_T } },
			{ id = "aug",   name = "Bullpup",               real = "Steyr AUG",     class = "weapon_cs16_aug",   price = 3500, kind = PRIMARY, ammo = "CS16_556NATO",   ammoMax = 90, teams = { TEAM_CT } },
			{ id = "sg550", name = "Krieg 550 Commando",    real = "SIG SG 550",    class = "weapon_cs16_sg550", price = 4200, kind = PRIMARY, ammo = "CS16_556NATO",   ammoMax = 90, teams = { TEAM_CT } },
			{ id = "awp",   name = "Magnum Sniper Rifle",   real = "AWP",           class = "weapon_cs16_awp",   price = 4750, kind = PRIMARY, ammo = "CS16_338MAGNUM", ammoMax = 30 },
			{ id = "g3sg1", name = "D3/AU-1",               real = "H&K G3/SG-1",   class = "weapon_cs16_g3sg1", price = 5000, kind = PRIMARY, ammo = "CS16_762NATO",   ammoMax = 90, teams = { TEAM_T } },
			{ id = "asval", name = "AS Val",                real = "AS Val 9x39mm", class = "weapon_cs16_asval",     price = 0, kind = PRIMARY, ammo = "CS16_9MMx39", ammoMax = 90, dev = true },
			{ id = "winchester", name = "Winchester 1892",  real = "Lever action",  class = "weapon_cs16_winchester", price = 0, kind = PRIMARY, ammo = "CS16_44-40",  ammoMax = 60, dev = true },
		},
	},
	{
		id   = "machineguns",
		name = "Machine Guns",
		items = {
			{ id = "m249", name = "ES M249 Para", real = "FN M249", class = "weapon_cs16_m249", price = 5750, kind = PRIMARY, ammo = "CS16_556NATOBOX", ammoMax = 200 },
			{ id = "m135", name = "M135 Minigun", real = "Minigun", class = "weapon_cs16_m135", price = 0,    kind = PRIMARY, ammo = "CS16_556NATOBOX", ammoMax = 400, dev = true },
		},
	},
	--[[
		Explosives: the pack's launchers and incendiaries, none of which were in
		1.6. Developer only, both because they aren't authentic and because a
		rocket launcher would end a competitive round rather than decide it.
	]]
	{
		id   = "explosives",
		name = "Explosives",
		dev  = true,
		items = {
			{ id = "mgl",     name = "MGL MK1",        real = "Grenade launcher", class = "weapon_cs16_mgl_mk1", price = 0, kind = PRIMARY, ammo = "CS16_MGL_MK1", ammoMax = 18, dev = true },
			{ id = "law",     name = "M72 LAW",        real = "Rocket launcher",  class = "weapon_cs16_law",     price = 0, kind = PRIMARY, ammo = "CS16_LAW",     ammoMax = 6,  dev = true },
			{ id = "molotov", name = "Molotov Cocktail", real = "Incendiary",     class = "weapon_cs16_molotov", price = 0, kind = GRENADE, ammo = "CS16_MOLOTOV", ammoMax = 3, maxOwned = 3, dev = true },
			{ id = "flare",   name = "Flare",          real = "Signal flare",     class = "weapon_cs16_flare",   price = 0, kind = GRENADE, ammo = "CS16_FLARE",   ammoMax = 3, maxOwned = 3, dev = true },
		},
	},
	{
		id   = "equipment",
		name = "Equipment",
		items = {
			{ id = "flashbang",  name = "Flashbang",        real = "Max 2",          class = "weapon_cs16_flashbang",  price = 200,  kind = GRENADE, ammo = "CS16_FLASHBANG",    ammoMax = 2, maxOwned = 2 },
			{ id = "hegrenade",  name = "HE Grenade",       real = "High Explosive", class = "weapon_cs16_hegrenade",  price = 300,  kind = GRENADE, ammo = "CS16_HEGRENADE",    ammoMax = 1, maxOwned = 1 },
			{ id = "smoke",      name = "Smoke Grenade",    real = "Smoke",          class = "weapon_cs16_smokegrenade", price = 300, kind = GRENADE, ammo = "CS16_SMOKEGRENADE", ammoMax = 1, maxOwned = 1 },
			{ id = "kevlar",     name = "Kevlar Vest",      real = "100 armour",     price = 650,  kind = GEAR, armor = 100 },
			{ id = "kevlarhelm", name = "Kevlar + Helmet",  real = "100 armour, head protection", price = 1000, kind = GEAR, armor = 100, helmet = true },
			{ id = "defusekit",  name = "Defusal Kit",      real = "Faster defusing", class = "weapon_cs16_defusekit", price = 200,  kind = GEAR, teams = { TEAM_CT }, once = true },
			{ id = "nvg",        name = "Nightvision Goggles", real = "Night vision", class = "weapon_cs16_nvg",     price = 1250, kind = GEAR, once = true },
		},
	},
}

--[[ Lookup ]]

CS16.BuyItems        = {}
CS16.BuyItemsByClass = {}

for _, category in ipairs( CS16.BuyCategories ) do
	for _, item in ipairs( category.items ) do
		item.category = category.id
		CS16.BuyItems[ item.id ] = item

		if item.class then CS16.BuyItemsByClass[ item.class ] = item end
	end
end

-- The weapon a player is currently carrying in a given slot, if any. Used to
-- swap out a primary or secondary rather than stacking them up.
function CS16.GetOwnedOfKind( ply, kind )
	for _, wep in ipairs( ply:GetWeapons() ) do
		local item = CS16.BuyItemsByClass[ wep:GetClass() ]
		if item and item.kind == kind then return wep, item end
	end
end

function CS16.GetBuyItem( id )
	return CS16.BuyItems[ id ]
end

--[[
	Developers see the whole pack; the two sides see 1.6's arsenal.

	Both halves matter. Anything marked `dev` is hidden from the playing teams,
	so a match can't be won with a rocket launcher, and a developer's team
	restrictions are dropped entirely, so they can hold a Galil and a FAMAS in
	the same session without changing sides to test them.
]]
function CS16.ItemAllowedForTeam( item, teamID )
	if teamID == TEAM_DEV then return true end
	if item.dev then return false end

	if not item.teams then return true end
	return table.HasValue( item.teams, teamID )
end

function CS16.CategoryAllowedForTeam( category, teamID )
	if teamID == TEAM_DEV then return true end
	return not category.dev
end

--[[
	What this player pays for this item, right now.

	Two things make it free. A developer isn't in the economy at all - there's no
	balance to protect and no money to spend. And a mode may hand the whole shop
	out gratis: team deathmatch does, where the buy menu is a loadout picker
	rather than a shop, and money would only be a delay between dying and being
	useful again.

	The single choke point for cost, which is why it is worth asking the mode
	here rather than in the purchase itself - the menu draws prices from this
	too, so a free mode shows zeroes rather than prices it will not charge.
]]
function CS16.PriceFor( ply, item )
	if ply:Team() == TEAM_DEV then return 0 end
	if CS16.ModeSetting( "FreeBuying", false ) then return 0 end

	return item.price or 0
end

-- Everything a player must satisfy before any purchase is considered.
function CS16.CanBuy( ply )
	-- Some modes hand out weapons rather than selling them. Asked of the mode
	-- rather than tested against its name, so a new one needs no edit here.
	if not CS16.ModeSetting( "Buying", true ) then
		return false, "There's no buying in this mode."
	end

	--[[
		Developers buy anywhere, at any point in the round. Waiting for freeze
		time in a spawn zone to test a weapon is exactly the friction the team
		exists to remove, and none of the rules being skipped protect anything -
		they're not in the round to unbalance.
	]]
	if ply:Team() == TEAM_DEV then
		if not ply:Alive() then return false, "You can't buy while dead." end
		return true
	end

	if not CS16.IsPlayingTeam( ply:Team() ) then return false, "Pick a team first." end
	if not ply:Alive() then return false, "You can't buy while dead." end
	if not CS16.InBuyTime() then return false, "Buy time is over." end
	if not ply:GetNWBool( "CS16.InBuyZone", false ) then return false, "You are not in a buy zone." end

	return true
end
