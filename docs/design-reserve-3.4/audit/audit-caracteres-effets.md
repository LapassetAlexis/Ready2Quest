# Audit of traits and their gameplay effects (QuestCompanion, read-only)

Paths below are relative to `/Users/alexis.lapasset/orca/workspaces/ReadyToQuest/qc-reserve-design/QuestCompanion/`.

## 1. Characters ("caractère")

Trait definitions are in `Personality.lua:118-131`. French labels are in `Personality.lua:25-38`. Draw weights are in `SpecimenTraits.lua:53-56`, and the rare set is at `:57`.

| id | FR | preferred need | weight | P(draw) |
|---|---|---|---|---|
| curious | Curieux | curiosity | 3 | 3/20 = 15 % |
| glutton | Gourmand | hunger | 3 | 15 % |
| daring | Téméraire | mood | 3 | 15 % |
| lazy | Paresseux | energy | 3 | 15 % |
| teasing | Taquin | mood | 3 | 15 % |
| cuddly | Câlin | mood | 3 | 15 % |
| zen | Zen | energy | 1 (rare) | 5 % |
| mischievous | Espiègle | mood | 1 (rare) | 5 % |
| wise | Sage | curiosity (owl) | never drawn | 0 |
| parrot | Perroquet | mood (parrot) | never drawn | 0 |
| mystic | Mystique | curiosity (wisp) | never drawn | 0 |
| sly | Rusé | curiosity (snake) | never drawn | 0 |
| fearful | Peureux | energy (chicken) | never drawn | 0 |
| tinker | Bricoleur | curiosity (squirrel_mech) | never drawn | 0 |

The six "exclusive" (appearance) characters are never drawn. They can only reach a specimen through migration (`SpecimenTraits.lua:263-288`), which keeps the trait the companion already had.

## 2. Sizes

Defined at `SpecimenTraits.lua:59-66`. Labels are at `:83-91`.

| id | FR | short label | weight / P | scale |
|---|---|---|---|---|
| tiny | Minuscule | XS | 2 % (rare) | 0.75 |
| small | Petit | S | 18 % | 0.88 |
| normal | Normal | (none) | 60 % | 1 |
| large | Grand | L | 18 % | 1.12 |
| giant | Géant | XL | 2 % (rare) | 1.25 |

The scale shown depends on framing (`SpecimenTraits.lua:69, 72-73, 317-326`):
- Formula: `eff = clamp(0.75, 1.25, 1 + (scale - 1) × keep)`.
- `keep` by framing: `{pied = 1, buste = 0.6, portrait = 0.4}`.
- Camera: `cam = 1 + (eff - 1) × 0.5`, applied only when eff > 1.
- Applied at `Companion.lua:2949-2954`, only when `app.captured`.

## 3. How traits are rolled

- `Roll()` at `SpecimenTraits.lua:123-132` uses plain `math.random()`. No `randomseed` call exists anywhere in the addon.
- **Independent of quality (stars), shiny and creature class.**
- Traits are rolled in `SpecimenAdd` (`CaptureSpecimens.lua:384`) whenever the incoming spec has no valid trait, for every origin.
- Size is rolled only when `origin == "capture"` (`:386-388`). Other origins get "normal", unless the spec already carries a size (trades pass it through, `CaptureTrades.lua:760`).
- Gift copies (`CaptureSpecimens.lua:891`): trait rolled, size normal.
- Migration (`SpecimenTraits.lua:259-304`): trait rolled or kept from the old companion, size "normal".
- Capturing a tiny or giant specimen sets feat flags `sizeTiny` / `sizeGiant` (`SpecimenTraits.lua:307-312`, called at `CaptureSpecimens.lua:406`).

## 4. Effects of a worn specimen's character

The trait used is the codex reference specimen's: `SpecimenReference(npc, shiny)`, codex `best` / `bestShiny` (`CompanionEffects.lua:369-371`, `CaptureSpecimens.lua:429`). That is the same specimen as `CompanionWornSpecimen` (`SpecimenTraits.lua:187-206`).

**A. Fixed trait effect (third slot "trait").** It applies whatever the "Caractère" setting is. Values come from `CompanionEffects.lua:94-107`, computed by `CompanionTraitEffect` at `:393-398` as `value = min(cap, base)`. Strength, needs and rank do not scale it.

| trait | kind | value | applied in (file:line) | exact mechanics |
|---|---|---|---|---|
| curious | decay, curiosity | 0.10 | CompanionDecayFactor `:694-701` | curiosity decay ×(1 − 0.10) |
| glutton | treatZone | 0.10 | TreatCheckZone `:666-687` | 10 % chance of an extra treat per zone milestone gained |
| daring | capture, named | 0.05 | CompanionCaptureBonus `:555-573`, then CaptureChance `:580-586` | capture ×(1 + 0.05) on elite/rare/rareelite/worldboss (`:39`) |
| lazy | rest | 0.10 | CompanionTick `:708-718` | energy += 4/min (REST_GAIN, `Companion.lua:66`) × 0.10 while resting and not sleepy |
| teasing | decay, mood | 0.08 | `:694-701` | mood decay ×0.92 |
| cuddly | pet | 0.25 | CompanionPet `:728-736` | a real pet adds mood +8 × 0.25 = +2 on top of the base +8 (`Companion.lua:3629`) |
| zen | decay, all needs | 0.05 | `:694-701` | all needs decay ×0.95 |
| mischievous | capture, all | 0.03 | `:555-586` | capture ×1.03 on everything |
| wise | aidKeep | 0.05 | CaptureSpend `:625-633` | 5 % chance an aid is not spent |
| parrot | chain | 0.10 | ShinyChance `:595-605` | shiny-hunt kill count ×1.10 |
| mystic | shiny, all | 0.05 | `:600-603` | shiny chance ×1.05 |
| sly | aidZone | 0.10 | `:671-676` | 10 % chance of an extra aid per zone milestone |
| fearful | decay, energy | 0.08 | `:694-701` | energy decay ×0.92 |
| tinker | aidRefund | 0.08 | CaptureResolve `:641-659` | 8 % chance a failed capture refunds the aid |

The trait effect is gated like the other effects:
- The companion module must be on (`ModuleOn`).
- `EFFECT_DELAY` = 120 s (real time) must have passed since the appearance changed (`:33, 477-479`).
- The cache key includes `specSerial` (`:466`).
- Mascots and winter companions have no trait slot: the seasonal branch never sets `result.trait`, and mascots have no npc.

**B. Personality effect.** This applies only when the setting `companionTraitSource == 1` ("Apparence", the default; `SpecimenTraits.lua:214-228`). The worn specimen's trait then becomes `CompanionTrait()`, and it changes the preferred need:
- Gains on that need ×1.5 (`PERSONALITY_GAIN`, `Personality.lua:145, 250`).
- Decay on that need ×0.7 (`PERSONALITY_DECAY`, `:146, 257-260`).
- It also drives the speech bubbles, tinted voice and label.

## 5. Size

Size has **no gameplay effect.** Its only uses are:
- the model scale and camera (§2);
- the feats (§3);
- display: labels and colors (`SpecimenTraits.lua:76`), the Reserve filter (`JournalReserve.lua:432`) and colors (`:1035`), trade payload (`CaptureTrades.lua:418, 692`), Share (`Share.lua:343, 352`).

## 6. Stars (quality) and shiny beyond display

| factor | effect | where |
|---|---|---|
| stars (quality) | effect strength +0.25 per star above 1, using the best owned stars of that version (1–3) | `CompanionEffects.lua:38, 361-363`; `CaptureQueue.lua:344` |
| shiny | effect strength +0.5 | `:37, 360` |
| rank | strength ×: trivial/minus/normal 1, elite 1.5, rare/rareelite 2, worldboss 2.5 | `:36, 359` |
| stars of the target creature | capture-chance factor {1, 0.8, 0.6} | `CaptureSpecimens.lua:130`, `Capture.lua:400-404` |
| quality roll by class (%1★/2★/3★) | normal 65/28/7, elite 50/35/15, rare 30/45/25 | `CaptureSpecimens.lua:122-128, 628-638` |
| release value (paillettes) | 2/4/10 by stars; any shiny = 25 | `CaptureSpecimens.lua:134, 533-538` |
| codex reference | a new specimen with more stars replaces the reference (not when kept in Reserve via `keepReserve`) | `CaptureSpecimens.lua:397-402` |

Strength also gets `+MenagerieTypeBonus` (`CompanionEffects.lua:364-366`).

**Stars and shiny do not affect the trait effect.**

## 7. Caps and stacking

- Type and mascot effects: `value = min(cap, base × strength × needsFactor)` (`:386`).
- `needsFactor = 0.5 + 0.5 × ok / 4`, where `ok` counts the needs at or above 50 (`:327-334`).
- Trait effects: `base == cap`, a fixed value (`:93-107`).
- Same kind across the hunt/comfort/trait slots (`:496-516`):
  - capture: bonuses add, then multiply once: `value × (1 + Σ)`, clamped to `CAPTURE_MAX` = 0.95 (`:585`, `Capture.lua:30`).
  - aidKeep / aidRefund / aidZone / treatZone / chain / rest / pet: summed (`Sum`).
  - shiny and decay: multiplied per item (`:602`, `:698`).
- Decay chain: the Personality base (0.7 on the preferred need) × each decay item × winter cold (`WinterCompanions.lua:731-743`).
- Winter `nightCapture` adds only `found[1]` (`WinterCompanions.lua:713-718`).
- The spot effect (paw on nameplates) uses `found[1]` only (`:995`).
- **Example overlaps:**
  - daring + demon `capture_named`: they add.
  - zen + giant `decay_all`: they multiply.

## 8. How effects are shown (string keys)

- **Companion page pane:** `EFF_TRAIT` = "Caractère : %s, %s" on the third line (`CompanionEffects.lua:169, 526-529, 896, 918`). The per-trait sentences are `EFF_trait_<id>` (`:170-183`, EN `:239-252`), with `%d` = `Pct(value)`.
- **Reserve preview:**
  - `SPEC_SIZE_LINE` "Taille : %s"
  - `SPEC_TRAIT_LINE_EFF` "Caractère : %s (%s)" (`SpecimenTraits.lua:92-94, 174-181`; `JournalReserve.lua:1007-1011`)
- **Short tags** "Grand · Curieux" (`SpecimenTagsShort` with `SPEC_TAGS_SEP`) appear on:
  - the capture stage (`SpecimenTraits.lua:343-362`)
  - `CaptureQueue.lua:778`
  - `ForgeBanners.lua:443`
  - `CompanionAllure.lua:459`
  - `JournalReserve.lua:933`
  - `CaptureTrades.lua:1314, 1325`
  - the Menagerie star line (`JournalWindow.lua:2518`)
- **Menagerie sheet effects** use `noTrait` (`CompanionEffects.lua:535-542`).
- **Change confirmation:** `CompanionConfirmText` lists the trait line too (`:825-836`).
- **Settings description** for zen and mischievous specimens: `TRAIT_DESC_SPEC_zen` and `TRAIT_DESC_SPEC_mischievous` (`SpecimenTraits.lua:96-97, 232-244`).
  - Their texts say "énergie +50 %" and "moral +50 %". That is `PERSONALITY_GAIN` 1.5, not the trait effect value.
- **Colors:** rare traits are GOLD_LIGHT; other traits take the color of their need (`SpecimenTraits.lua:75, 147-151`).