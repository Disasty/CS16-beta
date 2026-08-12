# Counter-Strike 1.6

A Counter-Strike 1.6 gamemode for Garry's Mod.

Bomb defusal the way 1.6 played it: buy zones and freeze time, the original
weapon prices and movement speeds, a plant that only works on a site, a defuse
that's faster with a kit, and a round that ends when it should. Built on `base`
rather than `sandbox` — this is a shooter, not a sandbox map with guns in it.

> **Status:** in development. Playable end to end, still being polished.

## What's in it

- **Four game modes** — competitive out of the box, plus gun game, team deathmatch and battle royale, switched with `/gamemode` ([below](#game-modes))
- **Two objectives** — bomb defusal, or hostage rescue on maps set up for it; the map decides, not the mode ([below](#objectives))
- **Levels** — cosmetic 1–99 on RuneScape's curve, per mode, with leaderboards on the MOTD ([below](#levels))
- **Rounds** — warmup, 15s freeze, 5:00 clock, bomb timer takes over on plant
- **MR12 match format** — 12 rounds a half, 60s halftime with a side swap, first to 13 wins; 12-12 goes to overtime
- **Five a side**, locked to your team for the map — no switching to whichever side is winning. Sides shrink to fit a smaller server, so eight slots plays four a side rather than five against three
- **Economy** — 1.6 prices throughout, round and kill rewards, `,` / `.` to buy ammo
- **Buy menu** — number-key driven like 1.6: B for categories, O for equipment — or click it
- **Objective** — plant gated to bomb sites, defuse with and without a kit, real win conditions
- **1.6 damage** — the hitgroup multipliers the weapon pack omits: head ×4, stomach ×1.25, legs ×0.75
- **Bots** — navmesh pathfinding, line-of-sight targeting; they buy, plant, defuse, throw grenades, clear the blast radius, and go blind when you flash them
- **Autofill** — bots keep both sides at 5v5 around whoever is actually playing, and clear out when the last player leaves
- **Spectator camera** — follow your team after you die; free look for spectators
- **Flashlight** on `F` — Half-Life 1's, which lights the surface you're looking at rather than throwing a cone from your eye
- **Kill feed** — the original 1.6 death sprites, with headshot markers
- **HUD, scoreboard, team and buy menus** — one cohesive 1.6 look, drawn from the original HUD sprites
- **Admin** — two ranks, chat commands, ranks persisted to disk
- **Developer tools** — a team you can walk a live match in, plus noclip, third person, phase, and a C menu for authoring map data ([below](#developer-tools))
- **Survivor carryover** — live through a round and you keep your kit, as you should
- **Dropping** — G drops your weapon, Q swaps back to your last, death scatters everything but your knife and defuse kit

## Requirements

This repository is Lua only. Every weapon, model, animation, sound and effect
comes from Workshop addons by other authors, and the server must mount all of
them.

There's a collection with everything in it, which saves subscribing to each one
and gets the content to connecting players:

**[Counter-Strike 1.6 gamemode content](https://steamcommunity.com/sharedfiles/filedetails/?id=3776478393)** — `3776478393`

```bash
srcds.exe -console +gamemode counterstrike16 +map de_dust2_classic +host_workshop_collection 3776478393
```

Mount it *or* install the addons by hand, not both — two copies of the same
content is asking for the two to drift apart, and then for a bug that only
reproduces on one of them.

The individual items, for reference:

| Addon | Author | Workshop |
|---|---|---|
| Counter-Strike 1.6 SWEPS (Reworked) | Xp1 | [3347104325](https://steamcommunity.com/sharedfiles/filedetails/?id=3347104325) |
| \[wOS\] Counter-Strike 1.6: Port Edition | Xp1 | [3218751593](https://steamcommunity.com/sharedfiles/filedetails/?id=3218751593) |
| CS 1.6 Blood & Spark FX | Xp1 | [3766744567](https://steamcommunity.com/sharedfiles/filedetails/?id=3766744567) |
| Counter-Strike 1.6 Playermodels | Geisteskrankenchan | [736218548](https://steamcommunity.com/sharedfiles/filedetails/?id=736218548) |
| \[wOS\] DynaBase — Dynamic Animation Manager | King David™ | [2916561591](https://steamcommunity.com/sharedfiles/filedetails/?id=2916561591) |
| \[wOS\] DynaBase Legacy Extensions | King David™ | [2917050373](https://steamcommunity.com/sharedfiles/filedetails/?id=2917050373) |
| Counter Strike 1.6 — Quake Sounds+ | disastrous | [3776584981](https://steamcommunity.com/sharedfiles/filedetails/?id=3776584981) |
| Half-Life 1 Prop Pack | Sirgibsalot | [665025902](https://steamcommunity.com/sharedfiles/filedetails/?id=665025902) |

The prop pack is only needed by the developer prop menu, but it is needed by
name: the gamemode ships an explicit list of its 742 models rather than scanning
for them, so without it that menu offers props the server cannot spawn. Nothing
a player does touches it.

The two DynaBase addons are the animation base the weapon packs are built on —
without them players hold weapons like Half-Life 2 citizens.

One trap if you extract the `.gma` files by hand rather than mounting the
collection: **three of these Workshop items share the title "Counter-strike 1.6
SWEP (Reworded)"** and extract to the same folder name, so they collide and end
up distinguished only by whatever suffix the extractor added. They aren't
copies of each other — one holds the weapons, one the death animations and the
addon scoreboard, one the headshots and pain sounds. The one with the weapons
is the one containing `lua/weapons/weapon_cs_base.lua`; check for that file
before assuming a folder is the weapon pack, because nothing else distinguishes
them and a wrong guess sends you reading code that isn't running.

### Maps

Any bomb-defusal map works in principle, provided it carries the usual
`info_player_terrorist` / `info_player_counterterrorist`, `func_buyzone` and
`func_bomb_target` entities. Only one is currently tested:

| Map | Author | Workshop |
|---|---|---|
| `de_dust2_classic` | White_Mask (re-upload) | [2508187204](https://steamcommunity.com/sharedfiles/filedetails/?id=2508187204) |

The map is in the collection too.

All credit for that content belongs to its authors — this project only supplies
the rules layer. See [Credits](#credits).

## Installing

```bash
cd garrysmod
git clone https://github.com/Disasty/CS16.git temp && mv temp/gamemodes/counterstrike16 gamemodes/ && rm -rf temp
```

Or download and copy `gamemodes/counterstrike16` into your server's `garrysmod/gamemodes/`.

Then launch with the gamemode, a supported map, and the content collection:

```bash
srcds.exe -console +gamemode counterstrike16 +map de_dust2_classic +host_workshop_collection 3776478393
```

Drop the collection argument if you've installed the addons into `addons/`
yourself — see [Requirements](#requirements).

### Every map needs a navmesh

Bots pathfind across Garry's Mod's navigation mesh, and so do the hostages —
they're NextBots. Without a mesh, bots hold position and shoot rather than move,
and a hostage stands where it spawned however politely you ask it to follow.

Some map addons ship one. Italy does, at
`addons/italy_from_counter_strike_1_6/maps/cs16_italy.nav`, which is why it works
the moment you mount it. Check before generating:

```bash
ls garrysmod/maps/<mapname>.nav garrysmod/addons/*/maps/<mapname>.nav
```

If there isn't one, generate it. `sv_cheats` must be on first, or the command is
refused:

```bash
sv_cheats 1
nav_generate
```

It freezes while it works — that freeze is how you know it's running — and can
take several minutes on a large map, reloading the map when it finishes. The mesh
is saved to `garrysmod/maps/<mapname>.nav` and reused thereafter.

**If nothing appears, read the console.** Generation can fail outright on some
maps, and it says why — but only in the console, and a failure leaves the server
responsive with no file written, which looks identical to the command never
having been typed.

#### "No valid walkable seed positions"

Generation floods outward from the map's player spawns, and on ported maps it
sometimes cannot validate a single one — `cs_cs16_assault` fails this way in
single-player and on the server alike. The spawns are fine; the generator just
will not accept them.

Seed it by hand instead. This traces each spawn down to the floor, checks a
player hull actually fits there, and hands the result to the generator:

```lua
navmesh.ClearWalkableSeeds()

for _, class in ipairs( { "info_player_terrorist", "info_player_counterterrorist" } ) do
    for _, e in ipairs( ents.FindByClass( class ) ) do
        local tr = util.TraceLine( {
            start  = e:GetPos() + Vector( 0, 0, 24 ),
            endpos = e:GetPos() - Vector( 0, 0, 256 ),
            mask   = MASK_PLAYERSOLID_BRUSHONLY,
        } )

        if tr.Hit and not tr.StartSolid then
            navmesh.AddWalkableSeed( tr.HitPos + Vector( 0, 0, 4 ), tr.HitNormal )
        end
    end
end

navmesh.BeginGeneration()
navmesh.Save()
```

The server freezes while it runs and anyone connected is dropped — rejoin once it
finishes. Assault produces 375 areas this way.

### Sound

Round announcements use the 1.6 radio clips (`radio/ctwin.wav` and friends) and
the kill announcer uses Quake-style calls from `sound/quake/`. Both come from
the Quake Sounds+ addon listed above.

Neither is bundled with this repository. If you'd rather use your own, the
paths live in `cfg.Sounds` and `cfg.Announcer` in `gamemode/core/sh_config.lua` —
and any entry left empty is simply skipped, so a missing file is silent rather
than an error.

## Setting up an admin

There are two ranks: **Developer** (everything) and **Administrator**
(kick, ban, mute, bots). The first Developer can only be made from the **server
console** — the command refuses to run for any player, whatever their rank:

```bash
cs16_setrank <name|steamid|steamid64> developer
```

Ranks are stored in `garrysmod/data/cs16/ranks.json` and survive restarts.
`cs16_listranks` prints the current assignments.

## Commands

Chat commands accept `/` or `!`. `/help` lists what you personally can run.

| Command | Rank | |
|---|---|---|
| `/help` | everyone | List available commands |
| `/xp` | everyone | Your level, experience, and how far the next one is |
| `/kick`, `/ban`, `/mute`, `/unmute` | Administrator | Moderation |
| `/bots <n>`, `/addbot [t\|ct]`, `/removebot`, `/kickbots` | Administrator | Bot management |
| `/autofill <on\|off>` | Administrator | Automatic match filling |
| `/gamemode [name]` | Administrator | List modes, or switch and reload the map. Takes short forms — `comp`, `gg`, `tdm` |
| `/restartround`, `/resetscore`, `/roundinfo` | Developer | Round control |
| `/setscore <t> <ct>`, `/halftime` | Developer | Match testing |
| `/botdebug` | Developer | Bot navigation diagnostics |
| `/setlevel <n>` | Developer | Jump to a gungame rung (gungame only) |
| `/hostagespot`, `/rescuezone`, `/zones` | Developer | Place map objectives the map itself lacks |
| `/brspawn`, `/brloot` | Developer | Place battle royale spawns and weapon drops. Both take `undo`, `clear`, or `remove <id>` |
| `/brcheck` | Developer | Check every battle royale spawn and loot point can actually be reached |
| `/pause` | Developer | Freeze the match and stop the clock. Again to resume |
| `/reloadmap` | Developer | Restart the current map |
| `/permaprop`, `/clearprops` | Developer | Keep a spawned prop through round and map changes, or clear them |
| `/zonesreset` | Developer | Throw away this server's zone edits, back to the shipped layout |
| `/zonesexport` | Developer | Write the current layout out as a shippable defaults file |
| `/gungame <1x|2x>` | Developer | Kills per ladder rung (gungame only) |

`cs16_truncate confirm` is deliberately **not** here: it wipes all progression
and runs from the server console only. See [Levels](#levels).

Naming a bot count by hand — `/bots`, `/addbot`, `/removebot` — turns autofill
off for the session, or the two would fight and autofill would win. `/autofill
on` hands control back.

## Developer tools

Developers get a fourth team, listed above the two sides in the team menu and
visible only to them. It exists to walk around a live match without being in
it: the bots keep playing a clean 5v5, they don't consider you a target, and
nothing can hurt you.

Joining it fills the server with bots if it's empty, so there's always something
to watch.

| | |
|---|---|
| **Hold C** | Developer menu on the left — camera and visibility, battle royale placement, hostage placement — and the prop menu on the right |
| **Prop menu** | The Half-Life 1 prop pack, 742 models with spawn icons, grouped by the game each came from. Click to spawn one where you're looking |
| **Z** | Undo the last prop you spawned |
| **Phaser** | Left click carries, **right click freezes**, **R** deletes, **E** rotates and **shift+E** snaps to 45°. Developers spawn holding it, on slot 1. Ships with the gamemode — no addon |
| **Pause** | In the menu. Freezes everyone in the match and stops the clock; developers and spectators carry on. Lifts itself if the last developer leaves |
| **Reload map** | In the menu, behind a two-press confirm |
| **V** | Noclip — developer team only, so you can't take off mid-match by accident |
| **Third person** | In the menu. Camera rests against the wall behind you rather than clipping through it |
| **Phase** | In the menu. Invisible, silent, and walked straight through — including your weapons and your scoreboard row |
| **B** | The normal buy menu, but free, usable anywhere at any time, and carrying the whole weapon pack |

The buy menu gains an **Explosives** category for developers — the MGL MK1, the
M72 LAW, molotovs and flares — along with the Python, sawn-off, AS Val,
Winchester and minigun. None of those were in 1.6, so the playing teams never
see them.

Two things stay out even for developers: the C4, which the round issues and
which would inject an objective into a match you aren't playing, and the
shield, whose item entities are broken upstream.

#### Props

Spawned props are cleared at the start of every round. Scenery thrown down to
test something is rubbish by the next round, and a competitive match played
around somebody's crates is worse than no props at all.

To keep one, point at it — or hold it with the phaser — and run `/permaprop`.
Kept props survive round changes *and* map changes, saved to
`data/cs16/props/<map>.json` the same way authored zones are. `/permaprop`
again releases it. `/clearprops` removes yours, `/clearprops all` everybody's,
and `/clearprops perma` takes the kept ones too.

There's a limit of 150 props per player, because a spawn menu and a scroll wheel
will otherwise put seven hundred physics objects into a live round before anyone
notices.

### Authoring map objectives

Ported 1.6 maps carry their brush entities — bomb sites, buy zones — but not
hostages, so those are placed by hand. Stand where one should be and run
`/hostagespot`; stand in the rescue area and run `/rescuezone [radius]`. Both
take `clear` to start over, and `/zones` lists what's placed.

Placed spots are drawn in the world for developers only — green posts with a
facing stub for hostages, a blue ring for the rescue area. Placing the first of
each turns the map into a rescue map immediately, without a reload.

A map needs **both** to count: hostages with nowhere to take them is
half-finished authoring, not a rescue map, and treating it as one would produce
a round nobody can win.

Battle royale spawns and loot points work the same way — `/brspawn` and
`/brloot`, both taking `undo`, `clear` and `remove <id>`, or the battle royale
page of the C menu, which is far less tedious when placing dozens. The REMOVE
rows there take the number written on the marker in the world; **removing
renumbers everything after it**, so delete from the highest number down if
you're taking out several. Spawns draw with a wide ring
so you can judge how far apart they are, which is the whole reason they are
placed by hand.

#### Shipped layouts, and changing them

Layouts come from one of two places, in this order:

1. `data/cs16/zones/<map>.json` — what **this server** has authored, if anything.
2. `gamemode/core/modules/zones/maps/<map>.lua` — what the **gamemode ships**.

The shipped set is why a fresh clone plays. Hostage rescue with no hostages and
battle royale with no spawns aren't modes, they're empty maps, and none of it
can be read out of a BSP — so the layouts are committed as content alongside the
code. `cs16_italy` and `cs_cs16_assault` ship hostages and a rescue zone;
`de_dust2_classic` ships ten battle royale spawns and twenty-eight loot points.

A server is never stuck with them. The moment anything is placed, the whole live
layout is written to the server's own file and that wins from then on — no flag
to set and no permission to ask. `/zonesreset` throws the local file away and
goes back to the shipped set, and `/zones` says which of the two is live.

To turn a layout you've authored into one the gamemode ships, `/zonesexport`
writes it out as a ready-to-commit Lua file and tells you where to move it. It
lands as `.lua.txt` and needs renaming, because `file.Write` refuses to create
`.lua` under `data/`.

Everything placed is drawn in the world for developers, and each set has its own
**Show markers** toggle on its page of the C menu — right while you are setting a
map up, and a hedge of labelled posts between you and the map every other minute.
The choice is archived per client, so it survives the map change that follows
every match.

## Layout

```
counterstrike16.txt  what Garry's Mod reads to list the gamemode
icon24.png           24x24, for the gamemode list
logo.png             256x256, for the loading screen

content/        models and materials the gamemode ships itself, mounted by
                Garry's Mod without being declared anywhere. Currently the
                phaser, which used to be an addon

entities/
  entities/     the hostage, and the map entities 1.6 maps expect to find -
                buy zones, bomb sites, the two spawn points
  weapons/      the developer phaser

gamemode/
  init.lua        server entry point
  cl_init.lua     client entry point
  shared.lua      shared entry point

  core/
    libraries/    the framework: config, teams, commands, player lifecycle,
                  spawns, movement, voice, spectating, developer phase, and
                  the round-state vocabulary every mode speaks
    modules/      a feature apiece, available to any mode
      admin/      ranks, permissions, moderation commands
      weapons/    buy catalogue, purchasing, dropping, switching, damage,
                  addon weapon corrections
      bots/       navmesh pathfinding, bot behaviour, match autofill
      economy/    money, round and kill rewards
      zones/      buy zones and bomb sites read off the map, plus the
                  hostage spots and rescue areas authored onto it
        maps/     one shipped layout per map, overridable per server
      kills/      kill feed and announcer, both driven by PlayerDeath
      progression/  experience, levels and the leaderboards, in SQLite
      props/      the developer prop menu's model list and spawning
      flashlight/ the Half-Life 1 flashlight
    modes/        what makes a game a game
      competitive/  round machine, MR12, the bomb, the hostages
      gungame/      the weapon ladder
      tdm/          team deathmatch: free loadouts, a running score
      br/           battle royale: authored spawns, floor loot, one survivor
    derma/        everything drawn: HUD, scoreboard, team, buy and developer
                  menus, kill feed, camera
```

Only the three entry points sit at the root — Garry's Mod requires those by
name. Everything else lives under `core/`, split by what it is rather than what
it does: `libraries/` is the framework and knows nothing about what game is
being played, `modules/` is one folder per feature, `modes/` decides the game,
and `derma/` is everything drawn.

**All loading happens in the entry points and nowhere else**: no file includes
another, so the load order is readable in one place rather than spread across
fifty files. Order is deliberate and dependency-driven, and the entry points
say why.

### Game modes

Competitive is the mode this gamemode is for, and the one it runs out of the
box. It's still registered like any other rather than being baked in — if the
default were special-cased, every later mode would be written against a shape
the default doesn't follow, and the default is the one nobody would test.

A mode owns what makes a game a game: what follows what, how you win, when you
respawn, whether there's a bomb. Everything underneath is the same either way.
Modules ask what the mode *is* — `CS16.ModeSetting( "Buying" )` — rather than
comparing against its name, so adding one doesn't mean edits scattered through
the buy menu, the bots and the HUD.

Every mode registers on both realms, which is cheap and has no side effects, so
`/gamemode` can list and validate names it isn't running. **Only the active
mode's server files load** — the hooks, timers and state, the things that would
fight each other.

Each mode also declares its own short forms, so `/gamemode comp`, `gg`, `tdm` and
`br` all work. They live on the mode rather than in a table inside the command, which
keeps adding a mode down to a single file; a full name always wins, so a short
form can never shadow a real one. `/gamemode` on its own lists them.

**Competitive** — MR12, five a side, no respawns. The default. What you're
playing *for* depends on the map: bomb defusal, or hostage rescue
([below](#objectives)).

Surviving a round reloads what you kept, free and instantly. 1.6 left you to do
it yourself, which here meant standing frozen through the buy period unable to
start, then spending the opening seconds of a live round pressing R. The
ammunition comes out of your own reserve, so it costs exactly what reloading by
hand would have — a magazine with no reserve behind it stays as empty as you
left it.

**Gun Game** — climb a 31-rung weapon ladder from the Glock to the knife. Your
old weapon goes and the new one lands in your hands, and the knife takes the
match on a single kill. No bomb, no buying, no friendly fire, three second
respawns. Ten a side rather than five, though the bots still only fill to five
so the rest of the room is for people.

Two kills a rung by default, which is sixty-one kills to win; `/gungame 1x`
makes it one a rung and thirty-one to win. The ladder itself is one list at the
top of `core/modes/gungame/sh_gungame.lua`, so cutting whole categories out of
the middle is the other way to shorten a game.

Three of the pack's weapons are deliberately kept off the ladder. The flare does
no damage, the molotov's fire kills without crediting anyone, and the minigun
doesn't fire reliably — and a rung you can't count on leaving strands whoever
draws it for the rest of the game. All three are still in the developer buy menu.

**Team Deathmatch** — the buy menu as a loadout picker rather than a shop.
Everything is free, you can buy any time and anywhere, and you respawn three
seconds later with whatever you last bought. First side to a hundred kills takes
it, or whoever is ahead when twenty minutes runs out. Friendly fire off, ten a
side, no team locks.

Only buying defines your loadout, which is worth knowing: picking a rifle up off
the floor doesn't change what you come back with, and you always respawn with
fresh grenades. Bots draw a random primary and secondary each spawn rather than
buying — with nothing costing anything, the buying logic has no way to choose
and would hand all ten of them the same gun.

**Battle Royale** — ten players, no respawns, last one alive wins and it goes on
their record. Everyone starts with a knife and a full vest on a spawn of their
own; guns are scattered across the map, one per loot point, drawn fresh each
round. The armour is not a nicety: nothing is bought here, so without it the
first person to find a rifle ends the round in about two shots each, and finding
one becomes the whole game rather than the start of it.

Free for all, and **one team to say so**. Everyone is on a side called Battle
Royale, and the scoreboard is a single list of ten rather than two columns
pretending a side won something. This ran as five a side to begin with, on the
grounds that the sides were cosmetic — they were not cosmetic where it counted.

With no side to pick, the team menu has nothing to ask, so battle royale
replaces it with a **model picker**: the ten models the 1.6 pack ships, shown as
models rather than named in a list. Hostage and VIP are in there too, because a
mode with no sides has nothing to dress for.

**Five rounds, then a map reload.** Rounds restart in place the way
competitive's do; every match used to end in a changelevel, which reset
everything correctly and was enormously heavy for something happening every few
minutes. Having enough players starts a **thirty second countdown** rather than
the match itself — everyone frozen for it — so whoever was slowest to load
doesn't arrive to find the rest already armed and hunting.

The spawns and loot points are **authored per map** — a 1.6 map puts nine spawns
in one room, which dropped into a free-for-all means ten people materialising
shoulder to shoulder. `de_dust2_classic` ships a full set; anywhere else, place
them with `/brspawn` and `/brloot`, or from the battle royale page of the
developer menu. Nothing runs until spawns exist, and the mode says so rather
than guessing.

Run **`/brcheck`** once a map is laid out. Being on the navmesh and being
connected to it are not the same thing: a generated mesh can leave islands, and
a loot point on one looks perfectly healthy while no bot on the server can reach
it. It checks every spawn and loot point and names the ones that fail.

Bots fetch a weapon before they go looking for a fight, and check the pathfinder
before committing to one — a gun on top of a crate is meshed and routable and
still needs a crouch-jump nobody reliably makes, so there is also a give-up clock
after which that gun is written off and the next candidate gets a turn.

Switching applies on a map change rather than at runtime:

```
/gamemode gungame
```

Hooks, timers and globals are process-wide, and a mode's state is spread across
globals, networked player variables and live entities. Unloading all that
correctly is the kind of thing that appears to work and then fails three rounds
later, looking like something else entirely. A changelevel is a guaranteed
clean slate and costs seconds. The choice is saved to `data/cs16/mode.txt` and
survives restarts.

### Objectives

Hostage rescue is **not a separate mode**. It's the same competitive round —
freeze, buy, MR12, no respawns — with a different thing to win it, so the map
picks it rather than `/gamemode`. A map with bomb sites plays defusal; a map
with hostage spots authored onto it plays rescue. Nobody switches anything.

Only three rules differ, and they're the three you'd expect:

| | Defusal | Rescue |
|---|---|---|
| Objective won by | planting and detonating / defusing | getting every hostage to a rescue zone |
| Clock running out | Counter-Terrorists win | **Terrorists win** — they were defending |
| Round start | one Terrorist is given the bomb | hostages are placed at their spots |

Elimination works the same either way. The clock reversal is the one that
surprises people: on a rescue map the Terrorists are the defenders, so time
expiring means the Counter-Terrorists failed.

Hostages are `base_nextbot`, so they path on the same navmesh the bots use.
Use one as a Counter-Terrorist and it follows you, use it again and it stays;
walk it into a rescue zone and it's saved for $1000. They move at 250 u/s
against a player's 320 — slow enough that escorting one is a decision.

Maps don't carry hostage spots in the BSP, so the gamemode ships them per map —
`cs16_italy` and `cs_cs16_assault` both have them out of the box. Any other map
is authored with the developer tools, and a server can override what ships. See
[Developer tools](#developer-tools).

Bots play it from both sides: Counter-Terrorists fetch the nearest hostage
nobody has claimed and walk it home, Terrorists each pick one and hold the
ground around it.

## Levels

Purely cosmetic, 1 to 99, on RuneScape's experience curve — 13,034,431 to reach
99, with level 92 as the halfway mark, so the last stretch is most of the work.
Nothing about how the game plays reads your level, which is what makes it safe
for the grind to be this long.

Experience is stored; **the level is always derived from it**, never saved
alongside, so the two can't drift apart. Past 99 experience keeps counting to a
cap of 200,000,000, and the leaderboard ranks on raw experience — otherwise the
top of a mature board would be a row of tied nines.

Kills pay by band, on the tens digit of your level:

| Level | 1–9 | 10–19 | 20–29 | 30–39 | 40–49 | 50–59 | 60–69 | 70–79 | 80–89 | 90–99 |
|---|---|---|---|---|---|---|---|---|---|---|
| Per kill | 50 | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 |

Plus 100 for a round win and 20 for losing one, 500 for the match and 150 for
losing it, and 100 apiece for planting, defusing, or bringing a hostage home.
Objectives pay flat — the objective is the round, whoever happens to be doing it.

Two rules keep it honest. **Killing a bot pays half**, because there are always
ten of them and they always die, so without it the fastest way to level would be
to play alone forever. **Team kills pay nothing and don't count as kills**, or
knifing your own side in spawn would be quicker than either.

Progression is **per mode**. Competitive and gun game keep separate experience,
levels and leaderboards, the way RuneScape keeps separate skills — which is what
makes it fine that a gun game kill comes eight times faster. Only one mode runs
per map, so the scoreboard and the MOTD never have to say which they mean.

Bots level too, and keep it between maps: they have no SteamID, so they're keyed
on their names, which works because the roster is ours and fixed. They get their
own leaderboard next to the players' rather than sharing one — ten bots playing
every round of every day would own all ten slots inside a week.

Battle royale also records **wins**, and ranks its board on them rather than on
level — the number anybody cares about there is how many times you were the last
one standing, and sorting by level would rank it by attendance. Every other mode
still leads with level.

Everything lives in `sv.db` under `cs16_progression`, written at the end of each
round. The wins column is added to an existing table on load if it predates
this, so an older server picks it up without a wipe.

To wipe it — every level, every career kill, both leaderboards — from the
**server console**:

```bash
cs16_truncate confirm
```

Without `confirm` it reports what it would erase and does nothing. It is not a
chat command and refuses to run for a player at any rank, because there is no
undo and no rank that should have it from inside the game. It clears everyone
currently connected as well as the table; otherwise the next round would write
all the old totals straight back.

## Configuration

Everything tunable lives in `gamemode/core/sh_config.lua` — round timings, economy,
starting loadouts, bot difficulty, ammo prices, announcer settings. It's
commented throughout.

Bot difficulty in particular is worth tuning to taste: `AimSpeed`,
`ReactionTime`, `AimError` and `FOV` between them decide whether they're a
warm-up or a genuine problem.

Two other knobs worth knowing about. `cfg.Damage.Scale` multiplies everything
on top of the hitgroup table, for when the whole game feels off rather than one
weapon; and `cfg.SpreadScale` is the weapon bloom, where `1` restores the
pack's own punishing spread exactly.

## A note on the code

This gamemode deliberately **never modifies the addons it depends on**. Where an
addon needs correcting it's overridden at runtime from inside the gamemode
instead, so Workshop updates can't undo it and this repository stays free of
anybody else's content. That has covered rather more than cosmetics:

- the weapon pack applies **no hitgroup scaling at all** — it reads the hitgroup
  once, to size the knockback, and deals the same damage wherever you hit, so a
  rifle headshot did what a leg shot did. 1.6's multipliers are restored in
  `ScalePlayerDamage`, which is most of why the guns feel right
- the planted C4 **let you start a defuse from further away than it would let
  you finish one**, so the bar could run its full length and silently fail. The
  defuse is ours; the rest of the entity is untouched
- every grenade calls `CS16_SelectBestWeapon` on the player after throwing, and
  **nothing anywhere defined it** — an extension point left open for a gamemode
- the flashbang is a **client-side overlay and nothing more**, so bots were
  immune to it. Blindness is now worked out server-side
- one grenade purchase gave two throws, because the SWEP's `Equip` hands you one
  before we do

The general shape: read what the addon actually does, then override the smallest
thing that fixes it. `scripted_ents.GetStored` and wrapping a shared entry point
have done most of the work.

## Credits

- Gamemode by **disastrous**
- **Xp1** — the CS 1.6 weapon packs, effects and the wOS port edition that
  nearly everything you see and hear in game comes from
- **Geisteskrankenchan** — Counter-Strike 1.6 player models
- **King David™** — wOS DynaBase, the animation system underneath it all
- **White_Mask** — the `de_dust2_classic` port
- **Scarecrow** and **Tony Paloma** (Drunken F00l) — the ST:TNG Phaser Mk II the
  developer phaser is built from, redistributed here with their permission
- **Sirgibsalot** — the Half-Life 1 prop pack the developer spawn menu lists
- Counter-Strike is a trademark of Valve Corporation. This is an unaffiliated
  fan project, and none of Valve's assets are distributed here.

## License

[0BSD](LICENSE) — use it, change it, run it, sell it, no attribution required.
It's the MIT license with the "keep this notice" clause removed, so there are
genuinely no strings.

That covers **this repository's code only**. The weapons, models, animations,
sounds and maps are not ours to license; they belong to their Workshop authors,
and Counter-Strike's assets belong to Valve. Whatever you build on top of this,
that content remains subject to their terms.
