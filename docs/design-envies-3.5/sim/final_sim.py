"""Règles finales 3.5 : boisson retirée (Repu = repas seulement), chasse : 15 tuées/capturées
en 10 min, brillante tuée, espèce nouvelle capturée -> Éveillé. Pas de friandise (pire cas)
puis 4 friandises par jour (cas courant)."""
import random, collections
DUR=45
SCEN = {
 # T, repos de départ, repas départ, taux repas/min, taux éveil hors chasse/min, visites repos, séjour, chasse?, tuées/min
 "30 min montée (auberge)":   dict(T=30, start_rest=3, startR=True,  R=1/40, E=1/5+1/20+1/30, visit=1/20, stay=(1,4), hunt=False, kills=1.0),
 "2h montée lanceur":         dict(T=120,start_rest=3, startR=True,  R=1/40, E=1/5+1/20+1/30, visit=1/20, stay=(1,4), hunt=False, kills=1.0),
 "2h montée mêlée":           dict(T=120,start_rest=0, startR=False, R=1/25, E=1/5+1/20+1/30, visit=1/25, stay=(1,4), hunt=False, kills=1.2),
 "3h farm 60 sans chasse":    dict(T=180,start_rest=0, startR=False, R=1/30, E=1/90, visit=1/60, stay=(0,3), hunt=False, kills=2.0),
 "3h chasse 60 (mode chasse)":dict(T=180,start_rest=0, startR=False, R=1/30, E=1/90, visit=1/60, stay=(0,3), hunt=True,  kills=2.0),
 "3h chasse 60 lente":        dict(T=180,start_rest=0, startR=False, R=1/30, E=1/90, visit=1/60, stay=(0,3), hunt=True,  kills=1.0),
 "donjon 75 min (de la ville)":dict(T=75,start_rest=3, startR=True,  R=1/40, E=1.0,  visit=0,    stay=(0,0), hunt=False, kills=2.0),
}
def run(s, dur, treats_per_day=0):
    left={'R':0,'P':0,'E':0}; hist=[0,0,0,0]; rest=0; resting_until=s['start_rest'] or -1
    kills=collections.deque(); treat_at=set()
    if treats_per_day: # 4 par jour ~ 1 par 6 h de jeu -> proba par minute
        pass
    for t in range(s['T']):
        g=set()
        if t<resting_until: rest+=1
        else:
            rest=0
            if s['visit'] and random.random()<s['visit']: resting_until=t+random.randint(*s['stay'])
        if rest>=2: g.add('P')
        if t==s['start_rest'] and s['startR']: g.add('R')
        if random.random()<s['R']: g.add('R')
        if random.random()<s['E']: g.add('E')
        if s['hunt']:
            n=sum(1 for _ in range(4) if random.random()<s['kills']/4)
            for _ in range(n): kills.append(t)
            while kills and kills[0]<=t-10: kills.popleft()
            if len(kills)>=15: g.add('E'); kills.clear()
            if random.random()<n*(1/120): g.add('E')   # brillante tuée ou espèce nouvelle
        if treats_per_day and random.random()<treats_per_day/(6*60):
            k=min(left,key=left.get); left[k]=max(left[k],60)
        for k in g: left[k]=max(left[k],dur)
        hist[sum(1 for k in left if left[k]>0)]+=1
        for k in left:
            if left[k]>0: left[k]-=1
    return [h/s['T'] for h in hist]
random.seed(7)
for treats in (0,4):
    print(f"== friandises/jour {treats} : part du temps à 0/1/2/3 états (3 = Rayonnant) ==")
    for name,s in SCEN.items():
        H=[0]*4
        for _ in range(3000): H=[a+b for a,b in zip(H,run(s,DUR,treats))]
        print(f"  {name:30s} "+" ".join(f"{x/30:5.1f}" for x in H))
