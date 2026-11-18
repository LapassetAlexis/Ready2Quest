# Reserve and Shop UI audit (QC 3.3.1, read-only)

Paths are relative to `/Users/alexis.lapasset/orca/workspaces/ReadyToQuest/qc-reserve-design/QuestCompanion/`. JR = `JournalReserve.lua`, JW = `JournalWindow.lua`. All y values are measured from the top of the content area, and all x values are offset by `PAD` (JW:630 `At`).

## 1. Geometry
| Constant | Value | Source |
|---|---|---|
| Journal | 980 × 680 | JW:36 |
| NAV_W / FOOTER_H | 220 / 56 | JW:326 |
| CONTENT_W / PAD / INNER | 758 / 24 / 710 | JW:327-329 |
| TOP | -(HEADER_HEIGHT 100)-6 = **-106** | JW:330, Socle/Theme.lua:758 |
| PAGER_Y | -(680-2-56)+8+22 = **-592** | JW:331 |
| PREVIEW_W / GRID_W | 210 / 710-210-16 = **484** | JW:332-333 |
| CONTROL_HEIGHT, BUTTON_SIZES, PAGER_HEIGHT | 24; xs 18, sm 24, md 28; 22 | Theme.lua:93,115,3286 |
| RESERVE_LAYOUT | tileW 58, tileH 84, gap 7, portrait 46, star 10, starStep 11, starY -55, shopH 50, shopGap 6, shopIcon 34, shopButton 104, actionH 24, actionGap 4, hintGap 10 | JR:62-64 |

**Reserve view (JR:626-789)**
| Element | x | y | Size |
|---|---|---|---|
| View chips « Réserve / Échanges » | 0 | -106 | 24 h |
| Paillettes badge (TOPRIGHT) | PAD+INNER | -106 | 24 h, auto width |
| Sort dropdown | 0 | rowY **-140** | 132 |
| Species dropdown | 142 | -140 | 180 (list 230, 12 rows) |
| Filter dropdown | 332 | -140 | GRID_W-332 = **152** (list 230, 12 rows) |
| Warn text (red, no wrap) | 0 | -177 (warnY -172) | 484; reduced by the gift button width |
| Gift button (TOPRIGHT) | 484 | -172 | auto × 24 |
| Grid | 0 | gridTop **-204** | **7 cols × 4 rows = 28 tiles**, step 65 × 91, used 448 × 364 (bottom -568) |
| Pager (TOPRIGHT) | 710 | -592 | — |
| Bottom row (`bottomY`) | 0 | -591 | « Faire de la place » (auto, primary, shown when near full), then « Échanger avec ma cible » at tidyW+8, then the hint (2 lines, hidden while tidy is offered) |
| Detail card (`BuildPreview`) | 500 | -140 | 210 × **440**; model stage 168; title, then up to 8 stacked lines; `maxBottom` 338 |
| Detail buttons | centred, width 186 | bottom +8 / +36 / +64 | Localiser / Relâcher / Mettre au Codex |
| Confirm text and Yes/No | 14,+40 ; 12/-12,+8 | — | Yes/No 90 each |

The grid pages by row: one wheel notch = 1 row (JR:613), and the pager chevrons go through `ScrollJournal`. `maxOffset = ceil(n/7)-4` (JR:1110-1113). The tiles are built once (JR:694).

**Shop (JR:862-918)**: rows `CreateTile` 710 × 50, step 56, first at y -140, 6 rows down to -470. Inside a row: icon 34 at x 10; name (F_LABEL, y -8) and description (F_SMALL, y -26) at x 54, width 438, no wrap; price width 84, right edge -124; « Acheter » 104 at right -10; Confirm/Cancel 50 each. Note text at y **-482**, width 710, wraps. No pager, no scroll.

## 2. Filter
- Three dropdowns: sort, species, filter. Before 3.3.1 the filter was « Tous / Brillants » chips; they were replaced because the row has no room (JR:667-674).
- **Filter choices** (`ns:ReserveFilterChoices`, JR:442-452), a flat list of `{value,label,hint}`: `all`, `shiny`, `size:<id>` for tiny, small, normal, large, giant (SpecimenTraits.lua:59), and `trait:<id>` for curious, glutton, daring, lazy, teasing, cuddly, zen, mischievous (:53). That is 15 entries, so the 12-row list scrolls.
- **One value at a time**: `frame.resShow` is a string. `ReserveView(sort, npc, filter)` (JR:424-438) applies shiny through `SpecimenList`, then does a post-pass on `size` (nil counts as "normal") or `trait`. Species is a separate AND (`frame.resNpc`). Species options are only the species present in the Reserve, sorted by label, with the count as hint and « Toutes les espèces » first (JR:943-961).
- **Persistence**: `resView` and `resSort` go through `JournalRemember`, validated by `STATE_VALID` (JW:377; `QuestCompanionDB.journalState`). `resShow` and `resNpc` are **not persisted**. Any change resets `resOffset=0`.

## 3. Sort
`RESERVE_SORTS = {stars,date,name}` (JR:55). Comparators are in CaptureSpecimens.lua:443-459:
- stars: stars desc, then shiny first, then id desc.
- date: `at` desc, then id desc.
- name: `name or npc` asc, then id asc.

## 4. Tile and tooltip
- Tile = `ns.AllureNewTile` (CompanionAllure.lua:434) plus `ReserveNewTile` (JR:526-541). It shows:
  - a 46 px portrait (2D, else a small 3D model, else the type icon);
  - the name label, in GOLD_LIGHT if shiny;
  - 3 stars, x0 13, y -55, desaturated when empty;
  - a size tag 20 × 13 at (2,-2), NAV background at α 0.85, only when the size is not normal;
  - a shiny `gem`.
- Accent: selected `SELECT`, better than Codex `GREEN`, shiny `GOLD_LIGHT` (JR:1131).
- `AllureShowRing` marks the selected tile.
- Tooltip (`ReserveTileTip`, JR:928-940): title `SpecimenLabel`; lines are stars, origin text (traded with · captured by/migration/gift · zone · dd/mm/YYYY), `SpecimenTagsShort` (size and trait), and optionally `RES_BETTER`.

## 5. Specimen actions
- **Left click** on a tile: `ReservePick` shows its detail card. In tidy mode the click toggles the tile instead (JR:700-703).
- No right click and no naming were found.
- Buttons on the detail card:
  - « Mettre au Codex » (`ReserveToCodex`): swaps with the Codex reference and picks the old reference.
  - « Relâcher (+n) »: a 2-step confirmation inside the card (`ReserveRelease(id[,true])`). It is disabled with a reason when `SpecimenCanRelease` fails (worn, reference, better, missing, locked).
  - « Localiser l'espèce / Effacer le repère » (`ReserveLocate`).
- There is no "wear" action on the Reserve; a look is worn only through the Codex reference.
- **Trade**: the bottom button calls `ns:TradeWithTarget()`; the « Échanges » view comes from `TradeBuildView` (CaptureTrades.lua).
- Release value: `PAILLETTES_RELEASE = {2,4,10, shiny=25}` (CaptureSpecimens.lua:134).
- Capacity: `CAPTURE_RESERVE_BASE` 50 plus `reserveBonus` (:120, :586).

## 6. Batch action
« Faire de la place » (ReserveTidy.lua) is the only multi-select:
- It is offered when count ≥ capacity − `RESERVE_TIDY_NEAR` (5).
- It pre-selects the `RESERVE_TIDY_COUNT` (5) least valuable specimens: fewest stars, then most duplicated species, then oldest. Shiny and non-releasable specimens are excluded.
- State: `frame.resTidy {id=true}` plus `resTidyOrder`. Unselected tiles drop to α 0.4.
- The card lists the first 5 plus « … et n autre(s) », the total, and « Relâcher (n) / Annuler ».
- `/qc tri` opens it.
- The selection is cleared on view change and on OnHide.

## 7. Shop (`ns.PAILLETTES_SHOP`, JR:42-51)
| id | kind | price | effect / limit |
|---|---|---|---|
| appat | aid | 4 | ×1.5, bag cap 10 (Capture.lua:46) |
| lasso | aid | 12 | ×2.5, cap 5 |
| sifflet | aid | 35 | sure capture, cap 3 |
| slots | slots | 40 | +10 Reserve slots, no limit |
| frame_glitter | cosmetic frame `shop_glitter` | 80 | once, whole account |
| bg_starfall | cosmetic bg `shop_starfall` | 60 | once, whole account |

- `ShopState` returns ok, short, full, owned, off or unknown.
- The buy button is disabled with a tooltip reason; a click on a disabled button calls `ShopRefused` (chat line, and the badge `Flash()` when short).
- Buying asks for an inline Confirm/Cancel (`frame.shopConfirm`), then `ShopBuy`, a chat line, and `PaillettesSpend`.
- Earning paillettes: zone milestones `PAILLETTES_MILESTONE` 2 (JR:54).

## 8. Reusable helpers
- **`ns.JournalUI`** (JW:908-914): `At, Text, Tip, HideTip, Panel, Chips, Pager, BuildPreview, PreviewSet` and the constants `PAD, INNER, TOP, PAGER_Y, HALF(343), COL_GAP(24), PREVIEW_W, GRID_W, CONTENT_W, WIDTH, HEIGHT, FOOTER_H, NAV_W`.
- **Socle Theme**: `CreateChips`, `CreateDropdown(parent,w,onSelect,{listWidth,maxRows,height})` (single value only, choices `{value,label,disabled,hint}`, Theme.lua:2027), `CreateButton(parent,w|"auto",size,label,onClick,style)` with styles primary, outline and accent, `CreateTile` (`SetAccent`, `SetSelected`, `SetFill`), `CreateCurrency`, `CreatePager`, `CreateSearchBox`, `Solid`, `Text`, `Border`, `TextHeight`, `TooltipTitle`, `TooltipLine`, `CreateSection`, `CreateTag`.
- **Module helpers**: `ns.ReserveNewTile`, `ns:ReserveTilePaint`, `ns.AllureNewTile`, `ns:AllureTileLook`, `ns.AllureShowRing`, `ns.PaillettesBadge`, `ns.PaillettesGlyph`, local `Enable(button,on,why)`.
- **Page registration**: `ns.JOURNAL_PANES[k] = {field,title,subtitle,build,refresh,scroll}` (JR:1372-1380).

## 9. Space constraints in comments and code
- The filter row is full: 0-484 is used by 132 + 10 + 180 + 10 + 152 (JR:667-668).
- The bottom row has no room for the hint next to both buttons, so the hint hides (JR:1101-1104).
- An earlier tidy button overlapped the grid, which is why it moved to the bottom row (JR:675-677).
- The grid uses 448 of 484 px, so **36 px are free on the right**. There are 23 px between the grid bottom (-568) and the pager (-591).
- The detail card has 8 lines and hides a line once it passes `maxBottom` 338.
- The shop has about 110 px free between the note (-482) and the footer area (-592).
- Docs: UI.md:464-475 says nothing may overlap (tested in `tests/modules/ui_windows.lua`, both styles) and everything is built once with no frame creation on refresh (UI.md:507-511).