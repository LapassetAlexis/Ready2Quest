# Review: note-envies.md, option B (lens: balance and player behaviour)

Simulation scripts: `/private/tmp/claude-2007623921/-Users-alexis-lapasset-orca-workspaces-ReadyToQuest-qc-reserve-design/c71c5d45-23dc-4285-87e3-69915616ccc5/scratchpad/envies/sim2/states_sim.py` and `/private/tmp/claude-2007623921/-Users-alexis-lapasset-orca-workspaces-ReadyToQuest-qc-reserve-design/c71c5d45-23dc-4285-87e3-69915616ccc5/scratchpad/envies/sim2/power_treats.py`. Each scenario was run 3000 times in 1-minute steps.

**Trigger rates assumed (from the code's events):**
- **Levelling:** a new subzone every 5 min, an elite or rare every 20 min, a stamp every 30 min, a camp or town every 20 to 25 min for 1 to 4 min. Casters drink every 4 min, melee eat every 25 min.
- **Farming at 60:** a rare every 90 min, a town trip every 60 min.
- **Dungeon:** every mob is elite (`Companion.lua:3747`).

| Scenario | % of time at 0/1/2/3 states | Average force |
|---|---|---|
| 30 min of levelling | 2 / 3 / 7 / **88** | 1.185 |
| 2 h levelling, caster | 0 / 1 / 21 / **78** | 1.177 |
| 2 h levelling, melee | 2 / 16 / 43 / 39 | 1.129 |
| 3 h farming at 60, caster | 2 / 55 / 38 / **5.5** | 1.076 |
| 3 h farming at 60, melee | 18 / 48 / 30 / **4** | 1.062 |
| 3 h farming, hearth every 45 min | 5 / 27 / 51 / 18 | 1.099 |
| Dungeon, 75 min | 0 / 1 / 39 / 60 | 1.159 |

## Findings, most severe first

1. **The bonus is smaller than the penalty the note calls unfelt.**
   - A normal one-star companion goes from ×1.12 to ×1.144 capture, a gain of 0.024. The note calls today's loss of 0.03 (×1.12 to ×1.09) unfelt.
   - Shiny undead: 1/115 becomes 1/110 at strength 2. Shiny chain: 25 kills to the maximum become 22.7, which means nothing after 10 minutes of farming.
   - At strength 4.25 (the top captured creature) and for a mascot at stage 5, every effect is already at its cap, so the bonus is nil. The exceptions are spot, decay_all and capture_all, which gain +0.01 to +0.04. The cap at ×1.2 is reached from strength 2.5 to 4.17 (`CompanionEffects.lua:429`).
   - So "un but au niveau 60" is false for exactly the endgame players.
   - **Fix:** apply Rayonnant outside the type caps, as a capture chance ×1.10 after effects and before CAPTURE_MAX, and shiny ×1.25 (1/150 becomes 1/120). Content and Joyeux become cosmetic only.

2. **The bonus goes to the wrong players.**
   - Levellers are Rayonnant 78 to 88 % of the time without trying.
   - Hunt-mode farmers at 60, who care most about capture and shinies, are Rayonnant 4 to 6 % of the time. Éveillé is up only 34 % for them because they find no new subzones and kill few rares.
   - At 60 the system turns into "eat a carte every 90 min", which is the chore again.
   - **Fix:** Éveillé also comes from 15 kills or captures in hunt mode within 10 min, from a shiny kill, or from a new species stamp.

3. **Treats alone keep the companion Rayonnant.**
   - A full pantry (3+3+3 singles, 2 festins, 3 bonbons) holds 1620 state-minutes, which is 9 h of Rayonnant.
   - Daily income is worth 2.2 h (30-min player) to 6.5 h (3-h player) of Rayonnant, so the bonus is effectively permanent.
   - Overflow at 2 paillettes per treat brings 6.8 to 19.4 paillettes a day, against 17.6 a day from missions (14 daily, 3.6 weekly share; `Daily.lua:58-62`). That is +39 to +110 % income.
   - Levellers never need treats under B, so the pantry overflows the most for them.
   - **Fix:** treat duration 60 min, festin 60 min, overflow worth 1 paillette.

4. **Extensions have no ceiling.**
   - Petting adds 5 min every 15 min, so a state lasts 135 min. With Câlin (10 min) it lasts 270 min. Bonbons add 30 min each on top.
   - This brings back the "pet every 15 min or lose the buff" ritual, the same chore as hunter pet feeding.
   - **Fix:** remaining time can never exceed the state's full duration (45 or 90). Petting gives no extension, only bond.

5. **The companion rarely voices a wish.**
   - It only wishes for a state it lacks, so with 78 to 88 % Rayonnant uptime it voices only 0.8 to 1.5 wishes per session. The 36 lines go nearly silent while levelling.
   - +1 bond per wish changes nothing for active players: other sources already offer 17 points a day against the 10-point cap (`SpecimenBond.lua:40,43`). Bond 5 still takes 18 days.
   - **Fix:**
     - When all three states are up, he wishes for the one with less than 15 min left.
     - The wish point goes outside the daily cap, 3 a day at most.

6. **The stage gate is trivial.** A new player is Rayonnant 88 % of the first 30 min: two minutes in the inn, then leaving town with food, then any subzone. **Fix:** say it plainly as "fulfil one wish", or drop the gate.

7. **Every percentage modifier in 4.5 is invisible.**
   - ±10 % is ±4.5 min. Uptime at 3 states moves by only 0.5 to 6.7 points, and average force by ≤0.007.
   - The preferred-state +30 % is only 13.5 min, and Paresseux saves 1 minute.
   - **Fix:** replace them with discrete rules, for example:
     - Curieux: gathering also gives Éveillé.
     - Gourmand: drinking no longer counts, only the Well Fed aura.
     - Paresseux: any camp gives Reposé at once.
     - Use ±50 % only if a duration change is kept.

8. **Repu depends on class.** Drinking refreshes Repu, so casters keep it 98 to 99 % of the time and melee 71 to 73 %. **Fix:** count the eat aura and Well Fed (`Companion.lua:3380-3383`), not drink.

9. **Some rules become undefined.**
   - `TreatForLowestNeed` (`Treats.lua:179`, `Daily.lua:453`) has no "lowest need" any more. **Rule:** the treat for the missing state, or the one with the least time left.
   - The bonbon no longer gives a state, so a mission that rewards one gives almost nothing. **Rule:** bonbon gives +bond instead.

10. **Reposé is trivial for anyone who hearths or uses the bank,** since `IsResting` is true in capitals: 97 % uptime in a 30-min session that starts in an inn. That is acceptable only if the decision says so.

## Mandatory changes

1. Rayonnant pays outside the type caps: capture ×1.10 before the 0.95 cap and shiny ×1.25. Without that, the bonus is unfelt and nil at the top tier.
2. Add hunt-mode Éveillé triggers (15 kills or captures in 10 min, a shiny, a new species), so farming at 60 is not 4 % Rayonnant.
3. Cap every extension at the full duration, shorten treats to 60 min and set overflow to 1 paillette, so treats and petting do not make Rayonnant permanent.