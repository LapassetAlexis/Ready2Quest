E={'spot':(.05,.25),'capture_humanoid':(.10,.40),'shiny_undead':(.15,.60),'aid_keep':(.08,.30),
 'shiny_chain':(.50,1.50),'capture_named':(.12,.45),'aid_zone':(.25,1.0),'aid_refund':(.20,.75),
 'capture_all(mascot)':(.02,.10),'decay_x':(.10,.40),'treat_zone':(.15,.60),'pet_mood':(.25,1.0),
 'decay_all':(.05,.25),'rest_energy':(.15,.60),'mascot_decay':(.04,.20)}
S=[1,1.5,2,2.5,3,3.5,4.25,5]
print("effect      strength: "+" ".join(f"{s:>5}" for s in S)+"  | strength where x1.0 caps / x1.2 caps")
for k,(b,c) in E.items():
    row=[]
    for s in S:
        v0=min(c,b*s); v1=min(c,b*s*1.2); row.append(f"{(v1-v0):+.2f}" if v1>v0 else "  nil")
    print(f"{k:22s} "+" ".join(f"{r:>5}" for r in row)+f"  | {c/b:.2f} / {c/b/1.2:.2f}")
print("\ncapture chance multiplier (type value + profile<=.20), base 40% chance:")
for s in (1,2,3,3.75):
    for prof in (0,.20):
        v0=min(.45,.12*s)+prof; v1=min(.45,.12*s*1.2)+prof
        print(f" named s{s} prof{prof}: x{1+v0:.3f} -> x{1+v1:.3f}  chance 40% -> {min(.95,.4*(1+v0))*100:.1f}% vs {min(.95,.4*(1+v1))*100:.1f}%")
print("\nshiny undead normal mob, no chain:")
for s in (1,2,3,4.25):
    v0=min(.6,.15*s); v1=min(.6,.15*s*1.2)
    print(f" s{s}: 1/{150/(1+v0):.0f} -> 1/{150/(1+v1):.0f}")
print("shiny_chain only scales kill count toward 50 kills: kills needed for max x3.75:")
for s in (1,2,3):
    v0=min(1.5,.5*s); v1=min(1.5,.5*s*1.2)
    print(f" s{s}: {50/(1+v0):.1f} -> {50/(1+v1):.1f} kills")
# current realistic factor vs new
print("\nfactor today realistic 0.75-1.0 ; new 1.0-1.2 ; relative gain at 0.75->1.2 =",1.2/0.75)
# treats: state-minutes
pantry={'biscuit':3,'infusion':3,'carte':3,'bonbon':3,'festin':2}
sm = 90*9 + 270*2 + 3*30*3
print("\nfull pantry state-minutes:",sm,"-> hours of Rayonnant:",sm/(3*60))
for name,per_day,festins in (("30-min player",3.4,0.5),("3-h player",9.7,1.6)):
    singles=per_day-festins
    smd = festins*270 + singles*90*0.8 + singles*0.2*90   # bonbon ~ 30*3=90
    print(f"{name}: {per_day} treats/day = {smd:.0f} state-min = {smd/180:.1f} h Rayonnant from treats alone")
print("Paillettes: missions 3*3+5=14/day + weekly (15+10)/7=3.6/day; overflow 2/treat -> 3.4..9.7 treats = 6.8..19.4/day")
