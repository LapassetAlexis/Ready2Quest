# Pokémon benchmark: storage, per-creature differences, sinks, collection goals, non-combat uses

## (a) Storage: filters, search, sort, batch actions

**GO search strings.** The search bar takes a small query language:
- `&` means AND, `,` (or `;` / `:`) means OR, and `!` means NOT.
- Typical tokens: `shiny`, `4*` (all IVs 15), `0*`–`3*` (appraisal bands), `lucky`, `shadow`, `purified`, `legendary`, `traded`, `hatched`, `costume`, `xxl`/`xxs`/`xl`/`xs`, `age0` (caught in the last 24 h), `distance100-` (caught at least 100 km away, useful for trade candy), `cp-1500`, `year2019`, `buddy0-5`, `@fire`/`@1fire` (move type), `+pikachu` (whole family), `#tag`, `dynamax`, `defender`.
- Classic cleanup string: `!shiny&!lucky&!legendary&!#keep&0*,1*,2*&age0-2`.
- You can select many Pokémon with a long press, or "Select all" on the search results, then transfer them in one batch. Favorites, shiny and legendary Pokémon trigger confirmation prompts.
- Tags (2020) are player-made labels with colours.
- **Why it works:** a text query lets power users write their own "sorting rules" without the team building a UI for each case. People share strings as community knowledge.

**HOME.**
- Free plan: 1 box of 30. Premium (about $2.99/month or $15.99/year): 200 boxes, 6,000 Pokémon.
- Box search filters by species, type, shiny, gender, Poké Ball, origin game, Gigantamax, nature, ability, moves and level, then shows only the matches.
- Range select and box-wide moves.
- National Dex view with per-form progress.

**Mainline games.**
- Sword/Shield and Scarlet/Violet: box search by name, type, Tera Type, held item, ability, nature, gender, ball and markings.
- Multi-select drag mode (the green "hand"), and box sort in Scarlet/Violet DLC updates.
- Six player-set markings (circle, triangle, square, heart, star, diamond; red or blue in later games) act as a lightweight tag system.

## (b) Per-creature differences without pay-to-win

**Natures.**
- 25 natures: 20 give one stat +10% and another −10%; 5 are neutral.
- Mints (Sword/Shield onward) change which stat the nature boosts, not the nature's name. You correct your "luck" with a farmable item, not with money.

**IVs.**
- Mainline: 0–31 per stat. The Judge function rates them in words. Hyper Training with Bottle Caps sets an IV to 31 at level 50 in Scarlet/Violet (level 100 in earlier games).
- GO: 0–15 for Attack, Defense and HP. Appraisal shows 0–4 stars plus bars. A 100% Pokémon is called a "hundo".
- In GO, IVs make about a 5–10% difference in CP. Levels and moves matter far more.

**Size.**
- GO: XXS, XS, XL, XXL. They affect looks, medals and Showcases, not stats.
- Scarlet/Violet: Scale value 0–255. The Mini Mark (0) gives the title "the Teeny" and the Jumbo Mark (255) gives "the Great". Purely cosmetic.

**Marks and ribbons.**
- Marks from weather, time of day, personality and the rare mark (about 1/1000) each give a title shown in battle. Only one title is shown at a time.
- Ribbons record achievements.
- **Why it works:** collectible differences that cost no power.

**Friendship/affection battle effects.**
- In Let's Go and Sword/Shield (and earlier, Amie/Refresh), high affection gives:
  - surviving a KO hit at 1 HP;
  - shaking off status;
  - a chance to dodge;
  - a higher crit rate;
  - about 1.2× XP.
- Scarlet/Violet removed these effects, because they skewed difficulty.
- **Why it works:** a reward for emotional attachment and time spent.

**GO buddy.**
- Heart thresholds: Good 1, Great 70, Ultra 150, Best 300.
- About 10 hearts a day, 20 when the buddy is "excited" (fastest Best Buddy: about 15 days).
- Perks:
  - Great Buddy: catch assist, finds souvenirs.
  - Ultra Buddy: finds presents, visits PokéStops.
  - Best Buddy: CP boost of +1 level (cap 51), plus a ribbon.
- **Why it works:** daily caps reward coming back each day, not grinding. Only one buddy can be active at a time, which caps the power gain.

**GO trading.**
- Traded Pokémon get new IVs, with a minimum that rises with friendship (Good 1, Great 2, Ultra 3, Best 5).
- Lucky Pokémon have IVs of at least 12/12/12 and cost 50% less stardust to power up. The lucky chance is about 5% normally, higher for old Pokémon, and guaranteed with "Lucky Friends".
- Trades give candy bonuses by distance, and dust costs drop with friendship.

**Mainline trading.** Traded Pokémon get 1.5× XP (1.7× for international trades). This rewards social play.

## (c) Sinks and inventory pressure (GO)

**Storage upgrades.**
- 200 PokéCoins for +50 slots, for both the Pokémon box and the item bag.
- Pokémon storage reached 9,300 in December 2024. Item bag figures vary between sources (about 8,300 in one report).
- Reaching the cap costs about 34,000 coins.
- Coins can be earned for free, capped at 50 a day from gym defending.

**Transfer.**
- 1 candy per transfer. Pokémon above level 31 have a chance of giving XL Candy.
- The Candy Machine lets you send many Pokémon at once.

**Stardust.** The main power-up sink. Costs rise from 200 to 15,000 per power-up, and XL Candy is needed above level 40.

**Why it works:** limited storage forces players to judge what to keep. Transferring turns duplicates into candy, a resource you need. Paying for slots is optional comfort, not power.

## (d) Collection goals

**Dex variants.**
- GO separates shiny, lucky, 3★/4★, shadow/purified, XXS/XXL and costume categories in the Pokédex.
- HOME tracks forms and gives a National Dex reward.

**GO medals.** Bronze, Silver, Gold and Platinum tiers per activity and per type. Type medals used to give a catch bonus.

**PokéStop Showcases (2023).**
- Players enter one Pokémon of a given species. The ranking uses a size score.
- Prizes: a badge plus items.
- This turns XXL/XXS Pokémon into something to compete with.

**Legends Arceus Pokédex research.**
- Each species has tasks (catch N, see a move N times, feed, defeat with a type…).
- Each task gives points. A species reaches research level 10 at 100 points, and "Perfect" when every task is done.
- **Why it works:** many paths to progress, so players with different styles all move forward. A single Pokédex entry becomes a set of varied goals.

## (e) Non-combat uses

**Pokémon Sleep.**
- Natures change helping speed (about ±10%), ingredient finding (about ±20%), main skill chance (about ±20%), XP and energy recovery. Sources disagree on the exact percentages.
- Sub-skills unlock at levels 10/25/50/75/100. Examples: Helping Speed S 7% / M 14%; Ingredient Finder S 18% / M 36%.
- **Why it works:** a "bad" combat nature can be good here, so every individual has a use.

**Poké Jobs (Sword/Shield).**
- Companies ask for certain types.
- You send several Pokémon from boxes for 1 h to 24 h.
- Rewards: XP and items, with more for Pokémon of the right type.
- This makes boxes useful while you are not playing.

**Poké Pelago (Sun/Moon).**
- Five islands, each with a job:
  - Abeens: befriending wild Pokémon;
  - Aplenty: berries;
  - Aphun: treasure;
  - Evelup: XP and EV training;
  - Avue: hot springs that hatch eggs and raise affection.
- Uses Poké Beans and works while you play.

**Let's Go Pikachu/Eevee.**
- Any Pokémon can follow you.
- Some can be ridden (Onix, Charizard, Arcanine, Lapras…).
- The starter partner has partner powers and is customized with outfits.
- **Why it works:** showing the bond makes it count.

## Common player complaints

- **GO storage management is tedious.** Hoarding for Community Days or evolutions fills the box, and transfer sessions take a long time. Third-party IV scanners (Calcy IV) existed because appraisal was slow.
- **The storage limit feels like a monetized irritant.**
- **IV elitism.** "Hundo or trash", and PvP rank-1 IVs (low Attack) that make one Pokémon out of 4,096 the "right" one, so players feel their catches are worthless.
- **Hard-to-learn search syntax**, discovered through community lists.
- **The HOME paywall** for real storage.
- **Mainline boxes:** sorting arrived late in some games, and there is no cross-box sort.
- **Removing Scarlet/Violet affection effects** made some players sad, though it solved a balance problem.
- **Daily buddy caps** are a source of frustration (FOMO).
- **Showcases** are dominated by size luck and people grinding the same species.

Sources:
- [mein-mmo – Dec 2024 storage increase](https://mein-mmo.de/en/pokemon-go-bag-full-there-is-now-more-space-for-pokemon-and-items,1091530/)
- [pokemongo.com – storage increase](https://pokemongo.com/hi/news/december-2024-storage-increase)
- [mein-mmo – max bags cost](https://mein-mmo.de/en/trainer-in-pokemon-go-gets-the-maximum-bags-without-spending-a-single-cent,1568975/)
- [Bulbapedia – Buddy Pokémon](https://Bulbapedia.Bulbagarden.net/wiki/Buddy_Pok%C3%A9mon)
- [iMore – Buddy Adventure](https://www.imore.com/everything-you-need-know-about-pokemon-go-buddy-adventure)
- [Pokémon GO Hub – Buddy guide](https://pokemongohub.net/post/guide/buddy-adventure-guide-everything-you-need-to-know/amp/)
- [Serebii – Pokémon Sleep natures](https://SEREBII.NET/pokemonsleep/natures.shtml)
- [Pokémon GO Hub – Sleep natures](https://pokemongohub.net/post/sleep/pokemon-sleep-natures/)
- [Bulbapedia – Skill (Sleep)](https://bulbapedia.bulbagarden.net/wiki/Skill_(Sleep))