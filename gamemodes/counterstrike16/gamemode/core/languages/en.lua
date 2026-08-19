--[[
	English. The reference language.

	Every other language file is a copy of this one with the values translated,
	so this file decides what keys exist. Adding a string to the gamemode means
	adding it here first.

	Rules that keep translations from breaking:

	  - {placeholders} are substituted at runtime. Keep every one that appears
	    in the English, spelled exactly the same. They can be moved anywhere in
	    the sentence, which is the entire reason they are named rather than %s.
	  - Write whole sentences. Never build one by joining fragments, because
	    languages that inflect adjectives cannot agree with a fragment they
	    cannot see.
	  - A value may be a table of { one = ..., other = ... } when a count is
	    passed. English and Portuguese split at the same place; not every
	    language does, which is why the choice lives in the string file.
	  - The [CS 1.6] chat prefix is added in code and never appears here.
]]

CS16.RegisterLanguage( "en", "English", {

--[[ Round flow -------------------------------------------------------------

	Reasons a round or match ended. These are set by the server as keys and
	translated on each player's own machine, so a Portuguese player and an
	English one watching the same round each read it in their own language.
]]

["round.waiting"]           = "Waiting for players",
["round.matchstarting"]     = "Match starting",
["round.halftime"]          = "Halftime, sides swapped.",
["round.restarting"]        = "Restarting round.",
["round.scorereset"]        = "Score reset.",

["round.end.ct.eliminated"] = "Counter-Terrorists eliminated",
["round.end.t.eliminated"]  = "Terrorists eliminated",
["round.end.hostages"]      = "Hostages were not rescued",
["round.end.t.timeout"]     = "Terrorists ran out of time",
["round.end.timeexpired"]   = "Time expired",
["round.end.bomb.detonated"] = "The bomb has detonated",
["round.end.bomb.defused"]  = "The bomb has been defused",
["round.end.br.winner"]     = "{player} is the last one standing.",
["round.end.br.nobody"]     = "Nobody survived.",
["round.br.nospawns"]      = "No spawns placed on this map. A developer can add them with /brspawn.",
["round.end.hostages.rescued"] = "All hostages rescued",

--[[ The bomb --------------------------------------------------------------]]

["bomb.pickup.self"]        = "You have the bomb. Plant it at a bomb site.",
["bomb.pickup.other"]       = "{player} has the bomb.",
["bomb.planted"]            = "The bomb has been planted at site {site}.",
["bomb.plant.notsite"]      = "You can only plant at a bomb site.",
["bomb.plant.away"]         = "You are not at a bomb site.",
["bomb.defuse.ctonly"]      = "Only Counter-Terrorists can defuse the bomb.",
["bomb.defuse.busy"]        = "{player} is already defusing the bomb.",
["bomb.defuse.cover"]       = "{player} is defusing the bomb, cover them.",
["bomb.defuse.moved"]       = "You moved away from the bomb.",
["bomb.defuse.ground"]      = "You have to be on the ground to defuse.",
["bomb.defuse.closer"]      = "Get closer to the bomb to defuse it.",

--[[ Hostages --------------------------------------------------------------]]

["hostage.follow"]          = "The hostage is following you.",
["hostage.stay"]            = "The hostage stays here.",

--[[ Joining a team --------------------------------------------------------]]

["team.already"]            = "You're already on that team.",
["team.notforyou"]          = "That team is not for you.",
["team.left"]               = "You left your team. You can rejoin when the map changes.",
["team.locked"]             = "You're locked to your team until the map changes.",
["team.full"]               = "That team is full.",

--[[ The heads-up display --------------------------------------------------

	Shouted text. It is uppercased in code with a UTF-8 aware routine, so
	write these in normal capitalisation and let the game shout them - and do
	not pre-uppercase accented letters here.
]]

["hud.bombplanted"]         = "Bomb planted",
["hud.getready"]            = "Get ready",
["hud.overtimenext"]        = "Overtime next",
["hud.halftime"]            = "Halftime",
["hud.waiting"]             = "Waiting for players",
["hud.waitingnext"]         = "Waiting for next round",
["hud.defusing"]            = "Defusing",
["hud.defusing.other"]      = "{player} is defusing",

["hud.hostages"]            = "Hostages  {rescued} / {total}",
["hud.hostage.leave"]       = "Press USE to leave the hostage here",
["hud.hostage.take"]        = "Press USE to move the hostage",

["hud.changingmap"]         = "Changing map",
["hud.nextround"]           = "Next round",

["hud.win.player"]          = "{player} wins",
["hud.win.t"]               = "Terrorists win",
["hud.win.ct"]              = "Counter-Terrorists win",
["hud.win.draw"]            = "Round draw",
["hud.match.t"]             = "Terrorists win the match",
["hud.match.ct"]            = "Counter-Terrorists win the match",
["hud.match.draw"]          = "Match drawn",

--[[ Team deathmatch and gun game ------------------------------------------]]

["tdm.end.t.scorelimit"]    = "Terrorists reached the score limit.",
["tdm.end.ct.scorelimit"]   = "Counter-Terrorists reached the score limit.",
["tdm.end.t.time"]          = "Time up, Terrorists win.",
["tdm.end.ct.time"]         = "Time up, Counter-Terrorists win.",
["tdm.end.draw"]            = "Time up, the game is a draw.",
["tdm.end.over"]            = "Game over.",

["gg.win"]                  = "{player} finished the ladder and wins the game.",
["gg.knife"]                = "{player} is on the knife, one kill to win.",

--[[ Scoreboard -----------------------------------------------------------]]

["scoreboard.developers"]       = "Developers",
["scoreboard.terrorists"]       = "Terrorists",
["scoreboard.counterterrorists"] = "Counter-Terrorists",
["scoreboard.spectators"]       = "Spectators",

["scoreboard.section"]          = {
	one   = "{title} - {count} player",
	other = "{title} - {count} players",
},

["scoreboard.level"]            = "Level",
["scoreboard.score"]            = "Score",
["scoreboard.deaths"]           = "Deaths",
["scoreboard.latency"]          = "Latency",
["scoreboard.dead"]             = "Dead",
["scoreboard.kit"]              = "D. Kit",
["scoreboard.info"]             = "{map}   {players}/{max} players",

--[[ Join menus -----------------------------------------------------------]]

["menu.team.title"]         = "Select Team",
["menu.class.title"]        = "Choose a Class",

["menu.team.t"]             = "Terrorist Forces",
["menu.team.ct"]            = "CT Forces",
["menu.team.auto"]          = "Auto Assign",
["menu.team.spectate"]      = "Spectate",
["menu.team.developer"]     = "Developer",
["menu.autoselect"]         = "Auto-Select",

["menu.brief.map"]          = "Map: {map}",
["menu.brief.mode"]         = "Mode: {mode}",

["menu.brief.defusal.ct"]   = "Counter-Terrorists: stop the bomb being planted, or defuse it if it already is. Eliminating the Terrorists wins the round as well.",
["menu.brief.defusal.t"]    = "Terrorists: plant the bomb at one of the sites and hold it until it detonates. Eliminating the Counter-Terrorists wins the round as well.",
["menu.brief.rescue.ct"]    = "Counter-Terrorists: find the hostages and walk them to a rescue zone. Eliminating the Terrorists wins the round as well.",
["menu.brief.rescue.t"]     = "Terrorists: keep the hostages where they are and stop the rescue. Eliminating the Counter-Terrorists wins the round as well.",

--[[ Classes --------------------------------------------------------------

	Written for this project rather than taken from the original, which is
	Valve's text. Factual where they name a real unit, and short enough to sit
	under the model without pushing it off the panel.
]]

["class.phoenix.name"]      = "Phoenix Connexion",
["class.phoenix.desc"]      = "Eastern European, and feared well past it. Formed in the confusion that followed the Soviet collapse, they took the view early on that anyone standing between them and the job was part of the job.",

["class.leet.name"]         = "Elite Crew",
["class.leet.desc"]         = "Wealthy, careful, and professional in a way the rest of this list is not. They buy the best of everything and hire people who already know how to use it.",

["class.arctic.name"]       = "Arctic Avengers",
["class.arctic.desc"]       = "Scandinavian, and at home in weather that stops everyone else. What started as smuggling across the northern borders now takes contracts anywhere cold enough to suit them.",

["class.guerrilla.name"]    = "Guerrilla Warfare",
["class.guerrilla.desc"]    = "Central American and long-lived. Thirty years in the jungle taught them patience, and the habit of fighting on ground they chose rather than ground they were handed.",

["class.seal.name"]         = "Seal Team 6",
["class.seal.desc"]         = "The United States Navy's counter-terrorism unit, stood up in 1980 and on permanent alert since. If Americans are taken anywhere in the world, these are the people sent for them.",

["class.gsg9.name"]         = "GSG-9",
["class.gsg9.desc"]         = "Germany's federal counter-terrorism group, raised after the Munich massacre of 1972 and built so that it would not happen twice. Methodical, heavily trained, and rarely in a hurry.",

["class.sas.name"]          = "SAS",
["class.sas.desc"]          = "Britain's Special Air Service, and the model most of the others copied. Their reputation was made on an embassy balcony in London in 1980, and quietly added to ever since.",

["class.gign.name"]         = "GIGN",
["class.gign.desc"]         = "France's gendarmerie intervention group, small by design and selected hard. Best known for ending the hijacking of an Air France flight at Marseille in 1994.",

["class.vip.name"]          = "VIP",
["class.vip.desc"]          = "The one everybody else is being paid to worry about.",

["class.hostage.name"]      = "Hostage",
["class.hostage.desc"]      = "Not strictly a combatant. Nobody will be expecting you.",

--[[ Buy menu -------------------------------------------------------------]]

["buy.title"]               = "Buy Menu",
["buy.prompt"]              = "Press B to buy, O for equipment",
["buy.title.category"]      = "Buy {category}",
["buy.shopbycategory"]      = "Shop by category",
["buy.cancel"]              = "Cancel",
["buy.primaryammo"]         = "Primary ammo",
["buy.secondaryammo"]       = "Secondary ammo",

["buy.kind.primary"]        = "primary weapon",
["buy.kind.secondary"]      = "secondary weapon",

["buy.price"]               = "Price",
["buy.free"]                = "No charge",
["buy.realname"]            = "Also known as",
["buy.description"]         = "Description",

--[[ What each thing in the shop is ---------------------------------------

	Short on purpose: a line or two, the length of the paragraph 1.6 puts under
	its equipment. What a gun is for, and what it costs you to carry, rather
	than a specification.
]]

["buy.glock18.desc"]        = "Cheap, quiet and fully automatic in bursts. The starting sidearm, and no worse for it at close range.",
["buy.usp.desc"]            = "Silenced, accurate, and hits harder than the Glock. The reason many Counter-Terrorists never buy a second pistol.",
["buy.p228.desc"]           = "A compact heavy pistol. More stopping power than the starting sidearms without the Desert Eagle's price.",
["buy.deagle.desc"]         = "Two hits anywhere, one to the head, at almost any range. Slow, loud, and worth it.",
["buy.python.desc"]         = "A .357 revolver. Enormous damage, six shots, and a reload you will regret starting.",
["buy.fiveseven.desc"]      = "Twenty rounds that punch through armour. Light damage on its own, so put them somewhere useful.",
["buy.elite.desc"]          = "Thirty rounds across two barrels. Wildly inaccurate past a corridor and very hard to survive inside one.",

["buy.m3.desc"]             = "A pump shotgun. Devastating within a few metres and useless beyond them.",
["buy.xm1014.desc"]         = "Semi-automatic buckshot as fast as you can pull the trigger. Clears a doorway, empties a wallet.",
["buy.sawn.desc"]           = "Two barrels, no stock, no range. Everything at arm's length dies.",

["buy.tmp.desc"]            = "Silenced and cheap. Kills poorly, but the kills pay well enough to buy something better.",
["buy.mac10.desc"]          = "Sprays fast and wide. A pistol round in a hurry, which at close range is enough.",
["buy.mp5navy.desc"]        = "The dependable one. Controllable, accurate enough to lean on, and cheap enough to buy every round.",
["buy.ump45.desc"]          = "Slower than the MP5 and hits harder for it. Forgiving at the ranges a sub-machine gun sees.",
["buy.p90.desc"]            = "Fifty rounds through armour with almost no recoil. Expensive, and hated by everyone it is used against.",

["buy.galil.desc"]          = "The cheapest rifle worth carrying. Thirty-five rounds and enough accuracy to matter.",
["buy.famas.desc"]          = "A burst-fire rifle that costs less than it should. Three rounds where they are aimed beats thirty where they are not.",
["buy.ak47.desc"]           = "One shot to an unhelmeted head at any range. Kicks hard, so learn to tap it.",
["buy.scout.desc"]          = "A light sniper rifle that barely slows you down. Rewards moving, punishes camping.",
["buy.m4a1.desc"]           = "The Counter-Terrorist rifle. Silenced, controllable, and forgiving of a shaky first burst.",
["buy.sg552.desc"]          = "A rifle with a scope on it. Awkward at both jobs and dangerous in the hands of somebody who has practised.",
["buy.aug.desc"]            = "The Counter-Terrorist answer to the Krieg. Zooms, and loses accuracy for the privilege.",
["buy.sg550.desc"]          = "An automatic sniper rifle. Fires as fast as you can click, at a price that hurts.",
["buy.awp.desc"]            = "Anything you hit below the head dies anyway. One shot, a long reload, and a slow walk.",
["buy.g3sg1.desc"]          = "The Terrorist automatic sniper. Five thousand dollars of not having to aim twice.",
["buy.asval.desc"]          = "Silenced, subsonic and armour-piercing. Quiet in a way nothing else on this list is.",
["buy.winchester.desc"]     = "A lever-action rifle from a century before this fight. Slow, accurate, and entirely out of place.",

["buy.m249.desc"]           = "A hundred rounds, no reload worth waiting for, and a price nobody can justify twice.",
["buy.m135.desc"]           = "A minigun. It spins up, and then the corridor stops existing.",

["buy.mgl.desc"]            = "A revolver that fires grenades. Six of them, as fast as you like.",
["buy.law.desc"]            = "One rocket, fired once, at something that deserved it.",
["buy.molotov.desc"]        = "Fire in a bottle. Denies ground rather than killing what is standing on it.",
["buy.flare.desc"]          = "A signal flare. Lights a room, blinds nobody, and looks the part.",

["buy.flashbang.desc"]      = "Blinds anyone looking at it, including you. Two is the limit and two is usually right.",
["buy.hegrenade.desc"]      = "Explosive, and enough to finish a wounded room. Rarely kills outright.",
["buy.smoke.desc"]          = "Blocks a sightline for long enough to cross it. The cheapest way through open ground.",
["buy.kevlar.desc"]         = "A vest that absorbs most of what hits your body. Nothing at all for your head.",
["buy.kevlarhelm.desc"]     = "The vest, and a helmet that turns some head shots into survivable ones. Worth the difference against rifles.",
["buy.defusekit.desc"]      = "Halves the time a defuse takes. The difference between reaching the bomb and reaching it in time.",
["buy.nvg.desc"]            = "Lights the dark, and tells everyone in it exactly where you are.",

--[[ Language selection ----------------------------------------------------]]

["lang.current"]            = "Language: {name} ({code})",
["lang.unknown"]            = "No language called '{code}'. Available: {list}",
["lang.set"]                = "Language set to {name}. Empty follows your game language.",
["lang.follow"]             = "Following your game language: {name}",

} )
