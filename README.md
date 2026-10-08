# Sink

The everything WoW: Forever addon.

- **Quest item warnings**: bag slot tint for quest items that are safe to delete, and the tracker lists them; a quest item still needed says until when on its tooltip.
- **Recipe vendors**: vendor tooltips list the recipes sold, checked when you know them; `/sink recipes missing` lists what you still lack.
- **Weapon skills and class training**: weapon master and class trainer tooltips show what you can still learn and at what level.
- **Profession recipes**: the Professions tab of the options window lists, for each profession you have, the trainer recipes you do not know yet and the skill each needs. Reagent tooltips list the recipes that use them, checked when you know them.
- **Library books**: every library book for the librarians in Stormwind and Undercity. Books you have not handed in or carried yet get a map pin, the librarians show how many you have handed in (10 for the necklace, 20 for the ring), and the Library tab lists them all. The tracker's Library Books section is off by default.
- **Items**: the Items tab of the options window lists every item Sink knows, with a search box: reagents and what they make, recipes and who sells them, quest items and the quests they are for or start. Hover one for its tooltip.
- **Rare scanner**: out of combat in the open world, nameplates, mouseover and target are checked for rares, quest elites and NPCs a quest still needs you at. What it finds gets a skull and is listed in the tracker's Nearby section; click a name there to target it. Needs enemy nameplates shown to see past your mouse, and cannot see a stealthed NPC before you do.
- **Treasure hunts**: the Cozy Sleeping Bag hunt's next stop is a pin on the map, with directions, moving on as you complete each step.
- **Fishing**: with a fishing pole equipped, the tracker shows in yellow when your Fishing skill, counting your pole and lure, is below what the zone needs for no fish to get away, with an estimate of how many you will land.
- **Gathering nodes**: hovering a mining or herb node on the minimap adds a red line for each one your skill is too low for, with the skill it needs.
- **Ability errors**: hides the repeating "Not enough energy" text and voice when you spam an ability.
- **Map icons**: vendors, trainers, flight masters, dungeon entrances and quest NPCs on the world map, filtered to your faction, class and professions. Click one to target and ping the NPC. Each kind (class trainers, profession trainers, innkeepers, auctioneers and so on) can be switched off on the Map Pins tab or in the world map's filter menu.
- **Level splits**: how long each level took in `/played` time, recorded for every character. The Splits tab lists them, and a small window for the last few levels can be turned on there.
- **Tracker**: a window styled like the objective tracker, listing rares and quest mobs seen nearby, the dungeon you are in (its bosses ticked off as they die, and your quests there with their objectives), unspent talent points, gathering tracking that is off (click to turn it on), quest items to delete (click to delete), dungeons with quests left (click a red quest to see its giver on the map, right-click a dungeon to ignore it), class training with its total cost (hover a skill for its tooltip, right-click to ignore it; the Ignored tab brings it back), and weapon skills you can learn.

Type `/sink`, click Sink in the addon compartment, or click the tracker's title to open the options window.

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
| `/sink version` | The version you are running |
| `/sink items [add <itemID> <questID> \| remove <itemID> \| on \| off]` | Quest item rules and warnings |
| `/sink recipes [add <itemID> [npcID] \| remove ... \| missing \| on \| off]` | Recipe vendors; `add` uses your target when no NPC ID is given |
| `/sink weapons [masters \| on \| off]` | Weapon skills you can learn and who teaches them |
| `/sink errors [on \| off \| toggle \| list]` | The ability error mute |
| `/sink map [add <name> \| remove <name> \| on \| off \| trainers all\|mine \| classes all\|mine]` | Map icons |
| `/sink splits` | Show or hide the splits window |
| `/sink tracker` | Show or hide the tracker |
| `/sink dump loc \| target \| trainer \| skills \| taxi \| npc [unverified]` | Developer dumps of IDs and coordinates, with a paste line to copy |

Each group also answers `help`, for example `/sink map help`.

## Adding data

The built-in tables sit at the top of their files: quest item rules in `QuestItems.lua`, recipe vendors in `Recipes.lua`, weapon masters in `Weapons.lua`, class training in `Trainers.lua`, profession trainer recipes and reagents in `Professions.lua`, map icons in `MapPins.lua`, and dungeons, NPCs and quests in `Quests.lua`. Each file's header comment describes its format.

- Stand next to an NPC and use `/sink dump target`, or stand at a place and use `/sink dump loc`. Both print a line to paste that is marked `verified = true`. The client never reports NPC positions, so the dump uses yours.
- `/sink dump trainer` at an open trainer window prints the table entry for that weapon master or class. A class's entry has every skill with its level and price; set the window's filter to show everything first, since it only dumps what the window lists.
- Merchant and weapon master windows are recorded as you visit them, so tooltips fill in without any typing. Class trainers are not: their skills and prices come only from the list in `Trainers.lua`.
- `/sink dump npc unverified` lists positions that came from Wowhead rather than from the game.
- Flight masters ("Gryphon Master", "Bat Handler" and so on) go in `MapPins.lua` like any NPC, but are drawn as the taxi node they stand at: that node's icon then targets and pings them on click.
- IDs: `wowhead.com/forever/npc=<id>` and `/item=<id>`, and map IDs on [wago.tools](https://wago.tools/db2/UiMap?build=1.60.1.69893).

## Files

`Core.lua` loads first. It holds the saved variables (`SinkDB`), the shared `ns` table, and the identity colour `ns.accent`. `Options.lua` holds the `/sink` commands and the options window. Every other `.lua` file is one of the features above, and `MapPins.xml` is the map pin template. `scripts/check-globals.sh` flags undeclared globals when `luacheck` is not installed.

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
