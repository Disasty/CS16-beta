--[[
	Português.

	Registered as "pt" rather than "pt-br", so it reaches Brazil (pt-br) and
	Portugal (pt-pt) both. The wording leans Brazilian, because that is who
	reviews it. If Brazil and Portugal ever need to differ on a line, add a
	pt-br.lua holding only the lines that differ: a regional file is consulted
	first and falls through to this one for everything it does not carry.

	This is a first pass written by Claude, not by a native speaker. It is
	meant to be read and corrected, not trusted. The lines below marked with a
	comment are judgement calls rather than translations, and are the ones
	worth arguing about first.

	How to work on this file
	------------------------

	Replace the Portuguese between the quotes. Leave everything to the left of
	the = alone: those keys are what the code looks the string up by, and
	renaming one means the game can no longer find it.

	Things that must survive
	------------------------

	  - {placeholders}. {player}, {site}, {rescued} and so on are filled in
	    with real values while the game runs. Keep every one that appears in
	    the English, spelled the same, but move it wherever the sentence needs
	    it. That is what they are for.
	  - Accents. This file is UTF-8 and the fonts render ã ç é õ correctly,
	    which was tested rather than assumed. Text the game shouts in capitals
	    is uppercased by code that understands accents, so write normally.
	  - Whole sentences. Never split one across two keys, because adjectives
	    have to agree with a noun that half a sentence cannot see.

	Things that stay English
	------------------------

	  - Command names: /gamemode, /bots, /xp, /brspawn.
	  - Real weapon names: Glock 18C, Desert Eagle, AK-47.
	  - The [CS 1.6] prefix, added by the code and not present here.

	Checking your work: /langcheck pt
]]

CS16.RegisterLanguage( "pt", "Português", {

--[[ Round flow ------------------------------------------------------------]]

["round.waiting"]           = "Aguardando jogadores",
["round.matchstarting"]     = "A partida vai começar",
["round.halftime"]          = "Intervalo, lados trocados.",
["round.restarting"]        = "Reiniciando a rodada.",
["round.scorereset"]        = "Placar zerado.",

-- JUDGEMENT: "Contra-Terroristas" is what Valve's own Portuguese uses.
-- "Antiterroristas" is also heard. Pick one and keep it everywhere.
["round.end.ct.eliminated"] = "Contra-Terroristas eliminados",
["round.end.t.eliminated"]  = "Terroristas eliminados",
["round.end.hostages"]      = "Os reféns não foram resgatados",
["round.end.t.timeout"]     = "O tempo dos Terroristas acabou",
["round.end.timeexpired"]   = "Tempo esgotado",
["round.end.bomb.detonated"] = "A bomba explodiu",
["round.end.bomb.defused"]  = "A bomba foi desarmada",
["round.end.br.winner"]     = "{player} é o último sobrevivente.",
["round.end.br.nobody"]     = "Ninguém sobreviveu.",
["round.br.nospawns"]      = "Nenhum ponto de nascimento foi colocado neste mapa. Um desenvolvedor pode adicioná-los com /brspawn.",
["round.end.hostages.rescued"] = "Todos os reféns foram resgatados",

--[[ The bomb --------------------------------------------------------------]]

-- JUDGEMENT: "local de bomba" for bomb site. Plenty of players simply say
-- "bombsite", or name the site A and B and never use a word for it at all.
["bomb.pickup.self"]        = "Você está com a bomba. Plante-a em um local de bomba.",
["bomb.pickup.other"]       = "{player} está com a bomba.",
["bomb.planted"]            = "A bomba foi plantada no local {site}.",
["bomb.plant.notsite"]      = "Você só pode plantar em um local de bomba.",
["bomb.plant.away"]         = "Você não está em um local de bomba.",
["bomb.defuse.ctonly"]      = "Somente Contra-Terroristas podem desarmar a bomba.",
["bomb.defuse.busy"]        = "{player} já está desarmando a bomba.",
["bomb.defuse.cover"]       = "{player} está desarmando a bomba, deem cobertura.",
["bomb.defuse.moved"]       = "Você se afastou da bomba.",
["bomb.defuse.ground"]      = "Você precisa estar no chão para desarmar.",
["bomb.defuse.closer"]      = "Chegue mais perto da bomba para desarmá-la.",

--[[ Hostages --------------------------------------------------------------]]

["hostage.follow"]          = "O refém está seguindo você.",
["hostage.stay"]            = "O refém vai ficar aqui.",

--[[ Joining a team --------------------------------------------------------]]

-- JUDGEMENT: "equipe" over "time". "Time" is the more natural Brazilian word,
-- but "equipe" reads correctly in Portugal too and this file serves both.
["team.already"]            = "Você já está nessa equipe.",
["team.notforyou"]          = "Essa equipe não é para você.",
["team.left"]               = "Você saiu da sua equipe. Você poderá entrar novamente quando o mapa mudar.",
["team.locked"]             = "Você está preso à sua equipe até o mapa mudar.",
["team.full"]               = "Essa equipe está cheia.",

--[[ The heads-up display --------------------------------------------------

	Shouted on screen. Written normally here and uppercased by code that
	handles accents, so do not pre-uppercase anything.
]]

["hud.bombplanted"]         = "Bomba plantada",
["hud.getready"]            = "Preparem-se",
["hud.overtimenext"]        = "Prorrogação a seguir",
["hud.halftime"]            = "Intervalo",
["hud.waiting"]             = "Aguardando jogadores",
["hud.waitingnext"]         = "Aguardando a próxima rodada",
["hud.defusing"]            = "Desarmando",
["hud.defusing.other"]      = "{player} está desarmando",

["hud.hostages"]            = "Reféns  {rescued} / {total}",

-- JUDGEMENT: "USAR" is the name of the +use binding. Writing "E" instead
-- would be clearer but wrong for anyone who has rebound the key.
["hud.hostage.leave"]       = "Pressione USAR para deixar o refém aqui",
["hud.hostage.take"]        = "Pressione USAR para levar o refém",

["hud.changingmap"]         = "Trocando de mapa",
["hud.nextround"]           = "Próxima rodada",

["hud.win.player"]          = "{player} venceu",
["hud.win.t"]               = "Terroristas vencem",
["hud.win.ct"]              = "Contra-Terroristas vencem",
["hud.win.draw"]            = "Rodada empatada",
["hud.match.t"]             = "Terroristas vencem a partida",
["hud.match.ct"]            = "Contra-Terroristas vencem a partida",
["hud.match.draw"]          = "Partida empatada",

--[[ Team deathmatch and gun game ------------------------------------------]]

["tdm.end.t.scorelimit"]    = "Os Terroristas atingiram o limite de pontos.",
["tdm.end.ct.scorelimit"]   = "Os Contra-Terroristas atingiram o limite de pontos.",
["tdm.end.t.time"]          = "Tempo esgotado, os Terroristas vencem.",
["tdm.end.ct.time"]         = "Tempo esgotado, os Contra-Terroristas vencem.",
["tdm.end.draw"]            = "Tempo esgotado, o jogo terminou empatado.",
["tdm.end.over"]            = "Fim de jogo.",

-- JUDGEMENT: "escada de armas" for the gun game ladder. There may well be a
-- settled term among Brazilian gun game players that I do not know.
["gg.win"]                  = "{player} completou a escada de armas e venceu o jogo.",
["gg.knife"]                = "{player} está na faca, uma morte para vencer.",

--[[ Scoreboard -----------------------------------------------------------]]

["scoreboard.developers"]       = "Desenvolvedores",
["scoreboard.terrorists"]       = "Terroristas",
["scoreboard.counterterrorists"] = "Contra-Terroristas",
["scoreboard.spectators"]       = "Espectadores",

["scoreboard.section"]          = {
	one   = "{title} - {count} jogador",
	other = "{title} - {count} jogadores",
},

["scoreboard.level"]            = "Nível",
["scoreboard.score"]            = "Pontos",

["scoreboard.deaths"]           = "Mortes",
["scoreboard.latency"]          = "Latência",
["scoreboard.dead"]             = "Morto",
["scoreboard.kit"]              = "Kit",
["scoreboard.info"]             = "{map}   {players}/{max} jogadores",

--[[ Join menus -----------------------------------------------------------]]

["menu.team.title"]         = "Escolha o time",
["menu.class.title"]        = "Escolha uma classe",

["menu.team.t"]             = "Forças Terroristas",
["menu.team.ct"]            = "Forças CT",
["menu.team.auto"]          = "Entrar automaticamente",
["menu.team.spectate"]      = "Assistir",
["menu.team.developer"]     = "Desenvolvedor",
["menu.autoselect"]         = "Seleção automática",

["menu.brief.map"]          = "Mapa: {map}",
["menu.brief.mode"]         = "Modo: {mode}",

["menu.brief.defusal.ct"]   = "Contra-Terroristas: impeçam que a bomba seja plantada, ou desarmem-na se já estiver. Eliminar os Terroristas também vence a rodada.",
["menu.brief.defusal.t"]    = "Terroristas: plantem a bomba em um dos locais e defendam-na até explodir. Eliminar os Contra-Terroristas também vence a rodada.",
["menu.brief.rescue.ct"]    = "Contra-Terroristas: encontrem os reféns e levem-nos até uma zona de resgate. Eliminar os Terroristas também vence a rodada.",
["menu.brief.rescue.t"]     = "Terroristas: mantenham os reféns onde estão e impeçam o resgate. Eliminar os Contra-Terroristas também vence a rodada.",

--[[ Classes --------------------------------------------------------------

	Os nomes das facções são nomes próprios e o jogo original os mantém em
	inglês. Traduza apenas as descrições, a menos que tenha certeza de que um
	nome tem forma consagrada em português.
]]

["class.phoenix.name"]      = "Phoenix Connexion",
["class.phoenix.desc"]      = "Do Leste Europeu, e temidos bem além dele. Formados na confusão que se seguiu ao colapso soviético, cedo adotaram a ideia de que quem estivesse entre eles e o trabalho fazia parte do trabalho.",

["class.leet.name"]         = "Elite Crew",
["class.leet.desc"]         = "Ricos, cuidadosos e profissionais de um jeito que o resto desta lista não é. Compram o melhor de tudo e contratam quem já sabe usá-lo.",

["class.arctic.name"]       = "Arctic Avengers",
["class.arctic.desc"]       = "Escandinavos, à vontade num clima que para todo mundo. O que começou como contrabando pelas fronteiras do norte hoje aceita contratos em qualquer lugar frio o bastante para eles.",

["class.guerrilla.name"]    = "Guerrilla Warfare",
["class.guerrilla.desc"]    = "Centro-americanos e de vida longa. Trinta anos de selva lhes ensinaram paciência, e o hábito de lutar no terreno que escolhem em vez do terreno que lhes dão.",

["class.seal.name"]         = "Seal Team 6",
["class.seal.desc"]         = "A unidade antiterrorista da Marinha dos Estados Unidos, criada em 1980 e em alerta permanente desde então. Se americanos são feitos reféns em qualquer lugar do mundo, são eles que vão buscá-los.",

["class.gsg9.name"]         = "GSG-9",
["class.gsg9.desc"]         = "O grupo antiterrorista federal alemão, criado após o massacre de Munique em 1972 e construído para que aquilo não se repetisse. Metódicos, muito bem treinados e raramente com pressa.",

["class.sas.name"]          = "SAS",
["class.sas.desc"]          = "O Special Air Service britânico, o modelo que quase todos os outros copiaram. A reputação foi feita na sacada de uma embaixada em Londres, em 1980, e vem sendo ampliada em silêncio desde então.",

["class.gign.name"]         = "GIGN",
["class.gign.desc"]         = "O grupo de intervenção da gendarmaria francesa, pequeno por opção e selecionado com dureza. Conhecido por encerrar o sequestro de um voo da Air France em Marselha, em 1994.",

["class.vip.name"]          = "VIP",
["class.vip.desc"]          = "Aquele com quem todos os outros estão sendo pagos para se preocupar.",

["class.hostage.name"]      = "Refém",
["class.hostage.desc"]      = "Não exatamente um combatente. Ninguém vai estar esperando por você.",

--[[ Buy menu -------------------------------------------------------------]]

["buy.title"]               = "Comprar",
["buy.prompt"]              = "Pressione B para comprar, O para equipamento",
["buy.title.category"]      = "Comprar {category}",
["buy.shopbycategory"]      = "Comprar por categoria",
["buy.cancel"]              = "Cancelar",
["buy.primaryammo"]         = "Munição primária",
["buy.secondaryammo"]       = "Munição secundária",

["buy.kind.primary"]        = "arma primária",
["buy.kind.secondary"]      = "arma secundária",

["buy.price"]               = "Preço",
["buy.free"]                = "Grátis",
["buy.realname"]            = "Também conhecida como",
["buy.description"]         = "Descrição",

--[[ O que cada coisa da loja é -------------------------------------------

	Curtas de propósito: uma ou duas linhas. Para que serve a arma e o que ela
	custa a você carregar, e não uma ficha técnica.
]]

["buy.glock18.desc"]        = "Barata, silenciosa e automática em rajadas. A pistola inicial, e nem por isso ruim de perto.",
["buy.usp.desc"]            = "Silenciada, precisa e mais forte que a Glock. O motivo de muitos Contra-Terroristas nunca comprarem outra pistola.",
["buy.p228.desc"]           = "Uma pistola pesada e compacta. Mais poder de parada que as iniciais, sem o preço da Desert Eagle.",
["buy.deagle.desc"]         = "Dois tiros em qualquer lugar, um na cabeça, a quase qualquer distância. Lenta, barulhenta e vale a pena.",
["buy.python.desc"]         = "Um revólver .357. Dano enorme, seis tiros e uma recarga da qual você vai se arrepender.",
["buy.fiveseven.desc"]      = "Vinte tiros que atravessam colete. Dano baixo sozinho, então coloque-os onde importa.",
["buy.elite.desc"]          = "Trinta tiros em dois canos. Terrível de longe e quase impossível de sobreviver de perto.",

["buy.m3.desc"]             = "Uma espingarda de bombeamento. Devastadora a poucos metros e inútil além disso.",
["buy.xm1014.desc"]         = "Chumbo grosso tão rápido quanto o dedo aguentar. Limpa uma porta e esvazia a carteira.",
["buy.sawn.desc"]           = "Dois canos, sem coronha, sem alcance. Tudo ao alcance do braço morre.",

["buy.tmp.desc"]            = "Silenciada e barata. Mata mal, mas as mortes pagam o suficiente para comprar algo melhor.",
["buy.mac10.desc"]          = "Espalha rápido e largo. Munição de pistola com pressa, o que de perto basta.",
["buy.mp5navy.desc"]        = "A confiável. Controlável, precisa o bastante e barata o bastante para comprar toda rodada.",
["buy.ump45.desc"]          = "Mais lenta que a MP5 e mais forte por isso. Perdoa erros nas distâncias em que uma submetralhadora vive.",
["buy.p90.desc"]            = "Cinquenta tiros que atravessam colete, quase sem recuo. Cara, e odiada por todos que a enfrentam.",

["buy.galil.desc"]          = "O rifle mais barato que vale carregar. Trinta e cinco tiros e precisão suficiente para importar.",
["buy.famas.desc"]          = "Um rifle de rajada que custa menos do que deveria. Três tiros onde você mirou valem mais que trinta onde não.",
["buy.ak47.desc"]           = "Um tiro em uma cabeça sem capacete, a qualquer distância. Coice forte, então aprenda a dar tiros curtos.",
["buy.scout.desc"]          = "Um rifle de precisão leve que quase não te atrasa. Recompensa quem se move e pune quem fica parado.",
["buy.m4a1.desc"]           = "O rifle dos Contra-Terroristas. Silenciado, controlável e perdoa uma primeira rajada tremida.",
["buy.sg552.desc"]          = "Um rifle com luneta. Desajeitado nas duas funções e perigoso nas mãos de quem treinou.",
["buy.aug.desc"]            = "A resposta Contra-Terrorista à Krieg. Aproxima a mira e perde precisão por isso.",
["buy.sg550.desc"]          = "Um rifle de precisão automático. Atira tão rápido quanto o clique, a um preço que dói.",
["buy.awp.desc"]            = "Qualquer acerto abaixo da cabeça mata do mesmo jeito. Um tiro, uma recarga longa e um andar lento.",
["buy.g3sg1.desc"]          = "O rifle automático de precisão dos Terroristas. Cinco mil dólares para não precisar mirar duas vezes.",
["buy.asval.desc"]          = "Silenciado, subsônico e perfurante. Silencioso de um jeito que nada mais nesta lista é.",
["buy.winchester.desc"]     = "Um rifle de alavanca de um século antes desta briga. Lento, preciso e completamente fora de lugar.",

["buy.m249.desc"]           = "Cem tiros, nenhuma recarga que valha esperar e um preço que ninguém justifica duas vezes.",
["buy.m135.desc"]           = "Uma minigun. Ela gira, e então o corredor deixa de existir.",

["buy.mgl.desc"]            = "Um revólver que atira granadas. Seis delas, na velocidade que você quiser.",
["buy.law.desc"]            = "Um foguete, disparado uma vez, em algo que mereceu.",
["buy.molotov.desc"]        = "Fogo numa garrafa. Nega terreno em vez de matar quem está nele.",
["buy.flare.desc"]          = "Um sinalizador. Ilumina uma sala, não cega ninguém e faz bonito.",

["buy.flashbang.desc"]      = "Cega quem estiver olhando, você inclusive. Duas é o limite e duas costuma ser o certo.",
["buy.hegrenade.desc"]      = "Explosiva, e suficiente para terminar uma sala ferida. Raramente mata sozinha.",
["buy.smoke.desc"]          = "Bloqueia uma linha de tiro pelo tempo de atravessá-la. O jeito mais barato de cruzar terreno aberto.",
["buy.kevlar.desc"]         = "Um colete que absorve quase tudo que acerta o corpo. Nada para a cabeça.",
["buy.kevlarhelm.desc"]     = "O colete, e um capacete que torna alguns tiros na cabeça sobrevivíveis. Vale a diferença contra rifles.",
["buy.defusekit.desc"]      = "Corta pela metade o tempo de desarme. A diferença entre chegar à bomba e chegar a tempo.",
["buy.nvg.desc"]            = "Ilumina o escuro, e diz a todos nele exatamente onde você está.",

--[[ Language selection ----------------------------------------------------]]

["lang.current"]            = "Idioma: {name} ({code})",
["lang.unknown"]            = "Não existe um idioma chamado '{code}'. Disponíveis: {list}",
["lang.set"]                = "Idioma alterado para {name}. Deixe vazio para seguir o idioma do jogo.",
["lang.follow"]             = "Seguindo o idioma do seu jogo: {name}",

} )
