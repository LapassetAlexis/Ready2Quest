# Specimen trades and achievements: audit

All paths are relative to `/Users/alexis.lapasset/orca/workspaces/ReadyToQuest/qc-reserve-design/QuestCompanion/`.

## 1. Trades (CaptureTrades.lua)

**Constants** (lines 109-124):

| Constant | Value |
|---|---|
| `TRADE_PREFIX` / `TRADE_PROTO` | "QCTrade" / 1 |
| `TRADE_MAX` | 3 specimens per side |
| `TRADE_INVITE_TTL` / `TRADE_RING_WAIT` | 60 s / 10 s |
| `TRADE_IDLE_TTL` / `TRADE_LOCK_TTL` | 300 s / 30 s |
| `TRADE_COOLDOWN` | 10 s |
| `TRADE_RESEND` | {5, 6, 120}: K resent every 5 s, 6 times, then every 2 min |
| `TRADE_DOUBT_ABANDON` | 7·86400 s |
| `TRADE_LOG_MAX` | 50 |
| Flood limit | 60 messages per 10 s per sender (`TRADE_IN_WINDOW`, `TRADE_IN_MAX`) |
| `TRADE_TEXT_MAX` | nm 48, by 36, ty 24, fa 24 bytes |
| Received message size | 255 bytes max (l.959); one spec 250 bytes max (l.440) |

**Protocol**
- Transport is an addon WHISPER through `ns:ChatQueue` from TrainerCard (l.464-471).
- Message format is `type~proto~tid~…`. The `tid` is `%x%04x` of (time % 2^24, random 0-65535) (l.473-476).
- Message types: I, R, A, D, O, V, L, K, F, X, N (l.38-51).
- A different proto gets a `D version` reply (l.969-973). Same-faction only: `TradeWithTarget` rejects the other faction (l.583-586).

**Flow (phases: inviting/invited → open → locking → prepared → done)**
1. **Invite.** `TradeInvite` sends I with the version and the target key, plus a trainer probe P so it can tell "old addon" from "no answer" (l.556-574). If no R arrives within 10 s, the session ends as `noanswer` or `oldaddon` (l.1065-1067).
2. **Accept.** The invitee answers with R. Accept sends A; decline sends D (l.590-610). If it is busy, in pending, on cooldown, off or in combat, it sends D with that reason (l.939-947).
3. **Open.** `TradeToggleOffer` adds or removes one of my specimens. Each change bumps `myRev`, resets both validations and re-sends the whole offer as O chunks (l.636-659).
   - `TradeValidate` needs at least one specimen on either side, my specimens still tradable, and `TradeRoom()==0`. It then sends `V~myRev~theirRev` (l.670-685).
   - The trade moves to locking only when both sides validated the same revisions (l.1008-1012).
   - A new O after validation sends the trade back to "open" (l.896-901).
4. **Locking.** Each side re-checks its specimens and room, then sends its full data as L chunks (l.813-829). On receiving L, `TryPrepare` requires `#theirLock==#theirs` and each raw string to match the displayed offer exactly, otherwise `mismatch` (l.832-837).
5. **Prepared.** `capture.tradePending = {tid, peer, at, give, get}` is saved and K is sent (l.842-845).
6. **Commit.** On the peer's K or F, `Commit` runs in one block (l.736-784):
   - My given specimens are removed with `SpecimenTake`.
   - Each received spec is decoded and added with `SpecimenAdd{…, origin="trade", keepReserve=true}`, so it never replaces your Codex specimen.
   - Fields are set: `tradedFrom` = peer short name, `tradedAt`, `firstOrigin` = sender's `o`, `hops` = hp+1.
   - Then: a log entry, `tradeCount++`, `FeatCount("trades",1,"account")`, and `FeatFlag("tradeNew","account")` if the species is new. F is sent.
7. **Recovery.** After `/reload` or relog, `tradePending` survives and K is resent. Replies: F or K means commit; X or N means drop. A K for an already-logged tid gets F, X or N from the log (l.985-991). The log makes it idempotent (l.739-742).

**Abort triggers:** cancel, `PLAYER_REGEN_DISABLED` (combat), `PLAYER_LEAVING_WORLD`, the "player not found" system message, idle or lock timeouts (l.1146-1169, 1076-1079). X is never sent after K. `TradeAbandon` is allowed only once the pending trade is at least 7 days old (l.1105-1116).

**What is transferred (`Fields` l.411-424):**
- `i` (sender's id, not reused), `n` npc, `s` stars (decoded 1..3), `h` shiny, `z` size, `t` trait, `zo` zone, `at` capture time, `by` original trainer, `o` first origin (capture, migration or gift3), `nm` name, `cl`/`ty`/`fa` (class, type, family).
- `hp` hops.
- **Traits and size are preserved.** If received values are invalid, trait becomes nil and size becomes "normal" (l.446-449).
- The original trainer (`by`) is preserved.
- **Not transferred:** the earlier `tradedFrom`/`tradedAt` (overwritten), the specimen id (a fresh id is assigned).
- `cl`/`ty`/`fa` are only used to create the species entry if it is new (`EnsureEntry` l.717-733).

**Not tradable** (`SpecimenCanTrade` l.370-378): missing, `worn` (Codex reference worn as appearance by any character), `reference` (a Codex specimen), `better` (beats your Codex), `locked` (in the current offer or pending). Locked specimens can't be released or set into the Codex either (l.381-393).

**Room** (l.506-522): shortfall = max(0, incoming_to_reserve − #given − free). A received specimen counts against the Reserve unless it is the first copy of a version you don't own (that one goes to the Codex). Base capacity is `CAPTURE_RESERVE_BASE=50` + `reserveBonus` (CaptureSpecimens.lua:120, 586-588).

**Anti-abuse:** one trade at a time, 10 s cooldown, no self-trade (same key), flood cap, recipient key in I, bounded decode. **There is no check that the sender really owns what it sends.** The received data is accepted once it fits the bounds and matches what was displayed.

**Picker UI** (l.1514-1545): a grid built from `ReserveView("stars")`, sorted by stars, **with no filter or search**, paged. A click toggles a specimen. Non-tradable tiles are dimmed (`DIM_ALPHA` or 0.45) and their tooltip gives the reason (`RES_WHY_<why>`). The header shows "%d / 3". There are two columns of 3 slots, Toi and the peer (l.1384-1419).
- Their tiles' tooltip shows origin, tags, and one of "new species", "new version" or "better than Codex" (l.1308-1331).
- History rows: date · peer, then Gave / Got (l.1491-1512).

Entry points: `/qc echange|trade <name|oui|non|annuler|abandonner>`, the right-click menu, and the "Échanger avec ma cible" button.

## 2. Achievements tied to specimens and collection

Columns: id (code), points, criterion, reward. All are account scope (A) unless marked otherwise.

| id (code) | pts | criterion | reward |
|---|---|---|---|
| men_first (1) | 5 | species ≥1 | appât ×1 |
| men_species_10/25/50/100/250/500 (2-7) | 10/10/10/25/50/50 | species ≥ n | titles 1-6; aids: 10 → appât+lasso, 50/100 → sifflet, 250 → sifflet×2; cosmetics: frame trainer (25), bg menagerie (50), frame master (100), bg grandmaster (250), soon cardbg card_census (500) |
| men_elite_1 (8) | 5 | elite ≥1 | – |
| men_rare_1 / _10 (9/10) | 10/25 | rare ≥1/10 | lasso / title 7 |
| men_boss_1 (11) | 25 | boss ≥1 | soon orn feat_chain |
| men_types_t1 (12) | 10 | typesTier1 ≥8 | lasso |
| men_type_* (13-20) | 10 each | beast/humanoid/undead/elemental 40; dragonkin/demon/giant/mechanical 20 | lasso, or title 8 (dragonkin) / title 9 (demon) |
| men_types_master (21) | 25 | meta, all 8 type achievements | title 10, soon frame feat_eight |
| men_stars3_1/25/100 (22-24) | 5/10/25 | species with `e.stars==3` ≥ n | –, appât×2, title 11 + soon orn feat_goldstars |
| men_batch_5 (25) | 10 | flag batch5 (≥5 in one "Tout capturer" batch) | – |
| men_bad_luck (26) | 5 | streak capFail 10 | title 40, appât×3 |
| men_level_gap (27) | 10 | flag levelGap (≥5 levels above you) | – |
| men_companion_types (28) / _boss (29) | 10/10 | 8 companion types active / worldboss companion | – |
| **men_size_giant (176)** | 10 | flag sizeGiant | – |
| **men_size_tiny (177)** | 10 | flag sizeTiny | – |
| shiny_seen_1 (30) | 5 | shinySeen ≥1 | – |
| shiny_found_5/15/30/50 (31-34) | 10/10/25/25 | shinyFound | frame sparkle / bg stardust / orn aura / title 12 + appearance hippogryph |
| shiny_cap_1/10/25 (35-37) | 10/25/50 | shinyCap | lasso / sifflet / title 13 |
| shiny_elite (38), shiny_3stars (39) | 10, 25 | shinyNamed ≥1, shiny3 ≥1 | –, soon orn feat_prism_orn |
| shiny_sealed (40), shiny_zones_10 (41) | 10, 25 | flag, ≥10 zones | – |
| **soc_trade_1 (178)** | 5 | streak trades ≥1 | – |
| **soc_trade_10 (179)** | 10 | streak trades ≥10 | – |
| **soc_trade_new (180)** | 10 | flag tradeNew | – |
| soc_showcase (81) | 5 | showcase 3 slots filled | – |
| soc_group_capture (84) | 5 | flag | – |
| fun_hogger_capture (154), fun_murlocs (156), fun_critter (157), fun_night_owl (163) | 10/10/5/5 | – | titles 32/33/–/34 |
| dng_capture_inside (127, char) | 10 | captureInside ≥1 (FeatsCatJeu.lua:461) | – |
| meta_menagerie (166) | 50 | 20 "men" achievements | title 35 |
| meta_shiny (167) | 25 | 10 "shiny" achievements | soon frame feat_prism |

Sources: FeatsData.lua:218-257 and FeatsCatMenagerie.lua:466-572. Names are in the strings files: "Premier échange", "Marchand de créatures", "Venu d'ailleurs", "Un géant parmi les bêtes", "Petit mais costaud".

- **Character/trait, Reserve, shop/paillettes:** no achievement found.
- **Size flags** are set only when `origin=="capture"` (CaptureSpecimens.lua:406, SpecimenTraits.lua:307-312). A traded giant or tiny specimen does not count.
- **Stars and shiny achievements** read `capture.creatures[npc]` (`stars`, `shinyStars`) per species, not per specimen (FeatsCatMenagerie.lua:121-123).

## 3. Engine API

- **Row format:** `{ id, n(code, never reused), cat, pts(5|10|25|50), scope("account"|"char"), crit=…, reward={aids, cosmetic={kind,id}, appearance, title=code, soon}, desc, pending, paid }`, added with `ns.FeatAdd` inside `ns.FeatCatalog(function() … end)` (FeatsData.lua:7-31, 141-171). Rows are stored in a compact 12-slot form (l.72-112).
- **Criterion types:**
  - `count` (source ≥ n)
  - `stat`
  - `flag`
  - `streak` (counter ≥ n)
  - `list`
  - `meta` (ids, or category + n)
  - `points`
- **Sources:** `ns.FEAT_SOURCES[name]={get(self,scope), topics, retro, dateOf}`.
- **Reporting progress:**
  - `ns:FeatFlag(key, scope)` stores `flag[key]=time()`.
  - `ns:FeatCount(key, delta, scope)` stores `ctr[key]=max(0, …)`.
  - `ns:FeatCountReset`.
  - `ns:FeatTouch(topic)` triggers a batched evaluation after 0.5 s.
  - References: Feats.lua:1006-1032.
- **Storage:** `db.feats` (account) or `CharData().feats`, shape `{v, got={[id]={at,lvl,r}}, ctr={}, flag={}}` (l.14-17, 185-194).
- **Catch-up:** flag and streak achievements are never awarded in catch-up (`Retro` l.661-669).
- **Strings:** names are `FEAT_<id>`, descriptions are `FEATD_flag_<key>`, `FEATD_streak_<key>` or `FEATD_<source>`.
- **Titles:** registry in FeatsTitles.lua, `[code]={pos, src, m, f, en…}`.

## 4. What the trainer card shows (TrainerCard.lua:624-782)

- Name, title (`ti`/`tg`/`t`), first capture date.
- `sp` species / `st` total, `sy` shinies, `sr` shinies spotted, `se` seals, `b` seals per continent.
- Achievement points `ap`/`aq`/`ac`, achievement showcase `hf` (3), counts per category `hk`.
- The current companion: name, npc, display, class, shiny, mascot, stars, type, strength, effects.
- A 3-slot showcase of **species versions** (`cap:<npc>[:s]`): npc, shiny, stars (best of that version), class, type, name.

**Not on the card:** individual specimens, trait, size, Reserve size, trade count, paillettes.

## 5. Share.lua (specimens)

- `ShareItemFromSpecimen` and `ShareItemFromResult` include name, shiny, stars, **size** (when not normal), class and new species (l.329-354).
- **Trait is not included. There is no share item for trades.**
- The Reserve preview has a Share button (l.892-922).
- Automatic group announce for shiny or 3-star captures: default on, `ANNOUNCE_GAP` 30 s (l.971).

## 6. Bond, age, level, XP

**No specimen has a bond, affinity, age, level or XP.** Searching for bond, affin, xp, lien, age and amitié found only creature names, lore, combat XP parsing and animation timers. The specimen schema is `{id, npc, stars, shiny, zone, at, by, origin, name, tradedFrom, tradedAt, firstOrigin, hops, trait, size}` (CaptureSpecimens.lua:29-35).

What exists today belongs to the **per-character companion**, not to a specimen:
- **Stage:** `COMPANION_STAGES` by player level 1/10/20/40/60, scale 0.70 to 1.18 (CompanionData.lua:201-207).
- **Time together:** `data.since` and `CompanionDaysTogether()` = floor((now−since)/86400)+1 (JournalWindow.lua:2280-2295).
- **Travel:** `data.travel` in metres.
- **Strength:** `EFFECT_RANK_STRENGTH[class]` (1, 1.5 elite, 2 rare, 2.5 boss) + 0.5 if shiny + 0.25·(stars−1) + type bonus (CompanionEffects.lua:36-38, 359-366).

The only "age-like" fields on a specimen are `at` (capture time) and `hops` (number of trades).