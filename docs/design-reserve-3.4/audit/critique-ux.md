## UX audit of section 4.5 and the detail card (fixed 980×680 journal)

Pixel estimates assume Inter 12 at about 6.5 px per character, 24 px padding on buttons and chips, and 8 px gaps.

### Blocking

**1. The detail card is twice too full.**
- Evidence: lines start at y −204 inside the card (168 + 14 + 22, JournalWindow.lua:834). `maxBottom` is 440 − 10 − 92 = 338 (JournalReserve.lua:716-721), which leaves 134 px. A 4th button raises `actionsH` to 4×28+8 = 120, so `maxBottom` drops to 310 and only 106 px are left, about 5 F_SMALL lines of 20 px.
- What you ask for, with 182 px of text width:
  - stars: 1 line
  - trait plus and minus ("Téméraire : capture d'élites et de rares +10 %" is about 270 px): 3–4 lines
  - size plus and minus: 2–3 lines
  - bond label and bar: 2 lines
  - origin ("Capturé par X · zone · date"): 2 lines
- That is 10–12 lines, about 220 px. `PreviewLayout` silently hides whatever goes past the limit.
- Fix:
  - Put the stars in the title row.
  - Show one tag row (`CreateTag`, 15 px) with trait and size; the plus and minus go in the tooltip of each tag.
  - Use a 6 px bond bar plus a "Complice 3/5" label on one line.
  - Origin: 1 truncated line.
  - Keep 3 buttons: Localiser moves to a 24 px icon button on the model stage.
  - Budget: 5 lines, which fits 106–134 px.

**2. Row 1 overflows by about 115 px.**
- Search 140 + "Filtres (3)" 90 + sort 132 + direction 24 + views dropdown about 180 ("Meilleurs que le Codex" 140 + arrow and padding) + 4 gaps of 8 = **598 px > 484**.
- Fix:
  - Move the views dropdown (170) to the −106 row, between "Réserve | Échanges" (about 170) and the currency badge. About 250 px are free there.
  - Row 1 becomes search 150 + Filtres 96 + sort 150 + direction 24 + gaps 24 = **444 px**.
  - The species dropdown goes away (the search box covers it).

**3. Row 2 (−172) is already taken** by the warn line (red, 484 px) and the gift button (JournalReserve.lua, audit 4 §1).
- Pills are about 64–168 px each ("Meilleurs que le Codex ×" is 168). After "37 sur 62" (60) and "Effacer" (60), only about 348 px remain. Four pills already overflow.
- Fix:
  - Make pills per group ("Taille : Grand, Géant"), at most 110 px with ellipsis.
  - Show the pills that fit, then a "+n" pill that opens the panel.
  - The warn line moves into the bottom row hint.
  - The gift button moves to the views row.

**4. The filter panel does not fit in 484×364.**
- Chips: 3+2+5+8+8+3+4+3+5+5 = **46 chips + the zone dropdown**.
- Rows at a 30 px step, with a 70 px label column (414 px left for chips):
  - stars 1, version 1, size 1 (about 374 px), trait 2, type 2, rank 1, zone 1, date 1, origin 1, bond 1 (numbers only), state 2 ("Meilleur que le Codex" alone is 150 px)
  - plus a header row: **15 rows = 450 px**, against a maximum of 12.
- Fix (gives 10 rows = 300 px, no scrolling):
  - cut date (the date sort and the "Récents" view cover it)
  - cut origin
  - fold version into the stars row ("1★ 2★ 3★ ✦")
  - put rank and zone on one row
  - state keeps Protégé / Échangeable / Relâchable ("Doublon" and "Meilleur" are already views)
- Build all chips once (UI.md:507). The panel overlaps the grid, which breaks the no-overlap rule (UI.md:464) unless it is modal: hide the tiles behind it and add it to `ui_windows.lua`.

### High

**5. Keyword search is ambiguous.** "Géant" is both a size and a creature type. "grand" also matches zone and creature names ("Grande…"). Each keyword would also need FR, EN and ES versions.
- Fix: search matches name and zone only. Typing a known value suggests the matching pill; it does not filter silently.

**6. Ctrl+click and Shift+click are hard to discover and clash with client conventions.** In WoW, Shift+click links into chat and Ctrl+click opens the dressing room (`IsModifiedClick("CHATLINK"/"DRESSUP")`, which players can rebind). A Shift range also makes little sense on a grid that pages by rows.
- Fix: a "Sélectionner" toggle that reuses the tidy mode (`frame.resTidy`, a click toggles the tile). Ctrl and Shift stay as shortcuts, mentioned in the tile tooltip.

**7. The bulk bar barely fits.** "Relâcher (+42)" 124 + "Protéger" 80 + "Proposer à l'échange" 154 + "Annuler" 76 + 24 of gaps = 458/484. There is no room for "Tout sélectionner (37)" or for the selection count.
- Fix: put the count in the button ("Relâcher 9/12 (+42)", counting only what can actually be released). "Tout sélectionner" replaces "Effacer" on row 2. "Proposer" is disabled with a reason when there is no trade target. Selecting items on other pages needs a confirmation that lists them.

**8. Bonding with "the Codex reference" is not understandable.** You only bond with a specimen while it is the companion, and that requires "Mettre au Codex". That label never says "partir avec lui".
- Fix: rename the button "Partir avec lui", add a "Compagnon actuel" badge, and change the green note to "Plus d'étoiles que ta référence".

### Medium

**9. Signals rely on colour alone.** Gold "Inséparable" border vs GOLD_LIGHT for shinies (same hue). Green = better. Alpha 0.4 = not selected in tidy mode. Lock = ?
- Fix: corner glyphs (lock, check, ↑, heart) and a non-gold border for Inséparable (for example BLUE).

**10. The search box keeps focus.** Movement keys get typed into it.
- Fix: `ClearFocus` on a grid click, on `OnHide` and on `PLAYER_REGEN_DISABLED`. Today only Escape and Enter clear it (Theme.lua:1204-1205).

**11. The tile tooltip gets too long.** It would grow from 4 lines to 8 or more.
- Fix: keep 3 lines on tiles (name + stars, tags, bond). Details go in the card.

**12. Saved views are not feasible as written.** "3 vues du joueur" needs a naming field, and `resShow` is not persisted today (JournalWindow.lua:377).
- Fix: one "Ma vue" slot, persisted through `JournalRemember`.

### The 3 mandatory changes
1. Cap the detail card at 5 lines plus 3 buttons. Plus and minus go in the tag tooltips; Localiser becomes an icon.
2. Move views and gift to the −106 row, and limit row 1 to search, Filtres, sort and direction (444 px). Use one pill per group with a "+n" overflow pill.
3. Cut the filter panel to 10 rows (no date or origin; version folded into stars; rank and zone on one row), modal and built once. Replace Ctrl/Shift as the main way to select with a "Sélectionner" mode.