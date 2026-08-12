--[[
	The phaser - this gamemode's physgun.

	Model: Scarecrow's ST:TNG "Phaser Mk II", ported from the GoldSrc version
	bundled with Tony Paloma's (Drunken F00l) AdminOP for Team Fortress Classic.
	Redistributed here with the permission of both, which is what lets it ship
	inside the gamemode rather than sit alongside it as an addon.

	It was built as a Half-Life gluon-gun replacement, so its animations are a
	continuous-beam set - altfireon / altfirecycle / altfireoff is start, hold,
	stop, which is exactly the shape of picking a prop up, carrying it and
	letting go.

	This is a Lua SWEP rather than a dressed-up weapon_physgun. GMod's physgun is
	a C++ engine weapon whose viewmodel is models/weapons/c_superphyscannon.mdl -
	a c_ model, drawn by bonemerging onto the player's ValveBiped c_arms. Putting
	a v_ model on that viewmodel entity draws nothing at all, and the properties
	that would fix it (ViewModel, UseHands, ViewModelFlip) only exist on Lua
	SWEPs. So the behaviour is reimplemented here instead of inherited.

	Scope: core grab. Hold at distance and release. Rotate, freeze and
	unfreeze-all are deliberately not here yet.
]]

AddCSLuaFile()

SWEP.PrintName = "Phaser"
-- Used with the permission of both, which is what lets it ship in the gamemode
-- rather than sit in an addon. See the Credits section of the README.
SWEP.Author    = "Model by Scarecrow and Tony Paloma"
SWEP.Purpose   = "Pick up and carry props, like the physgun."
SWEP.Category  = "Counter-Strike 1.6"

if CLIENT then
	--[[
		Weapon-select sprite, matching how the rest of the CS16 pack does it.
		The sprite is rendered from the model itself by make_selecticon.py, and
		its material carries the same gold "$color [1 0.75 0]" additive setup as
		the stock icons so it sits alongside them rather than near them.

		DrawWeaponInfoBox off suppresses the default author/purpose panel - the
		one that was showing a blank document next to the phaser.
	]]
	SWEP.WepSelectIcon     = surface.GetTextureID( "cs/sprites/phaser_selecticon" )
	SWEP.DrawWeaponInfoBox = false
	SWEP.BounceWeaponIcon  = false
end

--[[
	Not spawnable. AdminOnly alone only hides it from the spawn menu for
	non-admins; it is not an access control. Access is enforced server-side in
	autorun/server/cs16_phaser.lua, and there is no reason for this to be
	listed as spawnable at all.
]]
SWEP.Spawnable      = false
SWEP.AdminOnly      = true
SWEP.DrawCrosshair  = true
--[[
	Slot 1, which is Slot = 0 - the field is zero-based while the key you press
	is not. It sat on 5 (so, key 6) as a leftover from being an addon that had
	to keep out of the weapon slots a round uses. It ships with the gamemode
	now, only the developer team can hold one, and that team's other weapon is
	the knife on 3, so the front of the list is free and is where the tool you
	are here to use belongs.
]]
SWEP.Slot           = 0
SWEP.SlotPos        = 0

SWEP.ViewModel  = "models/weapons/cs16_phaser/v_phaser.mdl"
SWEP.WorldModel = "models/weapons/cs16_phaser/w_phaser.mdl"

-- The GoldSrc viewmodel carries its own arms, so GMod's c_arms must stay out.
SWEP.UseHands = false

--[[
	Left false on purpose, and it is worth saying why.

	The model draws right-handed already, matching how it looked in TFC.
	Setting this true flips it into the left hand - the opposite of what the
	name suggests you want here. Mirroring the mesh at build time is worse
	still: this model is not authored on Source's axes (its forward is Y, not
	X), so negating a coordinate flips the wrong plane and lands the whole
	viewmodel behind the camera, where it renders as nothing at all.

	Note the bone names disagree with the picture - "Bip01 R Hand" sits left of
	centre in bone space while the phaser visibly draws on the right. Trust the
	render, not the skeleton, if this ever comes up again.
]]
SWEP.ViewModelFlip = false

--[[
	GoldSrc viewmodels were built for a much wider viewmodel FOV than Source
	defaults to. Without this the phaser sits far too close to the camera.
]]
SWEP.ViewModelFOV = 78

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

-- How far in front of the eye a grabbed prop can be held, and how far away one
-- can be grabbed from in the first place.
local GRAB_RANGE = 4096
local MIN_DIST   = 32
local MAX_DIST   = 1024

local BEAM_COLOUR = Color( 25, 255, 40 )

--[[
	The engine physgun got these for free from weapon_physgun.txt; a Lua SWEP
	has to play them itself, which is why the beam went silent when this stopped
	being a dressed-up physgun.

	HoldSound is the gravity gun's hold_loop.wav rather than anything from the
	physgun's own script - Weapon_Physgun.Special1 resolves to a flaregun impact
	and is no use as a loop. Scarecrow's readme notes he never found a decent
	ST:TNG phaser sample, so there is nothing original to be faithful to here.
]]
local SND_ON   = "Weapon_Physgun.On"
local SND_OFF  = "Weapon_Physgun.Off"
local SND_HOLD = "Weapon_PhysCannon.HoldSound"

function SWEP:SetupDataTables()
	self:NetworkVar( "Entity", 0, "HeldEntity" )
	-- Where on the prop the beam landed, in the prop's local space, so the
	-- client can draw the beam to the same spot the server is steering.
	self:NetworkVar( "Vector", 0, "GrabPoint" )
end

-- Matches the CS16 knife. The phaser is about the same size and is held the
-- same way, so the knife's stance sits on it better than a pistol grip.
SWEP.HoldType = "knife"

--[[
	How the world model sits in the holder's hand.

	A ported GoldSrc p_ model is authored in player space rather than relative to
	a hand attachment, so without this it floats off on its own - see
	DrawWorldModel. These are bone-local: position and angle relative to
	WorldModelBone, which is the same space PAC3 edits in, so values taken from
	a PAC3 outfit parented to that bone can be pasted straight in.

	These look absurdly large for a hand offset, and that is expected:
	w_phaser's own origin sits far outside its geometry (bounds 8.4 x 44.7 x
	23.8), so the origin has to be pushed right out to bring the visible model
	into the hand. Measured in PAC3 against the "right hand" bone, not guessed.
]]
SWEP.WorldModelBone = "ValveBiped.Bip01_R_Hand"
SWEP.WorldModelPos  = Vector( 10.31, -62.26, -19.92 )
SWEP.WorldModelAng  = Angle( 66.35, 129.77, -2.33 )

--[[
	Where the beam leaves the world model.

	This is in the local space of the bone the mesh is rigid to, NOT the model's
	own space. w_phaser's entire mesh is skinned to one bone, "Phaser Low-Res",
	and it renders wherever the idle animation puts that bone - which is nowhere
	near where the bind pose leaves it. Measuring in model space therefore put
	the beam far behind the player. A vertex's offset from its own bone is
	constant under animation, so that is the space to work in.

	Measured by find_wm_muzzle.py: the mesh spans 13.59 units along the bone's
	X axis. This is the narrow (30-vertex) end. If the beam ever comes out of
	the grip instead, the other end is Vector( -6.27, -0.37, 1.58 ).
]]
SWEP.WorldModelMuzzleBone = "Phaser Low-Res"
SWEP.WorldModelMuzzle     = Vector( 6.58, -0.85, 1.58 )

function SWEP:Initialize()
	self:SetHoldType( self.HoldType )

	-- Made once and reused; the loop is started and stopped, never recreated.
	if SERVER then
		self.HoldLoop = CreateSound( self, SND_HOLD )
	end
end

--[[ Stopping the loop has to be unconditional - holstering, dying, dropping
     the weapon and disconnecting all have to silence it or it plays forever. ]]
function SWEP:StopHoldLoop()
	if self.HoldLoop then self.HoldLoop:Stop() end
end

--[[
	Every sequence we drive has its own activity in the QC, and we go through
	SendWeaponAnim rather than setting a sequence index on the viewmodel.

	Setting the index directly from the server is not prediction-safe: the two
	realms drift, and it showed up as the client stuck on altfireoff while the
	server was convinced it had gone back to idling. Activities network properly
	and survive that.
]]
local ACT = {
	idle1        = ACT_VM_IDLE,
	draw         = ACT_VM_DRAW,
	holster      = ACT_VM_HOLSTER,
	fidget1      = ACT_VM_FIDGET,
	altfireon    = ACT_VM_PULLBACK,
	altfirecycle = ACT_VM_RECOIL1,
	altfireoff   = ACT_VM_THROW,
}

--[[ Plays an animation by name and returns its length, for chaining. ]]
function SWEP:PlayVM( seq )
	local act = ACT[ seq ]
	if not act then return 0 end

	self:SendWeaponAnim( act )

	local ply = self:GetOwner()
	if not IsValid( ply ) then return 0 end

	local vm = ply:GetViewModel()
	if not IsValid( vm ) then return 0 end

	return vm:SequenceDuration()
end

function SWEP:Deploy()
	self:PlayVM( "draw" )
	return true
end

function SWEP:Holster()
	if SERVER then self:Release() end
	return true
end

function SWEP:OnRemove()
	if SERVER then
		self:Release()
		self:StopHoldLoop()
	end
	if CLIENT and IsValid( self.PhaserWorldModel ) then
		self.PhaserWorldModel:Remove()
	end
end

--[[
	Draw the world model in the holder's hand.

	The stock world model placement puts a ported GoldSrc p_ model out in space
	on its own - those models are authored in player space, not relative to a
	hand attachment, so the engine has nothing sensible to hang them off. The
	fix, and the same one weapon_cs16_knife_beta uses, is to draw our own
	clientside copy parented to the right hand bone with an explicit offset.
]]
function SWEP:DrawWorldModel()
	local owner = self:GetOwner()

	if not IsValid( owner ) then
		-- Dropped, or the holder is dead: nothing to parent to, draw normally.
		self:DrawModel()
		return
	end

	-- Spectating someone in first person shouldn't show their own weapon.
	local lp = LocalPlayer()
	if IsValid( lp ) and lp:GetObserverMode() == OBS_MODE_IN_EYE
		and lp:GetObserverTarget() == owner then
		return
	end

	if not IsValid( self.PhaserWorldModel ) then
		self.PhaserWorldModel = ClientsideModel( self.WorldModel )
		if not IsValid( self.PhaserWorldModel ) then return end
		self.PhaserWorldModel:SetNoDraw( true )
	end

	local bone = owner:LookupBone( self.WorldModelBone )
	if not bone then return end

	--[[
		Bone-local placement via LocalToWorld, rather than composing the offset
		out of Forward/Right/Up and then rotating.

		The two are not equivalent: the manual form applies the rotation after
		the translation, so position and angle interfere with each other and
		nudging one undoes the other. This form is the plain bone-space
		transform, which is also the convention PAC3 edits in - so numbers taken
		out of PAC3 drop straight in here.
	]]
	--[[
		Rebuild the holder's bones before reading them. Without this we get
		whatever was cached from the previous frame, which is why the phaser
		visibly trailed behind when moving quickly - it was drawing where the
		hand used to be.
	]]
	owner:SetupBones()

	local m = owner:GetBoneMatrix( bone )
	if not m then return end

	local pos, ang = LocalToWorld(
		self.WorldModelPos, self.WorldModelAng,
		m:GetTranslation(), m:GetAngles() )

	--[[
		Deliberately not parented. SetParent to a bone makes the engine apply
		that bone's transform at render time on top of the world position we
		just worked out, so the model is transformed twice and lags a frame
		behind. Positioning it outright every frame is both correct and simpler.
	]]
	self.PhaserWorldModel:SetPos( pos )
	self.PhaserWorldModel:SetAngles( ang )
	self.PhaserWorldModel:DrawModel()
end

--[[ Grab ]]

if SERVER then

	function SWEP:TryGrab()
		local ply = self:GetOwner()
		if not IsValid( ply ) then return end

		local tr = util.TraceLine( {
			start  = ply:EyePos(),
			endpos = ply:EyePos() + ply:EyeAngles():Forward() * GRAB_RANGE,
			filter = ply,
		} )

		local ent = tr.Entity
		if not IsValid( ent ) or ent:IsWorld() then return end
		if ent == ply then return end

		--[[
			Players and bots are grabbable too, but they are not moved the same
			way. A player's physics object is not something ComputeShadowControl
			can usefully steer, so they are carried by position instead - see
			UpdateHold. Everything else needs a real, movable physics object.
		]]
		local isPlayer = ent:IsPlayer()

		if not isPlayer then
			local phys = ent:GetPhysicsObject()
			if not IsValid( phys ) then return end

			--[[
				A frozen prop reports IsMoveable false - and so does a map's
				immovable brushwork, which is the same answer for two entirely
				different situations. Testing it alone meant this weapon could
				freeze a prop with right click and then never pick it up again,
				which is a trap rather than a feature.

				So physics props are allowed through and unfrozen on grab, the
				way the physgun does it. Anything else reporting immovable is
				meant to be, and stays that way.
			]]
			if not phys:IsMoveable()
				and not ent.CS16Prop
				and ent:GetClass() ~= "prop_physics"
			then
				return
			end
		end

		--[[
			Two different questions, deliberately.

			For props, ask the stock PhysgunPickup hook: existing prop
			protection then keeps working without knowing what a phaser is.

			For players, do not. The base gamemode answers PhysgunPickup with a
			flat false for any player - the physgun is not supposed to pick
			people up - so asking it would veto every single grab. The phaser is
			an admin-only tool and gates on its own hook, which also gives
			anything else a clean way to object.
		]]
		if isPlayer then
			if hook.Run( "CS16PhaserCanGrabPlayer", ply, ent ) == false then return end
		else
			if hook.Run( "PhysgunPickup", ply, ent ) == false then return end
		end

		self.HoldDist  = math.Clamp( ply:EyePos():Distance( tr.HitPos ), MIN_DIST, MAX_DIST )
		self.HoldLocal = ent:WorldToLocal( tr.HitPos )

		--[[
			The orientation to steer toward, which starts as the one it already
			has. Held on the weapon rather than read back off the prop each
			tick, because rotating it means having somewhere to put the new
			angle that the physics will then be asked to reach - see UpdateHold
			and the rotation hook at the bottom of this file.
		]]
		self.HoldAngle = ent:GetAngles()

		self:SetGrabPoint( self.HoldLocal )
		self:SetHeldEntity( ent )

		--[[
			Picking something up unfreezes it. Right click freezes and lets go;
			grabbing it again is the obvious way to ask for that back, and it is
			what the physgun does.
		]]
		if not isPlayer then
			local phys = ent:GetPhysicsObject()

			if IsValid( phys ) then
				phys:EnableMotion( true )
				phys:Wake()
			end
		end

		if isPlayer then
			--[[
				Freeze their movement while carried, and remember what it was so
				they are handed back exactly as they were. Bots included - they
				are players as far as this is concerned, and MOVETYPE_NONE stops
				their AI walking out of your grip.
			]]
			self.HeldMoveType = ent:GetMoveType()
			ent:SetMoveType( MOVETYPE_NONE )
			-- Marked so the spawn safety net can free anyone we lose track of.
			ent.CS16PhaserHeld = true
		else
			local phys = ent:GetPhysicsObject()
			phys:EnableGravity( false )
			phys:Wake()
		end

		self:EmitSound( SND_ON )
		if self.HoldLoop then self.HoldLoop:Play() end

		--[[
			Beam start, then settle into the looping hold once it has played
			out. Timer name is per-weapon so two players never share one.
		]]
		local dur = self:PlayVM( "altfireon" )
		local id  = "CS16Phaser.Hold." .. self:EntIndex()
		timer.Create( id, math.max( dur, 0.05 ), 1, function()
			if IsValid( self ) and IsValid( self:GetHeldEntity() ) then
				self:PlayVM( "altfirecycle" )
			end
		end )
	end

	function SWEP:UpdateHold()
		local ply = self:GetOwner()
		local ent = self:GetHeldEntity()
		if not IsValid( ply ) or not IsValid( ent ) then return end

		-- A carried player who dies is let go rather than dragged as a corpse.
		if ent:IsPlayer() and not ent:Alive() then self:Release() return end

		local target = ply:EyePos() + ply:EyeAngles():Forward() * self.HoldDist

		if ent:IsPlayer() then
			--[[
				Carried by position. Their movetype is NONE while held, so
				velocity would be ignored; placing them each tick is what
				actually moves them. The grab offset is skipped deliberately -
				hanging a player off one shoulder because that is where the
				trace landed looks wrong, so they ride on the crosshair.
			]]
			ent:SetPos( target - Vector( 0, 0, ent:OBBMaxs().z * 0.5 ) )
			ent:SetVelocity( vector_origin )
			return
		end

		local phys = ent:GetPhysicsObject()
		if not IsValid( phys ) then self:Release() return end

		--[[
			Aim the point that was actually grabbed at the crosshair, not the
			prop's origin. Without this the prop hangs off to one side by
			however far the origin sits from where you clicked - most obvious on
			something like an oil drum, whose origin is at its base rather than
			its middle.
		]]
		local grabOffset = ent:LocalToWorld( self.HoldLocal ) - ent:GetPos()
		target = target - grabOffset

		--[[
			ComputeShadowControl is what the engine's own physics grabbing uses.
			Setting the position directly would shove props through walls and
			hand infinite force to anything they touch; this steers the object
			with real forces instead, so it collides on the way.
		]]
		phys:Wake()
		phys:ComputeShadowControl( {
			secondstoarrive = 0.05,
			pos             = target,

			-- The angle we are steering toward rather than the one it happens
			-- to have. They are the same until something rotates it.
			angle           = self.HoldAngle or phys:GetAngles(),
			maxangular      = 5000,
			maxangulardamp  = 10000,
			maxspeed        = 100000,
			maxspeeddamp    = 10000,
			dampfactor      = 0.8,
			teleportdistance = 0,
		} )
	end

	function SWEP:Release()
		local ent = self:GetHeldEntity()
		local wasHolding = IsValid( ent )

		timer.Remove( "CS16Phaser.Hold." .. self:EntIndex() )
		self:StopHoldLoop()

		if IsValid( ent ) then
			if ent:IsPlayer() then
				--[[
					Hand them back exactly as they were. Falling back to
					MOVETYPE_WALK matters: without it a player let go while the
					weapon was switched away, or while they were dead, would be
					left frozen in place with no way out.
				]]
				ent:SetMoveType( self.HeldMoveType or MOVETYPE_WALK )
				self.HeldMoveType = nil
				ent.CS16PhaserHeld = nil
			else
				local phys = ent:GetPhysicsObject()
				if IsValid( phys ) then
					phys:EnableGravity( true )
					phys:Wake()
				end
			end
			hook.Run( "PhysgunDrop", self:GetOwner(), ent )
		end

		self:SetHeldEntity( NULL )

		--[[
			Only if something was actually let go. Release also runs on holster,
			death and removal, and firing the shutdown sound and animation when
			nothing was ever picked up is just noise.
		]]
		if wasHolding then
			self:EmitSound( SND_OFF )
			-- MaintainIdle takes over once altfireoff has run out.
			self:PlayVM( "altfireoff" )
		end

		self.HoldAngle = nil
	end

end

--[[
	Turning what you are carrying, on E.

	Read from StartCommand rather than from Think, and that is the whole trick:
	the mouse movement has to be taken *away* from the view as well as given to
	the prop, and the only place it exists before the engine turns your head
	with it is the command itself. Zeroing it there is what stops the world
	swinging around while you square up a crate.

	The mouse deltas and the view angle are two separate fields of the command,
	and that distinction is the whole of how this works.

	The first attempt zeroed the deltas on both realms, reasoning that the
	client had to agree or it would predict a turn and be corrected. What it
	actually did was destroy the input before it was ever sent: the client
	zeroed the deltas, the server received zeros, and every tick rotated the
	prop by nothing at all. Measured - the trace showed mouse=0,0 on every
	frame a prop was held, and real numbers on the frames it wasn't.

	So the deltas are left alone and travel intact, and the client holds the
	*view angle* still instead. The server gets both: a view that isn't
	turning, and the mouse movement to turn the prop with.

	It writes to HoldAngle rather than to the entity. UpdateHold hands that to
	ComputeShadowControl, so the prop is steered round by real forces and still
	collides with things on the way - setting angles outright would push it
	through walls.

	Hold shift as well and it snaps to 45 degrees, which is the reason anybody
	rotates a prop by hand: getting it square with the world.
]]
--[[
	Degrees of prop per unit of mouse.

	0.022 is not arbitrary: it is the engine's own m_yaw, the rate your view
	turns at default sensitivity. Matching it means the prop turns exactly as
	fast as looking around does, which is the thing your hand already knows how
	to do.

	It started at 0.4, which is eighteen times that. Mouse deltas peak near 190
	units in a single tick, so a flick was seventy-odd degrees between one frame
	and the next and the prop simply span.
]]
local ROTATE_SPEED = 0.022

--[[
	And a much faster one while snapping.

	Snapping quantises the result to 45 degrees, so the fine control the rate
	above buys is thrown away the moment shift is held - all that is left is how
	far the mouse has to travel to reach the next stop. At the free-rotation
	rate that is 22.5 degrees of accumulation, or over a thousand mouse units
	per click, which is most of a desk.

	At this rate a stop is about 300 units away: a deliberate movement rather
	than a twitch, and no risk of overshooting because there is nowhere between
	the stops to land. Landed on by feel between 0.022, where a click took most
	of a desk, and 0.15, which went off at a touch.
]]
local SNAP_SPEED   = 0.075
local SNAP_DEGREES = 45

local function SnapTo( value, step )
	return math.Round( value / step ) * step
end

--[[
	What the phaser is turning right now, or nil. Shared shape, different job on
	each realm: the client uses it to know whether to hold the view still, the
	server uses it to know whether to rotate.

	GetHeldEntity comes from SetupDataTables, and on the client that has not
	necessarily run for a weapon that has only just arrived - the class check
	passes at that point and the accessor is still nil.
]]
local function Rotating( ply, cmd )
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) or wep:GetClass() ~= "weapon_cs16_phaser" then return end
	if not wep.GetHeldEntity then return end
	if not cmd:KeyDown( IN_USE ) then return end

	local ent = wep:GetHeldEntity()

	-- Players are carried by position and have no orientation worth turning;
	-- spinning somebody round by the shoulders is not what this is for.
	if not IsValid( ent ) or ent:IsPlayer() then return end

	return wep, ent
end

if CLIENT then

	--[[
		Hold the view still while turning a prop.

		Only the angle is touched; the mouse deltas are left to travel to the
		server, which is what actually turns the thing. Zeroing them here was
		the bug this replaces.

		SetEyeAngles as well as SetViewAngles, because the command alone leaves
		the engine's own angle accumulating in the background - so letting go of
		E snapped the view to wherever the mouse had notionally wandered off to.
		Setting both keeps them agreeing.
	]]
	local locked

	hook.Add( "CreateMove", "CS16.PhaserLockView", function( cmd )
		local ply = LocalPlayer()
		if not IsValid( ply ) then return end

		if not Rotating( ply, cmd ) then
			locked = nil
			return
		end

		locked = locked or cmd:GetViewAngles()

		cmd:SetViewAngles( locked )
		ply:SetEyeAngles( locked )
	end )

end

-- Guarded rather than returned out of: the beam further down this file is
-- clientside, and a return here would take it with us.
if SERVER then

hook.Add( "StartCommand", "CS16.PhaserRotate", function( ply, cmd )
	local wep, ent = Rotating( ply, cmd )
	if not wep then return end

	local dx, dy = cmd:GetMouseX(), cmd:GetMouseY()
	if dx == 0 and dy == 0 and not cmd:KeyDown( IN_SPEED ) then return end

	local ang = wep.HoldAngle or ent:GetAngles()

	--[[
		Yaw about the world's up, pitch about the player's right. Rotating about
		the player's own axes is what makes the prop follow the mouse rather
		than tumbling in whatever frame it happens to be in.

		Both signs are positive, and that is the point rather than an accident.
		Negating them turns the prop against the mouse, which reads as pushing
		the far side of it away from you - correct if you were dragging the
		surface you can see, wrong for something held out in front of you. The
		physgun turns with the mouse, so this does too.
	]]
	local snapping = cmd:KeyDown( IN_SPEED )
	local speed    = snapping and SNAP_SPEED or ROTATE_SPEED

	ang:RotateAroundAxis( vector_up, dx * speed )
	ang:RotateAroundAxis( ply:EyeAngles():Right(), dy * speed )

	--[[
		Snapped after rotating rather than instead of it, so the mouse still
		drives which way it turns - it just arrives at 45 degree stops. The prop
		visibly clicks between them, which is the feedback that tells you it is
		square.
	]]
	if snapping then
		ang.p = SnapTo( ang.p, SNAP_DEGREES )
		ang.y = SnapTo( ang.y, SNAP_DEGREES )
		ang.r = SnapTo( ang.r, SNAP_DEGREES )
	end

	wep.HoldAngle = ang
end )

end

--[[
	Every one-shot sequence in this model - draw, holster, altfireon,
	altfireoff, fidget1 - simply stops on its last frame, so something has to
	put the viewmodel back into the idle loop afterwards. Doing it here rather
	than with a timer per animation means it self-heals: whatever the viewmodel
	is showing, once that animation has run out and nothing is being held, it
	falls back to idle1.
]]
function SWEP:MaintainIdle()
	local ply = self:GetOwner()
	if not IsValid( ply ) then return end

	local vm = ply:GetViewModel()
	if not IsValid( vm ) then return end

	local seq = vm:GetSequenceName( vm:GetSequence() )
	if seq == "idle1" then return end

	-- altfirecycle loops while a prop is held; leave it alone.
	if seq == "altfirecycle" then return end

	if vm:GetCycle() >= 0.99 then
		self:PlayVM( "idle1" )
	end
end

function SWEP:Think()
	local ply = self:GetOwner()
	if not IsValid( ply ) then return end

	if SERVER then
		local holding = IsValid( self:GetHeldEntity() )

		-- Dying mid-grab must not leave a carried player frozen in mid-air.
		if holding and not ply:Alive() then
			self:Release()
			return
		end

		--[[
			Freeze and delete, read here rather than from SecondaryAttack and
			Reload.

			Those two exist below and are the obvious place, and they are never
			reached: everything this weapon does runs off KeyDown in Think, and
			in that arrangement the engine's attack hooks simply do not fire for
			it. Filling them in produced a right click that did nothing at all.
			Reading the keys the same way the grab does is both consistent and
			demonstrably works.

			Latched on the release of the key, so holding the button down acts
			on one prop rather than on every prop picked up while it is held.
		]]
		local freeze = ply:KeyDown( IN_ATTACK2 )
		local remove = ply:KeyDown( IN_RELOAD )

		if freeze and holding and not self.CS16FreezeLatch then
			self:FreezeHeld()
		end

		if remove and not self.CS16RemoveLatch then
			self:RemoveAimed()
		end

		self.CS16FreezeLatch = freeze
		self.CS16RemoveLatch = remove

		-- Re-read: freezing and deleting both let go of whatever was held.
		holding = IsValid( self:GetHeldEntity() )

		--[[
			Let go of the trigger before picking anything up again.

			Freezing and deleting both drop what was being carried, and the
			trigger is still down when they do - so without this the very next
			tick grabs the same prop straight back, and grabbing unfreezes it.
			The two features cancelled each other out exactly: right click
			appeared to do nothing at all.

			Cleared when the trigger comes up, which is the same gesture the
			physgun asks for.
		]]
		if ply:KeyDown( IN_ATTACK ) then
			if not holding then
				if not self.CS16BlockGrab then self:TryGrab() end
			else
				self:UpdateHold()
			end
		else
			self.CS16BlockGrab = nil

			if holding then self:Release() end
		end

		if not IsValid( self:GetHeldEntity() ) then
			self:MaintainIdle()
		end
	end
end

--[[
	Right click freezes what is being carried, the way the physgun does.

	Letting go afterwards is the point of it. Freezing while still carrying
	means the next release un-freezes nothing and the prop hangs there anyway;
	dropping it is what makes the freeze visible.

	Players are carried by this weapon too - see the MOVETYPE_NONE handling in
	Release - and freezing a person's physics object does nothing useful, so
	only the things with physics worth freezing are touched.
]]
function SWEP:FreezeHeld()
	if CLIENT then return end

	local ent = self:GetHeldEntity()
	if not IsValid( ent ) or ent:IsPlayer() then return end

	local phys = ent:GetPhysicsObject()

	if IsValid( phys ) then
		phys:EnableMotion( false )
		phys:Sleep()
	end

	self:Release()

	-- Or the still-held trigger grabs it back next tick and unfreezes it.
	self.CS16BlockGrab = true

	ent:EmitSound( "Weapon_Physgun.Off" )
end

--[[
	Reload deletes what is being carried, or what is being looked at.

	Carried first, because pointing at a prop in your hands traces through to
	the wall behind it as often as not, and deleting the thing you are holding
	is unambiguous.

	What may go is CS16.CanRemoveProp's decision, and it is deliberately narrow:
	anything the map placed is refused. A developer tool that can delete the map
	by pointing at it is a developer tool that eventually does.
]]
function SWEP:RemoveAimed()
	if CLIENT then return end

	local ply = self:GetOwner()
	if not IsValid( ply ) then return end

	local ent = self:GetHeldEntity()
	if not IsValid( ent ) then ent = ply:GetEyeTrace().Entity end

	if not CS16.CanRemoveProp( ent ) then return end

	if IsValid( self:GetHeldEntity() ) then
		self:Release()
		self.CS16BlockGrab = true
	end

	ent:EmitSound( "Weapon_Physgun.Off" )
	SafeRemoveEntity( ent )
end

-- Everything is driven from Think so the beam can be continuous, and because
-- the engine's attack hooks are not reached for this weapon at all. These exist
-- only so it cannot fall back to any default behaviour. See Think.
function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
function SWEP:Reload() end

--[[ Beam ]]

if CLIENT then

	local beamMat = Material( "sprites/physbeam" )

	--[[
		Beam origin. In first person it comes off the model's own "muzzle"
		attachment - the one carried over from the GoldSrc $attachment - so it
		leaves the emitter tip rather than the middle of the screen. Everyone
		else sees it leave the world model.
	]]
	local function BeamStart( wep, ply )
		if ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then
			local vm = ply:GetViewModel()
			if IsValid( vm ) then
				local i = vm:LookupAttachment( "muzzle" )
				local a = i and i > 0 and vm:GetAttachment( i )
				if a then return a.Pos end
			end
		end

		--[[
			Third person: start from the clientside copy DrawWorldModel places
			in the hand, not the weapon entity, which the engine parks somewhere
			unrelated.

			Its *origin* is no good either - w_phaser is a GoldSrc p_ model whose
			origin sits ~65 units outside its own geometry, which is what made
			the beam appear to come from behind the player. OBBCenter was the
			next attempt and put it on the holder's chest, because that is where
			the middle of the phaser sits in this pose. WorldModelMuzzle is the
			emitter end of the mesh, which is what we actually want.
		]]
		local wm = wep.PhaserWorldModel
		if IsValid( wm ) then
			wm:SetupBones()
			local b = wm:LookupBone( wep.WorldModelMuzzleBone )
			local m = b and wm:GetBoneMatrix( b )
			if m then
				return LocalToWorld( wep.WorldModelMuzzle, angle_zero,
					m:GetTranslation(), m:GetAngles() )
			end
			-- Bone missing: the middle of the mesh still beats the origin.
			return wm:LocalToWorld( wm:OBBCenter() )
		end

		return wep:GetPos()
	end

	hook.Add( "PostDrawTranslucentRenderables", "CS16Phaser.Beam", function( depth, sky )
		if depth or sky then return end

		for _, ply in ipairs( player.GetAll() ) do
			local wep = ply:GetActiveWeapon()
			if not IsValid( wep ) or wep:GetClass() ~= "weapon_cs16_phaser" then continue end

			local ent = wep:GetHeldEntity()
			if not IsValid( ent ) then continue end

			local src = BeamStart( wep, ply )
			local dst = ent:LocalToWorld( wep:GetGrabPoint() )

			render.SetMaterial( beamMat )
			render.DrawBeam( src, dst, 6, 0, 1, BEAM_COLOUR )
		end
	end )

end
