# QC social / multiplayer audit (main, 3.5.0)

All paths are under `/Users/alexis.lapasset/Projects/ReadyToQuest/QuestCompanion/`.

## 1. What a player sees of another player

| Feature | What is shown | Trigger | Limits |
|---|---|---|---|
| Trainer card (`TrainerCard.lua`, prefix `QCTrainer`, `TRAINER_PROTO=1`, l.178-199) | Name, title (`ti`/`tg`), date of first capture, species/total, shinies captured and spotted, zone seals and seals per continent (`ek`/`ka`/`other`), feat points (account/char), 3 pinned feats (`hf`) and 4 category bars (`men`, `shiny`, `zone`, `char`), worn companion (npc, display, stars, type, strength, effect `hi/hv`, `ci/cv`), and a showcase of 3 creatures (`v1..v3`: npc, shiny, stars, rank, type, name). Serialized at l.734-786 | Right-click menu, only on known holders (l.1264), hidden in instance (l.1262). Player tooltip line. `/qc fiche [name]` | Chunks of 200 bytes (`TRAINER_CHUNK`). Answers the same player every 10 s at most (`ANSWER_GAP`). Timeout 12 s. Received cards are kept in memory for the session only (`state.cards`, l.1087) |
| Guild feats (`GuildFeats.lua`) | A banner « X a capturé une brillante / élite / rare », a seal, a species milestone (10/25/50/100/250) or a feat worth 25+ points. Click opens their card | `E~1~kind~id~zone~stars~rank~others[~title~form]` on `GUILD` only (l.16-30, 313) | 4 s to group a series (`GFEAT_GATHER`), one send every 30 s at most (`GFEAT_GAP`), queue of 3 banners, stale after 60 s. No saved feed |
| Share (`Share.lua`) | One chat line « [Quest Companion] X a capturé : … » covering captures, feats, seals, titles and batches (l.89-113) | Click on the Share button of a banner (Guild, Raid, Party, Say, Copy). Automatic announcement of shinies and 3-star captures to the group, `announceGroup=true` by default (l.175); to the guild only if switched on | `SHARE_GAP=10` s, `SHARE_REPEAT=60` s, `ANNOUNCE_GAP=30` s. Nothing is sent in combat |
| Social feats (`FeatsCatMenagerie.lua:558-569`) | `soc_card_1/10` (look at cards, 10 names kept, l.709), `soc_showcase`, `soc_guild_feat`, `soc_guild_cheer` (25 feats seen), `soc_group_capture` (a capture while grouped, l.646), `soc_title`, `soc_trade_1/10/new` | Hooks | All of these are one-off flags or counters |

## 2. Trades (`CaptureTrades.lua`)

**Conditions**
- Same faction (l.27-31, 588) and the other player online. No distance check and no target needed: `/qc echange <name>` works.
- The right-click entry only appears on known holders outside instances, because it is attached to the trainer-card menu (l.1267).
- Up to `TRADE_MAX=3` specimens per side, taken from the Reserve only. Codex references, the worn specimen, locked specimens and « better than Codex » are refused.
- Timers: invite 60 s, `TRADE_IDLE_TTL=300`, `TRADE_COOLDOWN=10`.
- History is kept in `capture.tradeLog`, 50 entries (`TRADE_LOG_MAX`).

**What travels** (l.411-425): npc, stars, shiny, size, trait, zone, at, by, origin, name, class, type, family, hops, and the size index `x`. Lock, nickname and bond do not travel (PLAN 3.4 l.90).

**What a traded specimen gives you**
- If you lack that version, it becomes the Codex reference (l.21). That is the only collection gain.
- It counts for 0 in species study and size records: `spec.origin == "capture"` (`SpecimenStudy.lua:6,146,212`; `SpecimenFilters.lua:178`).
- It does not count toward `capture.caught` (`CaptureSpecimens.lua:407`).
- It can still be released for 2/4/10 paillettes, or 25 for a shiny (`CaptureSpecimens.lua:538`, no origin check).
- It can be delivered to weekly orders (`ShopWeek.lua`, no origin check found).
- It can be worn, and its bond restarts at 0.

**Wishlist, « looking for », offers board:** not found.

## 3. Presence, roster, comparisons
- **Presence:** `H` (hello on group, raid or guild join; guild once per session), `P` (silent probe on target or tooltip hover, `GFEAT_PROBE_GAP=1`, `GFEAT_PROBE_FRESH=600`), `A` (ack, `ACK_GAP=300`).
- **Holders cache:** `db.trainerHolders[key] = epoch`, kept 14 days (l.192, 372).
- **Version ping:** not found. `H` carries only proto `1`. `ns.version` is sent only in the trade invite `I` (l.571).
- **Roster or list of known trainers, leaderboard, « my Codex vs yours », gifts between players, co-op goals, guild collection goals:** not found.

## 4. Group play
- Each client decides a kill on its own: kills by you, your pet or your group count via combat log `PARTY_KILL`/`UNIT_DIED` (`Bestiary.lua:14-17, 610-640`). Every addon user in the group therefore gets their own capture chance on the same mob.
- Shiny is rolled locally per player and per GUID (`Shiny.lua:3-5, 218-222`, `math.random`). One player can see a shiny that the groupmate does not. The only shared signal is the raid icon star, and only if the player is solo or leads the group (l.10-11).
- Group bonus: not found. The only group mechanics are the `groupCapture` flag and the automatic 3-star/shiny line to party.

## 5. Constraints that shape any social design
- Messages are 255 bytes maximum (`TRAINER_MAX_MSG`), with a 250-byte cap on a decoded specimen (l.442).
- Send queue: `TRAINER_BURST=6`, `RATE=1/s`, `QUEUE_MAX=40`, `TTL=60`, 5 retries. Nothing is sent in combat or during messaging lockdown (`TrainerBlocked`).
- Inbound flood caps: 40 messages per 10 s (card), 60 per 10 s (trade).
- **No ownership proof:** a modified client can send `s=3;h=1` and the receiver writes it into its Codex. Only bounds and whitelists are checked (l.442-461).
- Cross-faction whispers are impossible. Say and public channels need a hardware click (`Share.lua:14-16`). Right-click menus are suppressed in instances.

## 6. Data already broadcast that a new feature could reuse
- Card fields: `sp/st/sy/sr/se`, feat points, showcase npc list, continent badges, companion type and effects.
- `E` guild events carry npcID, zone and stars.
- Trade spec encoding (`TradeEncodeSpec`) is a ready, versionable specimen serializer.
- `QCTrainer` ignores unknown types and fields, so new message types are backward-safe (header l.10-13).
- Ready2Quest bridge: only `DEPARTURE`/`RETURN` callbacks (`Core.lua:231-240`). R2Q has its own `R2QGroup` prefix (`Ready2Quest/GroupReady.lua:22`), with no QC data shared.
- Weekly order seeds are global (`ShopWeek.lua:80-84, 245`): the trait-and-stars order is the same for every player that week. Type and zone orders depend on what the player has captured.

## 7. Discord / community hooks
- Share formats: `SHARE_MSG_CAPTURE/FEAT/FEATS/SEAL/TITLE/BATCH`, prefix `[Quest Companion]`.
- « Copy » puts the line in the chat edit box. No Discord/web export, no screenshot card, no `#captures-brillantes` hook: not found.
- Sharing a Reserve specimen was announced in the header as « Plus tard » (l.9-11). It is not implemented: no Share usage in `JournalReserve.lua`.

## Weak points

| What | Evidence | Why it matters to a player |
|---|---|---|
| A traded specimen is nearly worthless beyond Codex fill | Study, records and `caught` all filter `origin=="capture"` | Once versions are filled, there is no reason to trade. Trading peaks early and dies |
| No wishlist or « looking for » | Not found | You cannot tell a guildmate what you need. A trade starts blind, by whisper in chat |
| Trainer card ignores the 3.4/3.5 systems | Showcase is species-level (`ParseCapId`, l.716-722). No size, trait, bond, mastered study or mood/states. Still sends `hunt/comfort` | Your best specimen (Inseparable, record size, nickname) cannot be shown off |
| Guild size-record announcement was planned but is missing | PLAN 3.4 l.77 vs `GuildFeats` `KINDS = {s,n,z,r,h}` (l.138). Records go only to your own chat (`SpecimenStudy.lua:43-44`) | The rare-size moment stays private |
| No roster or presence list, no version ping | Holders cache is never displayed; `H` has no version | You cannot see which guildmates play QC, or who is outdated (trades fail with `TRADE_END_version` instead) |
| Guild feats are fleeting | 60 s stale, queue of 3, no saved feed | You miss guild events while AFK or in combat. There is no « guild news » page |
| Received cards are not persisted | `state.cards` only in memory | No way to compare later, no « friends' trainers » list |
| Group captures are fully independent, with no co-op | Bestiary local kill, `ShinyRoll` local | Grouping adds nothing to the creature-collecting side. A groupmate cannot even tell you that the mob is shiny for them |
| No ownership proof on trades | Decode trusts fields | A forged shiny or 3-star specimen can enter your Codex. This limits any future ranking or leaderboard |
| No comparison, leaderboard, gifting or guild goals | Not found | No social goal beyond 3 trade feats. Social feats are one-shot flags |
| Specimen share from the Reserve is unfinished | `Share.lua:9-11` « Plus tard »; no Share in `JournalReserve.lua` | You cannot brag about an owned specimen after the capture banner is gone |
| Instance gating hides card and trade menus | `TrainerCard.lua:1262`, `CaptureTrades.lua:1267` | Dungeon groups, where QC users actually meet, cannot open cards or trades from portraits |