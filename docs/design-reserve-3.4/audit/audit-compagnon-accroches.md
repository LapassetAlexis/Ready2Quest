# Companion and worn specimen: hooks for new systems (QuestCompanion 3.3.1)

## 1. Which companion is shown, and where its state lives

- **One appearance ID per character:** `CompanionData().appearance` (Companion.lua:729), stored in `db.chars["Name-Realm"].companion`.
  - The catalogue is the mascots in `ns.COMPANION_APPEARANCES`, followed by captured creatures from `ns:CaptureAppearances()` (Companion.lua:922, Capture.lua:519).
- **Captured looks are per species and version, not per specimen ID:** the IDs are `"cap:<npc>"` and `"cap:<npc>:s"` (Capture.lua:529/533).
  - The specimen behind a look is the Codex reference: `capture.codex[npc].best` or `.bestShiny`.
  - `ns:CompanionWornSpecimen()` (SpecimenTraits.lua:187) resolves it. `ns:SpecimenWorn(id)` (CaptureSpecimens.lua:522) scans every character on the account.
- **Changing the companion:**
  - `CompanionSetAppearance(id)` (Companion.lua:1009) refuses a locked look. `CompanionCycleAppearance` is at :996.
  - `CompanionAskAppearance` (CompanionEffects.lua:842) asks for confirmation, then effects wait `EFFECT_DELAY = 120` s of real time (:33).
  - Opening a chest equips the new look directly (CompanionChest.lua:270).

| Attached to the companion (per character) | Attached to the specimen (account, `db.capture.specimens[id]`) |
|---|---|
| `needs{hunger,energy,mood,curiosity}`, `stage`, `stageReady`, `sleepy`/`sleepyLeft`, `lastSeen`, `name` (mascot only), `unlocked{}`, `seenZones`/`seenSub`/`zoneVisit`, `persona{scores,unlocked,played,formed}`, `pantry`, `milestones`, `chests`, `daily`, `inn`, `weekly`, `missionsDone`, `since`, `effects`, `collection`, `tipsSeen`, `tutoDone` | `id, npc, stars(1-3), shiny, zone, at, by, origin, name, trait, size`, plus trade fields `tradedFrom, tradedAt, firstOrigin, hops` (CaptureSpecimens.lua:29-35) |

- **What the worn specimen gives:**
  - Its `trait` becomes `CompanionTrait()` when `companionTraitSource == 1` (SpecimenTraits.lua:213).
  - Its `size` sets the model scale through `CompanionSizeScale` (:317).
  - `CompanionName()` returns the species name (Companion.lua:742).
- **Needs and stage stay on the companion.** They are not reset when the look changes.

## 2. Event bus

- **Internal bus:** `ns:RegisterCallback(event, fn)` and `ns:FireCallback(event, ...)` (Libs/Socle/Store.lua:61/65). Callbacks run under `pcall`, with `RecordError("callback:"..event)`.
- **Game events:** they go through the shared hub `ns.On(event, owner, fn, where)` (Libs/Socle/Compat.lua:371) or `ns.Listen(owner, HANDLERS, gate)`.

**Internal events fired by the addon**

| Event | Payload | Fired at |
|---|---|---|
| `STAMP` | `{id, kind, name, new=true, level, date}` | Journal.lua:243 |
| `SPECIMENS` | `"add"`, id | CaptureSpecimens.lua:407 |
| `SPECIMENS` | `"reference"`, id | :516 |
| `SPECIMENS` | `"release"`, id | :566 |
| `SPECIMENS` | `"take"`, id | :579 |
| `SPECIMENS` | `"slots"`, nil | :598 |
| `SPECIMENS` | `"pin"`, npc | :667 |
| `SPECIMENS` | `"gift"`, ids[1] | :897 |
| `SPECIMENS` | `"trade"`, tid | CaptureTrades.lua:782 |
| `PAILLETTES` | balance, ±n, reason | CaptureSpecimens.lua:611/621 |
| `HUNT` | true / false | :715/:725 |
| `FEAT_EARNED` | `{id, n, pts, scope, cat, …}` | Feats.lua:960 |
| `DEPARTURE` / `RETURN` | Ready2Quest payload | relayed by the R2Q bridge (Core.lua:233) |

- **Not found as bus events:** kill, capture success, quest turn-in, level-up, death, gathering, treat given, play time. These exist only as `ns:` methods that modules wrap. This wrapping is the de facto hook mechanism (`Wrap` in Daily.lua:616 and Personality.lua:226):

| Method | Arguments / return |
|---|---|
| `CompanionOnKill(name)` | Companion.lua:3784. Deduplicated within 2 s through `companionRT.lastKill`. |
| `CompanionEliteKilled()` | :3748. Returns a bool. |
| `CompanionOnLevel(level)` | :3755 |
| `CompanionOnDead()` | :3826 |
| `CompanionOnAlive()` | :3831 |
| `CompanionOnZone(newArea)` | :3703 |
| `CompanionOnStamp(stamp)` | :3773 |
| `CompanionOnNpc(kind)` | :3893. `kind` is merchant, innkeeper, trainer, flight, banker, quest or talk. |
| `CompanionOnLoot(msg)` | :3669 |
| `CompanionPet()` | :3618 |
| `CompanionCheckAuras()` | eating detection |
| `CompanionTick(seconds)` | :3399. Runs every 10 s of play time. |
| `GatheringRecord(itemID, count, zoneID)` | Gathering.lua:348. Returns true on the first harvest of that resource. |
| `TreatGive(kind)` / `TreatGrant(kind, opts)` | Treats.lua:255/238 |
| `ChestCheck(zoneID)` | CompanionChest.lua:231 |
| `CaptureResolve(rolling)` | `rolling.target` = {npcID, class, type, shiny}. Wrapped by 5 modules (QC2-CONTRATS.md). |

- **Companion game-event table:** Companion.lua:4386-4456. It covers `QUEST_TURNED_IN` (:4441), `PLAYER_LEVEL_UP`, `PLAYER_DEAD`, `PARTY_KILL`, `COMBAT_LOG_EVENT_UNFILTERED`, `CHAT_MSG_COMBAT_XP_GAIN`, `ZONE_CHANGED*`, `PLAYER_UPDATE_RESTING` and others. It is gated by `ModuleOn()` at :4468.
- **Mission counters:** `ns:MissionEvent(kind, n, zoneID, info)` (Daily.lua:517) and `ns:WeeklyEvent(kind, n, info)` (Weekly.lua:187).

## 3. Needs, mood and personality

- **Need constants (Companion.lua:42-125):**
  - Range: max 100, floor 15, start 80. `SERENE_FLOOR = 50` once the last stage is reached.
  - Decay per minute of play: hunger 0.6, energy 0.4, mood 0.3, curiosity 0.5.
  - Gains: `REST_GAIN = 4`/min while resting, `EAT_GAIN = 6`/min while eating.
  - Thresholds: `NEED_LOW = 35` (the companion voices a need), `HAPPY_MIN = 70` (needed to evolve).
- **Curiosity gains (:52-61):** new zone +15, new subzone +4, zone revisited after 2 h +8, subzone change +1 (at most every 30 s), dungeon entry +10 (at most every 600 s), elite kill +8, flight arrival +5, chest +20, harvest +1. Stamps give +15 (rare) or +10.
- **Mood gains:** quest turned in +12, level-up +25, pet +8 (15 s cooldown), blue or better loot +10, kill +1.
- **Other gains:** R2Q `DEPARTURE` gives hunger +10 if food is in the bags. `RETURN` gives energy +5.
- **Mood label:** `CompanionMood()` (:772) uses the average of the 4 needs: ≥75 → radiant, ≥50 → happy, otherwise dreamy. Sleepy overrides all three.
- **Effects:** strength is `0.5 + 0.5*ok/4`, where `ok` counts needs ≥ `EFFECT_NEED_OK = 50` (CompanionEffects.lua:333).
- **Stages:** levels 1/10/20/40/60, with model scale 0.70 to 1.18 (CompanionData.lua:201). A stage needs both the level and all 4 needs ≥70. A stage is never lost.
- **Personality (Personality.lua):**
  - 14 traits (:117). Each has a favourite need and an fx amplitude.
  - The favourite need gains ×1.5 and decays ×0.7 (:143-149).
  - A trait forms after `PERSONALITY_FORM_AFTER = 3*3600` s of play. Score weights: curiosity 0.1, meal 3, kill 0.15, elite 2, rest-minute 0.25, death 6, pet 2.
  - It affects: line variants (75 % chance), trait remarks (`NOTICE`, 900 s gap), the daily trait mission (`TRAIT_MISSIONS`, Daily.lua:39), and the trait effect.

## 4. Treats (Treats.lua)

- **Types:**

| Treat | Effect |
|---|---|
| biscuit | hunger to 100 |
| infusion | energy to 100 |
| bonbon | mood to 100, hearts |
| carte | curiosity to 100, and it names what is left in the zone |
| festin | all four needs to 100 |

- **Caps (:23):** 3 of each kind, 2 festins. When full, the treat is eaten at once.
- **Glutton trait:** +15 mood on every treat.
- **Sources:**
  - Zone completion at 25 % and 50 % gives the treat for the lowest need; 75 % gives a festin (:279-286).
  - A golden chest gives a festin and 2 random treats (:340).
  - Daily and weekly missions give rewards from `MISSION_REWARDS` (Daily.lua:52).
  - Shiny kills (Shiny.lua, per TECHNIQUE.md).
- **Giving:** Shift+click on the creature opens the pantry (:463), then `TreatGive`.

## 5. Per-day and per-session counters

- **Per day:**
  - `daily` uses `day = date("%Y-%m-%d")` (Daily.lua:235). It holds missions with `have`, `carry` and `money`, plus `inn.card/total/full` and `daily.perfect`.
  - The inn stamp is limited to once per day.
  - `capture.wary = {day, n[npc]}` (CaptureSpecimens.lua:752-790). Each capture of the same species that day gives −15 %, down to a floor of ×0.4, in hunt mode only.
  - `db.discovery.day` and `dayFirst` (Discovery.lua:340).
- **Per week:** `weekly`, keyed by `WeeklyId` (server reset), at Weekly.lua:110.
- **Session only, not saved:** `ns.companionSession` (:4389), `ns.companionRT` (cooldowns, `lastKill`, `restIdle`), `personaState`.
- **Lifetime:** `persona.played`, `companion.since`, `missionsDone`, and `FeatCount(key)` counters (`deaths`, `quests`, `taxi`, `mounted`; Feats.lua:1021). A 60 s feat clock exists (FeatsCatMenagerie.lua:723).

## 6. Saved variables

- **Single saved variable:** `QuestCompanionDB` (toc:15, Config.lua:18).
- **Account level:** flat settings (`companion*`, `capture*`, `journal*`), `modules`, `capture` (creatures, specimens, codex, paillettes, pins, wary, items, display), `feats`, `discovery`, `trainerHolders`, `journalState`, `journalHubZones`, `juke`, `migratedFromR2Q`, `memoriesDropped`.
- **Per character:** `chars["Name-Realm"] = {companion, journal, feats}` (Store.lua:142).
- **Migration:** there is no global DB version.
  - Defaults are merged through `RegisterDefaults` (Store.lua:40). Old saved-variable names are renamed through `legacyDB`.
  - One-shot flags run from the `OnAddonLoaded` chain (Core.lua:204, wrapped at Companion.lua:1879).
  - Per-table schemas:

| Schema field | Value | Set at |
|---|---|---|
| `capture.specV` | 1 | CaptureSpecimens.lua:118 |
| `capture.traitV` | 1 | SpecimenTraits.lua:51 |
| `capture.displayRev` | `MODEL_DISPLAY_REV` | Companion.lua:1868 |
| `daily.percentV` | 2 | Daily.lua:545 |

  - Readers repair data lazily (`type(x) ~= "table"` guards).

## 7. i18n

- FR and EN are declared in each file with `ns.RegisterStrings(FR, EN)`. Companion lines use `ns.RegisterCompanionLines({pool={{fr,en}}})`.
- ES lives in `Locales_es.lua` through `RegisterLocaleStrings("es")`. The `tools/i18n.py` steps are: `export`, translate `<lot>.es.json`, `import`, `check`, `fit`.

## 8. Tests

- `python3 tests/run_tests.py` uses lupa (Lua 5.1). It runs the core scenarios, then every `tests/modules/*.lua` file (run_tests.py:360), each in a fresh Lua state.
- To add a module test, create `tests/modules/<feature>.lua` using `T.Check/T.Say/T.ResetWorld/T.QNS/T.Mock`. Run it alone by passing its name.
- `TEST_SEED=n` (default 1, run_tests.py:39) seeds the random draws. In the harness, `DAILY_AUTO=false` and `SHINY_CHANCE=0`.