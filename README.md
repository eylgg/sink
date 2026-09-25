# Sink

The everything WoW: Forever addon.

- **Player frame centering**: keeps the player frame centered whatever Edit Mode does. Off by default.
- **Quest item warnings**: tooltip line and bag slot tint for quest items that are safe to delete; the tracker lists them.
- **Recipe vendors**: vendor tooltips list the recipes sold, checked when you know them; `/sink recipes missing` lists what you still lack.
- **Weapon and class skills**: weapon master and class trainer tooltips show what you can still learn and at what level.
- **Ability errors**: hides the repeating "Not enough energy" text and voice when you spam an ability.
- **Map icons**: vendors, trainers, flight masters, dungeon entrances and quest NPCs on the world map, filtered to your faction, class and professions. Click one to target and ping the NPC.
- **Level splits**: how long each level took in `/played` time, with a small window for the last few levels. Off by default.
- **Tracker**: a window styled like the objective tracker, listing unspent talent points, quest items to delete (click to delete), dungeons with quests left, class skills with their total cost, and weapon skills you can learn.

Type `/sink` or click Sink in the addon compartment to open the options window.

## Install

Extract `Sink.zip` from the [releases page](https://github.com/eylgg/sink/releases) into `World of Warcraft/_classic_beta_/Interface/AddOns/`. For a working checkout, symlink it there instead:

```bash
ln -s "$PWD" "/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/Sink"
```

The folder name must match the TOC's base name, `Sink/` and `Sink_Camelot.toc`.

## Commands

| Command | Effect |
| --- | --- |
| `/sink` | Open the options window (`/sink config` works too) |
| `/sink status` | Centering on or off, the offsets and the version |
| `/sink on`, `off`, `toggle` | Player frame centering |
| `/sink x <n>`, `/sink y <n>` | Offset from screen center (-800 to 800) and height above the bottom (0 to 800, default 250) |
| `/sink reset`, `/sink center` | Default offsets; re-apply the position now |
| `/sink items [add <itemID> <questID> \| remove <itemID> \| on \| off]` | Quest item rules and warnings |
| `/sink recipes [add <itemID> [npcID] \| remove ... \| missing \| on \| off]` | Recipe vendors; `add` uses your target when no NPC ID is given |
| `/sink weapons [masters \| on \| off]` | Weapon skills you can learn and who teaches them |
| `/sink errors [on \| off \| toggle \| list]` | The ability error mute |
| `/sink map [add <name> \| remove <name> \| on \| off \| trainers all\|mine \| classes all\|mine]` | Map icons |
| `/sink splits` | Turn level splits on or off |
| `/sink tracker` | Show or hide the tracker |
| `/sink dump loc \| target \| trainer \| skills \| taxi \| npc [unverified]` | Developer dumps of IDs and coordinates, with a paste line to copy |

Each group also answers `help`, for example `/sink map help`.

## Adding data

The built-in tables sit at the top of their files: quest item rules in `QuestItems.lua`, recipe vendors in `Recipes.lua`, weapon masters in `Weapons.lua`, class skills in `Trainers.lua`, map icons in `MapPins.lua`, and dungeons, NPCs and quests in `Quests.lua`. Each file's header comment describes its format.

- Stand next to an NPC and use `/sink dump target`, or stand at a place and use `/sink dump loc`. Both print a line to paste that is marked `verified = true`. The client never reports NPC positions, so the dump uses yours.
- `/sink dump trainer` at an open trainer window prints the table entry for that weapon master or class. A class's entry has every skill with its level and price; set the window's filter to show everything first, since it only dumps what the window lists.
- Merchant and weapon master windows are recorded as you visit them, so tooltips fill in without any typing. Class trainers are not: their skills and prices come only from the list in `Trainers.lua`.
- `/sink dump npc unverified` lists positions that came from Wowhead rather than from the game.
- IDs: `wowhead.com/forever/npc=<id>` and `/item=<id>`, and map IDs on [wago.tools](https://wago.tools/db2/UiMap?build=1.60.1.69893).

## Files

`Core.lua` loads first. It holds the saved variables (`SinkDB`), the shared `ns` table, the identity colour `ns.accent`, and player frame centering. `Options.lua` holds the `/sink` commands and the options window. Every other `.lua` file is one of the features above, and `MapPins.xml` is the map pin template. `scripts/check-globals.sh` flags undeclared globals when `luacheck` is not installed.

## Releasing

Bump `## Version` in the TOC, then tag and push:

```bash
git tag v0.0.1 && git push origin v0.0.1
```

The GitHub workflow checks the tag against the TOC, builds `Sink.zip` from the files the TOC lists, and attaches it to a release. `scripts/package.sh` builds the same zip locally. `.gitattributes` and `.pkgmeta` keep everything except the addon files out of the downloads.

## Forever notes

- Interface `16001`. The `_Camelot` TOC suffix loads only on Forever.
- It runs the Retail (12.x) API, not Classic's: no `GetSpellInfo` or `UnitAura`. `WOW_PROJECT_ID` reports Mainline, so use the interface number to tell the two apart.
- `RegisterEvent` with an event the client does not know throws and aborts the file, so wrap uncertain events in `pcall`.
- Unit GUIDs, names and similar values are secret in combat and instances. Check them with `ns.Secret` before reading them.
- After 100 Lua errors in a session the client stops reporting any more.
- Blizzard's UI code for Forever is on the [`forever` branch of wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever).
