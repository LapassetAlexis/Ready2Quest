## Treats, pantry and inn loop that feeds the needs (QC 3.4.0 beta)

Paths below are relative to `/Users/alexis.lapasset/Projects/ReadyToQuest-wt/qc-3-4/QuestCompanion/`. Need constants are in `Companion.lua`: decay per minute of play (`DECAY`, :47) is hunger 0.6, energy 0.4, mood 0.3, curiosity 0.5. That is 36 + 24 + 18 + 30 = **108 points per hour** in total. Floor 15 (:44), start 80 (:45), floor 50 once all evolutions are done (:64). Evolution needs all four ≥ 70 (`HAPPY_MIN` :125, `CompanionIsHappy` :815).

### 1. Treat kinds and pantry (Treats.lua)
| Treat | Effect (`TreatEat` :210) | Cap |
|---|---|---|
| biscuit | hunger +100 | 3 |
| infusion | energy +100 | 3 |
| bonbon | mood +100, hearts | 3 |
| carte | curiosity +100, "sniff" line naming the least-advanced part of the zone (:197) | 3 |
| festin | all four +100 | 2 |

- Caps: `TREAT_CAP, FESTIN_CAP = 3, 2` (:23). The pantry holds at most 14.
- Each treat in practice fills its need to 100 (clamped).
- Glutton gets +15 mood on every treat (`GLUTTON_MOOD` :25, :219).
- Preferred need gains ×1.5 and decays ×0.7 (Personality.lua:145-146).
- When full, `TreatGrant` (:243-246) eats the treat at once (quiet effect plus a `TREAT_FULL` line). Nothing is lost; the need is filled.

### 2. Treat sources
| Source | Amount | Frequency | file:line |
|---|---|---|---|
| Zone milestone 25 / 50 % | 1 treat of the lowest need | once per zone, ever (needs ≥ 2 parts) | Treats.lua:279-285 |
| Zone milestone 75 % | 1 festin | once per zone | :281 |
| Golden chest (100 %, tier already complete) | festin + 2 random | once per zone | :340-351 |
| Daily mission (zone or trait) | 1 lowest-need treat + bait + 3 glitter | 3 per day | Daily.lua:58-59, 493 |
| All 3 dailies | festin + lasso + 5 glitter | 1 per day | :60, 504 |
| Weekly mission | 1 random treat | 3 per week | :61, Weekly.lua:201 |
| All 3 weeklies | festin | 1 per week | :62, Weekly.lua:207 |
| Inn card full | festin | every 7 stamps, at most 1 stamp per day | Daily.lua:22, 292-296 |
| Shiny killed | 1 random treat, 15 % chance of festin | shiny rate 1/150 per monster, ×3 elite/rare, ×3.75 max with chain | Shiny.lua:25-29, 277 |
| Effect `treatZone` | extra random treat per milestone at 15 % (cap 60 %); glutton trait 10-20 %; winter 10-50 % | needs that effect active | CompanionEffects.lua:77, 87, 96, 774 |
| Bond level 3 keepsake | 30 % per day, then 50 % bait, otherwise a treat | at most 1 per day | SpecimenBond.lua:46, 152-163 |

The Trainer's Shop sells no treats: `PAILLETTES_SHOP` (JournalReserve.lua:42-65) holds only aids, slots and cosmetics.

**Treats earned per day (estimates).** Assumptions: the player is levelling; there is no shiny or `treatZone` effect unless stated; the weekly totals are spread over 7 days.
- **30-minute player:** say 2 of 3 dailies done, so 2 treats. Inn festin 1/7 ≈ 0.14. About 1 milestone per day (assumed) adds 1. Weekly share: say 2 weeklies → 2/7 ≈ 0.29. **About 3.4 treats per day.**
- **3-hour player:** dailies 3 + festin = 4. Milestones: say 2 zones × 1.5 = 3. Inn 0.14. Weekly (4 + festin)/7 ≈ 0.57. Shinies: about 300 monsters targeted × 1/150 ≈ 2. **About 9.7 treats per day.**

### 3. Demand versus natural gains
- A treat used at 50 brings the need back to 100, so it covers 50 points.
- With no other gains, demand is 108 / 50 = **2.16 treats per hour**: hunger 0.72, curiosity 0.60, energy 0.48, mood 0.36. That means hunger every 83 min, curiosity every 100, energy every 125, mood every 167.
- **30-minute session:** decay is 54 points, about 1.1 treats. From the start value of 80, hunger falls to 62, so no need drops below 50.
- **3-hour session:** about 6.5 treats needed with no other gain.

Natural gains (Companion.lua):
| Need | Gain | Source and line |
|---|---|---|
| Hunger | +35 at the start of eating, then +6/min while eating | :3380, :67 |
| Hunger | +15 on Well Fed | :3383 |
| Hunger | +10 on leaving town with food in the bags | :3974 |
| Energy | +4/min instead of decay while `IsResting` or at a camp | :66, :3410 |
| Energy | +10 on entering a camp | :3387 |
| Energy | +5 on returning to town | :3982 |
| Energy | +20 per inn stamp | Daily.lua:21 |
| Mood | +8 per pet (15 s cooldown) | :3629, :72 |
| Mood | +12 per quest turned in | :4442 |
| Mood | +10 per blue item or better | :3673 |
| Mood | +25 per level | :3760 |
| Mood | +1 per kill | :3788 |
| Curiosity | new zone +15, new subzone +4, revisit +8, subzone change +1 (once per 30 s), dungeon +10, elite +8, flight +5, chest +20, gather +1 | :52-61 |
| Curiosity | journal stamp +10 (rare +15) | :3775 |
| Curiosity | daily mission done +10 | Daily.lua:23 |

What this means:
- One meal (+35) covers about 58 min of hunger decay.
- 6 min of rest covers 1 hour of energy decay.
- 2-3 pets or 2 quest turn-ins cover 1 hour of mood decay.
- A levelling player covers curiosity from subzone changes alone (up to +120 per hour).
- So natural gains match or exceed decay during ordinary levelling, while treat income is about 3-10 per day. The pantry tends to stay full and overflow (auto-eat at :243).
- This is an inference: no telemetry was found.

### 4. Inn, rest and eating
**Inn card** (`InnStamp`, Daily.lua:283-304)
- Trigger: talking to an innkeeper (`CompanionOnNpc` kind "innkeeper", :310).
- One stamp per day, by the computer's date (:287); days do not need to be in a row.
- Each stamp gives +20 energy and hearts.
- The 7th stamp gives a festin and resets the card.
- 3 full cards unlock the "chicken" look (:26, 295).

**Rest:** +4 energy per minute instead of decay (`CompanionTick` :3405-3410). The "INN" line plays on `IsResting` (:4454).

**Eating** (`CompanionCheckAuras` :3377; aura names :3321-3327)
- Eat auras: food, food & drink, refreshment, nourriture, nourriture et boisson, rafraîchissement.
- Drink auras: drink, boisson.
- Well Fed auras: well fed, bien nourri, repu.
- Gains: +35 hunger once when eating starts, +6 per minute while it lasts (:3411), +15 when Well Fed is gained.
- Lines: EAT or DRINK with the "eat" cooldown of 60 s (:117).
- Starting to eat also advances the "meals" mission (Daily.lua:638).

### 5. Giving a treat
- **Shift + click the creature** opens the pantry menu (Treats.lua:463-470), then one click on a treat: **2 clicks**.
- From the journal (already open):
  - the footer pantry is **1 click** (JournalWindow.lua:2064);
  - the Missions tab has a "Donner" button per treat (JournalWindow.lua:1863), 1 click on that tab.
- No auto-feed option was found (`autoFeed` and similar are not in the code). The only automatic eating is the full-pantry overflow.
- Each treat given adds 2 bond points, capped at 4 per day (SpecimenBond.lua:43, 223-225).

### 6. Trait missions tied to needs (Daily.lua:40-50)
| Trait | Mission | Target |
|---|---|---|
| glutton | meals | 3 |
| lazy | rest | 15 min |
| fearful | rest | 10 min |
| cuddly | pets | 3 |
| mischievous | pets | 5 |
| generic (no trait) | pets | 3 |
| zen | calm (no death) | 15 min |

- Reward (`trait` scope :59): 1 lowest-need treat + bait + 3 glitter.
- Rest is counted only while `CompanionResting` is true (:660). Pets count only without Shift (:628).

### 7. Lines about needs (the appeal side)
| Pool | Lines | Trigger | file:line |
|---|---|---|---|
| NEED_hunger / energy / mood / curiosity | 9 each (36) | need < 35 (`NEED_LOW` :124); lowest need first; not in combat or asleep; 120 s grace after login (:126); cooldown 300 s for any need, 900 s for the same need (:118-119) | CompanionLines.lua:607-650; `CompanionTryNeed` :3448 |
| EAT / DRINK | 14 / 10 | entering an eat aura, cd 60 s | CompanionLines.lua:358, 374 |
| INN / CAMP | 11 / 11 | resting / entering a camp | :328, :341 |
| DEPART / NOFOOD / RETURN | 12 / 8 / 11 | leaving or returning to town | :80, :70, :94 |
| Trait EAT variants | 14 traits | 75 % variant chance | PersonalityLines.lua; Personality.lua:144 |
| NOTICE glutton | 9 | hunger < 60, gap 900 s | Personality.lua:390, 147 |
| NOTICE lazy / cuddly | 8 / 8 | 40 min without rest / 20 min without a pet | :392, :394 |
| Voices: EAT per creature type | 3 × 9 types (27) | 60 % share | CompanionVoices.lua:29-35, 90+ |
| Voices: NEED | not found (no NEED mapping) | | CompanionVoices.lua:29-35 |
| Winter companions: NEED | 2 × 3 (6) | replaces the NEED_* pools | WinterCompanions.lua:501, 281, 361, 441 |
| CompanionShouts | nothing about needs (not found) | | |
| Treat lines | GOT 3, FULL 2, EAT 2 per kind (10), SNIFF 2, RETRO 1 + 1, GOLDEN 1, glutton variants 2 + 1 | | Treats.lua:78-129 |
| Tips | lines on the pantry, needs on hover, inns | | CompanionLines.lua:679, 690, 698, 801 |

The chatter slider gates these lines. Levels 0-2 allow only advice, event and tutorial bubbles, so NEED lines are silent there (Companion.lua:97-103). The default is level 3: 20 s between bubbles, cooldowns ×1. Level 4 halves the cooldowns. NEED bubbles have priority 2 (:79).