# QC 3.5.0: new-player and discoverability audit

## 1. First 60 minutes for a level-10 player

| When | What appears | Source |
|---|---|---|
| Login | Companion tutorial: 8 bubbles, 9 s each (`TUTO_STEP`). Covers states, Rayonnant, growth at 10/20/40/60, zone chest, chattiness. Ends with "dès que tu abats un monstre, je t'explique le filet" | Companion.lua:3650, :134; CompanionLines.lua:800-809 |
| First kill of a worthwhile species | Net, `CAPTURE_PROMPT` bubble, then the capture tour (5 steps). The tour waits for the companion tutorial and forces the old card/scene flow, not express | GuidedTour.lua:740-746, :233-258; CaptureExpress.lua:138 |
| After the tour | Express capture is ON by default, so the prep card is never seen again. Shift+click now throws the whole net, but tour step A3 said "Maj + clic … lance tout de suite" | CaptureExpress.lua:93; GuidedTour.lua:88 vs JournalGuide.lua:46 |
| First journal open | Journal tour: 10 tab steps | GuidedTour.lua:289-301 |
| ≥10 min, then every 20 min | Discovery tips, in strict catalogue order: look, frame, pet, pantry, journal, menu, needs, … Shop is tip #19 and trade #20, so roughly 6 h of play if none is skipped | Discovery.lua:29-30, :367-374 |
| Every 10 new species | Free Sifflet | Capture.lua:31, :885 |

The `P.TIP` pool has 34 tips and none is about capture, Codex, Reserve, glitter, bond or study (CompanionLines.lua:675-709).

## 2. Concepts vs explanations

| Concept | First explanation | Guide |
|---|---|---|
| Net, aids | GuidedTour.lua:84, :86 | yes (:44-48) |
| Stars | :86 | yes (:50-52) |
| Shiny | :84 (word only, no odds) | yes (:54-57) |
| Codex vs Reserve | :90-92 | one line (:51) |
| Hunt mode, wariness | :94 | in `net`/`stars` text |
| Size, character (of a specimen) | :98, one clause ("c'est rare !"), effects never explained | **none** |
| Bond | **NEVER**. First contact is the chat line `BOND_UP` (SpecimenBond.lua:201) | **none** |
| Study | **NEVER**. First contact is the chat line "Étude de X : Capturée (+2)" (SpecimenStudy.lua:225) | **none** |
| States, Rayonnant | CompanionLines.lua:802-803 | :62 |
| Wish | :96 ("son envie du moment"), what it gives is never said | :62 says "ses envies sont des bonus" (outdated wording) |
| Glitter | :98 (releasing only) | **none** |
| Shop | :99 | **none** |
| Weekly orders | only the footnote JournalReserve.lua:167 | **none** |
| Trades | :98 | **none** |
| Feats | :100 | :90 |

Out of 16 concepts, 5 are never explained in game (bond, study, orders, size effects, character effects) and the wish's effect is never stated. The Guide has 9 sections (JournalGuide.lua:21). The only 3.4/3.5 material in it is the states/Rayonnant paragraph.

**Vocabulary clashes**
- The page is named "Créatures" (JournalWindow.lua:453), but its tour step opens with "Le Codex" (GuidedTour.lua:97). "Ménagerie" still appears at :108.
- Each new species prints two chat lines: `CAPTURE_MSG_OK` ("rejoint ta collection (apparences du compagnon)", Capture.lua:87/882, because `starsBefore` is nil) and `CAPTURE_MSG_STARS` (CaptureQueue.lua:138).
- "exemplaire" (SpecimenBond.lua:60-61, ReserveBrowse.lua:94) vs "spécimen" elsewhere.
- "caractère" names both the companion's personality (Personality.lua:1, Discovery.lua:128) and a specimen's trait.
- "taille" names both the companion's display size (Discovery.lua:133) and a specimen's size.
- Retired gauges still appear: Discovery "needs" text "faim, énergie, moral et curiosité" (Discovery.lua:124), "pantry" text "l'envie la plus basse" (:108), trait descriptions with "énergie/moral +50 %" (SpecimenTraits.lua:95-96).

## 3. Tracker
Objective sources:
- core: Companion, Villages, Capitals, Dungeons, Level (JournalTracker.lua:464) and Zone (:612)
- Bestiary (species **killed**, Bestiary.lua:674)
- Gathering (Gathering.lua:409)
- Chest (CompanionChest.lua:391)
- daily missions (Daily.lua:736)

A capture objective appears only when a daily mission happens to be one. There is no "N espèces à capturer ici", no seal goal, no study task, no order, no "Réserve pleine". The only wish goal is `JRN_GOAL_HAPPY` (:97), shown when the next stage is waiting.

## 4. Notifications per capture
- **New species (notable):** express pill (3.6 s, 4 rows, CaptureExpress.lua:33-36), 2 chat lines (above), `STUDY_DONE` (+2), a forced `CAPTURE_OK` bubble that skips the 20 s gap (Capture.lua:883, Companion.lua:76), and a sound.
- **Occasional extras:** `BOND_UP`, the gift, a group announcement (`announceGroup` ON, Share.lua:175), feat banner and sound (`featToast` ON).
- **Size records** are printed from the 2nd capture of a species onward (SpecimenStudy.lua:123-129).
- **Caps:** toast 3 s (CaptureQueue.lua:80), chime gap 3 s (CaptureExpress.lua:41), combat or Reserve-full message 5 s (CaptureQueue.lua:268), share gap 10 s (Share.lua:41).
- **Hunt mode:** in express, non-notable catches have Print and Say silenced (CaptureExpress.lua:572-578), so the spam risk is low. With express OFF, every candidate raises the toast and plays the 3.5 s scene.

## 5. Settings and commands
- **83 rows on 10 pages.** These counts come from loading the addon in the test harness, read-only: general 4, companionMain 12, Quiet 4, Talk 7, Keys 3, Ornaments 16, journal 18, Character 2, Daily 17 (11 booleans ON), plus one container page.
- **Capture defaults:** express ON, auto OFF, aid-auto OFF, anim/toast/sound ON.
- **Key bindings:** 5 (Bindings.xml). Only Y (feats) gets a default key (Bindings.lua:79); the net and hunt bindings have none.
- **Slash commands:** astuces, blague, capture, carnet, chasse, coffre, compagnon, diag, dresseur, echange, fiche, filet, hf, juke, menagerie, metiers, minimap, modules, noel, options, reset, style, titre, tri, tuto, help.
- The Guide's command line (JournalGuide.lua:87) leaves out chasse, echange, tri and astuces.

## 6. Guide
Section by section: net, stars, shiny, effects (includes states and Rayonnant), seals, titles, missions, card, settings. Bond, study, orders, size, character, Reserve release and glitter, shop and trades are absent. GUIDE_net_5 (:48) lists where aids come from but not the shop.

## 7. Empty states (0 captures)
- **Reserve:** "Ta Réserve est vide : les spécimens moins bons … y arrivent" (JournalReserve.lua:105). No call to action.
- **Créatures:** "cible ou survole des monstres" (JournalWindow.lua:505). No capture hint.
- **Échoppe:** no empty state. Balance 0; `SHOP_NOTE` (:159) lists how to earn glitter but omits study (2 per task, 5 per mastered species) and the treat conversion. Orders show "Aucun pour l'instant" (:169).

## 8. Store page vs the first hour
- "Take one along as your hunting companion" and the bond (questcompanion.md:13, :30): nothing prompts the player to wear a capture, and bond points only go to a worn specimen (SpecimenBond.lua:7-9).
- "Your companion walks you through your first capture" (:68): true, but the tour shows a flow (prep card and scene) that express capture (on by default) never shows again.
- Outdated wording on the page: "the need it cares about" (:79) and the caption "its needs" (:83).
- The "seven new achievements" are promised, but study itself is never explained in game.

## Weak points
1. **Bond is invisible.** It is never explained and needs a worn capture, but nothing prompts the player to wear one. The headline 3.4 system sits idle for most new players.
2. **Study appears with no explanation.** Its "+2 paillettes" chat lines are in practice the main glitter source in the first hour (one per new species), yet `SHOP_NOTE` and the Guide never mention study.
3. **The Reserve stays empty in normal play.** The net only offers new, better or shiny specimens, so release, orders, trades and the "5 captures" study task all depend on hunt mode. No empty state or tracker line says so.
4. **The tour and express capture contradict each other.** GuidedTour.lua:88 and the Discovery tips "direct" and "batch" (Discovery.lua:147-153) describe Shift+click and Ctrl+click backwards compared with the default express mode. Players learn the wrong shortcuts.
5. **Discovery order buries the capture loop.** Cosmetic tips come first; shop and trade are tips #19 and #20 (about 6 h). The 34 ordinary tips contain no capture tip.
6. **3.5 rewrites missed some files.** Discovery "needs"/"pantry", the trait descriptions and the store page still use the retired gauges. The 3.5 plan's rewrite list (PLAN.md:111) did not include Discovery.lua.
7. **The tracker has no capture objective.** "Bestiaire de <zone>" counts kills, which reads like a capture goal but is not one. Seal, study, wish and order progress never appear on screen.
8. **Vocabulary is inconsistent.** Créatures/Codex/Ménagerie/collection, plus "caractère" and "taille" each meaning two different things. Each new species prints two chat lines with different terms.
9. **The Guide lags 3.4/3.5.** It has no section on the Reserve, shop, bond, study or trades, and its command list is incomplete.
10. **Shiny odds are not given before the first sighting.** Tour step A1 names shinies without explaining them.

The option row counts come from a throwaway script that loads the addon in the test harness, run from my scratchpad without touching the repo: `/private/tmp/claude-2007623921/-Users-alexis-lapasset-orca-workspaces-ReadyToQuest-qc-reserve-design/c71c5d45-23dc-4285-87e3-69915616ccc5/scratchpad/dump.lua`. The raw output is `dump.txt` in that same folder.