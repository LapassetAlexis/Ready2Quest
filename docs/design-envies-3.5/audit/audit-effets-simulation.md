## Needs audit, QC 3.4.0 (`/Users/alexis.lapasset/Projects/ReadyToQuest-wt/qc-3-4/QuestCompanion`)

### 1. needsFactor
`CompanionEffects.lua:361-368`: `factor = 0.5 + 0.5 * ok/4`, where `ok` counts the needs that are `>= EFFECT_NEED_OK` (50, l.34). The possible values are 1.0, 0.875, 0.75, 0.625 and 0.5.

**What it scales.** It only scales the type's `hunt` and `comfort` slots (l.427-431): `value = min(cap, base * strength * factor)`. That covers captured creatures, mascots and seasonal companions (Winter Veil). `strength` = rank (1 / 1.5 / 2 / 2.5) + 0.5 if shiny + 0.25 per star above 1 + type bonus (`MENAGERIE_TYPE_STEP` 0.25 per tier, at most 3 tiers, so +0.75). A captured creature therefore tops out at 4.25. For mascots and seasonal companions, strength is the stage (1 to 5).

**What it does not scale:**
- trait effects (`CompanionTraitEffect` l.444-450: `base * EFFECT_BOND_MUL[bond]` only);
- extras: the second upside, the downsides and the size effects (`CompanionProfileExtras` l.455-473: `def.base` stays fixed);
- bond;
- wariness;
- the Personality preferred-need modifiers.

**Feedback loop.** `decay_*` comfort effects are themselves scaled by the factor, so a lower factor makes needs decay faster.

**Shown to the player.** The journal shows it as "Force ×s · envies n/4 : p %" (l.1030).

### 2. Effect values: factor 1.0 / 0.75 / 0.5

| effect | base | cap | strength 1 | strength 2 | strength 3.5 |
|---|---|---|---|---|---|
| spot | .05 | .25 | .05/.04/.03 | .10/.08/.05 | .18/.13/.09 |
| capture_humanoid | .10 | .40 | .10/.08/.05 | .20/.15/.10 | .35/.26/.18 |
| shiny_undead | .15 | .60 | .15/.11/.07 | .30/.22/.15 | .53/.39/.26 |
| aid_keep | .08 | .30 | .08/.06/.04 | .16/.12/.08 | .28/.21/.14 |
| shiny_chain | .50 | 1.50 | .50/.38/.25 | 1.00/.75/.50 | 1.50/1.31/.88 |
| capture_named | .12 | .45 | .12/.09/.06 | .24/.18/.12 | .42/.32/.21 |
| aid_zone | .25 | 1.00 | .25/.19/.12 | .50/.38/.25 | .88/.66/.44 |
| aid_refund | .20 | .75 | .20/.15/.10 | .40/.30/.20 | .70/.53/.35 |
| capture_all (mascot) | .02 | .10 | .02/.01/.01 | .04/.03/.02 | .07/.05/.04 |
| decay_hunger/energy/curiosity/mood | .10 | .40 | .10/.08/.05 | .20/.15/.10 | .35/.26/.18 |
| treat_zone | .15 | .60 | .15/.11/.07 | .30/.22/.15 | .53/.39/.26 |
| pet_mood | .25 | 1.00 | .25/.19/.12 | .50/.38/.25 | .88/.66/.44 |
| decay_all | .05 | .25 | .05/.04/.03 | .10/.08/.05 | .18/.13/.09 |
| rest_energy | .15 | .60 | .15/.11/.07 | .30/.22/.15 | .53/.39/.26 |
| mascot_decay | .04 | .20 | .04/.03/.02 | .08/.06/.04 | .14/.11/.07 |
| winter_treat / winter_energy / winter_nose / winter_pet / winter_cold | .10/.08/.03/.25/.06 | .50/.40/.15/1.00/.30 | linear, same pattern | | |

- **Exact case asked:** capture_named at its 0.45 cap, i.e. strength ≥ 3.75 (only reachable with the type bonus), drops to 0.45 × 0.5 = 0.225 at factor 0.5. A normal-rank, one-star creature loses 0.06: the capture chance goes from ×1.12 to ×1.06.
- **winter_sack:** its value is never read. `WinterSackCheck` (`WinterCompanions.lua:676-700`) only checks that the companion is Greatfather Winter, so the factor has no real effect on it.

Trait values at bond 1 to bond 5 (×1 to ×2), not scaled by needs (`CompanionEffects.lua:95-108`):

| trait effect | value |
|---|---|
| curious | decay curiosity .10 → .20 |
| glutton | treatZone .10 → .20 |
| daring | capture_named .05 → .10 |
| lazy | rest .10 → .20 |
| teasing | decay mood .08 → .16 |
| cuddly | pet .25 → .50 |
| wise | .05 |
| parrot | .10 |
| mystic | .05 |
| zen | .05 → .10 |
| sly | .10 |
| mischievous | .03 → .06 |
| fearful | .08 |
| tinker | .08 |

Trait + size capture bonuses are clamped together to [-0.10, +0.20] (l.136, l.656-661). The total capture bonus is never below -0.5 (l.681).

### 3. 3.4 maluses on need decay
All are fixed and apply from bond ≥ 2 (`EFFECT_BOND_EXTRA`, l.134, l.467). Decay is multiplied by `(1 - v)` (l.795), so a negative value speeds it up.

| source | effect | line |
|---|---|---|
| minus_curious | energy ×1.10 | l.113 |
| minus_glutton | hunger ×1.15 | l.114 |
| minus_lazy | curiosity ×1.10 | l.116 |
| minus_teasing | energy ×1.10 | l.117 |
| minus_cuddly | mood ×1.10 | l.118 |
| minus_daring | wary −0.05 (not a decay effect) | l.115 |
| size_large_hunger | hunger ×1.05 | l.126 |
| size_giant_hunger | hunger ×1.10 | l.129 |

**Offsetting bonus.** The specimen trait also becomes the persona (`SpecimenTraits.lua` `CompanionTrait` wrap) when the "Caractère" setting is on "Apparence", the default. Its preferred need then decays ×0.7 and gains ×1.5 (`Personality.lua:145-146`, 247-261). For a Glutton, the preferred need is hunger.
- Giant + Glutton at bond ≥ 2: hunger = 0.6 × 0.7 × 1.15 × 1.10 = 0.531/min, slower than the base 0.6.
- Giant with any non-hunger trait: hunger = 0.66/min.

**Wariness** (`CaptureSpecimens.lua:138`, 799-808): `step 0.15, floor 0.4`, and only while hunt mode is active. In 3.4 the floor becomes `clamp(0.4 + Σwary, 0.25, 0.60)` (`CompanionEffects.lua:1209-1226`): tiny +.15, small +.05, plus_teasing +.05, minus_daring −.05, large −.05, giant −.10. These are independent of needs.

### 4. Bond (`SpecimenBond.lua`)

| item | value |
|---|---|
| levels (l.39) | 0 / 10 / 35 / 80 / 180 points |
| daily cap (l.40) | 10 points |
| maximum level (l.101-105) | stars + 2, clamped to 3..5 |
| route (l.43) | 1 point per 1500 m, cap 3/day |
| treat given (l.43) | 2 points, cap 4/day |
| pet (l.43) | 1 point, cap 2/day |
| quest turned in (l.43) | 2 points, cap 4/day |
| successful capture (l.43) | 2 points, cap 4/day |
| keepsake (l.47) | bond 3: 30 % chance on the first point of the day, a bait or a treat |
| migration (l.48) | 10 points per day already worn, at most 35 |

- Only the worn specimen earns points. Mascots and seasonal companions earn none.
- **Links to needs.** The `treat` source (`TreatGive`, l.221-228) and the `pet` source (l.229-236) are the only ones tied to the needs system. The `pet` wrapper does not check `companionLastPet`, so a call that returns true also counts. The `CompanionEffects` comment (l.819-821) says that includes the pantry (Maj+clic) and the tutorial. Need levels never gate bond.

### 5. Other things gated by needs

| what | rule | file |
|---|---|---|
| Stage evolution | all 4 needs ≥ `HAPPY_MIN` 70 and awake. Otherwise `stageReady` waits, and the goal list shows "happy n/4" | `Companion.lua:807-862`, 3954 |
| Speech bubbles | lowest need < `NEED_LOW` 35 → `NEED_*` bubble, cooldowns 300 s overall and 900 s per need | `Companion.lua:3446-3458` |
| Mood label | average ≥ 75 radiant, ≥ 50 happy, otherwise dreamy (shown in the hover and the forged medallion) | `Companion.lua:772-781`, `ForgeCompanion.lua:213` |
| Floating animation | when happy | `CompanionFx.lua:215` |
| Glutton remark | hunger < 60 | `Personality.lua:390` |
| Missions | the reward treat is the one for the lowest need (`TreatForLowestNeed`) | `Daily.lua:453` |

Shouts, voices, feats and mission completion: no needs reads found (grep of `.needs`, `IsHappy` and `CompanionMood` across the addon).

**Last stage.** At `stage ≥ 5` the floor becomes `SERENE_FLOOR` 50 (`Companion.lua:64`, 3407). Since 50 is `>= EFFECT_NEED_OK`, needsFactor stays at 1.0 forever.

### 6. Simulation
Script: `/private/tmp/claude-2007623921/-Users-alexis-lapasset-orca-workspaces-ReadyToQuest-qc-reserve-design/c71c5d45-23dc-4285-87e3-69915616ccc5/scratchpad/envies/sim/needs_sim.py`

**Assumptions:**
- start at 80 (`NEED_START`), 10 s ticks;
- per minute decay: hunger 0.6, energy 0.4, mood 0.3, curiosity 0.5;
- 2 kills/min, each mood +1 (`Companion.lua:3788`);
- 1 quest per 10 min, mood +12 (l.4442);
- 1 new subzone per 5 min, curiosity +4 (l.3735);
- no eating, no treats, no rest, no inn; no decay-type comfort effect.

Times in minutes (session-length rows: needsFactor at the end, and from which minute):

| scenario | hunger <50 | hunger <35 | energy <50 | energy <35 | 60 min | 120 min | 180 min |
|---|---|---|---|---|---|---|---|
| base | 50.2 | 75.2 | 75.2 | 112.5 | 0.875 (from 50) | 0.75 (from 75) | 0.75 |
| Giant, non-hunger trait, bond ≥ 2 | 45.5 | 68.3 | 75.2 | 112.5 | 0.875 (from 46) | 0.75 | 0.75 |
| Giant + Glutton, bond ≥ 2 | 56.5 | 84.8 | 75.2 | 112.5 | 0.875 (from 57) | 0.75 | 0.75 |
| Giant + Glutton, bond 1 | 71.5 | 107.2 | 75.2 | 112.5 | 1.0 | 0.75 | 0.75 |
| Curious, bond ≥ 2 | 50.2 | 75.2 | 68.3 | 102.3 | 0.875 | 0.75 | 0.75 |
| last stage (any of the above) | never | never | never | never | 1.0 | 1.0 | 1.0 |
| base, no new subzones | 50.2 | 75.2 | 75.2 | 112.5 | 0.875 | 0.625 (curiosity <50 at 60.2, <35 at 90.2) | 0.625 |

- Mood stays at 100 throughout: kills alone add +2/min against a 0.3/min decay.
- Hunger and energy reach the floor of 15 at about 108 min and 162 min.
- In normal questing, factor 0.5 is never reached. The realistic worst case is 0.75, or 0.625 with no exploration.
- Real refills not modelled:

| refill | amount | file |
|---|---|---|
| eating | +35 at the start, +6/min while eating, +15 when "fed" | `Companion.lua:3380-3383` |
| departure with food in bags | +10 | l.3974 |
| resting | +4 energy/min | l.3410 |
| camp | +10 energy | l.3387 |
| inn stamp | +20 energy | `Daily.lua:21` |