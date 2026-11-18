## Findings: technical feasibility and migration (most severe first)

**1. Trait and size maluses are silently dropped by the effect engine.**
- Evidence: `ActiveOf` keeps only `effect.value > 0` (CompanionEffects.lua:~505). The `CaptureChance` wrapper returns early when `bonus <= 0` (:583). So "−5 % élites", "faim −15 % plus vite" and the others never apply.
- Evidence: `EFFECT_SLOTS = {hunt, comfort, trait}`, so there is one trait item and no size slot. `CompanionEffectValue` hard-codes the same three slots.
- Fix: add the slots `traitMinus`, `size` and `sizeMinus`, filled only when a specimen is worn (mascot and winter have none). Allow signed values: decay uses `1 − v`, so a malus is v < 0. In `CompanionCaptureBonus`, tag each item with its slot and clamp the trait+size sum to `[−0.10, +0.20]`. Remove the `bonus <= 0` early return and floor the bonus at −0.5.

**2. "Pas remplacé d'office" traps the better specimen in the Reserve.**
- Evidence: a 3★ kept beside a bonded 1★ reference is "better" (CaptureSpecimens.lua:436). It is then refused for release (:549), for trade (CaptureTrades.lua:375) and by Faire de la place. The only way out is to promote it, which drops the bonded reference.
- Evidence: `Sync`/`BestOf` (:361) still sets `creatures[npc].stars = 3`. So `men_stars3` still counts, which is fine. But effect strength reads `CaptureStars`, i.e. entry stars (CaptureQueue.lua:344, CompanionEffects.lua:361). The worn 1★ therefore gets 3★ strength, and the TrainerCard shows 3★.
- Fix: `SpecimenCanRelease`/`SpecimenCanTrade` skip "better" when the reference is bond ≥ 2 or protected, and ask for confirmation instead. Strength reads `SpecimenReference(npc, shiny).stars`. Add a test next to specimens.lua:454 and trades.lua:322.

**3. Bond changes are not in the effect cache key.**
- Evidence: the key is `app, stage, needsOk, serial, count, specSerial, stars, bonus` (CompanionEffects.lua:466). Bond points are not in it, so a level-up keeps the old value until another change.
- Fix: call `Touch(capture)` only on a level change, never on point gain. Point gain would invalidate `SpecimenReserveCount` and the worn caches 10 times a day.

**4. The migration source the note relies on does not exist.**
- Evidence: "10 points par jour passé ensemble" assumes per-specimen time. `data.since` is per character and set lazily by the journal (JournalWindow.lua:2283). The only per-appearance time is the effect record `since` (CompanionEffects.lua:433), per character and reset on every look change.
- Fix: points = `min(40, 10 × floor((now − record.since)/86400))` for each character's current `cap:` look. Take the max across characters. Store `capture.bondV = 1`.

**5. The "personne ne perd rien" claim is false, and tests pin current values.**
- Evidence: Curieux moves from curiosity decay −10 % to milestone paillettes. Taquin moves from mood decay −8 % to wariness. All six common traits gain a malus.
- Evidence: specimen_traits.lua:200 asserts `base == cap` for every trait def. Bond scaling breaks that. :358 and :374 pin trait_curious 0.10 and mischievous 0.03.
- Fix: keep `base` as the bond-1 value. Add `bondMul = {1, 1.25, 1.5, 1.75, 2}` in `CompanionTraitEffect(trait, bond)`. Rewrite those 3 checks. The changelog must say that Curieux and Taquin change.

**6. Wariness modifiers and the Curieux plus have no hook.**
- Evidence: `CaptureWariness` is a plain function (CaptureSpecimens.lua:782), and specimens.lua:377-400 pin step 0.15 and floor 0.4. Wariness only applies in hunt mode, so the Taquin, Petit and Minuscule pluses are worth 0 to casual players.
- Fix: add a new effect kind `wary` that wraps `CaptureWariness` and multiplies only `step`. Clamp the step to [0.05, 0.25] and leave the floor unchanged.
- Fix: a Curieux plus with a hunt-only effect is weak, so give Taquin a non-hunt part, e.g. −10 % mood decay kept.
- Fix: the milestone plus becomes kind `milestone`, read via `CompanionEffectValue` inside `PaillettesOnMilestones` (JournalReserve.lua:460). It must skip `opts.quiet` catch-ups, as treatZone already does (:667).

**7. The species study would pay out retroactively.**
- Evidence: "capturée" and "3★" are already true for every owned species. For example, 300 species × (2+2) is about 1,200 paillettes the day it ships.
- Fix: count retro progress but pay nothing, same as the Feats `Retro` policy for flags.
- Fix: size and trait tasks count `origin == "capture"` only. Trades have no ownership check (audit 7), so a modified client can forge `z`, `t` and a size index. Records and guild announces are capture-only for the same reason.

**8. Trade payload.**
- Evidence: `TrainerDecode` is generic key=value (TrainerCard.lua:424) and `TradeDecodeSpec` reads named keys. A new key `x` (size index, ~5 bytes) is ignored by 3.3.1 clients.
- Fix: keep `TRADE_PROTO = 1`, because bumping it makes every old client reply `D version`. A missing `x` means the cran midpoint. Never send `nick`, lock or bond (bond resets on trade). Check `#encoded ≤ 250` in tests with 48-byte names.

**9. Schema.**
- Fix: `specV 1→2`, with lazy repair in `Store` (:313).
- Fix: `lock` (bool), `nick` (≤24 bytes), `bond = {p, day, c = {route, treat, pet, quest, cap}}` written only when non-zero, and `zi` derived deterministically from `id` for existing specimens.
- Fix: `capture.study[npc] = {t = bits, z = bits, n, paid = bits}` and `capture.slotBuys`.
- Shop migration: `slotBuys = floor(reserveBonus/10)`. Players already above 150 keep their slots and see "max".

**10. Filter panel: costs and "built once".**
- Cost: lookups of `creatures[npc]` are O(1). Facet counts over 150 specimens × ~11 groups is about 2k operations, cheap if cached on `specSerial` and the filter.
- Cost: zone names via `C_Map.GetMapInfo` should be cached per uiMapID for the session.
- The zone list is unbounded, so it must be a dropdown, not chips.
- Migrated specimens carry the 6 exclusive traits, which the 15-choice list misses today (JR:442).
- Prebuild about 55 chips plus a pool of 8 pills plus a "+n" pill.
- Rangée 2 collides with the warn line and gift button at −172 (JR). Move warn into the pills row.
- The batch bar's "Proposer à l'échange" only works inside an open trade, so limit it to the trade picker.
- Persist `resShow`/`resNpc`/views via `STATE_VALID` (JW:377).

**11. Bond exploits.**
- "10 min de route" gives AFK points. Use `data.travel` instead, e.g. 1 point per 1.5 km, max 3 per day.
- The same reference can be worn on several characters. Counters must be per specimen and account-wide, keyed on `DayKey()`.

**12. i18n and API.**
- i18n: about 140 new keys (8 traits × 2 lines, 10 size lines, 5 bond levels plus 5 sources, about 25 filter labels, 6 views, the batch bar, 6 study tasks, shop and orders), so about 420 entries across FR/EN/ES. Search keywords need per-locale alias tables.
- API risk is low: `CreateSearchBox` is already used (CompanionAllure.lua:522) and Ctrl/Shift are already read via `Key()`. `ClearFocus` must run on Escape and on hide.

## Lots, in this order
1. **Filters, protection, selection.** CaptureSpecimens.lua (filter predicates, sorts, `lock`, "protected" reason, specV 2), ReserveTidy.lua, JournalReserve.lua (rows, panel, batch bar), CaptureTrades.lua (picker filters, CanTrade), JournalWindow.lua (STATE_VALID), Locales_es.lua. Tests: specimens, menagerie_journal, trades, ui_windows.
2. **Profile and bond.** A new SpecimenBond.lua (wraps `CompanionTick`, `TreatGive`, `CompanionPet`, `CaptureResolve`, QUEST_TURNED_IN), SpecimenTraits.lua (`zi`, plus/minus defs), CompanionEffects.lua (slots, signed values, `wary` and `milestone` kinds, cap, bond multiplier), CaptureSpecimens.lua (non-replacement, ref.stars), CaptureTrades.lua (`x`), then the JournalReserve card, Share and TrainerCard. Tests: specimen_traits.
3. **Study, records, shop, orders, feats.** A new SpecimenStudy.lua, the JournalReserve shop, Weekly.lua, FeatsData.lua / FeatsCatMenagerie.lua.

Lot 2's core (CompanionEffects and SpecimenBond) can run in parallel with lot 1. Edits to JournalReserve.lua wait for lot 1 to merge.

## Mandatory
1. Signed effect values plus the new slots and per-slot tagging (#1). Without them, half of the profile does nothing.
2. Exempt bonded or protected references from the "better" lock, and compute strength from `ref.stars` (#2).
3. No retroactive study payout, and records/study count `origin == "capture"` only (#7).