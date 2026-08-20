--[[
	The poses the menus stand a player model in.

	Garry's Mod player models carry one animation set, and a menu pose is not in
	it. wOS DynaBase exists to graft extra animations onto that set at runtime,
	which is how the weapon pack already adds its own, and this registers ours
	the same way: a small model that is nothing but sequences, mounted over
	every gender so whichever one a model reports finds it.

	Timing is the part worth knowing. DynaBase fires InitLoadAnimations from a
	CreateTeams hook, and CreateTeams runs after a gamemode's shared files have
	loaded - so registering here is early enough, where registering from
	anything later would not be. The weapon pack gets away with autorun because
	addons load before gamemodes; we cannot.

	The model itself lives in this gamemode's content folder, so there is
	nothing for a server owner to install and nothing extra in the required
	items.

	Animations by Xp1.
]]

local POSE_MODEL = "models/menu/anim_cs16_pose.mdl"

hook.Add( "InitLoadAnimations", "CS16.RegisterMenuPoses", function()
	if not wOS or not wOS.DynaBase then return end

	wOS.DynaBase:RegisterSource( {
		Name   = "Counter-Strike 1.6 menu poses",
		Type   = WOS_DYNABASE.REANIMATION,
		Male   = POSE_MODEL,
		Female = POSE_MODEL,
		Zombie = POSE_MODEL,
	} )

	--[[
		Mounted for each gender in turn. One file answers for all three because
		it holds poses rather than a full animation set, and a pose does not
		care which skeleton variant asked for it.
	]]
	hook.Add( "PreLoadAnimations", "CS16.MountMenuPoses", function( gender )
		if gender == WOS_DYNABASE.MALE
			or gender == WOS_DYNABASE.FEMALE
			or gender == WOS_DYNABASE.ZOMBIE then
			IncludeModel( POSE_MODEL )
		end
	end )
end )

--[[
	Which pose a model stands in, by model rather than by class, so the battle
	royale grid and the class screen agree without either knowing about the
	other's list.

	A pose can ask for a weapon in the model's hand. The animation only moves
	the arms; it has no idea what they are meant to be holding, so a pose built
	around a machine gun looks like a man miming one until the gun is put there.

	The p_ model is the one to name: it is the version built to sit in a hand,
	as opposed to the w_ pickup that lies on the floor. It needs no placing.
	Bone merging welds it to the figure's own skeleton, which is how the weapon
	pack carries its models and is Xp1's own advice, so a pose that moves the
	arm takes the gun with it and no angle or offset is written down anywhere.

	A model with no entry falls back to the standing idle every player model
	has. Nothing breaks if a pose is missing; it simply stands normally.
]]
CS16.MenuPoses = {
	[ "models/cs/playermodels/guerilla.mdl" ] = {
		sequence = "guerrila_menu",
		weapon   = "models/weapons/cs16/p_m249.mdl",
	},
}

--[[
	The sequence to play for this model.

	Returns the fallback when the pose has not been added yet or the animation
	model failed to mount, which is the case a server without DynaBase lands in.
]]
function CS16.MenuPoseFor( ent )
	if not IsValid( ent ) then return nil end

	local entry = CS16.MenuPoses[ ent:GetModel() ]

	if entry and entry.sequence then
		local seq = ent:LookupSequence( entry.sequence )
		if seq and seq > 0 then return seq end
	end

	local idle = ent:LookupSequence( "idle_all_01" )
	if idle and idle > 0 then return idle end
end

if CLIENT then
	--[[
		The weapon in the pose's hand, drawn inside the panel's own 3D pass.

		A model panel draws one model. Anything else has to be drawn during
		that same pass, which is what PostDrawModel is for - and why this is a
		function the panel calls rather than a child entity that would never be
		rendered on its own.

		The prop is created once and hangs off the panel, because building a
		clientside model every frame would be a new entity sixty times a second.
		It is kept out of the world with SetNoDraw and drawn by hand here.
	]]
	function CS16.DrawMenuProp( panel, ent )
		if not IsValid( panel ) or not IsValid( ent ) then return end

		local entry = CS16.MenuPoses[ ent:GetModel() ]

		--[[
			The panel is reused for a different model on the class screen, so a
			prop left from the last selection has to go rather than be drawn
			floating beside somebody who is not holding anything.
		]]
		if not entry or not entry.weapon then
			if IsValid( panel.CS16Prop ) then panel.CS16Prop:Remove() end
			panel.CS16Prop = nil
			return
		end

		if IsValid( panel.CS16Prop ) and panel.CS16Prop:GetModel() ~= entry.weapon then
			panel.CS16Prop:Remove()
			panel.CS16Prop = nil
		end

		if not IsValid( panel.CS16Prop ) then
			panel.CS16Prop = ClientsideModel( entry.weapon, RENDERGROUP_OPAQUE )
			if not IsValid( panel.CS16Prop ) then return end

			panel.CS16Prop:SetNoDraw( true )
			panel.CS16Prop:SetParent( ent )
			panel.CS16Prop:AddEffects( EF_BONEMERGE )
		end

		--[[
			Re-parented when the figure underneath changes.

			The class screen reuses one panel for every class, and setting a new
			model on it builds a new entity - so the weapon would still be
			merged onto the skeleton of whoever was selected before, which no
			longer exists.
		]]
		if panel.CS16Prop:GetParent() ~= ent then
			panel.CS16Prop:SetParent( ent )
			panel.CS16Prop:AddEffects( EF_BONEMERGE )
		end

		panel.CS16Prop:SetupBones()
		panel.CS16Prop:DrawModel()
	end

	--[[
		Clientside models are not owned by the panel that made them, so closing
		a menu without this leaves one behind for every model that was looked
		at, for the rest of the map.
	]]
	function CS16.ClearMenuProp( panel )
		if IsValid( panel ) and IsValid( panel.CS16Prop ) then panel.CS16Prop:Remove() end
		if IsValid( panel ) then panel.CS16Prop = nil end
	end
end
