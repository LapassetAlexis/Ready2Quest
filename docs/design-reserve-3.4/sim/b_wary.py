import random
QMIX=[(1,.65),(2,.28),(3,.07)];QF={1:1,2:.8,3:.6}
def stars():
    r=random.random();a=0
    for s,p in QMIX:
        a+=p
        if r<a: return s
    return 3
def session(kills,nspecies,stepmult,bonus=0.0,base=.5,floor=.4,step=.15):
    n=[0]*nspecies;streak=0;caps=0
    for i in range(kills):
        sp=i%nspecies
        w=max(floor,1-step*stepmult*n[sp])
        p=min(.95,base*QF[stars()]*w*(1+bonus))
        p=min(.95,p+.05*min(5,streak))
        if random.random()<p: caps+=1;n[sp]+=1;streak=0
        else: streak+=1
    return caps
random.seed(1);R=400
mods={'tiny .6 (elite-5%)':.6,'small .85':.85,'normal 1':1,'large 1.15':1.15,'giant 1.4':1.4,
      'Taquin5+tiny (0.3+0.4 additive=.3)':.3,'Taquin5*tiny mult .42':.42,'Tem +20% + giant +40% =1.6':1.6}
for ns in (1,3,10):
    print(f"\n120 kills/h, 2h=240 kills, species rotated={ns}")
    for name,m in mods.items():
        c=sum(session(240,ns,m) for _ in range(R))/R
        print(f"  {name:38s} caps/2h={c:6.1f}")
