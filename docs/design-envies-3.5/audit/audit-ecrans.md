# Needs display audit: QC 3.4.0 (worktree qc-3-4)

Repo root: `/Users/alexis.lapasset/Projects/ReadyToQuest-wt/qc-3-4`. Nothing in the repo was changed.

## Core constants (the numbers every display uses)

| Constant | Value | file:line |
|---|---|---|
| NEED_FLOOR / NEED_START / NEED_MAX | 15 / 80 / 100 | Companion.lua:43-45 |
| DECAY per minute of play | hunger 0.6, energy 0.4, mood 0.3, curiosity 0.5 | Companion.lua:47 |
| SERENE_FLOOR (all evolutions done) | 50 | Companion.lua:64 |
| NEED_LOW, the threshold for a "need" bubble | **35** | Companion.lua:124 |
| HAPPY_MIN, needed to evolve | 70 | Companion.lua:125 |
| `ns.NEED_LOW`, the threshold for the orange colour | **30** | JournalWindow.lua:737 |
| EFFECT_NEED_OK, the threshold for effects | **50** | CompanionEffects.lua:34 |
| Effect strength factor | `0.5 + 0.5*ok/4` (each need below 50 costs 1/8, floor 0.5) | CompanionEffects.lua:361-368 |
| Mood word from the average of the 4 needs | ≥75 radiant, ≥50 happy, otherwise dreamy; sleepy overrides | Companion.lua:772-782 |

The code uses four thresholds: 30 (colour), 35 (bubble), 50 (effects) and 70 (happy). `GUIDE_effects_3` calls a companion "heureux" at 50 % (EFFECT_NEED_OK), while `JRN_EVO_NEEDS` and `JRN_EVO_HOW_2` say "heureux" means 70 %.

## (1) Surfaces that display needs

| Surface | Geometry | Colours / tiers | file:line |
|---|---|---|---|
| Journal nav dashboard, companion block | Block at nav x=18, y=navY(-280 default)-16. Width W=184 (220-36), height 80 (6+14+4+4×14). Name line "Nom · humeur" in F_LABEL (12, semibold), LABEL colour. 4 rows of 14 px: label in F_SMALL (11), MUTED_LIGHT, width 66. Bar at x=66, width 118, **height 2**, y=row-5. No number shown. Hover tip on the block only (`JRN_NAVSUM_COMPANION_TIP`). | Forged theme: NeedTier. Otherwise GOLD at ≥70, MUTED_LIGHT below. | JournalWindow.lua:2981-3020, 3067-3081, 3101-3115 |
| Companion page, needs rows | See (2). ListRow 343×30, label F_LABEL, value width 52 ("NN %"). Bar at x=120, width 147, height 5. Each row has its own tooltip (`ShowNeedTooltip`). | Forged theme: NeedTier (GREEN ≥70, GOLD/LABEL in between, ORANGE_DEEP <30). Otherwise GOLD ≥70, else MUTED with LABEL text. | JournalWindow.lua:1052-1071, 2409-2421, 738-743 |
| Need tooltip (journal) | Title "%s : %d %%", then HAPPY or LOW, HOW, 2-3 lines from `JRN_NEED_<key>_n`, DECAY, and SERENE when at the last stage | Title gets TooltipTitle when happy, otherwise PARCHMENT | JournalWindow.lua:712-755 |
| Hover card on the on-screen companion | Toast 220 wide, pad 12. Title F_TITLE (16). Sub line: stage · mood word. 4 rows of 18 px: label F_SMALL in LABEL, width 66. Bar at x=left+70, width ≈90 (196-70-36), **height 4**. Value F_SMALL in MUTED_LIGHT, right-aligned "NN %". | **2 tiers only**: GOLD ≥70, MUTED_LIGHT below. NeedTier is not used here, in any theme. | Companion.lua:2629-2748 |
| On-screen frame, mood label | F_SMALL, TEXT colour, BOTTOM +6, width FRAME_W-8 | Word only, no bars | Companion.lua:2299-2303, 3005 |
| Forged mood tab | `FORGE_MOOD_TAB` h16, tuck 3, pad 9. Width = text + 18 | radiant→green plate, happy→bronze, dreamy→arcane, sleepy→disabled; ink colours set in the code | ForgeCompanion.lua:88-96, 195-221 |
| Journal tracker goal | "Rends %s heureux pour évoluer", progress "n/4 envies comblées". Hint lines from `CompanionHappyHints` (`COMP_HAPPY_LINE` / `COMP_HAPPY_OK` + `COMP_HOW_*`). | Goal bar only | JournalTracker.lua:97,100,389-392; Companion.lua:821-833, 3956 |
| Chat `/qc compagnon` | `COMP_MSG_NEEDS` "Faim %d · Énergie %d · Moral %d · Curiosité %d" | none | Companion.lua:341, 4263-4266 |
| Pantry (Shift+click menu and journal footer) | No need values. Only `TREAT_DESC_*` ("Faim à 100 %."…) | none | Treats.lua:48-52, 370-436 |
| Speech bubbles | `NEED_<key>` pools, 9 FR/EN lines each (36 in total) | none | CompanionLines.lua:607-650; trigger Companion.lua:3448-3460 (lowest need <35, cooldowns 300 s overall / 900 s per need, 120 s grace after login) |

## (2) Companion page layout

Window 980×680. Content INNER=710, PAD=24, HALF=343, COL_GAP=24. TOP=-106 (header 100 + 6). Footer top ≈ -622 (HEIGHT-2-FOOTER_H, see the comment at JournalWindow.lua:331). The JournalWindow.lua:326-335 and 932-938 lines give these constants.

| y (top) | Left column (x 0..343) | Right column (x 367..710) |
|---|---|---|
| -106 → -282 | Hero, 710×176: portrait 148, name, trait/size tags, losange steps at -66, "next" text, bubble 52 tall at -94, chest button | (full width) |
| -292 → -350 | 5 stat tiles, height 58, full width | |
| -366 | Section "Ses envies (heureux = toutes à 70 %)" | Section "Allure (n)" |
| -392, -426, -460, -494 (row h30, step 34) → bottom -524 | 4 need rows | -392 → -458 allure card (h66); -470 frame/background labels; -486 dropdowns; -518 ornament label; ornament toggles from -534, +24 per wrapped line |
| -532 | Section "Ses effets" (`colY-26-4*34-4`) | |
| -556 / -572 / -588 | Effect lines: hunt / comfort / trait, F_SMALL | |
| -590 or -606 | State line `EFF_STRENGTH` + state (y -58 or -74) | |

Free space at the bottom of the left column: with a trait line, the state line ends near -617, about **5 px** above the footer. Without a trait line, about 20 px.

## (3) How effect strength and low needs are communicated

- The only place that shows the penalty is the state line on the Companion page: `EFF_STRENGTH` = "Force ×%s · envies %d/4 : %d %%". For example, 2 needs at 50 % or more shows "envies 2/4 : 75 %" (CompanionEffects.lua:223, 1030).
- The effect labels already contain the reduced value (`base*strength*factor`, CompanionEffects.lua:429-430). No "-x %" is shown anywhere.
- The Guide text `GUIDE_effects_3` explains the 1/8 rule.
- The need tooltip says nothing about effects. It only mentions happiness at 70 % (`JRN_NEED_TIP_HAPPY` / `LOW`).
- The nav dashboard and the hover card do not show the effect factor.

## (4) Explanatory texts (FR)

- Bubble tutorial (CompanionLines.lua:801-802):
  - « J'ai quatre besoins : faim, énergie, moral, curiosité. Survole-moi pour les voir. »
  - « Mange, repose-toi à l'auberge, rends des quêtes, explore : ça me comble ! »
- Tips (CompanionLines.lua:690, 698):
  - « Astuce : survole-moi pour voir ma faim, mon énergie, mon moral, ma curiosité. »
  - « Astuce : l'auberge et la ville me redonnent de l'énergie. »
- Guided tour (GuidedTour.lua:96): « Ton compagnon : son humeur, ses envies (faim, énergie, moral, curiosité) et ses effets. « Choisir… » change son allure. »
- Guide (JournalGuide.lua:62): « Un compagnon heureux (ses quatre envies à %d %% ou plus) donne ses effets en entier ; chaque envie en dessous en retire un huitième, jamais moins de la moitié. … » The value filled in is EFFECT_NEED_OK = 50 (JournalGuide.lua:298). The Guide sections (JournalGuide.lua:21) include **no section dedicated to needs**.
- Losange-steps tooltip (JournalWindow.lua:98): « Pour la franchir, il doit être heureux : ses quatre envies à %d %% ou plus. Mange, repose-toi, rends des quêtes, explore. »
- Need tooltip lines: JournalWindow.lua:79-95, for example « Elle baisse doucement pendant que tu joues, jamais hors connexion. »

## (5) Settings related to needs

- There is **no dedicated option**: nothing to hide the bars, and no need alert or need sound. A grep for `OPT_*NEED*` and similar names found nothing.
- The only indirect control is the "Bavardage" slider: need bubbles are allowed only at level 3 (Normal) and above. Levels 1 and 2 use `allow` lists without "need" (Companion.lua:97-103). The level 3 description is `COMP_CHATTER_DESC_3` « …conseils, réactions, envies, astuces… » (Companion.lua:185).

## (6) Rewrite volume (string keys)

- Unique FR/EN keys whose name contains NEED/hunger/energy/mood/curiosity/happy, or whose value mentions those words: **100**.
- Of those, 45 have a need word in the key name itself.
- 97 of them have a Spanish entry in Locales_es.lua, and 110 ES values contain need words.
- Also in Locales_es.lua: 42 `COMP_SAY_NEED_*` entries.
- FR value matches per file: CompanionEffects 28, Personality 19, Companion 10, Treats 6, Discovery 4, JournalWindow 3 (+15 `JRN_NEED_*` keys), others 1-2.
- These counts come from regex matching, so they are approximate.

## (7) Tests

There are 102 files in `tests/modules/`. Assertion lines (`Check(`, `.ok(`) that mention needs words total **106**. Main files:

- `companion.lua`: 41
- `companion_treats.lua`: 8
- `companion_rewards.lua`: 7
- `zone_data.lua`: 7
- `journal_forge.lua`: 6 (pins the three NeedTier tiers on the page and the nav at :114-133)
- `companion_effects.lua`: 5
- `companion_forge.lua`: 5 (mood-tab ink contrast)
- `companion_frame.lua`: 4 (`#evo.needs == 4`, values contain "%", :228)
- `journal_tracker.lua`: 4
- `menagerie_journal.lua`: 4
- `companion_needs.lua`: 3 (5 scenarios: curiosity sources, serene floor, tooltip)
- `companion_personality.lua`, `specimen_traits.lua`, `winter_veil.lua`, `bestiary.lua`: 2 each
- `companion_daily.lua`, `missions.lua`, `r2q_ui.lua`, `ui_forge_navigation.lua`: 1 each

The 106 figure comes from grep on lines and is approximate.