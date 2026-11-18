# (a) capture chance + pity Markov: expected tries per catch, success rate per offer (stationary)
RATE={'normal':.5,'elite':.25,'rare':.15}
Q={1:1,2:.8,3:.6}
def eff(base,bonus): return min(.95,base*(1+bonus))
def tries(p):
    # pity: +0.05/miss up to 5, cap .95; expected tries until success
    E=0; surv=1
    for k in range(200):
        pk=min(.95,p+.05*min(5,k)); E+=surv; surv*=1-pk
    return E
profiles={
 'today none':0,
 'today Téméraire':.05,
 'today demon rare3*shiny capture_named .36 + Tem':.41,
 'today demon cap .45 + Tem':.50,
 'new Tem5+Giant (.18)':.18,
 'new demon .36+Tem5+Giant':.54,
 'new demon .45+Tem5+Giant':.63,
 'new demon .45 + Esp5+Giant':.59,
}
for cls in RATE:
  for st in (1,3):
    base=RATE[cls]*Q[st]
    print(f"\n{cls} {st}*  base={base:.3f}")
    for n,b in profiles.items():
        p=eff(base,b); t=tries(p)
        print(f"  {n:45s} p={p:.3f} tries={t:.2f} catch/offer={1/t:.3f}")
# relative vs absolute ambiguity of '+20%'
print("\n+20% relative on elite .25 ->",.25*1.2," absolute ->",.45)
