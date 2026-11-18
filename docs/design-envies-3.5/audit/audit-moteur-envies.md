# Needs engine audit: QuestCompanion 3.4.0 (qc-3-4 worktree)

## 1. Constants

| Constant | Value | File:line |
|---|---|---|
| NEED_KEYS | hunger, energy, mood, curiosity | Companion.lua:42 |
| NEED_MAX / NEED_FLOOR / NEED_START | 100 / 15 / 80 | Companion.lua:43-45 |
| DECAY per minute of play | hunger 0.6, energy 0.4, mood 0.3, curiosity 0.5 | Companion.lua:47 |
| SERENE_FLOOR | 50 | Companion.lua:64 |
| REST_GAIN (energy/min while resting) | 4 | Companion.lua:66 |
| EAT_GAIN (hunger/min while eating) | 6 | Companion.lua:67 |
| TICK / MAX_STEP | 10 s / 60 s | Companion.lua:68-69 |
| PET_COOLDOWN | 15 s | Companion.lua:72 |
| SLEEPY_AFTER / MIN / MAX / PER_HOUR | 7200 s / 60 s / 600 s / 20 s | Companion.lua:73-75 |
| COOLDOWNS.need / need_each | 300 s / 900 s | Companion.lua:118-119 |
| NEED_LOW | 35 | Companion.lua:124 |
| HAPPY_MIN | 70 | Companion.lua:125 |
| NEED_GRACE | 120 s | Companion.lua:126 |
| EFFECT_NEED_OK | 50 | CompanionEffects.lua:34 |
| ns.NEED_LOW, journal colour only (a second constant with the same name) | 30 | JournalWindow.lua:737 |
| PERSONALITY_GAIN / PERSONALITY_DECAY (the trait's preferred need) | ×1.5 / ×0.7 | Personality.lua:145-146, 250, 259 |

Time from 80 down to each threshold (base decay, no modifiers):

| Need | Below 70 | Below 50 | Down to 15 |
|---|---|---|---|
| Hunger | 16.7 min | 50 min | 108 min |
| Energy | 25 min | 75 min | 162 min |
| Mood | 33 min | 100 min | 217 min |
| Curiosity | 20 min | 60 min | 130 min |

Decay modifiers: decay effects multiply by (1 − value) (CompanionEffects.lua:791-797, defs at :76-116, with caps up to 0.40). Trait "minus" effects speed decay up by 10–15 % (:113-116). The Winter cold effect slows decay in cold zones, and WINTER_MELT applies to mood in hot zones (WinterCompanions.lua:732-743).

## 2. Tick logic

- **Driver.** `ns.Every("companion", CLOCK_POLL=0.1)` adds `min(step, 60)` to a counter. Every 10 s or more it calls `CompanionTick(pending)` (Companion.lua:4488-4508). The only gate is `ModuleOn()`.
- **"Play time"** means any time the client is logged in with the module on. There is no AFK check: no `UnitIsAFK` call exists anywhere.
- **Decay formula.** `delta = -DECAY[k] * minutes * DecayFactor(k)`. While resting, energy takes `+4*min` instead. While eating, hunger takes `+6*min` instead. The result is clamped to `[floor, 100]` (Companion.lua:3408-3413).
- **Resting** means `IsResting()` or `AtCamp()` (Companion.lua:3393-3396). Only energy stops decaying. The other three still decay.
- **Taxi.** Decay continues during the flight. Landing gives +5 curiosity (Companion.lua:3418-3419).
- **Dead.** `CompanionOnDead` and `CompanionOnAlive` only set `rt.dead` and pick a speech line (Companion.lua:3826-3837). Decay continues.
- **Offline.** Nothing decays ("rien hors connexion", Companion.lua:46). `lastSeen` is written on every tick (:3428) and at `PLAYER_LOGOUT` (:4399). At login, `away = now - lastSeen` is used only to decide the sleepy state (:3576-3603). Needs are carried over unchanged.
- **Login grace.** No need bubble for 120 s after login (:3597).

## 3. Gain sources

| Event | Need | Amount | Cap / cooldown | File:line |
|---|---|---|---|---|
| Eating or drinking aura starts | hunger | +35, then +6/min instead of decay | edge-triggered on aura start | Companion.lua:3379-3380, 3411 |
| "Well Fed" aura gained | hunger | +15 | edge | :3383 |
| Arriving at a camp | energy | +10 | edge | :3386-3387 |
| Resting | energy | +4/min instead of decay | — | :3410 |
| `rest` effect while resting and not sleepy | energy | +4 × Σvalue per min (bypasses `CompanionAdd`, Personality and the floor) | value caps 0.60 / 0.20 | CompanionEffects.lua:805-813 |
| Petting | mood | +8 | 15 s | Companion.lua:3622, 3629 |
| `pet` effect (petting) | mood | +8 × Σvalue | same petting | CompanionEffects.lua:825-830 |
| Rare+ loot (quality 3 or higher) | mood | +10 | none | Companion.lua:3672-3673 |
| Quest turned in | mood | +12 | none | :4441-4442 |
| Level up | mood | +25 | — | :3760 |
| Kill | mood | +1 | 2 s dedup | :3784-3788 |
| Successful capture | mood | +5 | — | Capture.lua:885 |
| `DEPARTURE` callback with food in bags | hunger | +10 | — | Companion.lua:3973-3974 |
| `RETURN` callback | energy | +5 | — | :3980-3982 |
| Inn stamp | energy | +20 (INN_ENERGY) | once per day | Daily.lua:21, 284-290 |
| Mission completed | curiosity | +10 (MISSION_CURIOSITY) | per mission | Daily.lua:23, 495 |
| New zone | curiosity | +15 | once per zone | Companion.lua:53, 3711 |
| Zone revisit | curiosity | +8 | 2 h real time since the last visit | :54, 3715 |
| Dungeon entry | curiosity | +10 | 600 s | :56, 3719-3721 |
| New subzone | curiosity | +4 | once | :53, 3735 |
| Subzone change | curiosity | +1 | 30 s | :55, 3736-3739 |
| Elite, rare or world boss killed | curiosity | +8 | — | :57, 3751 |
| Flight landing | curiosity | +5 | — | :58, 3419 |
| Zone chest opened | curiosity | +20 | per chest | :59; CompanionChest.lua:268 |
| Gathering | curiosity | +1 | per node | :60; Gathering.lua:353 |
| New stamp | curiosity | +10, or +15 if rare | `stamp.new` only | Companion.lua:3775 |
| Treat (biscuit / infusion / bonbon / carte) | its own need | +100 | pantry 3 of each, Feast 2 (overflow is eaten at once) | Treats.lua:23, 216 |
| Feast | all four | +100 each | — | Treats.lua:214 |
| Glutton trait eats a treat | mood | +15 | — | Treats.lua:25, 219 |

- **Personality.** Positive gains to the trait's preferred need are multiplied by 1.5 (Personality.lua:246-254). This applies to every `CompanionAdd`, not to the in-tick rest/eat deltas or the `rest` effect.
- **Treat sources.** Zone completion 25 % and 50 % gives the treat for the lowest need. 75 % gives a Feast (Treats.lua:281). Missions can grant the lowest-need treat (Daily.lua:453).

## 4. Sleepy state

- **Entered** at login when `away >= 7200 s`. Then `sleepyLeft = clamp(floor(away/3600*20), 60, 600)` seconds of play (Companion.lua:3599-3601).
- **Left** when the in-tick countdown runs out (:3424-3426), or by `CompanionWake`. Wake is called on petting (:3628), level up (:3761) and quest turned in (:4443).
- **What it changes:**
  - Mood label becomes "sleepy" (:774).
  - `CompanionIsHappy` returns false, which blocks evolution (:817).
  - No need bubbles (:3450).
  - No INN line (:4454).
  - Sleep animation (:2985).
  - The `rest` effect bonus is off (CompanionEffects.lua:808).
  - MISSED line at login (:3609).
- Needs are not touched.

## 5. Stages and SERENE_FLOOR

- **Stages.** Five, unlocked at levels 1 / 10 / 20 / 40 / 60, with scale 0.70 / 0.82 / 0.94 / 1.06 / 1.18 (CompanionData.lua:201-207).
- **Evolution.** Reaching a level sets `stageReady`. The companion evolves only while `CompanionIsHappy()`, meaning all four needs `>= 70` and not sleepy (Companion.lua:842-869). This is re-checked on every tick (:3415) and on every positive `CompanionAdd` (:767).
- **A stage cannot be lost.** `if target <= data.stage then ... return false` (:850).
- **What a stage gives:**
  - Model scale (:2925-2974).
  - Effect strength = stage for the mascot and seasonal companions (CompanionEffects.lua:385, 420).
  - SERENE_FLOOR at the last stage.
- **SERENE_FLOOR.** `floor = stage >= #STAGES and 50 or 15`. It applies only in the tick's clamp (Companion.lua:3407, 3412), and `Clamp(v+delta, 50, 100)` also raises a lower value to 50 on the next tick. Effects count a need as satisfied with `>= EFFECT_NEED_OK (50)` (CompanionEffects.lua:365). At stage 5, after one tick, all four needs are therefore `>= 50`: `needsOk = 4` and the strength factor is always 1.
- **Exceptions:**
  - `CompanionAdd` and `CompanionData` clamp to 15, not 50 (:724, :763). No negative `CompanionAdd` call was found.
  - The floor does not guarantee 70, so evolution is irrelevant at the last stage anyway.
  - It does guarantee no need bubbles, since 50 is not below 35.

## 6. Consequences at the floor (15)

Nothing in the code punishes a need at 15 beyond the following:

- **Mood label.** It comes from the average of the four needs: ≥ 75 radiant, ≥ 50 happy, otherwise "dreamy". There is no "sad" (:772-781).
- **Effect strength factor.** `0.5 + 0.5*ok/4`, where `ok` counts needs at 50 or more. Minimum 0.5 (CompanionEffects.lua:361-367, 425-429).
- **Need bubble.** Fires below 35. It picks the lowest need, with cooldowns of 300 s overall and 900 s per need (:3448-3459).
- **Evolution blocked** while any need is below 70.
- **No "happy" float animation** (CompanionFx.lua:215).
- **Journal and hover colours:** below 30 orange, 70 or more green or gold.

## 7. Where need values are read

| Consumer | What it decides | File:line |
|---|---|---|
| `CompanionMood` | mood label (average) | Companion.lua:772-781 |
| `CompanionHappyCount` / `CompanionIsHappy` | evolution gate, float animation | :807-818; CompanionFx.lua:215 |
| `CompanionHappyHints` | per-need hint text (≥ 70) | Companion.lua:821-833 |
| `CompanionCheckStage` (via IsHappy) | evolve or set stageReady | :851 |
| `CompanionTryNeed` | need bubble (< 35) | :3448-3459 |
| `CompanionRefreshHover` | bar fill and colour (≥ 70 gold) | :2737-2745 |
| `CompanionStatusLine` | chat status values | :4263-4266 |
| `CompanionEffectNeeds` | effect strength factor (≥ 50) | CompanionEffects.lua:361-367 |
| `CompanionEffects` cache key | recompute when `needsOk` changes | CompanionEffects.lua:533, 542 |
| Effects pane | text showing `needsOk` and the factor | CompanionEffects.lua:1030 |
| `TreatForLowestNeed` | which treat a 25/50 % reward or a mission gives | Treats.lua:179-187; Daily.lua:453; JournalWindow.lua:1543 |
| `PersonaTickNotice` (glutton) | remark when hunger < 60 | Personality.lua:390 |
| `NeedTooltipLines` | tooltip (≥ 70, shows the serene line) | JournalWindow.lua:713-731 |
| `NeedTier` | bar colour (≥ 70 green, < 30 orange) | JournalWindow.lua:738-743 |
| Journal evolution pane and pet box | bars, happy threshold | JournalWindow.lua:1011, 2409-2412, 3104-3108 |
| Guide page | prints EFFECT_NEED_OK | JournalGuide.lua:298 |
| ForgeCompanion | mood label → visual | ForgeCompanion.lua:213 |

Not found: any need value read by capture, shiny, spawn or loot logic other than through the effect strength factor.