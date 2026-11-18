## Companion audit, QC 3.5.0 (main)

### 1. What the choice of companion changes
**Strength**, `CompanionEffects.lua:385-399`:
- Rank: normal ×1, elite 1.5, rare 2, world boss 2.5 (`:35`).
- Shiny +0.5, +0.25 per star above 1 (`:36-37`).
- Type completion tier +0.25 per tier, 3 tiers max (`MenagerieCollection.lua:27-29,453`).
- Range: 1.0 to 4.25.

Mascots and Winter companions use stage 1-5 as strength (`:379,414`).

| Type | Hunting effect (base/strength, cap) | Comfort effect (cap) |
|---|---|---|
| beast | uncaptured beasts only: capture 0.05 (0.25) | Fed lasts longer 0.10 (0.40) |
| humanoid | humanoid capture 0.10 (0.40) | extra treat at zone milestone (0.60) |
| undead | undead shiny chance 0.15 (0.60) | Rested 0.10 (0.40) |
| elemental | aid not spent 0.08 (0.30) | Alert 0.10 (0.40) |
| dragonkin | shiny chain: kills count 0.50 (1.50) | all states 0.034 (0.134) |
| demon | elite/rare capture 0.12 (0.45) | petting extends the shortest state 0.25 (1.00) |
| giant | extra aid at zone milestone 0.25 (1.00) | all states 0.05 (0.25) |
| mechanical | failed capture returns the aid 0.20 (0.75) | rest faster 0.15 (0.60) |
| mascot | capture on everything 0.02 (0.10) | all states 0.04 (0.20) |

Source: `:145-156`, `:61-84`.

- **Character:** bonus × bond multiplier `{1,1.25,1.5,1.75,2}` (`:132`). Six traits have base equal to cap, so the bond multiplier does nothing for them: wise, parrot, mystic, sly, fearful, tinker (`:100-106`). None of these six is rolled for new specimens (`SpecimenTraits.lua:53-56`).
- **From bond 2:** the character's downside and the size effects switch on (`:111-128`). Character and size together on capture are clamped to −0.10…+0.20 (`:136`).
- **Radiant** (all 3 states on): capture ×1.10, shiny ×1.20 (`CompanionStates.lua:24`), applied before `CAPTURE_MAX` 0.95 (`Capture.lua:30`).
- **Capture multiplier, weakest to best:**
  - Weakest: ×0.95 (tiny specimen on elites/rares, `:120`).
  - Best on a named target: demon at strength ≥3.75 (0.45) + daring at bond 5 (0.10) + giant size (0.08) = ×1.63, then ×1.10 Radiant = **×1.79**.
  - Best on any target that matches no type effect: a stage-5 mascot at ×1.21 beats every captured creature (mischievous at bond 5: ×1.06, then ×1.17 with Radiant).
- **Shiny multiplier:** ×1.0 up to ×1.60 (undead) × 1.05 (mystic) × 1.20 = **×2.02**, undead only. The dragonkin chain at strength 3 multiplies kill counts by 2.5, so the ×3.75 max needs 20 kills instead of 50 (`Shiny.lua:27-28`). Nothing raises the shiny chance on every creature apart from Radiant and mystic, which new specimens never get.
- **Dominant choice:** the demon. Petting extends the shortest state by 0.25 × 45 = 11 min, with a 15 s cooldown (`Companion.lua:91`, `CompanionStates.lua:110-121`). Four clicks top all three states up to 60 min, so Radiant can be kept up forever. Within a type only the strongest specimen counts, so normal 1-star specimens never matter as companions.

### 2. Stages (`CompanionData.lua:201-207`)
| Stage | Level | Scale |
|---|---|---|
| Hatchling | 1 | 0.70 |
| Youngling | 10 | 0.82 |
| Seasoned | 20 | 0.94 |
| Valiant | 40 | 1.06 |
| Legendary | 60 | 1.18 |

- Gate: the player level, plus one wish granted after reaching it (`Companion.lua:835-838,865-895`).
- A stage gives:
  - mascot or Winter strength;
  - a scale-up for mascots only (captured creatures keep their real size, `:2997`);
  - a label, a dance and a bubble.
- The creature never changes form: there is no display field per stage.

### 3. Mascots vs captured creatures
- 24 mascots (`CompanionData.lua:4-28`) and 3 Winter companions (`WinterCompanions.lua`).
- Mascots have:
  - a name the player gives (`/qc compagnon nom`);
  - a stage-based scale;
  - +10% capture on every creature at stage 5;
  - a character formed by play, which gives no trait effect, since that effect is computed only for captured creatures (`CompanionEffects.lua:403-408`).
- Captured creatures have:
  - type effects, 4-6× stronger;
  - a type voice;
  - character, size, bond;
  - but they keep their species name (`Companion.lua:737-754`).
- Reason to keep a mascot: off-type capture, or the custom name.

### 4. Wearable looks
- Every captured version can be worn, normal and shiny, with no limit (`Capture.lua:519-545`). Only the Codex reference specimen of a species is worn, never a Reserve specimen.
- The picker (`CompanionAllure.lua`) has search, filter chips (type / Shiny / Favourites, Shift+click to favourite) and sorts by type, then name.
- Tile tooltips show type, size and character only (`:444-473`). There are no effects, no strength and no bond. Effects are compared only in the confirm dialog, with a 120 s delay before they apply (`:33`).

### 5. Wishes (`CompanionStates.lua:126-215`)
- The pool is the 3 states only. An inactive state is picked, with the character's preferred state weighted ×2.
- Timing: no wish in the first 120 s after login, then a 1200 s gap after each granted wish (`Companion.lua:58-63`).
- **A wish never expires:** it is cleared only by `WishMet` (`:195`).
- Reward: +1 bond, 3 per day on top of the daily cap of 10 (`SpecimenBond.lua:56`). A mascot gets its states refilled instead.
- No wish is tied to capture, zones, species or the shiny hunt.
- A granted wish has no bubble and no FX. The chat line only shows if `journalChat` is on, and it is off by default (`:206`, `Journal.lua:127`).

### 6. Interactions and reactions
- **Player actions:**
  - pet (15 s cooldown);
  - treats with Shift+click: 4 kinds plus Festin (`Treats.lua:29`);
  - mascot rename;
  - specimen nickname (15 glitter, free at bond 5, `ShopWeek.lua:203-221`);
  - `/qc blague`, `anim`, mute and hide.
  - There are no tricks and no companion photo; Share covers captures and achievements.
- **Bubbles:** 79 pool entries and 698 line pairs in `CompanionLines.lua`, plus 9 type voices × 12 situations (`CompanionVoices.lua:20-26`), plus jokes, lore, shouts and treat pools.
- **FX:** bounce, shake, float, hearts, crumbs, `!`, zzz (`CompanionFx.lua`).
- **Missing bubbles:**
  - a bond level-up only prints to chat (`SpecimenBond.lua:200`);
  - the bond-3 keepsake is chat only (`:181`).

### 7. History
- The Companion page shows tiles for days, captures, shinies, missions and km (`JournalWindow.lua:2432-2438`).
- Those figures are per character or per account, not per specimen. "Days together" counts from the first opening of the page (`:2336-2350`).
- A specimen stores capture zone, date, catcher and bond points. Its daily per-source counters `bond.c` reset every day (`SpecimenBond.lua:166`).
- Not found: per-specimen time worn, distance, captures made together, memorable moments.

### 8. Team
Not found. There is one worn creature, and Reserve specimens do nothing while not worn. The only passive is the Codex keep rule at bond ≥2.

### Weak points
| What | Evidence | Why it matters to a player |
|---|---|---|
| Petting keeps Radiant up forever | `CompanionEffects.lua:813`, `CompanionStates.lua:110` | Petting turns +10% capture / +20% shiny into a permanent bonus; states and wishes stop mattering. |
| Evolution is a number | `Companion.lua:2997` | A captured creature never grows or changes form; "Legendary" looks the same as "Hatchling". |
| Most of the collection is useless as a companion | strength formula `:385-399` | Only the strongest specimen per type, out of 8 types, is worth wearing. |
| A mascot beats captured creatures off-type | `:84` vs `:107` | It feels backwards for a Pokémon-like. |
| Nickname is not shown as the companion's name | `Companion.lua:737` vs `SpecimenFilters.lua:235` | The bond-5 reward cannot be seen on the companion itself. |
| A granted wish is silent; wishes never expire | `CompanionStates.lua:195,206` | No feedback loop, nothing to look forward to. |
| Only 3 wish kinds, none about capture | `:126-155` | Wishes do not connect to the collection. |
| Stale character descriptions after 3.5 | `Personality.lua:43-52`, `SpecimenTraits.lua:97` | Still promise "moral +50 %", but morale no longer exists. |
| Picker has no effect, strength or bond info | `CompanionAllure.lua:444-473` | You cannot choose by effect without opening each confirm dialog. |
| No per-specimen history | `SpecimenBond.lua:166` | The bond has no memories to show. |
| No team, Reserve is idle | not found | Captured creatures have no role after capture. |