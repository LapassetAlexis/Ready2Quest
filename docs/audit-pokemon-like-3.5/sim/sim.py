"""Quest Companion 3.5 capture pacing simulation (assumption-driven model).
Constants copied from the addon source (Capture.lua, CaptureSpecimens.lua,
Shiny.lua, CompanionStates.lua, MenagerieCollection.lua). Behavioural
assumptions are in ASSUME and printed with the results."""
import json, math, random, statistics, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
ZONES = json.load(open(os.path.join(HERE, 'zones.json')))

# ---- addon constants ----
RATES = {0: 0.50, 1: 0.25, 4: 0.15, 2: 0.10, 3: 0.04}       # rank code -> CAPTURE_RATES
QGROUP = {0: (65, 28, 7), 1: (50, 35, 15), 4: (30, 45, 25), 2: (30, 45, 25), 3: (30, 45, 25)}
QFACTOR = {1: 1.0, 2: 0.8, 3: 0.6}
CAP_MAX = 0.95
PITY_STEP, PITY_MAX = 0.05, 5
LVL_ABOVE, LVL_BELOW, LVL_FLOOR, LVL_CEIL = 0.04, 0.03, 0.5, 1.5
SHINY = 1 / 150; SHINY_RANK = 3; CHAIN_K = 50; CHAIN_MAX = 3.75
SEAL_SHINY = 1.5
RADIANT_CAP, RADIANT_SHINY = 1.10, 1.20
WARY_STEP, WARY_FLOOR = 0.15, 0.4
GIFT_EVERY = 10
AID_CAP = {'appat': 10, 'lasso': 5, 'sifflet': 3}
AID_MULT = {'appat': 1.5, 'lasso': 2.5}
RANK_GIFTS = {10: ['appat', 'lasso'], 50: ['sifflet'], 100: ['sifflet'], 250: ['sifflet', 'sifflet']}

ASSUME = dict(
    kills_per_min=1.5,          # questing pace incl. travel
    seen_per_kill=2.0,          # nameplates/targets rolled for shiny per kill; a spotted shiny is always hunted down
    radiant_uptime=0.5,         # share of play time Radiant (3.5 plan: 39-88 % depending on activity)
    leveling_hours=180,         # /played to 60
    zone_hours_per_80=4.0,      # leveling time spent in a zone of 80 species
    rare_per_hour_in_zone=0.15, # chance per hour to find+kill one specific rare spawn while in its zone
    elite_weight=0.3,           # kill weight of an elite species vs a normal one
    weight_sigma=1.0,           # lognormal spread of kill weights between normal species (quest hubs)
    lasso_per_week=3, sifflet_per_week=1, appat_per_day=1,  # missions / stamps income
    faction='A',
)


def species_pool():
    pool = {}
    for zid, z in ZONES.items():
        rows = [r for r in z['rows'] if r['f'] != ASSUME['faction'] and r['rank'] != 3
                and r['lo'] >= 0 and r['hi'] < 9999]
        lv = sorted(r['lo'] for r in rows if r['lo'] > 0) or [1]
        med = lv[len(lv) // 2]
        pool[zid] = dict(name=z['name'], med=med, rows=rows)
    return pool


def run(minutes_per_day, seed, hunt=False, max_days=3000, focus_zone=None):
    rng = random.Random(seed)
    pool = species_pool()
    order = sorted(pool, key=lambda z: pool[z]['med'])
    # kill weights
    W = {}
    for zid, z in pool.items():
        for r in z['rows']:
            if r['rank'] in (2, 4):
                continue
            w = rng.lognormvariate(0, ASSUME['weight_sigma'])
            if r['rank'] == 1:
                w *= ASSUME['elite_weight']
            W[(zid, r['npc'])] = w
    owned = {}        # npc -> best stars (normal)
    shiny_owned = set()
    kills = {}
    aids = {'appat': 0, 'lasso': 0, 'sifflet': 0}
    streak = 0
    caps = dups = 0
    reserve = 0; reserve_full_day = None
    wary = {}; wary_day = -1
    shiny_caps = 0; shiny_seen = 0
    sealed = set()
    milestones = {}
    dup_curve = []
    hours = ASSUME['leveling_hours'] if focus_zone else 0.0
    # leveling schedule: list of (zid, hours)
    sched = []
    tot = 0
    for zid in order:
        h = ASSUME['zone_hours_per_80'] * len(pool[zid]['rows']) / 80
        sched.append((zid, h)); tot += h
    scale = ASSUME['leveling_hours'] / tot
    sched = [(z, h * scale) for z, h in sched]
    si, left = 0, sched[0][1]
    kpm = ASSUME['kills_per_min']

    def grant(a, n=1):
        aids[a] = min(AID_CAP[a], aids[a] + n)

    def player_level():
        return min(60, 1 + 59 * min(1, hours / ASSUME['leveling_hours']))

    def missing(zid):
        return sum(1 for r in pool[zid]['rows'] if r['npc'] not in owned)

    def attempt(r, zid, stars, shiny, day):
        nonlocal streak, caps, dups, reserve, shiny_caps
        npc = r['npc']
        new = npc not in owned if not shiny else npc not in shiny_owned
        base = RATES[r['rank']]
        diff = (r['lo'] + r['hi']) / 2 - player_level()
        f = max(LVL_FLOOR, 1 - LVL_ABOVE * diff) if diff > 0 else min(LVL_CEIL, 1 - LVL_BELOW * diff)
        c = base * f * QFACTOR[stars]
        if hunt and not new:
            n = wary.get(npc, 0)
            if n > 0:
                c *= max(WARY_FLOOR, 1 - WARY_STEP * n)
        aid = None
        if (shiny or (new and r['rank'] in (2, 4))) and aids['sifflet']:
            aid = 'sifflet'
        elif (shiny or (new and r['rank'] in (1, 2, 4))) and aids['lasso']:
            aid = 'lasso'
        elif new and aids['appat']:
            aid = 'appat'
        if aid:
            aids[aid] -= 1
        if aid == 'sifflet':
            ok = True
        else:
            c *= AID_MULT.get(aid, 1)
            c = min(CAP_MAX, c)
            if rng.random() < ASSUME['radiant_uptime']:
                c = min(CAP_MAX, c * RADIANT_CAP)
            c = min(CAP_MAX, c + PITY_STEP * min(PITY_MAX, streak))
            ok = rng.random() < c
        streak = 0 if ok else streak + 1
        if not ok:
            return
        caps += 1
        wary[npc] = wary.get(npc, 0) + 1
        if shiny:
            if npc not in shiny_owned:
                shiny_owned.add(npc); shiny_caps += 1
            else:
                dups += 1; reserve += 1
            return
        if npc in owned:
            dups += 1; reserve += 1
            owned[npc] = max(owned[npc], stars)
        else:
            owned[npc] = stars
            n = len(owned)
            if n % GIFT_EVERY == 0:
                grant('sifflet')
            for a in RANK_GIFTS.get(n, []):
                grant(a)
            for m in (10, 50, 100, 250, 500):
                if n >= m and m not in milestones:
                    milestones[m] = day

    for day in range(1, max_days + 1):
        if day % 7 == 0:
            grant('lasso', ASSUME['lasso_per_week']); grant('sifflet', ASSUME['sifflet_per_week'])
        grant('appat', ASSUME['appat_per_day'])
        wary = {}
        mins = minutes_per_day
        while mins > 0:
            block = min(30, mins); mins -= block
            # pick zone
            if focus_zone:
                zid = focus_zone
            elif si < len(sched):
                zid = sched[si][0]
                left -= block / 60
                if left <= 0:
                    si += 1
                    if si < len(sched):
                        left = sched[si][1]
            else:
                zid = max(pool, key=lambda z: (missing(z), -int(z)))
                if missing(zid) == 0:
                    zid = rng.choice(order)
            hours += block / 60
            z = pool[zid]
            lvl = player_level()
            elig = [r for r in z['rows'] if (r['lo'] + r['hi']) / 2 <= lvl + 4 and r['rank'] not in (2, 4)]
            if not elig:
                elig = [r for r in z['rows'] if r['rank'] not in (2, 4)][:3]
            weights = [W[(zid, r['npc'])] for r in elig]
            nk = int(block * kpm + rng.random())
            events = [rng.choices(elig, weights)[0] for _ in range(nk)] if elig else []
            for r in z['rows']:
                if r['rank'] in (2, 4) and (r['lo'] + r['hi']) / 2 <= lvl + 4:
                    if rng.random() < ASSUME['rare_per_hour_in_zone'] * block / 60:
                        events.append(r)
            sealmul = SEAL_SHINY if zid in sealed else 1
            for r in events:
                npc = r['npc']
                kills[npc] = kills.get(npc, 0) + 1
                stars = rng.choices((1, 2, 3), QGROUP[r['rank']])[0]
                # shiny: rolled on each seen unit; spotted shinies are always killed
                ch = SHINY * (SHINY_RANK if r['rank'] in (1, 2, 4) else 1)
                ch *= 1 + (CHAIN_MAX - 1) * min(kills[npc], CHAIN_K) / CHAIN_K
                ch *= sealmul * (RADIANT_SHINY if rng.random() < ASSUME['radiant_uptime'] else 1)
                if rng.random() < 1 - (1 - ch) ** ASSUME['seen_per_kill']:
                    shiny_seen += 1
                    if npc not in shiny_owned:
                        attempt(r, zid, stars, True, day)
                    continue
                offer = npc not in owned or stars > owned[npc] or hunt
                if offer:
                    attempt(r, zid, stars, False, day)
            # seals
            have = sum(1 for r in z['rows'] if r['npc'] in owned)
            if have == len(z['rows']) and zid not in sealed:
                sealed.add(zid)
                if focus_zone:
                    return dict(seal_day=day, hours=hours)
        if reserve >= 50 and reserve_full_day is None:
            reserve_full_day = day
        for k in (1, 10, 25):
            if len(shiny_owned) >= k and ('shiny%d' % k) not in milestones:
                milestones['shiny%d' % k] = day
        if day in (7, 30, 90, 180, 365, 730):
            dup_curve.append((day, len(owned), caps, round(dups / caps, 2) if caps else 0, len(sealed)))
        if len(owned) >= 500 and 'shiny25' in milestones and day > 730:
            break
    return dict(milestones=milestones, dup_curve=dup_curve, reserve_full_day=reserve_full_day,
                species=len(owned), shinies=len(shiny_owned), sealed=len(sealed), caps=caps, dups=dups,
                shiny_seen=shiny_seen, hours=hours)


def med(vals):
    vals = [v for v in vals if v is not None]
    return round(statistics.median(vals)) if vals else 'never'


if __name__ == '__main__':
    for kv in sys.argv[1:]:
        k, v = kv.split('='); ASSUME[k] = type(ASSUME[k])(float(v)) if not isinstance(ASSUME[k], str) else v
    print('ASSUME', ASSUME)
    seeds = range(1, 9)
    for label, mpd, hunt in (('casual 30min', 30, False), ('heavy 3h', 180, False), ('heavy 3h hunt-on', 180, True)):
        rs = [run(mpd, s, hunt) for s in seeds]
        keys = [10, 50, 100, 250, 500, 'shiny1', 'shiny10', 'shiny25']
        print('\n==', label)
        print(' days to:', {k: med([r['milestones'].get(k) for r in rs]) for k in keys})
        print(' reached-share:', {k: sum(1 for r in rs if k in r['milestones']) / len(rs) for k in keys})
        print(' reserve>=50 dups (no release) day:', med([r['reserve_full_day'] for r in rs]))
        print(' curve (day, species, caps, dupShare, sealed):', rs[0]['dup_curve'])
        print(' end: species', med([r['species'] for r in rs]), 'shinies', med([r['shinies'] for r in rs]),
              'sealed', med([r['sealed'] for r in rs]), 'hours', med([r['hours'] for r in rs]))
    # one-zone seal at level 60 (Westfall 1436: 83 species for Alliance view incl. rares/elites)
    for label, mpd in (('casual', 30), ('heavy', 180)):
        for zid in ('1436', '1432', '1413'):
            rs = []
            for s in seeds:
                r = run(mpd, s, focus_zone=zid, max_days=1500)
                rs.append(r.get('seal_day'))
            n = len(species_pool()[zid]['rows'])
            print('seal', label, ZONES[zid]['name'], n, 'species -> days', med(rs), 'never-share',
                  sum(1 for x in rs if x is None) / len(rs))
