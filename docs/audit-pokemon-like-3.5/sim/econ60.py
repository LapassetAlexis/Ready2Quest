"""Paillettes economy, QC 3.5.0 constants (read from the code), 60 days.

Constants (file:line in the audit):
  release 2/4/10, shiny 25           CaptureSpecimens.lua:134
  quality odds normal 65/28/7        CaptureSpecimens.lua:123
  quality capture factor 1/.8/.6     CaptureSpecimens.lua:129
  wariness step .15 floor .4 (hunt)  CaptureSpecimens.lua:138
  base chance normal .50, pity +.05x5  Capture.lua:34-43, max .95
  shiny 1/150                        Shiny.lua:25
  reserve base 50                    CaptureSpecimens.lua:120
  slots 40+20k, +10, max 150         ShopWeek.lua (SHOP_SLOTS)
  aids 4/12/35, daily stock 5/2/1, bag caps 10/5/3
  cosmetics 80,60,80,100,120,60,80,100 (arrival, 2 per week of 8)
  nickname 15
  missions zone/trait 3, all3 5, weekly 5, allWeekly 10   Daily.lua:55-61
  milestone 2                         JournalReserve.lua:68
  study 2 per task (5 tasks), 5 mastered   SpecimenStudy.lua:29-30
  orders 12/14/16 x3 per week, all3 -> 1 free arrival cosmetic  ShopWeek.lua
  pantry overflow 1                   Treats.lua:249
Behaviour assumptions are explicit in PROFILES.
"""
import random, statistics

REL = {1: 2, 2: 4, 3: 10}
SHINY_REL = 25
Q_ODDS = [(1, .65), (2, .28), (3, .07)]
Q_FACT = {1: 1.0, 2: .8, 3: .6}
SIZES = [("tiny", 2), ("small", 18), ("normal", 60), ("large", 18), ("giant", 2)]
TRAITS = [("curious", 3), ("glutton", 3), ("daring", 3), ("lazy", 3), ("teasing", 3), ("cuddly", 3), ("zen", 1), ("mischievous", 1)]
COSMETICS = {"frame_glitter": 80, "bg_starfall": 60, "frame_ember": 80, "frame_frost": 100,
             "frame_verdant": 120, "bg_dusk": 60, "bg_tide": 80, "bg_grove": 100}
AIDS = {"appat": (4, 5), "lasso": (12, 2), "sifflet": (35, 1)}

PROFILES = {
    # 30 min/day, no hunt mode: net only when worth it (new species, better stars, shiny)
    "casual": dict(kills=60, hunt=False, new_per_day=3, pool=15, zone_days=4,
                   p_daily=.6, p_weekly=.5, milestones_per_day=.3, overflow_per_day=.3,
                   orders_per_week=1, nick_per_week=.3, buy_aids=False, keep_reserve=20),
    # 3 h/day, hunt mode on: every kill gets a net
    "heavy": dict(kills=360, hunt=True, new_per_day=12, pool=15, zone_days=2,
                  p_daily=.95, p_weekly=.9, milestones_per_day=1.0, overflow_per_day=1.5,
                  orders_per_week=3, nick_per_week=1, buy_aids=False, keep_reserve=30),
    "heavy+aids": None,  # heavy that also buys the full daily aid stock it consumes
}
PROFILES["heavy+aids"] = dict(PROFILES["heavy"], buy_aids=True)


def wpick(pairs):
    r = random.random() * sum(w for _, w in pairs)
    for k, w in pairs:
        r -= w
        if r <= 0:
            return k
    return pairs[-1][0]


def run(p, days=60, seed=0):
    random.seed(seed)
    bal = earned = 0
    src = dict(release=0, missions=0, milestone=0, study=0, orders=0, overflow=0)
    sink = dict(slots=0, cosmetics=0, aids=0, nick=0)
    slot_buys, cap = 0, 50
    owned = set()
    codex = {}       # npc -> best stars (normal)
    shiny_codex = set()
    reserve = []     # list of (npc, stars, shiny)
    study = {}       # npc -> dict(n, s3, sizes, traits, paid)
    next_npc = 0
    pool = []
    events = {}
    for day in range(1, days + 1):
        week_day = (day - 1) % 7
        if week_day == 0:
            arrivals = random.sample(list(COSMETICS), 2)
            orders_left = p["orders_per_week"]
            weekly_done = 0
        if (day - 1) % p["zone_days"] == 0:
            # new hunting ground: some known species + new ones
            fresh = list(range(next_npc, next_npc + p["new_per_day"] * p["zone_days"]))
            next_npc += len(fresh)
            pool = fresh[: p["pool"]]
        today = {}
        pity = 0
        for _ in range(p["kills"]):
            npc = random.choice(pool)
            stars = wpick(Q_ODDS)
            shiny = random.random() < 1 / 150
            if not p["hunt"]:
                worth = npc not in codex or stars > codex.get(npc, 0) or (shiny and npc not in shiny_codex)
                if not worth:
                    continue
            ch = .5 * Q_FACT[stars] + .05 * min(pity, 5)
            if p["hunt"]:
                ch *= max(.4, 1 - .15 * today.get(npc, 0))
            ch = min(.95, ch)
            if random.random() >= ch:
                pity += 1
                continue
            pity = 0
            today[npc] = today.get(npc, 0) + 1
            size, trait = wpick(SIZES), wpick(TRAITS)
            # study
            row = study.setdefault(npc, dict(n=0, s3=False, sizes=set(), traits=set(), paid=set()))
            row["n"] += 1; row["s3"] |= stars == 3; row["sizes"].add(size); row["traits"].add(trait)
            done = {"caught": True, "stars3": row["s3"], "five": row["n"] >= 5,
                    "sizes": len(row["sizes"]) >= 3, "traits": len(row["traits"]) >= 3}
            for t, ok in done.items():
                if ok and t not in row["paid"]:
                    row["paid"].add(t); bal += 2; src["study"] += 2
            if len(row["paid"]) == 5 and "m" not in row["paid"]:
                row["paid"].add("m"); bal += 5; src["study"] += 5
            # codex / reserve
            if shiny:
                if npc not in shiny_codex:
                    shiny_codex.add(npc)
                else:
                    reserve.append((npc, stars, True))
            elif stars > codex.get(npc, 0):
                if npc in codex:
                    reserve.append((npc, codex[npc], False))
                codex[npc] = stars
            else:
                reserve.append((npc, stars, False))
            # reserve full: release the cheapest beyond keep (player behaviour)
            while len(reserve) >= cap:
                reserve.sort(key=lambda s: SHINY_REL if s[2] else REL[s[1]])
                s = reserve.pop(0)
                v = SHINY_REL if s[2] else REL[s[1]]
                bal += v; src["release"] += v
        # end of day: release surplus beyond keep_reserve
        reserve.sort(key=lambda s: SHINY_REL if s[2] else REL[s[1]])
        while len(reserve) > p["keep_reserve"]:
            s = reserve.pop(0)
            v = SHINY_REL if s[2] else REL[s[1]]
            bal += v; src["release"] += v
        # missions
        d = sum(1 for _ in range(3) if random.random() < p["p_daily"])
        g = 3 * d + (5 if d == 3 else 0)
        bal += g; src["missions"] += g
        if week_day == 6:
            w = sum(1 for _ in range(3) if random.random() < p["p_weekly"])
            g = 5 * w + (10 if w == 3 else 0)
            bal += g; src["missions"] += g
        # zone milestones (cap 3 per zone, ~44 zones -> 132)
        if src["milestone"] < 132 * 2 and random.random() < p["milestones_per_day"]:
            bal += 2; src["milestone"] += 2
        # pantry overflow
        o = int(p["overflow_per_day"]) + (1 if random.random() < p["overflow_per_day"] % 1 else 0)
        bal += o; src["overflow"] += o
        # orders: deliver from reserve on a weekday (reward 12/14/16)
        if week_day == 3 and orders_left:
            n = min(orders_left, len(reserve))
            for _ in range(n):
                reserve.pop(0)
                r = random.choice((12, 14, 16)); bal += r; src["orders"] += r
            if n == 3:
                free = [c for c in arrivals if c not in owned]
                if free:
                    owned.add(free[0])
            orders_left = 0
        # ---- spending (priority: slots, then arrival cosmetics, aids, nick)
        if p["buy_aids"]:
            for aid, (price, stock) in AIDS.items():
                for _ in range(stock):
                    if bal >= price:
                        bal -= price; sink["aids"] += price
        bought = True
        while bought:
            bought = False
            price = 40 + 20 * slot_buys
            if cap < 150 and bal >= price:
                bal -= price; sink["slots"] += price; slot_buys += 1; cap += 10; bought = True
                if cap >= 150:
                    events.setdefault("slots maxed", day)
        for c in arrivals:
            if c not in owned and bal >= COSMETICS[c]:
                bal -= COSMETICS[c]; sink["cosmetics"] += COSMETICS[c]; owned.add(c)
        if len(owned) == len(COSMETICS):
            events.setdefault("all 8 shop cosmetics", day)
        if random.random() < p["nick_per_week"] / 7 and bal >= 15:
            bal -= 15; sink["nick"] += 15
        earned = sum(src.values())
        if day in (7, 30, 60):
            events["bal_d%d" % day] = bal
    events.update(balance=bal, earned=earned, src=src, sink=sink, cap=cap, owned=len(owned),
                  species=len(codex), mastered=sum(1 for r in study.values() if "m" in r["paid"]))
    return events


def main():
    for name, p in PROFILES.items():
        runs = [run(p, seed=s) for s in range(40)]
        def med(key):
            vals = [r.get(key) for r in runs if r.get(key) is not None]
            return (statistics.median(vals), len(vals)) if vals else (None, 0)
        print("==", name)
        for k in ("slots maxed", "all 8 shop cosmetics"):
            m, n = med(k)
            print(f"  {k}: median day {m} ({n}/40 runs reach it)")
        for k in ("bal_d7", "bal_d30", "bal_d60", "earned", "cap", "owned", "species", "mastered"):
            print(f"  {k}: median {med(k)[0]}")
        srcs = {k: statistics.median(r['src'][k] for r in runs) for k in runs[0]['src']}
        sinks = {k: statistics.median(r['sink'][k] for r in runs) for k in runs[0]['sink']}
        print("  sources (60 d, median):", srcs)
        print("  sinks   (60 d, median):", sinks)


if __name__ == "__main__":
    main()
