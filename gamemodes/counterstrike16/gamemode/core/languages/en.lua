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

--[[ Language selection ----------------------------------------------------]]

["lang.current"]            = "Language: {name} ({code})",
["lang.unknown"]            = "No language called '{code}'. Available: {list}",
["lang.set"]                = "Language set to {name}. Empty follows your game language.",
["lang.follow"]             = "Following your game language: {name}",

} )
