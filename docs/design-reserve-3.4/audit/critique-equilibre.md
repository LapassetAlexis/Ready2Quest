## Balance and economy review of the Reserve / Creatures design note (v1)

Simulations are in `/private/tmp/claude-2007623921/-Users-alexis-lapasset-orca-workspaces-ReadyToQuest-qc-reserve-design/c71c5d45-23dc-4285-87e3-69915616ccc5/scratchpad/sim/` (`a_capture.py`, `b_wary.py`, `b2_floor.py`, `cd_bond_econ.py`).

### Findings, most severe first

**1. Paillettes already buy power, so §4.7 "rien de puissant ne s'achète" is false.**
- Evidence: the sifflet (35) is a sure capture (Capture.lua:393). The only limit is the bag cap of 3, and you can refill it as often as you like (JournalReserve.lua:307-323).
- Modelled income: a heavy player makes about 348 per day once study tasks, Curieux and orders are added. That is about 10 sifflets per day. A casual player makes about 45, so about 1.3 per day.
- The 1,300 for slots is gone in 3.7 days (heavy) or 29 days (casual). After that, all the surplus goes into sure captures on rares.
- Fix: a daily shop stock per account of 5 appâts, 2 lassos and 1 sifflet. Or move the sifflet out of the shop and keep it as a reward only.

**2. Swapping the Codex reference skips EFFECT_DELAY.**
- Evidence: `activeAt = record.since + EFFECT_DELAY` (CompanionEffects.lua:477). `record.since` only moves when the appearance changes. `SpecimenSetReference` (CaptureSpecimens.lua:504) only bumps `specSerial`, which refreshes the cache instantly.
- The player can therefore keep a Taquin-Minuscule for hunting and a Téméraire-Géant at bond 5 for rares, and switch between them in one click while a rare sits in the queue (30 s).
- Fix: when the reference of the worn version changes, reset `record.since` (120 s delay) and refuse the change in combat. Bond points follow the new specimen only after those 120 s.

**3. Wariness size modifiers do almost nothing, and Géant is strictly dominant.**
- Evidence (b), 240 hunt kills, normal mobs, pity on, captures per 2 h:

| Hunt pattern | Minuscule | Normal | Géant |
|---|---|---|---|
| 1 species | 68.2 | 67.3 | 67.2 |
| 10 rotated species | 85.7 | 78.7 | 76.4 |

- The 0.4 floor is reached after 3 to 7 captures whatever the step, and pity hides the rest.
- Wariness exists only in hunt mode (CaptureSpecimens.lua:789). Outside hunt mode, Géant's minus costs exactly 0, while its +8 % on elites and rares always applies.
- The floor is the real lever: floor 0.3 gives 59.8, floor 0.5 gives 75.5.
- Fix: size changes the floor, not the step. Minuscule 0.55, Petit 0.45, Normal 0.40, Grand 0.35, Géant 0.30.
  - Giant then loses about 12 % of hunt captures in exchange for +4.5 % catches per elite offer.
  - Also give Géant a minus outside hunt mode: hunger drops 10 % faster.

**4. Taquin becomes a dead trait, and "personne ne perd rien" is false.**
- Today Taquin gives mood decay ×0.92 (CompanionEffects.lua:101). The new plus works only in hunt mode and is worth almost nothing (Taquin 5 + Minuscule: 70.0 vs 67.3 on one species). Its new minus (energy drops 10 % faster) applies all the time.
- Curieux also loses its current curiosity effect. Every common trait gains a minus that does not exist today.
- Fix:
  - Taquin keeps mood −8 → −16 % and adds floor +0.05.
  - Curieux keeps curiosity −10 → −20 % and adds the milestone paillettes.
  - Migrated specimens get no minus until bond 2.

**5. The "+20 %" cap is ambiguous and is not the total.**
- Bonuses are summed, then applied as a multiplier: `value×(1+Σ)` (CompanionEffects.lua:585), with pity added afterwards (Capture.lua:808).
- Type effects stack on top: capture_named reaches 0.45, so Σ = 0.63.
- Gains with pity, current best → new best:

| Target | Catches per offer, best today (Σ 0.50) | Best new (Σ 0.63) |
|---|---|---|
| Elite 1★ | 0.430 | 0.458 (+6.5 %) |
| Rare 3★ | 0.240 | 0.249 (+4 %) |

- A Téméraire-Géant at bond 5 with no type bonus goes from 0.328 to 0.364 on an elite 1★ (+11 %).
- This is safe, but almost invisible. Write the rule as: "trait + size ≤ +0.20 added to the bonus sum; total ≤ 0.95 before pity".

**6. Bond pacing is fine for a heavy player and too slow for a casual one.**

| Player profile | Bond 2 | Bond 3 | Bond 4 | Bond 5 |
|---|---|---|---|---|
| Hits the cap (10 per day) | 1 day | 4 days | 10 days | 25 days |
| Realistic 30 min (about 6 per day: route 2, treat 1, pet 1, quest 1, capture 1) | 2 | 7 | 17 | 42 |
| Same, playing 4 days a week | 3 | 12 | 30 | 73 |

- In 30 minutes, 10 points means doing all five sources, including 3 × 10 uninterrupted minutes.
- Fix: thresholds 10 / 35 / 80 / 180, plus one free catch-up point per day missed (up to 7).

**7. Bond and the daily cap need a defined scope.** The bond is account-wide, but `SpecimenWorn` scans every character (CaptureSpecimens.lua:522), so alts can wear the same reference.
- Fix: the cap is counted per specimen and per local day on `db.capture` (account), never per character.
- Migration: take the max across characters, not the sum. Use time played with that look, not `CompanionDaysTogether` (calendar days, JournalWindow.lua:2280), which hands every veteran bond 3.

**8. Retroactive study tasks pay out a windfall.** 300 species give about 780 paillettes on day one; 600 species give about 1,560. This empties every sink at once.
- Fix: retroactive tasks give feats and borders, no paillettes. Only tasks completed after the update pay.

**9. Forged or traded specimens now carry power.** Nothing checks that the sender owns what it sends (CaptureTrades audit §1). A modified client can send a 3★ Géant Espiègle.
- Fix: a received specimen gets its trait and size bonus only from bond 2 onwards.
- Study tasks count only `origin=="capture"`, like the size feats (SpecimenTraits.lua:307).

**10. Small issues.**
- Stars as "potential" is muddled: effect strength reads the best stars of the version (`CaptureStars`, CompanionEffects.lua:361), not the stars of the worn specimen. Use the worn specimen's stars.
- The bond-3 keepsake: limit it to appât or a basic treat, never a lasso or sifflet.

### Mandatory changes
1. A daily shop stock on aids (sifflet 1 per day), so paillettes stop buying power.
2. Reset `record.since` / EFFECT_DELAY when the reference changes, and block it in combat.
3. Size and Taquin act on the wariness floor (0.55 → 0.30), Géant gets a minus outside hunt mode, and Taquin and Curieux keep their current effect.