--[[
	G drops the weapon you're holding, as it did in 1.6.

	The server decides whether it's actually droppable - this only asks. Edge
	detected through WatchKey, so holding the key drops once rather than
	emptying your hands and then everything you walk over.
]]

CS16.WatchKey( "dropweapon", KEY_G, function()
	net.Start( "CS16.DropWeapon" )
	net.SendToServer()
end )
