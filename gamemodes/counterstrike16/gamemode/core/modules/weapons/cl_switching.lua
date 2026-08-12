--[[
	Q, as CS has always had it: back to the weapon you were last holding.

	Read through WatchKey rather than PlayerBindPress because the decision needs
	the server's view of what you're carrying, and because Q's own bind is
	blocked below - once it's blocked there's no bind press left to listen for.
]]

CS16.WatchKey( "quickswitch", KEY_Q, function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end

	net.Start( "CS16.QuickSwitch" )
	net.SendToServer()
end )

--[[
	Q is bound to +menu out of the box - Sandbox's weapon selection wheel, which
	has no place here and would open every time you tried to switch back. The
	number keys already cover picking a specific weapon.
]]
--[[
	Matched exactly rather than by substring: "+menu_context" is C, the context
	menu, which the areas tool is going to want. A substring test would take
	that away too.
]]
hook.Add( "PlayerBindPress", "CS16.BlockWeaponWheel", function( ply, bind, pressed )
	if string.Trim( bind ) == "+menu" then return true end
end )
