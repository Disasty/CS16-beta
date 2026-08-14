# Translating Counter-Strike 1.6

Every line of text a player reads is looked up by key, so translating the
gamemode means editing one file and nothing else. You do not need to read or
understand any of the game code.

## Where the files are

```
gamemodes/counterstrike16/gamemode/core/languages/
    en.lua      English, the reference. Do not translate this one.
    pt.lua      Portuguese, serving both Brazil and Portugal.
```

`en.lua` decides which keys exist. Every other file is a copy of it with the
values translated.

## What you edit

Each line looks like this:

```lua
["bomb.planted"]  = "The bomb has been planted at site {site}.",
```

Change only what is between the quotes on the right. The part in square
brackets is the key the code looks the string up by, and renaming it means the
game can no longer find the line.

```lua
["bomb.planted"]  = "A bomba foi plantada no local {site}.",
```

**You do not have to finish.** Anything still in English displays in English,
so the file is safe to save, test and commit at any point.

## The four rules

**Keep every `{placeholder}`.** `{player}`, `{site}`, `{rescued}` and the rest
are filled in with real values while the game runs. Keep each one that appears
in the English line, spelled exactly the same. You can move them anywhere the
sentence needs, which is the whole reason they are named instead of numbered.
Dropping one means a value never reaches the player.

**Accented characters are fine.** The files are UTF-8 and the fonts render
`ã ç é õ` correctly. Write `ação`, not `acao`. Text that the game shouts in
capitals is uppercased by code that understands accents, so write these in
normal capitalisation and let the game do it.

**Write whole sentences.** Never split one across two keys. Portuguese
adjectives have to agree with a noun that a half-sentence cannot see.

**Some things stay English.** Chat command names (`/gamemode`, `/bots`, `/xp`),
real weapon names (Glock 18C, Desert Eagle, AK-47), and the `[CS 1.6]` prefix,
which is added by the code and never appears in these files.

## Counts

When a number decides between singular and plural, the value is a table:

```lua
["round.remaining"] = {
    one   = "{count} rodada restante",
    other = "{count} rodadas restantes",
},
```

## Checking your work

In game, as a developer:

```
/langcheck pt
```

It reports how much is translated, anything missing, any key that does not
exist in English (usually a typo), and any placeholder you dropped or
misspelled. That last one is the only fault that reaches a player as visible
nonsense, so it is always listed in full.

To read the game in a language your Garry's Mod client is not set to:

```
/language pt
/language auto
```

Otherwise the gamemode follows your `gmod_language` setting by itself.

## Adding a new language

1. Copy `en.lua` to `<code>.lua`. Prefer the base code (`es`, `nl`, `fr`)
   over a regional one (`es-es`), because a base file serves every region
   that speaks the language. Garry's Mod reports regional codes like `es-es`
   and `pt-pt`, and they all fall back to the base.
2. Change the first line inside the file to name it:
   `CS16.RegisterLanguage( "es", "Español", {`
3. Add it in two places, next to the existing ones:
   `gamemode/shared.lua` and `gamemode/init.lua`.
4. Translate, then run `/langcheck <code>`.

A regional code falls back to its base before falling back to English, so a
player on `pt-br` or `pt-pt` both read `pt.lua`. If one region ever needs
different wording, add a `pt-br.lua` holding only the lines that differ; it is
consulted first and falls through to `pt.lua` for everything else.
