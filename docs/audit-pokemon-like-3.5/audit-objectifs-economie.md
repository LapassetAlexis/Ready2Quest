## QC 3.5.0 audit: collection goals, rewards, paillettes economy

### 1. Paillettes sources and sinks (as coded)

| Source | Amount | Cap / limit | Ref |
|---|---|---|---|
| Release from Reserve | 2 / 4 / 10 by stars, shiny 25 | none | CaptureSpecimens.lua:134 |
| Daily zone or trait mission | 3 each (3 a day) | 3/day | Daily.lua:56-57 |
| All three dailies | 5 | 1/day | Daily.lua:58 |
| Weekly mission | 5 each (3 a week) | 3/week | Daily.lua:59 |
| All three weeklies | 10 | 1/week | Daily.lua:60 |
| Zone milestone (25/50/75 %) | 2, or 3 with Curieux worn | 3 per zone | JournalReserve.lua:68, CompanionEffects.lua:109 |
| Species study | 2 per task (5 tasks), 5 when mastered | 15 per species | SpecimenStudy.lua:29 |
| Weekly orders | 12/14/16 each | 3/week | ShopWeek.lua (ORDER_REWARDS), :319 |
| Treat overflow (pantry full) | 1 | pantry holds 3 of each treat, 2 Festins | Treats.lua:249, :27 |

| Sink | Price | Limit | Ref |
|---|---|---|---|
| Reserve +10 slots | 40 + 20 × buys | max 150 slots (base 50) → 10 buys, **1,300 total** | ShopWeek.lua SHOP_SLOTS; CaptureSpecimens.lua:120 |
| Aids: appat / lasso / sifflet | 4 / 12 / 35 | daily stock 5/2/1 (79/day max), bag caps 10/5/3 | JournalReserve.lua:43-45; ShopWeek SHOP_STOCK; Capture.lua:46-48 |
| Shop cosmetics (8) | 60–120 each, **680 total** | only the 2 weekly arrivals can be bought (ShopWeek SHOP_ARRIVALS) | JournalReserve.lua:48-63 |
| Nickname | 15 (free at bond ≥5) | unlimited | ShopWeek SHOP_NICK_PRICE |

The economy has no other `PaillettesSpend` calls (grep). No feat tracks `paillettesEarned`.

**Simulation** (`/private/tmp/claude-2007623921/-Users-alexis-lapasset-orca-workspaces-ReadyToQuest-qc-reserve-design/c71c5d45-23dc-4285-87e3-69915616ccc5/scratchpad/scan3/sim/econ60.py`): 40 seeds, medians. Assumptions are mine: casual = 60 kills a day, no hunt mode; heavy = 360 kills a day, hunt mode, wariness and pity modelled.

| Profile | Earned in 60 d | Slots maxed | All 8 cosmetics | Balance d7 / d30 / d60 |
|---|---|---|---|---|
| Casual | 1,482 (study 552, missions 460, release 296) | never (130 slots at d60) | 2 of 40 runs | 38 / 49 / 68 |
| Heavy | 21,400 (release 14,807, study 5,065) | **day 5** | day 43 (only 20 of 40 runs) | 960 / 8,687 / **19,408** |
| Heavy, buys full aid stock daily | same | day 6 | day 43 | 444 / 6,373 / 14,687 |

For casual players the economy works. For heavy players it breaks down. Slots run out in the first week. Cosmetics are held back only by the weekly rotation. By day 60 the only sinks left are aids (79 a day, and only if the aids get used) and nicknames.

### 2. Reward catalogue

| Kind | Total | Obtainable | Not obtainable |
|---|---|---|---|
| Titles | 40 | 39 | `fun_unlucky` is pending (FeatsCatJeu.lua:502) |
| Companion frames | 31 (12 chest tiers, 1 shiny, 10 seal, 2 rank, 2 feat, 4 shop) | 31 | – |
| Companion backgrounds | 39 (20 base, 1 shiny, 10 seal, 2 rank, 2 feat, 4 shop) | 39 | – |
| Ornaments | 16 (9 base, 7 feat) | 15 | `feat_wildcrown`: `dng_raid_hyjal` is pending (FeatsCatJeu.lua:457) |
| Appearances | 24 fixed, plus captured creatures (`cap:<npc>`) | 24 | – |
| Card backgrounds / frames | **0 exist** | 0 | 7 feats point to them as "soon": `men_species_500`, `zone_seal_ek`, `zone_seal_ka`, `meta_zones`, `meta_trainer`, `meta_hero`, `meta_points_1500` |

The game has 187 feats. **107 give nothing**, and 4 more give only a "soon" item. Collection feats that give nothing: `men_study_10/50/100`, `men_bond_familiar`, `men_bond_inseparable`, `men_traits_all`, `men_sizes_all`, `men_size_giant`, `men_size_tiny` (FeatsCatMenagerie.lua:505-514), `shiny_seen_1`, `shiny_elite`, `shiny_sealed`, `shiny_zones_10`, and `soc_trade_1/10/new` (:567-569). Every feat added in 3.4 is in that list.

### 3. Goals by horizon

- **Session:** new species (capNew), study tasks (+2 each), shinies at 1/150 (Shiny.lua:25), zone milestones, a free sifflet every 10 captures (Capture.lua:31).
- **Week:** 3 weekly missions, 3 orders plus one free cosmetic, the 2 shop arrivals.
- **Month:** trainer ranks at 50 and 100 species, seals, type tiers (common 10/20/40, rare 5/10/20), the Inséparable bond.
- **Long term:** 250 species is the last trainer rank (MenagerieCollection.lua:36). 500 species gives a title plus a "soon" reward. The data holds **3,541 species** across 44 zones (ZoneCreatures_Forever.lua).
- **Holes:** nothing between 250 and 500 species, nothing after 500. Type tiers stop at tier 3. Study mastery feats give nothing. Shinies stop rewarding after shiny_found_50 and shiny_cap_25.

### 4. Daily and weekly missions

- **Daily (3):** one menagerie mission from 4 kinds (capNew, capType, capNamed, captures fallback; MissionsMenagerie.lua:5, :187), one exploration mission from 4 kinds (gather, quests, village, percent; Daily.lua:33), and one trait mission. The trait mission comes from the companion's character (Daily.lua:400-401), so the **same companion gets the same third mission every day**. There are 11 distinct trait kinds in total (Daily.lua:38-46).
- **Weekly (3):** 9 kinds plus a typed capture (Weekly.lua:20-30). Each week always includes 1 capture mission and 1 shiny hunt (:197-200).
- No mission asks for a size, character, star count, bond, companion state, study task or order (grep of Daily.lua, Weekly.lua and MissionsMenagerie.lua). Orders are the only systems that ask for a profile (type+size, character+2 stars, zone), and they are fixed at those 3 shapes.

### 5. Seals and type tiers

- **Per seal:** shinies ×1.5 in that zone (MenagerieCollection.lua:25). The first seal in a biome gives the biome frame, the second gives its background (:211-218). There are 10 biomes and 40 zones with a biome (:44-56).
- **Seal feats:** seal_1 gives a lasso, seal_5 a sifflet, seal_15 a title, and all of EK or all of Kalimdor gives only "soon". Seal feats are per character (scope CH, FeatsCatMenagerie.lua:528-531), while specimens are account-wide.
- **After the 2nd seal in a biome**, and after every zone is sealed, nothing more is earned.
- **Type tiers:** each tier adds +0.25 strength (:28) and stops at tier 3 (:438-449). There is no tier 4 and no cosmetic.

### 6. Feats per category

| Cat | men | shiny | zone | day | soc | char | dng | prof | quest | fun | meta |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Count | 38 | 12 | 23 | 14 | 10 | 21 | 21 | 12 | 11 | 17 | 8 |
| Points | 615 | 230 | 460 | 190 | 65 | 255 | 490 | 155 | 185 | 110 | 285 |

Total: 3,040 points, including 15 pending feats.

Meta feats:
- `meta_menagerie` gives a title.
- `meta_shiny` gives frame `feat_prism`.
- `meta_zones` gives only "soon".
- `meta_trainer` needs 3 metas plus 1,000 points (FeatsCatMenagerie.lua:813) and gives a title plus "soon".
- `meta_dungeons` and `meta_hero` give titles; `meta_hero` also has a "soon" reward.
- `meta_points_500` gives nothing; `meta_points_1500` gives only "soon".

High point totals unlock nothing usable.

### 7. Seasonal content

Winter Veil is the only event (WinterVeil.lua, WinterCompanions.lua, feat `fun_winter_veil`, FeatsCatMenagerie.lua:581). The only other one is a personal one: the companion's birthday (`fun_birthday`, :578, gives nothing). There is no Hallow's End, Lunar Festival or other holiday, and no event creatures, because the data excludes seasonal NPCs (ZoneCreatures_Forever.lua header).

### Weak points

1. **Heavy hunters pile up paillettes with nothing to buy.** About 19k by day 60, with slots maxed on day 5 (sim). After that, release, study and orders pay into nothing, so the hunting loop loses its point.
2. **Release is ~70 % of heavy income** (14.8k of 21.4k). The supply of duplicates is effectively unlimited and nothing caps it.
3. **Cosmetics are gated by rotation, not price.** With 2 of 8 per week, half of heavy runs still miss one at day 60. Waiting is the only obstacle.
4. **The 3.4/3.5 feats give nothing** (study, bond, sizes, characters). The new systems don't feed the reward loop.
5. **Card cosmetics don't exist.** 7 high-tier feats (500 species, both continent seals, 3 metas) show "coming soon". The game's top goals have no payoff yet.
6. **Gap from 250 to 500 species, and nothing after 500.** That is out of 3,541 species, so the long-term collector has nothing to aim for.
7. **The trait daily repeats every day** for a given companion (Daily.lua:400). That is fatigue on 1 of the 3 dailies.
8. **No mission uses size, character, bond, state, study or orders.** The new systems have no daily hook.
9. **Seals stop paying after the 2nd in a biome.** The continent-wide rewards are "soon", so the endgame of sealing has no reward.
10. **The shop's "how to earn" note is stale.** It lists release, missions and milestones but leaves out study, orders and overflow (JournalReserve.lua:159, :244). Players don't learn about their two biggest steady sources.
11. **Aids are the only recurring sink**, and only while capturing. Bag caps of 10/5/3 (Capture.lua:46-48) make stockpiling impossible.
12. **Winter Veil is the only event.** There is no calendar to bring players back in other seasons.