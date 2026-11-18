# QC audit: capture odds and the paillettes economy

## 1. Capture chance

`ns:CaptureChance` is at Capture.lua:386-406. CompanionEffects.lua:580-588 wraps it, and `CaptureRoll` adds the pity bonus at Capture.lua:807-810.

```
if aid == sifflet → 1 (sure)
chance = RATE[class] × levelFactor × QUALITY[stars] × wary × aidMult
chance = min(0.95, chance)                       -- CAPTURE_MAX, Capture.lua:30
chance = min(0.95, chance × (1 + effectBonus))   -- CompanionEffects.lua:585
chance = min(0.95, chance + 0.05 × min(5, missStreak))  -- pity, Capture.lua:43,808
```

| Term | Values | Where |
|---|---|---|
| RATE | trivial/minus 0.60, normal 0.50, elite 0.25, rare 0.15, rareelite 0.10, worldboss 0.04 | Capture.lua:34-37 |
| levelFactor | mob above you: `max(0.5, 1-0.04·diff)`. Mob below you: `min(1.5, 1+0.03·|diff|)` | Capture.lua:40,393-397 |
| QUALITY | 1★ ×1, 2★ ×0.8, 3★ ×0.6 | CaptureSpecimens.lua:130 |
| wary | Hunt mode only: `max(0.4, 1-0.15·capturesToday[npc])`. The count goes up on every successful capture and resets each local day (`%Y-%m-%d`) | CaptureSpecimens.lua:138,763-792; CaptureQueue.lua:766 |
| Aids | appât ×1.5 (bag cap 10), lasso ×2.5 (cap 5), sifflet = sure (cap 3) | Capture.lua:45-49 |
| Pity | +0.05 per consecutive miss, up to 5 misses (+0.25). Resets on a success | Capture.lua:43,807-810 |

Companion effects add to `effectBonus` (CompanionEffects.lua:64-107):

- capture_humanoid: 0.10 per point, cap 0.40
- capture_named: 0.12, cap 0.45
- capture_all: 0.02, cap 0.10
- spot (beast not yet captured): 0.05, cap 0.25
- trait_daring: 0.05; trait_mischievous: 0.03
- winter_nose: night capture 0.03, cap 0.15

Two aid effects reduce aid consumption:

- aidKeep: elemental, 0.08, cap 0.30
- aidRefund: mechanical, 0.20, cap 0.75

The "Aide conseillée automatique" setting (express capture) spends the strongest aid in the bag on a 3★ or a shiny (CaptureExpress.lua:149-155; CaptureStage.lua:1381).

## 2. Quality and shiny

Quality is rolled at the kill (CaptureQueue.lua:581; CaptureSpecimens.lua:122-128):

| Group | 1★ | 2★ | 3★ |
|---|---|---|---|
| normal (includes trivial and minus) | 65 | 28 | 7 |
| elite | 50 | 35 | 15 |
| rare (includes rareelite and worldboss) | 30 | 45 | 25 |

Because a better specimen is harder to catch, captured normal mobs come out at about 71 / 24.5 / 4.6 %. Arithmetic: 0.65×1, 0.28×0.8 and 0.07×0.6, normalised over 0.916.

Each specimen also gets a size roll: tiny 2, small 18, normal 60, large 18, giant 2 (SpecimenTraits.lua:59-64).

Shiny is rolled once per GUID, the first time the mob is targeted or hovered (Shiny.lua:218-251). The formula is at Shiny.lua:183-187:
`1/150 × (3 if elite/rare/rareelite/worldboss) × (1 + 2.75 × min(kills,50)/50)`

- The kill-chain multiplier reaches ×3.75 at 50 kills of that species (1/40). For an elite at full chain that is 0.075.
- A sealed zone multiplies by ×1.5 (MenagerieCollection.lua:25,392-398).
- Effects (CompanionEffects.lua:595-604): shiny_undead +0.15 per point (cap 0.60); trait_mystic +0.05 on all creatures; shiny_chain multiplies kills by (1+v), cap 1.5; trait_parrot 0.10.
- Killing a shiny gives a free lasso (Capture.lua:962). It also gives a treat: a Festin 15 % of the time, otherwise a random basic treat (Shiny.lua:277).

## 3. Hunt mode and throttles

- **Hunt mode** (CaptureSpecimens.lua:683-742): every kill joins the net queue (reason `hunt`, CaptureQueue.lua:404,582). Durations are 5/15/30/60 min or until stopped (`HUNT_CHOICES`, :136).
  - Its only cost is wariness.
  - No cooldown, no daily cap and no per-hour cap: not found.
- **Outside hunt mode**, a kill is offered only if it is: a shiny, a new version, better stars than your Codex specimen, or a pinned species (CaptureQueue.lua:398-406).
- **Throttles:**
  - Queue: max 12 candidates, each kept 30 s counted from the end of combat (CaptureQueue.lua:31-32).
  - One net at a time (`state.rolling`).
  - Classic flow: the pending prompt lasts 12 s (Capture.lua:28), and there is no throw in combat (CaptureQueue.lua:648).
  - Express capture throws instantly, can be chained, and works in combat. Shift+click empties the whole queue (CaptureExpress.lua:541-603).
  - A full Reserve blocks only versions you already own (CaptureSpecimens.lua:642-647). It holds 50 slots at base (:120).
- **Free sifflet** for every 10 new species (Capture.lua:31,884).

## 4. Paillettes sources

All paillettes are account-wide (CaptureData).

| Source | Amount | Cap / frequency | Where |
|---|---|---|---|
| Release from the Reserve | 1★ 2, 2★ 4, 3★ 10, shiny 25 | Not the Codex reference, not a worn look, not a specimen better than the Codex | CaptureSpecimens.lua:134,534-568 |
| Daily zone or trait mission | 3 each, ×3 missions | per day, per character | Daily.lua:58-59 |
| All 3 dailies done | +5 | per day | Daily.lua:60,504 |
| Weekly mission | 5 each, ×3 | per week | Daily.lua:61; Weekly.lua:201 |
| All 3 weeklies done | +10 | per week | Daily.lua:62 |
| Zone milestone 25/50/75 % | 2 each | Once per zone per character (6 per zone) | JournalReserve.lua:54,460-472 |

Not found as sources: feats, chest, trades, inn. All mission paillettes require capture to be on.

**Estimate** (my assumptions; nothing here is from the code):

- **Casual, 30 min, no hunt mode:**
  - Dailies, all 3: 9 + 5 = 14.
  - Weeklies: about 1 of 3 per week, 5/7 ≈ 0.7.
  - Milestones: about 1 per day, 2.
  - Releases: about 5 Reserve specimens per day (old Codex references pushed out by upgrades), each worth about 2.86 on average (0.71×2 + 0.245×4 + 0.046×10), so ≈ 14.
  - **Total ≈ 30 per day.**
- **Heavy, 3 h, hunt mode for 2 h:**
  - Kills: about 2 per minute, so about 240 offers.
  - Success rate:
    - Equal-level normal mob: average chance ≈ 0.458. With the pity Markov chain that is about 2.0 tries per catch, so a 50 % success rate.
    - Farming a few species with wariness at its 0.4 floor: chance ≈ 0.183, or 3.6 tries per catch with pity, so 28 %.
    - Taken as a blend: about 35 %.
  - Captures: 240 × 0.35 ≈ 84 specimens, × 2.86 ≈ 240 paillettes. The Reserve, at 50 slots, forces releases along the way.
  - Missions: 14 + 3.6 (25/7) = 17.6.
  - Milestones: about 3, so 6.
  - **Total ≈ 260 per day.** That is about 9× the casual figure.

## 5. Paillettes sinks

Shop (JournalReserve.lua:42-51, `ShopBuy` :307-323):

| Item | Price | Repeatable |
|---|---|---|
| Appât | 4 | Yes, up to bag cap 10 |
| Lasso | 12 | Yes, up to bag cap 5 |
| Sifflet | 35 | Yes, up to bag cap 3 |
| +10 Reserve slots | 40 | Unlimited (no cap found) |
| Frame `shop_glitter` | 80 | Once, account-wide |
| Background `shop_starfall` | 60 | Once, account-wide |

Filling every bag cap once costs 40 + 60 + 105 = 205, and the one-time cosmetics cost 140 in total. Not found as sinks: trades, rerolls, anything else.

## 6. Missions

- **Daily missions** (Daily.lua:377-412; MissionsMenagerie.lua:156-184). They are drawn at the first zone entered each local calendar day (poll every 2 s, Daily.lua:24,592). Three slots:
  1. **Menagerie:**
     - capNew: 1 species never captured in the zone
     - capNamed: 1 elite or rare in the zone
     - capType: 2 of a type, in the zone
     - fallback "captures": 2 anywhere
  2. **Exploration:**
     - gather: 5
     - quests: 2 turn-ins
     - village: 1 new place
     - percent: +3 % zone completion
     - fallback: talks 3 / kills 10
  3. **Trait** (Daily.lua:40-48):
     - places 2, meals 3, elites 1, rest 15 or 10 min, kills 20, pets 3 or 5
     - turnins 3, talks 3 or 4, nightKills 5 (21:00–06:00 game time), calm 15 min without dying, gold 1
     - generic default: pets 3
  - Rules:
    - One reroll per day, zone missions only (Daily.lua:415).
    - Missions not done are dropped the next day.
    - Each completion: treat for the lowest need + appât + 3 paillettes + 10 curiosity.
    - All three: Festin + lasso + 5. Ten perfect days unlock the `squirrel_mech` look (Daily.lua:27).
- **Weekly missions** (Weekly.lua:20-30,134-169). Three per week:
  - always one capture mission: typeCapture (2 of type X, captured while bringing a type-X companion) or captures 6 / captureNamed 1
  - one shiny mission: shinyKill 1 or shinyCapture 1
  - the third from: dailies 8, kills 150, stamps 6, gather 20, turnins 15
  - Reset: server weekly reset (`C_DateAndTime.GetSecondsUntilWeeklyReset`), otherwise the `%Y-%W` calendar week.

## 7. Other currencies and loops

- **Treats** (Treats.lua):
  - Pantry, per character: 3 of each basic treat (biscuit, infusion, bonbon, carte), 2 Festins (:23). When full, the treat is eaten on the spot.
  - Sources:
    - zone 25/50 % milestone: treat for the lowest need; 75 %: Festin (:271-288)
    - missions
    - shiny kill
    - golden chest: Festin + 2 random (:339-358)
    - inn card: Festin every 7 stamps, 1 stamp per day, +20 energy each (Daily.lua:21-22,283-304)
  - Sink: give to the companion, which sets that need to 100 (all four for a Festin).
  - Why it matters: companion effects need each need ≥ 50 (`EFFECT_NEED_OK`, CompanionEffects.lua:34), and those effects carry the capture and shiny bonuses.
- **Capture aids from other sources** (Capture.lua:56-67):
  - Journal stamps: subzone 25 % appât, capital 25 % appât, zone 100 % weighted draw, rare 50 % lasso, dungeon 100 % lasso + 20 % sifflet, level 30 % draw.
  - Draw weights: appât 60 / lasso 33 / sifflet 7.
  - Zone milestones: 25 % appât, 50 % lasso, 75 % draw.
  - Effect aidZone adds extra drops.
- **Zone chest** (CompanionChest.lua:231-286): a zone at 100 % lets you pick one tier cosmetic. The tier comes from the zone's minimum level: <20 → 1, <40 → 2, otherwise 3. Once a tier is exhausted, the zone turns golden.
- **Shiny cosmetics**: at 5/15/30/50 shiny kills (Shiny.lua:38-47).

This audit was read-only. Two files outside your list were needed and also read: CaptureSpecimens.lua, which holds quality, wariness, hunt mode and the paillettes API, and JournalReserve.lua, which holds the shop and the milestone paillettes. Supporting parts of Weekly.lua, MissionsMenagerie.lua, CompanionEffects.lua and MenagerieCollection.lua were checked too.