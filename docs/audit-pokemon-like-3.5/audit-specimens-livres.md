# QC 3.4 specimens: plan vs what shipped (main, QC 3.5.0)

## 1. Plan item status

| Plan item (PLAN.md) | Status | Evidence |
|---|---|---|
| §1 `lock`, `nick` (24), `zi` 75–125 | Shipped | SpecimenFilters.lua:40-43, 162-182 |
| §1 `specV` 1→2 | Partial | `SPECIMEN_SCHEMA_V2 = 2` is defined (SpecimenFilters.lua:38) but nothing reads it. `SPECIMEN_SCHEMA` is still 1 (CaptureSpecimens.lua:118) |
| §2 trait upside ×1…×2, downside from bond 2 | Shipped | CompanionEffects.lua:131-133, 438-444 |
| §3 size effects (wariness floor, named, hunger) | Shipped | CompanionEffects.lua:119-140 |
| §3 size records | Partial | Shown in chat and on the species line (SpecimenStudy.lua:237-238, 280). The guild announce does nothing (see §4) |
| §5 bond (sources, levels, potential, keepsake, migration, Codex kept) | Shipped | SpecimenBond.lua:39-50, 154-206, 285-313; CaptureSpecimens.lua:401 |
| §5 bond 5 title | Missing | `men_bond_inseparable` has no reward (FeatsCatMenagerie.lua:512) |
| §7 search, filters, views, 7 sorts, batch select | Shipped | SpecimenFilters.lua:497, 596; ReserveBrowse.lua:1-26 |
| §7 « Relâcher (n) » | Deviated | It sits on the selection card, not the batch bar (JournalReserve.lua:1131; batch bar keys are only protect/trade/cancel, :1296) |
| §7 batch release leaves shinies aside | Deviated | ReserveTidy.lua:84, 146 |
| §8 « Étude à finir » chip | Renamed | It shipped as « À étudier » (JournalWindow.lua:460) |
| §8 5 study diamonds + 1 gold | Partial | 5 diamonds (JournalWindow.lua:2796-2806). The "gold" one is the old shiny marker (`row.star`), not study progress |
| §8 species card: 5 tasks, « Tes exemplaires », « Prendre comme compagnon » | Partial | Only one text line (JournalWindow.lua:2593) |
| §9 study, 2/5 glitter, retro without pay | Shipped | SpecimenStudy.lua:28-31, 136-158 |
| §9 shiny task | Partial | Stored (`row.sh`, :119) but never paid and never shown. `STUDY_shiny` is never read |
| §10 daily stock, slots 40+20n up to 150, nickname 15 | Shipped | ShopWeek.lua:21-23 |
| §10 arrivals drawn from `soon` cosmetics + tint variants | Deviated | 8 fixed `arrival` items, 2 of them the old 3.0 cosmetics (JournalReserve.lua:48-63) |
| §10 weekly orders | Shipped, in ShopWeek.lua | Weekly.lua has no orders (ShopWeek.lua:230-342) |
| Share.lua, TrainerCard.lua | Untouched | No bond, nick or trait anywhere in either file |

## 2. Choosing the specimen that travels with you

The specimen you wear is always the **Codex reference** of the worn version (`cap:<npc>[:s]`, SpecimenBond.lua:143-151). Two separate places are involved:

1. **Réserve:** click a tile, then « Mettre au Codex » (JournalReserve.lua:739, 1253). If the current reference is bonded (level 2+) or protected, a confirm appears: « Le lien reste à l'ancien » (ReserveBrowse.lua:94).
2. **Créatures:** click the species row (JournalWindow.lua:1365-1368). A dialog compares current vs new effects (CompanionEffects.lua:906-945). Effects restart after `EFFECT_DELAY = 120` s (CompanionEffects.lua:33). Swapping is refused in combat (SpecimenBond.lua:266).

Comparison before swapping:
- The Reserve card shows the candidate's upside, downside and bond (JournalReserve.lua:1188).
- The current reference appears only as stars (« RES_CODEX_REF », :1196) or as a bond name in the confirm. Its trait, size and effects are never shown side by side.
- A Reserve specimen's bond is effectively always « Inconnu 0/10 », because points only go to the worn one (SpecimenBond.lua:173). So any upgrade starts the bond from zero.

## 3. Nickname

| Where | Shown? |
|---|---|
| Reserve tile label | Yes (JournalReserve.lua:584) |
| Reserve card title, tooltip, selection list | Yes (:1209, 1088, 1116) |
| Bond, keepsake and nickname chat lines | Yes (SpecimenBond.lua:166, 201; ShopWeek.lua:223) |
| Search | Yes (SpecimenFilters.lua:469) |
| Companion plate / `CompanionName` | **No**: uses the species name (Companion.lua:737-752) |
| Créatures card, trade window | No (CaptureTrades.lua:793, 1342 use `SpecimenLabel`) |
| Share | No (Share.lua:348-353 sends name, stars, size, rank) |
| Trainer card | No |
| Trades | Does not travel (by plan) |

## 4. Size index records

- Kept per species in `study[npc].lo/hi`, from your own catches only (SpecimenStudy.lua:120-131).
- Shown as a chat line on a new record and in « Records : %d à %d » on the species line (:280).
- **Guild announce is not implemented.** `GuildFeatAnnounce` is called inside a guard at SpecimenStudy.lua:239 but defined nowhere in the addon (a grep finds only that one reference).
- The index itself (`zi`) only drives display, sorting and records. Every effect reads the size band (CompanionEffects.lua:137-140).

## 5. Weekly orders and arrivals

**Orders** (ShopWeek.lua:244-264):
- Always the same 3 kinds:
  - type + size ≥ Grand (type picked from types you have captured);
  - one of the 8 traits with 2+ stars;
  - a zone taken from your own specimens (`where="all"`, so Codex references count).
- The pick is seeded from the week id.
- Rewards come from `{12,14,16}`.
- If nothing matches, the card shows « Aucun pour l'instant » with the button disabled (JournalReserve.lua:1491-1493). There is no reroll and no partial credit.
- `ORDER_SIZES` (:230) is dead code.
- Bonus for all three: one of **that week's 2 arrivals**, free (:332-342). If you own both, there is no « Prendre » button (JournalReserve.lua:1432) and the bonus is lost, while the note still says « choisis un cosmétique » (:1500).

**Arrivals:**
- Pool of 8 items, 2 per week, picked by a hash of `"r<week>"` (ShopWeek.lua:125-141).
- There is no rotation. Simulated over 16 weeks (week ids 2969-2984): glitter appears 7 times, 6 of them in a row (weeks 2972-2978), and the same pair comes back after 14 weeks. Consecutive ids produce correlated seeds.

**Cosmetics still "à venir":** 7, all trainer-card ones (`card_*`). `FeatResolveSoon` has no list for the `cardbg`/`cardframe` kinds (FeatsCatMenagerie.lua:600), so they can never resolve. The 8 companion `soon` items do resolve.

## 6. Bond level 5 « Inséparable »

What the player gets:
- Upside ×2 (`EFFECT_BOND_MUL`).
- One free nickname (ShopWeek.lua:204-207).
- An achievement worth 25 points, with no title.

What the plan promised but did not ship:
- **"Mark"**: none. The tile shows 4 green pips, identical to the lower pips (ReserveBrowse.lua:829-838, 857).
- **Title**: missing.
- **Reachability:** only 3-star specimens can reach level 5 (`stars+2`, SpecimenBond.lua:106).

Beyond 5: `bond.p` keeps growing with no use. Daily cap is 10, plus up to 3 from the 3.5 wish source (:46). Nothing follows level 5.

## 7. Study mastery

- Requirements: 1 catch, a 3-star, 5 catches, 3 sizes, 3 traits (`STUDY_NEED`, :30).
- Payout: 2 glitter per task + 5 for mastery, so 15 per species at most.
- Achievements 181-183 at 10/50/100 mastered species, with points only (FeatsCatMenagerie.lua:508-510).
- No gameplay, cosmetic or Codex mark. The only trace is the « Espèce maîtrisée » text and the « À étudier » chip clearing.
- The retro pass rebuilds study only from specimens still owned (:143-149), so catches released before 3.4 never count.

## 8. Data that is stored but unused, or shown with no effect

- `bond.c` per-source daily counters: never shown, so the player cannot see "today x/10".
- `row.sh` (shiny task) and `STUDY_shiny`: never shown, never paid.
- `nickFree`, `orders.bonus`, `SPECIMEN_SCHEMA_V2`: internal only, or unused.
- `zi` shown on the card as « Grand (112) »: no effect beyond its band.
- Bond line on every Reserve specimen: can't progress unless that specimen is worn.

## Weak points

1. **Bond resets when you upgrade.**
   - Evidence: points only go to the worn specimen (SpecimenBond.lua:173); « Le lien reste à l'ancien ».
   - Why it matters: a better catch costs days of bond, so players keep a weaker specimen.
2. **No side-by-side comparison.**
   - Evidence: the card shows only the reference's stars (JournalReserve.lua:1196).
   - Why it matters: swapping is a blind choice.
3. **Choosing the companion takes two screens** (Réserve, then Créatures).
   - Evidence: §2 above; « Prendre comme compagnon » is missing.
   - Why it matters: friction for the most important choice.
4. **Nickname never reaches the companion.**
   - Evidence: Companion.lua:737.
   - Why it matters: you pay 15 glitter for something you only see in the Reserve.
5. **Inséparable is a dead end.**
   - Evidence: no mark, no title, points have no use after 180.
   - Why it matters: no goal after about 2–3 weeks.
6. **Record guild announce is a no-op.**
   - Evidence: SpecimenStudy.lua:239.
   - Why it matters: a social hook that was promised and is missing.
7. **The order bonus can be lost.**
   - Evidence: no button when both arrivals are owned (JournalReserve.lua:1432).
   - Why it matters: the reward for finishing all three orders silently disappears.
8. **Orders can be impossible.**
   - Evidence: a rare trait (Zen or Espiègle, ≈5 % per catch, from the trait weights) with 2+ stars, or a zone order where your only specimen is the Codex reference. No reroll.
   - Why it matters: the weekly loop can't be completed through no fault of the player.
9. **Arrivals repeat.**
   - Evidence: glitter shows up 6 weeks in a row (simulation in §5).
   - Why it matters: the shop feels stale.
10. **Study shiny task and mastery reward nothing visible.**
    - Evidence: §7, §8.
    - Why it matters: grinding duplicates only pays 15 glitter per species.
11. **7 trainer-card cosmetics stay « à venir ».**
    - Evidence: FeatsCatMenagerie.lua:600.
    - Why it matters: achievement rewards remain empty promises.
12. **The trainer card and Share ignore bond, trait and nickname.**
    - Evidence: Share.lua:348-353.
    - Why it matters: nothing to show off from the new 3.4 systems.