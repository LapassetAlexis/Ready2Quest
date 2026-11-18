## Creatures/Codex audit (QuestCompanion, Forever client)

### 1. Data available per species

| Field | Static data (`ZoneCreatures_Forever.lua`) | Learned at runtime (`Bestiary.lua:432-490`, per character) | Saved at capture (`Capture.lua:857-860`, account) |
|---|---|---|---|
| npcID | yes (key) | from GUID, `NpcID()` :108 | key of `creatures[npc]` |
| name | `fr`, `en` (+`es` via `ns.SpanishName`) :30-38 | `UnitName` | `entry.name` |
| zone(s) | uiMapID block `Z[id]`; one npc can appear in several zones | `book[zoneID][npcID]` | `entry.zoneID` (first zone only) |
| level | `lvl={min,max}` | `UnitLevel` -> `species.level` | `entry.level` |
| rank/elite | `rank` 0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare -> `RANK_CLASS` (Bestiary:150) | `UnitClassification` -> `species.class` | `entry.class` |
| creature type | **not found** | `UnitCreatureType` (localized string) -> `species.type` | `entry.type` |
| family | **not found** | `UnitCreatureFamily` -> `species.family` | `entry.family` |
| faction-friendly flag | `f` = "A"/"H"/nil | — | — |
| spawn position | `ns.ZONE_CREATURE_POS[zone]`: "npc\txxxyyy" in thousandths of the map, 44 zones | — | — |
| displayID / model | **not found** in static data. `DisplaySizes_Forever.lua` has 13,932 display sizes keyed by displayID, with no npc link | `ModelLearnDisplay` (Companion.lua:~1929) probes `GetDisplayInfo` -> `account.display[npc]` (account-wide, `ModelDisplayTable` :1856) | — |

The **specimen record** is written by `SpecimenAdd` (CaptureSpecimens.lua:380). Fields: `id, npc, stars 1-3, shiny, zone, at, by, origin, name, trait, size`.

A species that has never been met has no type: `typeKey` is set only when `known` (Capture.lua:726).

### 2. Counts (ZoneCreatures_Forever.lua)

- **Zones:** 44.
- **Rows (species × zone):** 3,688.
- **Unique npcIDs:** 3,541. After the faction filter: 3,277 for Alliance, 3,392 for Horde.
- **Rank distribution (rows):** normal 2,831, elite 500, rare 263, rare elite 70, world boss 24 (12 unique).
- **Faction flags (rows):** `f=A` 273, `f=H` 153.

Species per zone:

| Range | Zones |
|---|---|
| 1–31 | Shen'dralas 1, Moonglade 3, Deadwind Pass 13, Mount Hyjal 31 |
| 48–100 | Most zones; median about 82 |
| 100–208 | Wetlands 110, Dustwallow 110, Alterac 113, Feralas 122, Tirisfal 131, Desolace 136, STV 161, Ashenvale 182, Barrens 208 |

Data is lazy-loaded through `ns.LazyZones(Z, Zone)` (line 3864). Read it with `ns.ZoneIds` / `ns.ZoneEach`.

### 3. Creatures page layout

Built by `BuildMenagerie` (JournalWindow.lua:1199). The window is 980×680, the nav is 220 wide, the usable width `INNER` is 710, `GRID_W` = 484 and `PREVIEW_W` = 210.

- **Row 1 (y=-106):**
  - Zone dropdown, 200 wide: "here", "all", then zones sorted A→Z with a level hint.
  - Rarity dropdown, 124 wide: `all/normal/elite/rare/boss`.
  - Sort dropdown: `no/name/level/rank/kills/date`.
  - Search box (210 wide) on the right. It matches only names of known species (Capture.lua:739).
- **Row 2 (y=-138):** 7 state chips: `all, todo, pinned, captured, missing, tokill, shiny` (:362).
- **Row 3 (y=-170):** type buttons from MenagerieView.lua.
  - "All" plus 8 square buttons of 24 px with a 4 px gap: beast, humanoid, undead, elemental, dragonkin, demon, giant, mechanical.
  - Tooltip: "%d captured · %d met". A summary of the active filter sits on the right.
- **Count text** (:2647-2654), one of:
  - "%d captured · %d met · %d in total"
  - the shiny variant
  - in todo/pinned states: "%d to complete · %d pinned"
- **List** (gridTop -206): 9 rows of 30 px (`MEN_ROW_H`), computed at :1261. Each row shows:
  - `#no` (fixed Pokédex number: zones by level, then level, then npc; Capture.lua:597-602)
  - type icon (padlock if unknown)
  - name in rarity colour, or "???"
  - pin and locate icons
  - 3 drawn stars
  - type text, or in todo state: zone + "Reserve N"
  - 3 px green bar if the normal version is captured
  - gold diamond for a shiny (filled = captured, outline = only seen)
  - gold tint if worn or pinned
- **Collection strip** below the list (h=70, `MenagerieCollection.lua:696`):
  - seal diamond, title "<zone> seal: have/need", 96×4 progress bar coloured by biome
  - reward line
  - trainer-title line ("Title · N species · M for next")
  - tooltip: per-type tiers and title list
  - "all zones" view shows "Seals: %d zones sealed"
- **Preview** on the right (`JournalPreviewMenagerie` :2459), 3 tiers:
  - Unknown: locked.
  - Met: rank/level, zone, Reserve count, pinned/todo, effects, chance %, kills, shiny status.
  - Captured: date + stars + size/trait of the Codex reference, plus an Equip action.
  - Also: rotatable 3D model (drag: `(cx-dragX)/60`), Normal/Shiny toggle, Locate button.
- **Pager** at y=-592.
- **Exploration page:** `CodexZoneCounts` gives `{total, todo, missing, complete}` per zone (MenagerieView:298), used at JournalCompletion.lua:306/747/766. "To complete" opens `OpenMenagerieTodo`.

### 4. Existing collection goals

- **Zone seal** (MenagerieCollection.lua:326-387)
  - Condition: every species of the zone, normal version, world bosses excluded, after the faction filter, merged with learned species. Zones with no static table cannot be sealed.
  - Reward: shinies ×1.5 in that zone (`SEAL_SHINY_MULT`).
  - Biome rewards: the 1st seal in a biome unlocks frame `seal_<biome>`, the 2nd unlocks background `seal_<biome>`. There are 10 biomes, with a zone→biome map for 41 zones (:44-56); the default is forest.
- **Type tiers:** common types need 10/20/40 captures, rare types (dragonkin, demon, giant, mechanical) need 5/10/20. Each tier gives +0.25 companion strength (`MenagerieTypeBonus`).
- **Trainer ranks** (species captured, either version):

  | Species | Title | Reward |
  |---|---|---|
  | 10 | apprentice | appât + lasso |
  | 25 | trainer | frame "trainer" |
  | 50 | seasoned | sifflet + bg "menagerie" |
  | 100 | master | sifflet + frame "master" |
  | 250 | grandmaster | 2 sifflets + bg "grandmaster" |

  Since 2.7 these are paid by the feats `men_species_<n>`; `men_species_500` (title 6) was added.
- **Stars:** "To complete" = the Codex reference has fewer than 3 stars (normal version, or shiny if owned) (MenagerieView:245).
- **Feats** (FeatsCatMenagerie.lua:468-531):
  - `men_rare_*`, `men_boss_1`, `men_type_*` (40 for common types / 20 for rare types), `men_types_master`, `men_stars3_1/25/100`
  - `shiny_seen/found_5/15/30/50`, `shiny_cap_1/10/25`, `shiny_3stars`, `shiny_sealed`, `shiny_zones_10`
  - `zone_seal_1/5/15`, `zone_seal_ek`, `zone_seal_ka`, `zone_all_biomes` (10)
  - Rewards: aids, titles, cosmetics; some are marked `soon`.
- **Other:** a free sifflet every 10 new species (`CAPTURE_GIFT_EVERY`, Capture.lua:884). The Bestiary "species defeated" and "named foes" parts are goals but are excluded from the exploration percentage (Bestiary:649-654).

### 5. Codex entry vs Reserve specimens

- **Collection record:** `capture.creatures[npc]` (`normal`, `shiny`, `stars`, `shinyStars`, `at`, `shinyAt`, name/class/type/family/zoneID). This summary is what every reader uses (MenagerieList, feats, seals, appearances).
- **Specimens:** `capture.specimens[id]`. `capture.codex[npc] = {best, bestShiny}` points to the reference specimen; every other specimen is in the Reserve (base 50 slots, `CAPTURE_RESERVE_BASE`).
- **How they stay in sync:**
  - `Reconcile` (CaptureSpecimens.lua:266) creates a "migration" reference for any owned version that lacks one.
  - `Sync` (:361) sets stars = best owned.
  - A reference cannot be released or traded (`"reference"`, :546, :575).
- **Can a species be in the Codex without a Reserve specimen?** Yes, that is the normal case: the Reserve holds only non-reference duplicates (`CodexReserveCounts` excludes references).
- **Can a species be captured without a Codex reference?** No: Reconcile always creates one.
- **No delete path:** no `creatures[x] = nil` exists anywhere.
- **Trades:** `EnsureEntry` (CaptureTrades.lua:715) can create `creatures[npc]` with `normal=false` and `keepReserve`.

### 6. Account-wide vs per character

| Data | Scope | Where |
|---|---|---|
| captures, specimens, codex, pins, paillettes, displays | **account** | `QuestCompanionDB.capture` (Capture.lua:288), merged from characters since 2.9.0 |
| learned bestiary (seen/killed/type/family) | **character** | `char.journal.bestiary` (Bestiary:130, Journal:204) |
| seals, type tiers announced, ranks | **character** | `CompanionData().collection` (MenagerieCollection:16, :282) |
| feats `men`/`shiny` | account | FeatsData.lua:50-51 |
| feats `zone` | character | FeatsData.lua:52 |
| page filters | account | `db.journalState` (JournalWindow:384) |

Seal progress counts account-wide captures, but the seal record itself and the faction filter are per character. `known` (met/killed) is per character, except that a captured species is always `known` (Capture.lua:681).