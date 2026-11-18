# Real constants: Companion.lua 43-66, Personality.lua 145-146, CompanionEffects.lua 34,113-129,361-368
DECAY = dict(hunger=0.6, energy=0.4, mood=0.3, curiosity=0.5)
FLOOR, SERENE, MAX, START = 15, 50, 100, 80
TICK = 10
P_GAIN, P_DECAY = 1.5, 0.7
OK = 50
def run(minutes, trait=None, mult=None, stage5=False, start=START, kills_pm=2, quest_every=10, sub_every=5):
    mult = mult or {}
    pref = dict(curious="curiosity", glutton="hunger", daring="mood", lazy="energy", teasing="mood", cuddly="mood").get(trait)
    n = {k: float(start) for k in DECAY}
    floor = SERENE if stage5 else FLOOR
    cross = {k: {} for k in DECAY}; fac = []
    def add(k, a):
        if k == pref: a *= P_GAIN
        n[k] = min(MAX, max(FLOOR, n[k] + a))
    steps = int(minutes * 60 / TICK)
    for s in range(1, steps + 1):
        t = s * TICK
        for k in DECAY:
            f = (P_DECAY if k == pref else 1.0) * mult.get(k, 1.0)
            n[k] = min(MAX, max(floor, n[k] - DECAY[k] * TICK / 60 * f))
        # events (kills spaced 60/kills_pm s, >=2s debounce ok)
        kills = int(t * kills_pm / 60) - int((t - TICK) * kills_pm / 60)
        for _ in range(kills): add("mood", 1)
        if t % (quest_every * 60) == 0: add("mood", 12)
        if sub_every and t % (sub_every * 60) == 0: add("curiosity", 4)
        for k in DECAY:
            for thr in (50, 35):
                if n[k] < thr and thr not in cross[k]: cross[k][thr] = t / 60
        ok = sum(1 for k in DECAY if n[k] >= OK)
        if t % 600 == 0: fac.append((t // 60, 0.5 + 0.5 * ok / 4, {k: round(v) for k, v in n.items()}))
    return cross, fac
SCEN = [
  ("base (no trait effect on decay)", {}),
  ("Giant, non-hunger trait (daring), bond>=2", dict(trait="daring", mult=dict(hunger=1.10))),
  ("Giant + Glutton, bond>=2", dict(trait="glutton", mult=dict(hunger=1.15*1.10))),
  ("Giant + Glutton, bond 1 (no minus/size yet)", dict(trait="glutton")),
  ("Lazy, bond>=2 (curiosity x1.10)", dict(trait="lazy", mult=dict(curiosity=1.10))),
  ("Curious, bond>=2 (energy x1.10)", dict(trait="curious", mult=dict(energy=1.10))),
  ("base, last stage (SERENE_FLOOR)", dict(stage5=True)),
  ("Giant+Glutton bond>=2, last stage", dict(trait="glutton", mult=dict(hunger=1.15*1.10), stage5=True)),
  ("base, no new subzone (sub_every=0)", dict(sub_every=0)),
]
for name, kw in SCEN:
    for m in (60, 120, 180):
        c, f = run(m, **kw)
        if m == 180 or name.startswith("base (no"):
            print(f"== {name} | {m} min")
            print("  crossings (min):", {k: v for k, v in c.items() if v})
            print("  factor/10min:", " ".join(f"{t}:{x:.3f}" for t, x, _ in f))
            print("  end needs:", f[-1][2])
