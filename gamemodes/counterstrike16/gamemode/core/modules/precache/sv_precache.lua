--[[
	Loading everything up front.

	Source loads a model the first time something asks for one, which means the
	first grenade thrown, the first prop spawned and the first player to wear an
	unusual model each cost a hitch at the worst possible moment. Doing it while
	the map is still loading trades a longer wait nobody is playing through for
	no waits during the ones they are.

	Off by default for nothing: everything here is already mounted, so this
	costs load time and precache slots rather than downloads. The props are the
	only part large enough to be worth turning off, which is why they have their
	own switch.
]]

local function Precache( list, seen )
	local n = 0

	for _, model in ipairs( list ) do
		if model and model ~= "" and not seen[ model ] then
			seen[ model ] = true
			util.PrecacheModel( model )
			n = n + 1
		end
	end

	return n
end

--[[
	Every model a weapon can put on screen.

	Read off the registered weapons rather than listed by hand, so a weapon
	added to the catalogue is precached without anybody remembering to come
	here. Both models matter and for different reasons: the view model is what
	you see, the world model is what everybody else sees you holding.
]]
local function WeaponModels()
	local models = {}

	for _, wep in ipairs( weapons.GetList() ) do
		models[ #models + 1 ] = wep.ViewModel
		models[ #models + 1 ] = wep.WorldModel
	end

	return models
end

local function PlayerModels()
	local models = {}

	for _, entry in ipairs( CS16.Config.PickableModels or {} ) do
		models[ #models + 1 ] = entry.model
	end

	for _, roster in pairs( CS16.Config.Models or {} ) do
		for _, model in ipairs( roster ) do models[ #models + 1 ] = model end
	end

	models[ #models + 1 ] = CS16.Config.Developer.Model
	models[ #models + 1 ] = CS16.Config.HandsModel

	return models
end

local function PropModels()
	local models = {}

	for _, group in ipairs( CS16.PropList or {} ) do
		for _, model in ipairs( group.models ) do models[ #models + 1 ] = model end
	end

	return models
end

--[[
	On Initialize rather than InitPostEntity.

	Precaching has to happen before the map's own entities are created, or the
	engine has already had to load some of this the slow way to build them - and
	on a dedicated server precaching after that point is what produces the
	"attempted to precache unknown model" warnings.
]]
hook.Add( "Initialize", "CS16.Precache", function()
	local cfg  = CS16.Config.Precache
	local seen = {}

	local weapons_ = cfg.Weapons     and Precache( WeaponModels(), seen ) or 0
	local players  = cfg.PlayerModels and Precache( PlayerModels(), seen ) or 0
	local props    = cfg.Props       and Precache( PropModels(), seen ) or 0

	MsgN( ("[CS 1.6] Precached %d model(s): %d weapon, %d player, %d prop."):format(
		weapons_ + players + props, weapons_, players, props ) )

	--[[
		Sounds are cheap and there are few of them, so they are not optional.
		A round-start cue that stutters the first time it plays is worse than
		the entire cost of loading every one of them.
	]]
	local sounds = 0

	for _, path in pairs( CS16.Config.Sounds or {} ) do
		if isstring( path ) then
			util.PrecacheSound( path )
			sounds = sounds + 1
		end
	end

	if sounds > 0 then MsgN( ("[CS 1.6] Precached %d sound(s)."):format( sounds ) ) end
end )
