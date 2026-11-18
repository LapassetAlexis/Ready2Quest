## Review of the "envies" note B: feasibility, migration and UX in the 3.4 code

**1. Too big for the 3.4 beta (critical).** Code that would break, counted by call site:
- `CompanionAdd`: 29 sites (Companion 19, Treats 3, Daily 2, and 1 each in Capture, CompanionChest, CompanionEffects, Gathering, Personality). 12 of them feed mood (kill, loot, quest, level, capture, petting, Glutton), and that need disappears.
- Other functions: `.needs` reads 32 (JournalWindow 14, Companion 11, Effects 5, Personality 1, Treats 1), `needsOk` 8 (cache key at CompanionEffects.lua:542), `CompanionMood` 6, `CompanionIsHappy` 5, `TreatForLowestNeed` 4, `CompanionHappyCount` 3, `CompanionEffectNeeds` 3, `NeedTier` 3, `CompanionHappyHints` 2 (JournalTracker), `PersonaTickNotice` 2, `CompanionStatusLine` 2.
- About 17 effect definitions of kind `decay` (CompanionEffects.lua:76-126). The note maps only some of them. `decay_mood`, `t_teasing` and `s_cuddly` act on mood, which is no longer a state, and `mascot_decay` and `decay_all` are left out.
- 17 test files mention needs. `companion_needs.lua` has to be rewritten entirely.
- The 3.4 beta 2 is already public (e76bdf6). **Fix:** ship it as its own 3.5 with a beta.

**2. The simpler variant gets about 90 % of the benefit (major).** Keep `char.companion.needs` and the tick.
- Set all three decays to 0.667/min, so 100 → 70 takes exactly 45 min. Each trigger sets the need to 100 instead of adding to it.
- "State active" means need ≥ 70. Remaining time is `(v-70)/rate`, so the timer comes free.
- Change `CompanionEffectNeeds` to return `1 + {0,.05,.10,.20}[ok]`. The cache key and its 8 `needsOk` sites stay as they are.
- The `decay` effects keep their meaning: a slower decay simply means a longer state.
- No save migration is needed, and the test changes are mostly thresholds. Delete `SERENE_FLOOR` (Companion.lua:64, 3407) and drop mood from `NEED_KEYS`. `CompanionMood` becomes the count of active states.

**3. Departing with food only works with Ready2Quest installed (major).** `DEPARTURE` is bridged from Ready2Quest (Core.lua:231-238). A Quest Companion-only player never gets Repu that way. **Fix:** label it as a Ready2Quest bonus. Eating (eat aura edge, Companion.lua:3379) stays the base source.

**4. Wish bubbles are muted at chatter levels 0-2 (major).** `CHATTER[1..2].allow` has no `need` family (Companion.lua:97-103). The bubble cooldowns (300 s overall, 900 s per need, :118-119) also clash with the note's "20 min". **Fix:** store the wish as data (`rt.wish = {key, until}`) and show it on the page, hover card and dashboard whatever the chatter level. The bubble is only an echo of it. Set the per-need cooldown to 1200 s.

**5. Mood lines lose their target (medium).** The `NEED_mood` lines ask for a cuddle or a quest turn-in, for example « Tu me fais un câlin ? Juste un petit. » and « On rend une quête ? J'adore les fins heureuses. ». Neither action gives a state any more. The other pools work unchanged as requests: « J'ai un petit creux… on s'arrête manger ? », « Je tombe de sommeil… une auberge, peut-être ? », « Et si on allait voir derrière cette colline ? ». Two problems remain:
- Lines like « Mon ventre fait plus de bruit que tes combats » are remarks, not requests.
- The energy lines clash with the existing post-login `sleepy` state.

**Fix:** move the 9 mood lines to reactions when the companion reaches Rayonnant. Rewrite the tutorial lines (CompanionLines.lua:801, 690) and GuidedTour.lua:96.

**6. Mascots and winter companions get almost nothing (medium).** They have no bond (SpecimenBond.lua:9). Their strength equals their stage (CompanionEffects.lua:385, 420), and at stage 5 a wish gives them nothing. Winter cold (`CompanionDecayFactor` wrapper, WinterCompanions.lua:731-743) has no hook, and melt targets mood. **Fix:**
- Answering a wish adds 15 min to every active state.
- Cold zone: states last +X % (the cold effect's value).
- Hot zone: timers run ×`WINTER_MELT`.

**7. "2 minutes in an inn or city" has no counter yet (low).** `IsResting()` covers both inns and cities. `rt.restIdle` (Companion.lua:3547-3553) resets after each idle line, so it can't be reused. **Fix:** add a new `rt.restSec` accumulated in the tick (:3393), granting at ≥ 120 s. These triggers all exist:
- camp edge :3386
- inn stamp Daily.lua:284
- new zone :3711, new subzone :3735
- dungeon entry :3719
- elite kill :3751
- chest CompanionChest.lua:268
- new stamp :3775

**8. Page geometry: the note's content doesn't fit (low).** The space now used runs from -366 to -524 (158 px), with 5 px of slack.
- 3 two-line plates at a 34 px step take 102 px, the mood line 16 and the wish line 16. That is 134 px, against 132 below the header.
- The "how to get it" text (about 75 characters) doesn't fit on one plate line at 11 px.

**Fix:** put "how to get it" in the plate tooltip, and merge mood and strength into the existing `EFF_STRENGTH` line (CompanionEffects.lua:1030).
- Nav dashboard (184×80): name line, one row of 3 dots, and a wish label of at most 30 characters ("Envie : manger"), not the quote.
- Hover card (220 wide): 3 rows of 18 px fit.

**9. Saved data migration (low).** At stage 5, `SERENE_FLOOR` keeps every need ≥ 50, and most are ≥ 70. The note's rule would make almost everyone Rayonnant on day 1. **Fix:** migrate to no states and leave `stageReady` alone, or use variant 2, which needs no migration.

**10. Treats left without a target (low).** `TreatForLowestNeed` (Treats.lua:179) has nothing to pick once mood is gone, and the bonbon has no need of its own. **Fix:** give the treat for a missing state, otherwise a biscuit. `PersonaTickNotice` (Personality.lua:390) changes from "hunger < 60" to "not Repu".

### Mandatory changes
1. Ship it as 3.5, not inside the 3.4 beta.
2. Build it as variant 2: numeric needs kept internally, states derived at ≥ 70, decay 0.667/min, triggers set the need to 100, factor floored at 100 %.
3. Store the wish as data shown in the UI whatever the chatter level, and give mascots and seasonal companions a non-bond reward (+15 min on active states).