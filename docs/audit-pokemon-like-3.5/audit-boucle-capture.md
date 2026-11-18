## Quest Companion 3.5 audit: capture loop and long-term pacing

Source: `/Users/alexis.lapasset/Projects/ReadyToQuest/QuestCompanion/`. The simulation code and its outputs are in `/private/tmp/claude-2007623921/-Users-alexis-lapasset-orca-workspaces-ReadyToQuest-qc-reserve-design/c71c5d45-23dc-4285-87e3-69915616ccc5/scratchpad/scan3/sim/`: `parse.py`, `sim.py`, `out.txt` and `out_slow.txt`.

### 1. The loop, from kill to specimen
1. **Kill counted.** You, your pet or your group must have engaged the mob, then it dies (Bestiary.lua:14-17, 607-640). Critters are excluded (Bestiary.lua:100). **Never in an instance:** `JournalZone` returns nil there (Journal.lua:264, Bestiary.lua:446).
2. **Quality rolled at the kill** (CaptureQueue.lua:581). The mob joins the queue only if its "reason" is one of: shiny, new species, more stars than you own, pinned, or hunt mode (CaptureQueue.lua:398-406).
3. **Queue rules.** Each mob waits 30 s, counted from the end of combat (`CAPTURE_QUEUE_TIME`, :31). The queue holds 12 at most (:32) and drops the least interesting. The timer pauses while you choose or watch the scene (:487-512).
4. **One throw per mob.** On a failure the mob is gone (:675, Capture.lua:833-834).

| Mode | Clicks | What happens automatically |
|---|---|---|
| Classic (express off) | net → chooser if 2 or more (CaptureBatch) → throw; +1 click per aid | scene: 0.7 s throw + up to 3 × 0.55 s shakes + 3.5 s result (CaptureStage.lua:43-44, Capture.lua:29) |
| Express (**default on**, CaptureExpress.lua:93) | 1 click per throw; Shift+click throws at the whole queue; works **in combat** (no combat check in `CaptureExpressThrow`, :541) | one-line result chip only |
| Auto (default off) | 0 | throws at the kill; a shiny waits in the queue unless an aid goes with it (:674-678) |

The player's decisions are: which candidate, whether to spend an aid, hunt mode on or off, pin or skip a species, and keep or release.

### 2. Odds as coded
- **Base rates** (Capture.lua:34-37): trivial/minus 0.60, normal 0.50, elite 0.25, rare 0.15, rare elite 0.10, world boss 0.04.
- **Level factor** (:40): −4 % per level the mob is above you (floor ×0.5), +3 % per level below (ceiling ×1.5).
- **Quality** (CaptureSpecimens.lua:122-130): 1/2/3 stars weighted 65/28/7 (normal), 50/35/15 (elite), 30/45/25 (rare, rare elite, boss). The chance factor is ×1 / ×0.8 / ×0.6.
  - Expected chance for a new species: normal ≈ 45.8 %, elite ≈ 21.8 %, rare ≈ 12.2 %, rare elite ≈ 8.1 %.
- **Effects** (CompanionEffects.lua:640-677):
  - Type effects, each as base / cap: humanoid capture 0.10/0.40, elites and rares 0.12/0.45, mascot "all" 0.02/0.10, beast spotting 0.05/0.25 (on species not yet captured only).
  - Strength: rank ×1 to ×2.5, +0.5 if shiny, +0.25 per star, +0.25 per type tier (:35-37, MenagerieCollection.lua:29).
  - Character + size effects are summed and clamped to [−0.10, +0.20] (:135). The total bonus is never below −0.5.
- **Radiant**: capture ×1.10, shiny ×1.20, capped at 0.95 (CompanionStates.lua:24, 91-103).
- **Pity**: +0.05 per consecutive failure, up to +0.25. The streak is global, not per species (Capture.lua:43, 809-812).
- **Cap**: 0.95 (Capture.lua:30). A Whistle (Sifflet) makes the capture certain.
- **Aids**: Bait (Appât) ×1.5 (cap 10 in the bag), Lasso ×2.5 (cap 5), Whistle certain (cap 3) (:45-49). A free Whistle every 10 new species (:31). Killing a shiny gives a Lasso (:963).
- **Wariness** (hunt mode only): ×max(floor, 1 − 0.15·n), where n is today's captures of that species (CaptureSpecimens.lua:138, 799-807).
  - Floor 0.4, moved by "wary" effects: tiny +0.15, small +0.05, large −0.05, giant −0.10, teasing +0.05, daring −0.05. The result is clamped to [0.25, 0.60] (CompanionEffects.lua:119-127, 1199-1215).
- **Shiny chance** (Shiny.lua:25-28, 183-187):
  - 1/150, ×3 for named mobs, chain up to ×3.75 after 50 kills of the species, ×1.5 in a sealed zone (MenagerieCollection.lua:25, 394).
  - The roll happens once per GUID on target, mouseover **and nameplate** (Bestiary.lua:696-698).

### 3. Simulation
**Assumptions:**
- Alliance; capturable pool **3,265** species (44 zones, 3,541 NPCs; 476 elite, 263 rare, 70 rare elite, 12 boss).
- Kills spread across species with lognormal weights; one spawn of a given rare found per 0.15 h in its zone.
- Levelling to 60 takes 180 h; then the player farms the zone with the most species missing.
- Aid income: Lasso 3/week, Whistle 1/week, Bait 1/day.
- Base scenario: 1.5 kills/min, 2 shiny rolls per kill, Radiant 50 % of the time. Slow scenario: 1 kill/min, σ=2, 1 roll per kill, Radiant 30 %.

| Median days (base / slow) | Casual 30 min | Heavy 3 h |
|---|---|---|
| 10 species | 4 / 5 | 1 / 1 |
| 50 | 17 / 24 | 3 / 4 |
| 100 | 29 / 42 | 5 / 8 |
| 250 | 54 / 92 | 9 / 16 |
| 500 | 103 / 166 | 18 / 28 |
| 1st shiny | 1 / 4 | 1 / 1 |
| 10 / 25 shinies | 16 / 34 ; 30 / 78 | 3 / 7 ; 7 / 16 |
| Seal Westfall (83 species), starting at level 60 | 88 / 1026 (75 % never) | 23 / 329 |

- **Duplicates (hunt off):** 24-41 % of captures, all from star upgrades. **Hunt on:** 74 % at day 30, 95 % at day 730.
- **Reserve of 50 with no releases** fills at casual day 30-53, heavy day 5-9, and hunt-on day 1-2.
- **Seal timing depends almost entirely on the long tail** of rarely met species. It varies tenfold between the two scenarios.

### 4. What is left for a player with 500 species and all seals
- 2,765 more species, with no milestone.
- Shiny versions: up to 3,265.
- Study: 5 tasks per species, 2 sparkles (paillettes) each, +5 when complete (SpecimenStudy.lua:28-30). Finite.
- Size records (tiny and giant at 2 % each) and the 8 characters (SpecimenTraits.lua:53-65). Finite.
- Bond: up to 180 points per specimen, 10 per day (SpecimenBond.lua:39-40). Finite.
- Truly repeatable:
  - Daily and weekly missions, but `capNew` only when the zone still has new species (MissionsMenagerie.lua:165).
  - Hunt mode → release → sparkles.
  - Shop: daily stock of 5 Bait, 2 Lasso, 1 Whistle (ShopWeek.lua:21); 3 orders per week at 12/14/16 (:25).
  - Trades.
- Sparkle sinks that run out: 8 rotating cosmetics (680 sparkles in total) and Reserve slots up to 150 (1,300 sparkles).

### 5. Rarity structure
- Rank counts: 476 elite, 263 rare, 70 rare elite, 12 boss. Bosses are excluded from seals (MenagerieCollection.lua:331).
- **No time-of-day, weather, season or event species.** The generator excludes seasonal NPCs (ZoneCreatures_Forever.lua:20-21).
  - Night only affects the `winter_nose` effect (CompanionEffects.lua:89).
  - Companion.lua:3603 says it outright: "Pas de pluie : aucune API fiable ne dit la météo" (no rain: no reliable API reports the weather).
- No legendary encounters. Live rares come only from the minimap vignette alert (LiveRares.lua).
- No dungeon or raid fauna, because capture never works in an instance.

### 6. Failure points
| Failure | Rule |
|---|---|
| Escape | the mob is lost; you must kill another one |
| Queue expiry | 30 s after combat, applies to a waiting shiny too (Prune, :444) |
| Queue overflow | more than 12 drops the least interesting (:451) |
| Reserve full | blocks a duplicate or upgrade, never a new species (CaptureSpecimens.lua:656-660) |
| Combat | classic flow refuses (CaptureQueue.lua:648); express allows it |
| Group or outdoor raid | allowed: group kills count (Bestiary.lua:625) |
| Instance | no capture at all |

### Weak points
1. **Sealing is gated by the long tail, not by skill.**
   - Evidence: every non-boss species counts (MenagerieCollection.lua:326-336), including opposite-faction guards (Durotar for an Alliance player: NPC 16096, elite, level 55) and 14 rows at level 9999 (Ashenvale 4, Hinterlands 3, Duskwood 2, Feralas 2, Zephras 3). Whether those 9999 rows can be captured at all is unverified. Rares get one throw per spawn at 12 %.
   - Why it matters: seal time swings from 88 to 1,026 days for a casual player.
2. **Shinies are not rare.**
   - Evidence: nameplates roll too, and the chain multiplier adds to it; the first one comes on day 1. The Shiny.lua:3-4 header says only target and hover roll, so the doc has drifted from the code. Shiny rewards stop at 50 (Shiny.lua:38-46).
   - Why it matters: the hunt for shinies loses its thrill within a week for a heavy player.
3. **Progression stops.**
   - Evidence: trainer ranks end at 250. The 500-species achievement reward is "card_census (à venir)". The continent seals' crests are still "coming soon": 15 `soon` entries in FeatsCatMenagerie.lua (:476, 527-528 and others).
   - Why it matters: more than 2,700 species have no goal attached.
4. **No instance or legendary content, and no time or event variety.**
   - Evidence: Journal.lua:264.
   - Why it matters: dungeons, the most memorable places in Classic, are blank in the collection, and the world never surprises.
5. **Hunt mode floods the player with duplicates (95 % by day 730), and the sparkle economy dries up.**
   - Evidence: finite sinks (cosmetics and slots); the Reserve fills in 1-2 days.
   - Why it matters: releasing becomes a chore with nothing to earn.
6. **A shiny can be lost while AFK or in auto mode.**
   - Evidence: auto mode holds a shiny if no aid goes with it, yet the 30 s expiry still applies.
   - Why it matters: this is the worst kind of frustration loss.
7. **Pity is global, not per species, and a failed rare is gone for hours.**
   - Evidence: Capture.lua:809.
   - Why it matters: bad luck lands hardest on the highest-value targets.
8. **The decisions are thin.**
   - Evidence: express + auto remove every choice; aids are the only lever, and the auto-aid setting takes that one too.
   - Why it matters: no skill expression, so the loop becomes passive collecting.
9. **The final 3.5 Radiant rules were never re-simulated.**
   - Evidence: design-envies-3.5/PLAN.md:122 (Radiant 4-88 % of the time depending on activity).
   - Why it matters: an untested ×1.10 / ×1.20 bonus may be nearly always on or nearly never.