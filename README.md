# Sink

A starter addon for **World of Warcraft: Forever**, the Classic+ flavor that entered beta on 2026-09-17 and launches on 2026-11-04.
It does six things: it can keep your player frame horizontally centered no matter what Edit Mode does (off by default, `/sink on` enables it), it warns about quest items that are safe to delete, it shows on vendor tooltips which of their recipes you still need to buy, it hides the "Not enough energy" text and voice that repeat on every press when you spam an ability, it puts icons with tooltips on the world map, and it tracks which weapon skills your class can still learn and who teaches them.

## Install

The quickest way is `Sink.zip` from the [releases page](https://github.com/eylgg/sink/releases): extract it and you get a `Sink` folder containing only the addon files. Put that folder at the path below.

For a working checkout instead: Forever installs next to your other WoW flavors in a `_classic_beta_` folder, and this folder needs to end up at:

```
World of Warcraft/_classic_beta_/Interface/AddOns/Sink/
```

On macOS the game normally lives in `/Applications/World of Warcraft`. A symlink keeps the game pointed at this checkout while you edit it:

```bash
ln -s "$PWD" "/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/Sink"
```

Then start the game (or `/reload` if it is already running), enable **Sink** in the AddOns list on the character screen, and type `/sink` in chat.

The folder name and the TOC's base name must match: `Sink/` and `Sink_Camelot.toc`. If you rename the addon, rename both, and also the `SinkDB` saved variable, the `Sink_OnAddonCompartmentClick` function, and the `/sink` slash command.

## Commands

| Command | Effect |
| --- | --- |
| `/sink` | Open the options window, which also opens with `/sink config` or by clicking Sink in the addon compartment. Its pages are icon tabs down the right edge, as on the professions window |
| `/sink status` | Show whether centering is on and the current offsets |
| `/sink on`, `/sink off`, `/sink toggle` | Turn player frame centering on or off. It is off by default, and off puts the frame back where your Edit Mode layout has it |
| `/sink x <n>` | Horizontal offset from the center of the screen, -800 to 800. Negative moves left |
| `/sink y <n>` | Height of the frame's bottom edge above the bottom of the screen, 0 to 800. Default 250, which matches Blizzard's default layout height |
| `/sink reset` | Back to the default offsets |
| `/sink center` | Re-apply the position right now |
| `/sink items ...` | Quest item warnings, see below |
| `/sink recipes ...` | Recipe vendor tooltips, see below |
| `/sink weapons ...` | Weapon skills and weapon masters, see below |
| `/sink errors ...` | Ability error spam, see below |
| `/sink map ...` | Icons on the world map, see below |
| `/sink dump ...` | Developer dumps of IDs and coordinates, see below |

## Quest item warnings

Some quest items stay in your bags after the quest that needed them is done. Sink keeps a list of "item X is safe to delete once quest Y is complete" rules and warns you in three ways, quiet to loud:

1. A yellow "Safe to delete, quest complete" line on the item's tooltip once the quest is done, and a grey "Keep until ..." line before that.
2. A chat line and a short on-screen notice when the item is spotted in your bags after the quest is complete.
3. A popup with **Delete** and **Keep** buttons, once per item per session. Delete picks the item up and destroys it, the same as dragging it out of your bags.
4. A red tint on the item's bag slot for as long as it is safe to delete, in both the separate and the combined bag windows.

The bag check runs after a quest turn-in, on login, and whenever your bags change, so it also catches an item you loot late. Nothing is shown during combat; the check waits until combat ends.

Built-in rules live at the top of `QuestItems.lua`, one per item: the item ID and the quest ID, or a list of quest IDs when every one of them must be complete.

| Command | Effect |
| --- | --- |
| `/sink items` | List every rule with quest and bag status |
| `/sink items add <itemID> <questID>` | Add a rule for this character (saved in `SinkDB.questItems`) |
| `/sink items remove <itemID>` | Remove a rule you added in game |
| `/sink items scan` | Re-check the bags and show the popup again |
| `/sink items on`, `/sink items off` | Turn the warnings on or off |

Rules added in game are lost on logout until Blizzard fixes the saved-variables bug on the beta, so copy the ones you want to keep into `QuestItems.lua`. Quest names come from `C_QuestLog.GetTitleForQuestID`, which can be empty until the client has cached that quest; the addon asks for it and shows `quest #99134` in the meantime.

## Recipe vendors

Hover a vendor and its tooltip lists the recipes it sells, with a green check for the ones you already know and a red cross for the ones you do not. The recipe item's own tooltip gets a "sold by" line in return.

"Known" is read from the recipe item's tooltip data, which carries the red "Already known" line once you have learned it. That works for every profession without opening a profession window. If the item is not in the client cache yet the line shows "(loading)", the data is requested, and the next hover has the answer.

Built-in vendors live at the top of `Recipes.lua`: NPC ID, name, location and the item IDs of the recipes sold.

Opening any merchant window remembers the vendor's recipes, whether or not that vendor is in the list, so the list of purchasable recipes grows as you visit vendors without you typing anything. Nothing is printed.

`/sink recipes missing` opens a small movable window with every listed recipe you still lack, grouped by vendor with its location. It refreshes when you learn a recipe or a merchant window updates, and Escape closes it.

| Command | Effect |
| --- | --- |
| `/sink recipes` | List vendors and which of their recipes you know |
| `/sink recipes add <itemID> [npcID]` | Add a recipe to a vendor. With no NPC ID, your current target is used |
| `/sink recipes remove <itemID> [npcID]` | Remove a recipe you added in game |
| `/sink recipes missing` | Window listing recipes you can buy but do not know, by vendor |
| `/sink recipes on`, `/sink recipes off` | Turn the tooltip lines on or off |

Wowhead's Forever database is the quickest place to find IDs (`wowhead.com/forever/npc=<id>`, `wowhead.com/forever/item=<id>`). In game, `/sink recipes add <itemID>` while targeting the vendor records the same thing without looking anything up. Like the quest item rules, vendors added in game are lost on logout until the beta's saved-variables bug is fixed.

## Weapon skills

Which weapon skills your class can learn, which you have and how far along they are, and which weapon master teaches the rest. Hover a weapon master, or their map icon, and the tooltip lists everything they teach, in this order: a red cross for each skill you can learn, with the level it needs when there is one, such as Polearms (20), sorted by level and then name; a green check for each skill you know; plain grey for each one your class cannot take. Every group is alphabetical, and the list commands use the same order. Opening a weapon master's window records what they teach and prints nothing. On by default.

Three sources feed it. Learned skills and ranks come from `C_SkillInfo`, the API behind Forever's own Skills panel, keyed by the same skill line IDs vanilla used (Swords 43, Daggers 173, and so on), and from the proficiency spell each trainer grants, as a second signal. A lookup by name is the last fallback. Fist weapons are the odd one: weapon masters offer them, but on Forever the rank is kept under the Unarmed skill every character has, so the Skills page never lists them and the proficiency spell is the only sign a character has trained them. What a weapon master teaches comes from the built-in table at the top of `Weapons.lua`, seeded from Wowhead's Forever database and Warcraft Wiki for the eight vanilla masters, and from the trainer window itself: opening one records what it lists, the way merchants record recipes. Which skills your class can learn has no API, so it is a table of the vanilla proficiencies; the trainer window only lists what your class can take, which confirms the table as you visit, and a skill you turn out to know is shown whether or not the table lists it. The window also carries the level each skill needs, which is recorded and shown; Polearms at 20 is in the table to begin with. Wands come from class trainers, not weapon masters, and the table says so.

| Command | Effect |
| --- | --- |
| `/sink weapons` | The weapon skills your class can still learn, each with the city of a weapon master on your side who teaches it, such as `Guns (Thunder Bluff)`, or `Polearms (20, Undercity)` when a level is needed |
| `/sink weapons masters` | The weapon masters on your side and what they teach, marked the same way |
| `/sink weapons on`, `/sink weapons off` | Turn the tooltip lines on or off |

`/sink dump trainer` prints the open trainer window's services and a line for the master table. The window lists only what your class can take, and its Available, Unavailable and Already Known boxes narrow that further, so the dump and the recording see one class's view; the built-in table is the full list. Like the other in-game recordings, masters recorded from the window are lost on logout until the beta's saved-variables bug is fixed.

## Quests

`Quests.lua` keeps one record per dungeon, NPC and quest, linked by ID, so each fact is written once:

- `ns.dungeons`, by instance ID: the Map table ID that `GetInstanceInfo()` returns inside, 2999 for Ruins of Lordaeron. Wowhead's "zone" ID for a dungeon (16611) is an area ID; its row in the AreaTable names the map as its continent. Each dungeon has a name, `minLevel`, `maxLevel`, and the entrance's `map`, `x` and `y`. A position recorded on a continent map, which is what `/sink dump loc` gives in a cave with no zone map of its own (Wailing Caverns gives Kalimdor, 1414), is fine: the pin is drawn on the zone that point lies in, found with `C_Map.GetMapInfoAtPosition` and converted through world coordinates. NPC positions work the same way.
- `ns.npcs`, by NPC ID: the name, and either `map`, `x`, `y` for one outside or `instance` for one inside a dungeon.
- `ns.quests`, by quest ID: `name` (shown until the client has the quest cached), `faction` (`"Horde"`, `"Alliance"` or `"Both"`, the default), `minLevel` where known (else the dungeon's), `dungeon` (the instance ID the quest is for) and `start`, how you get it: `{ npc = id }` from an NPC, `{ drop = id }` from an item that NPC drops, `{ item = id }` from an item you loot from the ground, recorded in `ns.questItems` with the `instance` it is found in, `{ after = id }` once the quest before it is turned in, and `{ after = id, npc = id }` when that NPC offers it then: Thrall gives Hidden Enemies 1/5 and, once it is turned in, 2/5, so his pin comes back for part 2. A quest with an `after` counts as available only once the quest before it is done. A quest can also name an NPC it sends you to, `objective = { npc = id }`: Hidden Enemies 2/5 sends you to Neeru Fireblade. That NPC gets a yellow "?" pin titled "Quest Objective" while the quest is in your log and the objective is not done: until its objectives are complete, or, for a talk-to quest with no objectives, which the game counts complete as soon as it is taken, until it is turned in. The map redraws when that changes. `finish = { npc = id }` is who takes the quest in; they get a yellow "?" pin titled "Turn In" once the quest is ready to hand in, its objectives complete or, for a talk-to quest, straight away. A giver's pin says "Dungeon Quest" when one of their quests is for a dungeon, and "Quest" otherwise, as for the later parts of a chain. The starts and finishes not given in game, and the NPC positions they needed, were filled in from Wowhead's Forever database and are unverified until checked: `/sink dump npc unverified` lists them, NPCs recorded inside a dungeon included.

From these the map draws each dungeon's entrance with its quests and a "Dungeon Quest" pin on each NPC who gives one. A drop whose NPC is inside the quest's dungeon reads "Kill "The Baron" inside", an NPC inside it who gives the quest reads "Talk to "Nalpak" inside", and an item on the ground inside it reads "Loot inside": "Crest of Lordaeron (Loot inside)". All of them are yellow until done, never red.

Quests linked by `after` make a series. The step follows the name on the map tooltips, "Hidden Enemies (3/5)" on Ragefire Chasm and "(1/5)" on Thrall, though not on the first quest of a series that starts inside a dungeon, where "(Kill "The Baron" inside)" says enough, and the objective tracker adds it to the end of the title: "Unending Torment (2/5)". A series whose parts all have their own names, such as Searching for and Returning the Lost Satchel, keeps its steps in the tracker, and on the map tooltips shows them from the second part on: "Leaders of the Fang (3/3)", but plain "Searching for the Lost Satchel". Sink hooks the tracker's `UpdateSingle`, which sets each quest's header on every update, and appends the step to the header text; if the longer title would wrap onto another line, Blizzard's title is kept so the tracker layout never breaks.

## Ability errors

Press an ability you cannot afford and the game tells you twice: red text at the top of the screen and your character's voice ("I don't have enough energy", "Not enough mana"). Spam the button and both repeat on every press. Sink hides those messages, text and voice, along with the "not ready yet" cooldown errors. This is on by default.

On Retail these messages never show at all: `UIErrorsFrame` keeps a `BLACK_LISTED_MESSAGE_TYPES` table with every "out of ..." and cooldown error in it, and a blacklisted type gets neither text nor sound. Forever replaces that table with a single entry (`Blizzard_UIErrorsFrame/Camelot/UIErrorsFrameOverrides.lua`) to bring the Classic messages and voices back. The only one it throttles is "Not enough mana", so energy and rage users get the worst of it.

Sink uses Blizzard's own switch for that table, `UIErrorsFrame:SetMessageTypeEnabled(type, false)`, on each muted type. Turning the mute off puts every type back the way it was. Nothing else about the frame is touched, so other errors show and sound exactly as before.

The muted types are listed at the top of `Errors.lua` by their `LE_GAME_ERR_*` name: every "Not enough ..." resource error and the two "not ready yet" cooldown errors. "Out of range" and "You are facing the wrong way" are not muted; they tell you something the action bar does not. Names the client does not know are skipped.

| Command | Effect |
| --- | --- |
| `/sink errors` | Whether the mute is on and how many errors it hid this session |
| `/sink errors on`, `/sink errors off`, `/sink errors toggle` | Turn the mute on or off. Also a checkbox in the options window |
| `/sink errors list` | The messages that are muted |

To silence every error voice line instead, including ones Sink leaves alone, untick **Error Speech** under Options > Sound. That is a game setting, keeps the red text, and needs no addon.

## Map icons

Icons on the world map with a tooltip on mouseover. The tooltip says what the icon is for, in Sink's colour; for a recipe vendor it also lists the recipes sold and whether you know them, and for a weapon master the skills taught, the same lines those modules put on the NPCs' own tooltips. Clicking an icon that marks an NPC targets them and pings them with the game's own ping, so the ping marker shows where they stand. On by default.

Forever runs the Retail map, which is built for this. `WorldMapFrame` holds a list of data providers; whenever the map opens or changes zone it asks each one to refresh, and the provider asks the map for pins from a named template (`SinkMapPinTemplate` in `MapPins.xml`, the one XML file, because the map's pin pools need a virtual template). A pin is an ordinary frame the map positions from normalized coordinates, and the map wires its mouse scripts to the pin's `OnMouseEnter` and `OnMouseLeave` methods, which is where the tooltip lives. Pins sit on the zoomed canvas, so each one sets scaling limits that the map divides by the canvas scale on every zoom change; the icons keep the same size on screen at any zoom. Pins that land on each other are nudged apart on screen by the map's own nudging, with the values Blizzard's flight points use, while their stored positions stay exact; two Orgrimmar weapon masters who stand side by side are the case that needed it.

Targeting and pinging are protected actions an addon cannot perform itself, so each icon carries a secure action button as an overlay that runs a macro on a real click: clear the target, `/targetexact <name>`, `/ping [@target,exists]`, which sends the plain contextual ping only when the NPC was found, and `/targetlasttarget [@target,noexists]`, which gives you your previous target back when they were not. Targeting by name finds the NPC when they are loaded around you, so it is for "which one is the blacksmith" in town, not for locating someone across the zone. A secure button's attributes can only be set out of combat, so icons first shown during a fight are redone when it ends; right-click still zooms the map out.

Each icon is drawn round, inside a one-pixel ring in Sink's identity colour (see below) with a one-pixel dark outline. That is three textures in the template, each clipped to a circle by Blizzard's `CircleMask` atlas, the mask the party and totem frames use, so no artwork ships with the addon. Pixel snapping is off on the textures and masks, as on Blizzard's small round frames, which keeps the circle edges smooth at this size. The ring turns white under the mouse.

Built-in icons live at the top of `MapPins.lua`, keyed by the zone's map ID. Each one has `x` and `y`, an `icon` texture, a `note` that becomes the tooltip's text, a `name` shown when there is no note and used by the list and `/sink map remove`, an `npc` ID that ties it to a vendor in `Recipes.lua` or a weapon master in `Weapons.lua`, and for a class trainer whose note is a title rather than "<Class> Trainer", such as "High Priest", a `class` field naming the class. A note that starts with a profession rank, Apprentice, Journeyman, Expert or Artisan, gets the skill cap that rank teaches to, such as "Journeyman Blacksmith (150)". A city has several trainers per profession, one per rank, and only the one you need is drawn: the lowest rank whose cap is above your current maximum in that profession, so at Blacksmithing 150 you see the Expert; the lowest rank of all if you do not have the profession; the highest if you have outgrown every one on the map. The word after the rank names the profession, and the map redraws when your skills change. `/sink map` still lists every pin.

Which professions' trainers are drawn at all depends on you, unless "Show all profession trainers" is on: the secondary professions, cooking, fishing and first aid, always; your own primary professions always; and the other primary professions only while you still have a free slot, so once you have picked two, only their trainers remain. A class trainer is drawn only for its class unless "Show all class trainers" is on.

Dungeon entrances are drawn with the map's own blue portal (the `Dungeon` atlas) and their level range after the name, such as "Ruins of Lordaeron (11 - 24)". The tooltip lists the dungeon's quests for your faction: a red cross for one not in your log, a yellow waiting mark for one in it, a green check for one you have done, in that order and alphabetical within each. A quest that drops inside the dungeon shows how to get it, "Unending Torment (Kill "The Baron" inside)", and stays yellow until it is done, never red. An NPC who gives a dungeon quest, such as Deathguard Kristof in Tirisfal, gets a yellow "!" pin titled "Dungeon Quest" with the same lines, drawn only while they have a quest for you: for your faction, neither in your log nor done, and your level at least the quest's minimum. The map redraws when you level or accept, turn in or abandon a quest. Clicking a dungeon takes you to where its quests are: with one quest you can pick up from an NPC, the map opens on that NPC's zone and their pin pulses for a few seconds; with more, a menu lists them to choose from. The tooltip says so in grey when there is something to find. Other pins pass left clicks through to the map, so they zoom in as before, and right-click still zooms out everywhere. "Show dungeons" turns the entrances off. None of these pins are listed in `MapPins.lua`; they are built from the records in `Quests.lua`, see Quests below.

Those boxes, and "Show map icons", live on the Map Pins tab of the options window, `/sink`, under their own headings.

A pin, or an NPC or dungeon record in `Quests.lua`, carries `verified = true` when its position was taken in game, next to the NPC with `/sink dump target` or at the place with `/sink dump loc`; the pasted lines include it. Without it the position came from elsewhere, such as Wowhead, and `/sink dump npc unverified` lists it. Coordinates are 0 to 1 across the zone map, which is Wowhead's numbers divided by 100. Wowhead's page text rounds them to whole percent; the map data embedded in the page (`g_mapperData` in the source) has one decimal, about five yards in a zone this size, and also names the map ID. For the exact spot, stand there and use `/sink dump loc`, or target the NPC and use `/sink dump target`. Map IDs come from the client's UiMap table, which [wago.tools](https://wago.tools/db2/UiMap?build=1.60.1.69893) lists per build; the dumps print it as well.

| Command | Effect |
| --- | --- |
| `/sink map` | List the icons by zone |
| `/sink map add <name>` | Put an icon where you stand, saved per character (`SinkDB.mapPins`) |
| `/sink map remove <name>` | Remove an icon you added in game |
| `/sink map on`, `/sink map off` | Show or hide the icons |
| `/sink map trainers all`, `/sink map trainers mine` | Every profession trainer, or only the ones for you (the default) |
| `/sink map classes all`, `/sink map classes mine` | Every class trainer, or only your class's (the default) |

Like the other in-game additions, icons added with `/sink map add` are lost on logout until the beta's saved-variables bug is fixed, so paste the printed line into `MapPins.lua` to keep one.

## Developer dumps

`/sink dump ...` prints the IDs and coordinates the built-in tables are made of, in a form you can paste. These change nothing; they are for filling in `MapPins.lua`, `Recipes.lua` and `QuestItems.lua`. Chat text cannot be selected, so a dump that ends in a paste line also opens a small box with that line already selected: Cmd+C on a Mac or Ctrl+C on Windows copies it, and Enter or Escape closes the box.

| Command | Effect |
| --- | --- |
| `/sink dump loc` | Zone, map ID and parent map, subzone, and your position both as percent and as the 0 to 1 values, then a map icon line to paste |
| `/sink dump target` | Your target's name, NPC ID, GUID and tooltip lines, then a map icon line with the NPC ID, name and title filled in |
| `/sink dump trainer` | The open trainer window's services, and for a weapon master a line for the table in `Weapons.lua`; all of it also opens in a window, selected, to copy |
| `/sink dump skills` | Every skill line the client lists for this character, then each weapon skill with its skill line and proficiency spell status |
| `/sink dump npc` | Every position in the built-in tables, NPCs, places such as zeppelins, quest NPCs and dungeon entrances, by zone, with the file it is in; unverified ones are marked |
| `/sink dump npc unverified` | Only the positions not yet taken in game, the ones to check with `/sink dump target` next to the NPC or `/sink dump loc` at the place |

The client only reports positions for the player and group members, never for an NPC, so `/sink dump target` uses your own position for the icon line; stand next to the NPC first. For a vendor that never moves that is exact. Wowhead's page source carries one-decimal coordinates for every spawn point (`g_mapperData`) and the same map ID, which is where the built-in entries came from.

## Identity colour

Everything Sink prints or draws uses one colour, `ns.accent` at the top of `Core.lua`: the `Sink:` chat prefix, the sold-by line on recipe tooltips, vendor names in the recipe list and its window title, and the ring and tooltip title of each map icon. Change it there and everything follows; `ns.Accent(text)` wraps a string in it for chat and tooltips. Colours that carry meaning are not tied to it: green on and red off, the yellow quest item warnings, the check and cross marks.

The value is oklch(0.558 0.146 230), which in sRGB is 0, 0.505, 0.721 or `#0081B8`; the red channel lands just below zero, so the colour sits a hair outside sRGB and clamps.

## How it works

Player frame centering is off until you enable it with `/sink on` or the checkbox in the options window, so installing the addon moves nothing by itself. Once on, the choice is saved.

Forever runs the Retail (Mainline) UI, so the player frame is an Edit Mode system frame. Edit Mode re-anchors it every time a layout is applied: at login, on a layout switch, when Edit Mode closes, on a UI scale change. It does that through a Lua wrapper on the frame, so `hooksecurefunc(PlayerFrame, "SetPoint", ...)` fires after every Blizzard reposition, and the addon immediately puts the frame back at the configured spot.

Three rules keep this safe:

- **Combat.** The player frame is protected, so nothing is moved while `InCombatLockdown()` is true. The move is retried on `PLAYER_REGEN_ENABLED`.
- **Edit Mode.** While Edit Mode is open the addon stays out of the way so you can still drag the frame. When Edit Mode closes (`EventRegistry` event `EditMode.Exit`) the frame is re-centered.
- **Re-entrancy.** The addon's own `SetPoint` call is skipped by the hook through an `applying` flag, so there is no loop.

Offsets are stored in UIParent units and divided by the frame's scale before `SetPoint`, exactly as Edit Mode's own `ApplySystemAnchor` does, so the "Frame Size" setting in Edit Mode does not shift the frame.

## Files

| File | Purpose |
| --- | --- |
| `Sink_Camelot.toc` | Manifest. `_Camelot` is Forever's game-type suffix, so this addon only loads on Forever. Interface `16001` |
| `Core.lua` | Saved variables, the positioning logic, event handling, the `SetPoint` hook |
| `QuestItems.lua` | Quest item rules, the bag scan, the tooltip line, the bag slot tint, the Delete/Keep popup |
| `Recipes.lua` | Vendor recipe list, the known-recipe check, the vendor and recipe tooltip lines, merchant reminders, the missing-recipes window |
| `Weapons.lua` | Weapon skill lines, class proficiencies, the weapon master table, trainer window recording, the tooltip lines, `/sink weapons` |
| `Quests.lua` | Dungeon, NPC and quest records, the quest tooltip lines, the series step in the objective tracker |
| `Errors.lua` | The muted message types and the blacklist switch that hides their text and voice |
| `MapPins.lua` | Built-in map icons, the pin mixin with its tooltip and click-to-target overlay, the data provider, the `/sink map` commands |
| `MapPins.xml` | The pin template: round icon, identity-colour ring, dark outline; the only XML file |
| `Dump.lua` | `/sink dump loc` and `/sink dump target`, developer output for filling in the tables |
| `Options.lua` | `/sink` commands, the options window with its General and Map Pins tabs, the addon compartment click |
| `.luacheckrc` | Globals list for `luacheck`, if you lint |
| `scripts/package.sh` | Builds `dist/release/Sink.zip` from the files the TOC lists |
| `scripts/check-globals.sh` | Flags globals a Lua file uses that are neither standard nor listed in `.luacheckrc`, for when luacheck is not installed; a missing function shows up here, not as a syntax error |
| `.github/workflows/release.yml` | GitHub Actions: builds the zip and attaches it to a release named after the version on every `v*` tag |
| `.gitattributes` | Keeps GitHub's automatic "Source code" archives to the addon files only |

The Lua files share a private table through the `local ADDON_NAME, ns = ...` idiom; `Core.lua` fills it and the other files use it, which is why the TOC lists `Core.lua` first.

## Releasing

Users should only ever get the addon files, so two things keep the README, the lint config and the tooling out of downloads.

**Tagged releases** go through GitHub Actions. Nothing needs to be switched on or configured; the workflow's own token is allowed to create releases. Tag the commit whose TOC carries the matching version, then push the tag:

```bash
git tag v0.0.1 && git push origin v0.0.1
```

The workflow in `.github/workflows/release.yml` checks that the tag matches `## Version` in the TOC, builds `Sink.zip` (a `Sink/` folder holding the TOC and the files it lists, nothing else), creates the release **Sink 0.0.1** for that tag with generated notes, and attaches the zip. Edit the notes on the web afterwards if you want.

**GitHub's own "Source code" links** on tags and releases are built with `git archive`, which honours `.gitattributes`. The file marks everything except the addon files as `export-ignore`, so those archives are clean too. Their top-level folder is named after the repository and tag, `sink-0.0.1`, so anyone using one has to rename it to `Sink`; point people at `Sink.zip` instead.

**Locally**, `scripts/package.sh` builds the same `dist/release/Sink.zip` from the committed tree, so you can hand someone a zip without tagging. It reads the file list from the TOC, so a new Lua file only needs to be added there.

## Forever-specific notes (beta build 1.60.1.69893)

- **Interface number** is `16001`. Check yours in game with `/dump select(4, GetBuildInfo())`.
- **TOC suffix** `_Camelot` loads only on Forever. `_Mainline` also loads on Forever but would load on Midnight too. A plain `Sink.toc` with `## Interface: 16001` works as well.
- **It is the Retail API.** Forever shares the vast majority of the 12.1.5 (Midnight) API, including Edit Mode, `C_*` namespaces and the Settings panel. The old Classic globals such as `GetSpellInfo`, `UnitAura` and `GetTalentInfo` do not exist. Port from Retail code, not Classic code. Note that `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` on Forever, so do not use that constant to tell the two apart; use the interface number.
- **Beta bug: saved variables never load.** The client writes `SavedVariables` on logout but does not read them back at login, so your offsets reset each session for now. Nothing in the addon needs to change; it will persist once Blizzard fixes the client.
- **Beta bug: Lua error cap.** After 100 errors in a session the client stops reporting any. If Sink seems silent, check that another addon is not flooding errors, then `/reload`.
- **Unknown events throw.** `RegisterEvent` with a name the client does not know raises an error and aborts the rest of the file. `Core.lua` wraps the one uncertain registration in `pcall`; do the same for anything you add.
- **Secure snippets are broken on the beta** (`loadstring_untainted` is missing). That breaks action-bar and click-cast addons, not this one. Avoid `SecureHandler*` templates until Blizzard fixes it.
- **Midnight's combat restrictions apply.** Aura data, creature health and damage numbers are "secret" values in combat, and so are unit GUIDs and names in tooltips, in combat and in instances. A secret value can be passed along but reading it (`strsplit`, `tostring`, comparing) is an error blamed on the addon. Sink checks with `ns.Secret(value)` in `Core.lua` (`issecretvalue` and `canaccessvalue`) before reading any unit data; a secret GUID means that tooltip gets no Sink lines.
- No addon site has a Forever game flavor yet, so distribute as a zip or a git checkout.

## Sources

- [TOC format](https://warcraft.wiki.gg/wiki/TOC_format) on Warcraft Wiki: the `_Camelot` suffix, interface numbers, directives.
- [forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit): day-one measurements of the beta client, including the bugs above and a captured API baseline.
- [AnyMove Forever](https://github.com/Pirson-s-Addons/AnyMoveForever): a working Forever addon that moves Edit Mode frames the same way.
- [wow-ui-source, `forever` branch](https://github.com/Gethe/wow-ui-source/tree/forever): Blizzard's UI code for Forever. `Blizzard_EditMode/Shared/EditModeSystemTemplates.lua` has `ApplySystemAnchor` and `SetPointOverride`; `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` has the frame, tab and slider templates the options window in `Options.lua` is built from; `Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua` and its `Camelot/UIErrorsFrameOverrides.lua` are what `Errors.lua` works around; `Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua` is the pin and data provider API `MapPins.lua` uses.
- [World of Warcraft: Forever](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever) on Warcraft Wiki for release and beta dates.
- [wago.tools UiMap](https://wago.tools/db2/UiMap?build=1.60.1.69893): the Forever build's map table, for the zone IDs `MapPins.lua` is keyed by.
