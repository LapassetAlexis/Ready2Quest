"""Uptime of the 3 proposed states (Repu R, Repose P, Eveille E), 1-min steps.
Triggers are Poisson rates per minute (assumptions in SCEN), plus scheduled events.
Reposé requires >=2 consecutive min resting (IsResting or camp)."""
import random, statistics as st
DUR=45
def poisson(rate): return random.random() < rate
SCEN = {
 # name: length, start events, per-min rates, resting visits (rate, stay minutes), wish
 "30min lvl (login in inn)": dict(T=30, start_rest=3, startR=True, R=1/8, E=1/5+1/20+1/30, visit=1/20, stay=(1,4)),
 "2h lvl caster":            dict(T=120, start_rest=3, startR=True, R=1/4, E=1/5+1/20+1/30, visit=1/20, stay=(1,4)),
 "2h lvl melee (eats rarely)":dict(T=120, start_rest=0, startR=False, R=1/25, E=1/5+1/20+1/30, visit=1/25, stay=(1,4)),
 "3h farm 60 caster":        dict(T=180, start_rest=0, startR=False, R=1/4, E=1/90, visit=1/60, stay=(0,3)),
 "3h farm 60 melee/warlock": dict(T=180, start_rest=0, startR=False, R=1/30, E=1/90, visit=1/60, stay=(0,3)),
 "3h farm 60 hearth each 45m":dict(T=180, start_rest=3, startR=True, R=1/30, E=1/90, visit=1/45, stay=(2,4)),
 "dungeon 75min (from city)":dict(T=75, start_rest=3, startR=True, R=1/4, E=1.0, visit=0, stay=(0,0)),
}
def run(s, dur=DUR, wish_gap=20):
    left={'R':0,'P':0,'E':0}; hist=[0,0,0,0]; up={'R':0,'P':0,'E':0}
    rest=0; resting_until=-1; wishes=0; fulfilled=0; wish=None; next_wish=2
    # start: if start_rest, player is in inn for start_rest minutes
    if s['start_rest']: resting_until=s['start_rest']
    for t in range(s['T']):
        gained=set()
        if t<resting_until: rest+=1
        else:
            rest=0
            if s['visit'] and poisson(s['visit']):
                resting_until=t+random.randint(*s['stay'])
        if rest>=2: gained.add('P')
        if t==s['start_rest'] and s['startR']: gained.add('R')  # departure with food
        if poisson(s['R']): gained.add('R')
        if poisson(s['E']): gained.add('E')
        if t==0 and 'dungeon' in str(s): gained.add('E')
        for k in gained: left[k]=dur
        if wish and wish in gained: fulfilled+=1; wish=None; next_wish=t+wish_gap
        missing=[k for k in left if left[k]<=0]
        if wish is None and t>=next_wish and missing:
            wish=random.choice(missing); wishes+=1
        n=sum(1 for k in left if left[k]>0); hist[n]+=1
        for k in left:
            if left[k]>0: up[k]+=1; left[k]-=1
    T=s['T']; return [h/T for h in hist], {k:v/T for k,v in up.items()}, wishes, fulfilled
def summarize(dur=DUR, N=3000, show=True):
    out={}
    for name,s in SCEN.items():
        H=[0]*4; U={'R':0,'P':0,'E':0}; W=F=0
        for _ in range(N):
            h,u,w,f=run(s,dur)
            H=[a+b for a,b in zip(H,h)]
            for k in U: U[k]+=u[k]
            W+=w; F+=f
        H=[x/N for x in H]; U={k:v/N for k,v in U.items()}
        avg_strength=sum(p*m for p,m in zip(H,[1.0,1.05,1.10,1.20]))
        out[name]=(H,U,avg_strength,W/N,F/N)
        if show:
            print(f"{name:30s} 0/1/2/3 states: "+" ".join(f"{x*100:5.1f}" for x in H)+
              f" | up R {U['R']*100:4.0f} P {U['P']*100:4.0f} E {U['E']*100:4.0f} | avg force {avg_strength:.3f} | wishes {W/N:.1f} fulfilled {F/N:.1f}")
    return out
random.seed(1)
print("== duration 45 ==");a=summarize(45)
print("== duration 49.5 (+10%, Zen/Curieux/comfort) =="); b=summarize(50)
print("== duration 40.5 (-10% revers) =="); c=summarize(40)
print("delta uptime-at-3 (+10% / -10%), points:")
for k in a: print(f"  {k:30s} {100*(b[k][0][3]-a[k][0][3]):+5.1f} / {100*(c[k][0][3]-a[k][0][3]):+5.1f}   force {b[k][2]-a[k][2]:+.3f}/{c[k][2]-a[k][2]:+.3f}")
