# Specimen data model audit: QuestCompanion 3.3.1

## 1. Fields stored per specimen
Each specimen is stored as `capture.specimens[id]`. The doc block is at CaptureSpecimens.lua:29-35. `SpecimenAdd` builds the record at :380-388, and `Store` repairs or migrates the table at :313-324.

| Field | Type / values | Where set |
|---|---|---|
| `id` | int, taken from `capture.specNext` (`NewId`, :252-257) | :380 |
| `npc` | npc id (`tonumber` if possible) | :380 |
| `stars` | 1..3, kept in range by `Clamp` (:228) | :380 |
| `shiny` | `true` or nil | :380 |
| `zone` | uiMapID or nil | :380. A capture passes `target.zoneID` (CaptureQueue.lua:762) |
| `at` | `time()` or nil | :381. A capture passes `time()` (CaptureQueue.lua:762) |
| `by` | character name (plain) | :381 |
| `origin` | `"capture"`, `"migration"`, `"gift3"` or `"trade"` | :381. Migration :283, gift :891, trade CaptureTrades.lua:760 |
| `name` | creature name text | :381 |
| `trait` | key of `ns.PERSONALITY_TRAITS`, rolled if missing | :384. Weights at SpecimenTraits.lua:53-56: curious, glutton, daring, lazy, teasing, cuddly ×3; zen, mischievous ×1 |
| `size` | `tiny`, `small`, `normal`, `large`, `giant` | :386-388. Rolled only when origin is `"capture"`; otherwise `"normal"`. Weights 2/18/60/18/2 and scales 0.75/0.88/1/1.12/1.25 (SpecimenTraits.lua:59-64) |
| `tradedFrom`, `tradedAt`, `firstOrigin`, `hops` | trade metadata | CaptureTrades.lua:764-765 |

**Not stored on the specimen:**
- level, creature class (rank), type, family and display: these live only in the per-species summary `capture.creatures[npc]`, with fields `name`, `class`, `level`, `type`, `family`, `zoneID`, `normal`, `shiny`, `stars`, `shinyStars`, `at`, `shinyAt` (Capture.lua:858-866).
- a GUID, the time of day, any favourite or locked flag, and any nickname.

Trades send `cl`, `ty` and `fa` taken from the species entry (CaptureTrades.lua:421-422). The receiving side does not keep them on the specimen.

Other keys on `capture` (:36-44):
- `codex`, `specNext`, `specV` (= `ns.SPECIMEN_SCHEMA` = 1, :118) and `traitV`
- `specSerial` (cache serial, :259-261) and `specDirty` / `traitDirty`
- `paillettes`, `paillettesEarned` and `reserveBonus`
- `pins[npc]`, `caught`, `wary`, `gift30Used`
- `tidyWarned` and `fullWarned` (ReserveTidy.lua:226-240)

## 2. Reserve capacity
- Base: `ns.CAPTURE_RESERVE_BASE = 50` (:120). It was 20 before 3.3.1.
- Capacity = `50 + max(0, floor(capture.reserveBonus))` (:586-589).
- Upgrades come from the shop item `{ id="slots", kind="slots", slots=10, price=40 }` (JournalReserve.lua:46), applied through `ReserveAddSlots` (:316). `ShopState` (:288-304) has no cap for the `slots` kind, so there is **no max (not found)**.
- Reserve count = specimens that are not a Codex reference (`SpecimenReserveCount`, :484-495, cached on `specSerial`).
- Full means count ≥ capacity (:591-593).
- When the Reserve is full, `CaptureBlockedReason` returns `"reserveFull"` only if that version is already owned (`CaptureHas(npc, shiny)`), meaning the specimen would go to the Reserve (:642-647). A new species or version still goes to the Codex.
- `SpecimenAdd` itself does not check space (:53-54).
- Gift copies fail with `"full"` (:885).
- Strings: `CAPTURE_MSG_RESERVE_FULL` (:156).

## 3. Codex
- Storage: `capture.codex[npc] = { best = id, bestShiny = id }`, one reference per species and version (:36). It holds pointers only; no other data per species.
- **On add** (:389-402): if the version has no reference, the new specimen becomes the reference (place `"codex"`). Otherwise it replaces the reference if `new.stars > best.stars`, where `best` is the highest-star specimen of that version, ties going to the lowest id (`BestOf`, :242-250), and `spec.keepReserve` is not set (trades set it). Ties never promote.
- **"Better than Codex"** (:436-441): the specimen is not the reference and `spec.stars > ref.stars`. Only stars count; size and trait are ignored.
- Manual promotion: `SpecimenSetReference` (:504-518). The old reference simply becomes a Reserve specimen.
- `Sync` (:361-369) copies the best stars into `creatures[npc].stars` / `shinyStars`.

## 4. Release rewards
- `ns.PAILLETTES_RELEASE = { 2, 4, 10, shiny = 25 }` (:134). It was 1/3/8/20 before 3.3.1.
- Reward = 25 for any shiny, otherwise `values[Clamp(stars)]` (:534-540).
- Credit goes through `PaillettesAdd(gain,"release")`, which also raises `paillettesEarned` (:606-613).
- Refusal reasons are checked in this order (:542-551): `missing`, `worn`, `reference`, `better`.

## 5. Public `ns:` API for specimens
| Signature | Purpose |
|---|---|
| `SpecimenList(filter)` (:461) | `filter = {where="all"\|"reserve"\|"codex", npc, shiny=bool, stars=min, sort="stars"\|"date"\|"name"\|"id"}`, returns a new table |
| `SpecimenReserve(sort)` (:481) | same as list with `where="reserve"` |
| `SpecimenReserveCount()` (:484) | count without allocating |
| `SpecimenGet(id)` (:417) | one specimen |
| `SpecimenIsReference(id)` / `SpecimenReference(npc, shiny)` (:421/429) | Codex checks |
| `SpecimenBetterThanCodex(id)` (:436) | stars above the reference |
| `SpecimenLabel(spec)` (:497) | name plus shiny tag |
| `SpecimenMigratedCounts()` (:817) | species, total, shiny counts of origin `"migration"` |
| `ReserveTidyRanked()` / `ReserveTidyCandidates(n)` (ReserveTidy.lua:78/99) | release order and top n plus gain |
| `SpecimenTagsShort(spec)` (SpecimenTraits.lua) | "Grand · Curieux" |

Sort keys (`SORTS`, :443-459):
- `stars`: stars descending, then shiny first, then id descending
- `date`: `at` descending, then id descending
- `name`: `name or npc` ascending, then id
- `id`: ascending

The UI exposes `ns.RESERVE_SORTS = {"stars","date","name"}` and `RESERVE_SHOWS = {"all","shiny"}` (JournalReserve.lua:55-56). There is no filter on size, trait, zone or origin in `SpecimenList`. The repo's latest commit message mentions a size and trait filter, but it is not in `SpecimenList`.

## 6. ReserveTidy selection (ReserveTidy.lua)
- Pool: Reserve specimens that are not shiny and pass `SpecimenCanRelease` (:79-85).
- Order (:86-94):
  1. fewest stars first
  2. then the species with the most copies in the Reserve
  3. then the oldest `at`
  4. then `tostring(id)`
- The first `ns.RESERVE_TIDY_COUNT = 5` are preselected (:20, :99-107).
- The user can toggle tiles; a shiny or unreleasable tile is refused (:146-162).
- Confirm calls `SpecimenRelease(id, true)` on each one (:185-197).
- Warning thresholds:
  - "Near full" = count ≥ capacity − `RESERVE_TIDY_NEAR` (= 5) (:22, :109-111).
  - The companion warns once near full and once when full (`tidyWarned` / `fullWarned`), with cooldowns `reserve` = 600 s and `reservefull` = 120 s (:72, :222-242).
  - Triggered by the `SPECIMENS` events `add`, `release`, `take` and `slots` (:244-248).
- Commands: `/qc tri` and `/qc tidy` (:211-212).

## 7. Storage scope
- Everything is account-wide in `QuestCompanionDB.capture`, built by `ns:CaptureAccount()` (Capture.lua:288-318), which merges each character's old `char.companion.capture` once (`mergedFrom`).
- Per character: `db.chars[key].companion.appearance`, the worn look. `captureHuntOn` / `captureHuntUntil` sit at the root of `ns:DB()`.
- Config.lua declares the SavedVariable `QuestCompanionDB` (:18). Core.lua defaults are only `enabled`, `showMinimap` and `chars={}` (:17-21). No capture defaults are registered; the table is built lazily.

## 8. Locked, favourite and worn flags
- **Favourite: not found.** No persisted lock flag either.
- `ns.TradeLocked(id)` is transient: the id is in a pending or current trade offer (CaptureTrades.lua:354-365).
- **Worn:** `SpecimenWorn(id)` (:522-532) is true if the specimen is a Codex reference and some character's `companion.appearance == "cap:<npc>"` (or `"cap:<npc>:s"` for shiny). This means the worn specimen is always the current Codex reference of that version, not a chosen specimen.
- `CompanionWornSpecimen()` (SpecimenTraits.lua:187-206) resolves it the same way through `codex.best` or `codex.bestShiny`, with a cache, and returns nil during the winter theme.

## 9. Memory and encoding
- In SavedVariables, a specimen is a plain Lua table with string keys. No compact encoding and no per-specimen memory estimate were found.
- Compact encoding exists only for trade messages: `TradeEncodeSpec` uses short keys `i, n, s, h, z, t, zo, at, by, o, nm, cl, ty, fa, hp` through `ns.TrainerEncode`, with decoded text capped at 250 chars (CaptureTrades.lua:412-460).