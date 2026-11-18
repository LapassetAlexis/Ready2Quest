# (c) bond pacing
TH=[10,40,100,250]
def days(rate): 
    import math; return [math.ceil(t/rate) for t in TH]
for label,rate in [('cap 10',10),('Câlin 11',11),('casual realistic 6 (route2,treat1,pet1,quest1,cap1)',6),('casual 4 days/wk *6',6*4/7),('heavy 10',10)]:
    print(f"{label:55s} days to L2..L5 {days(rate)}")
# (d) economy
place_costs=[40+20*i for i in range(10)]; print("places total",sum(place_costs))
def income(kind):
    if kind=='casual':
        base=30; new_species=4; ms=1  # milestones/day
        study=new_species*2 + new_species*0.3*2  # captured + some other tasks
        curieux=ms*1 # +1..+2 per milestone (lvl1..5) -> extra
        orders=3*16/7*0.5
    else:
        base=260; new_species=15; ms=3
        study=new_species*2+new_species*1.5*2
        curieux=ms*2
        orders=3*16/7
    return base+study+curieux+orders
for k in ('casual','heavy'):
    inc=income(k); 
    # sinks: places 1300 once; weekly arrivage ~180; nicknames 15
    d_places=1300/inc
    print(f"{k}: ~{inc:.0f}/day, places done in {d_places:.1f} d, weekly surplus after places {inc*7-180:.0f}; sifflets/day affordable {inc/35:.1f}")
# retro windfall for study tasks
for sp in (100,300,600):
    print(f"veteran {sp} species retro: captured {sp*2}, + 3* (say 30%) {int(sp*.3*2)}, total ~{sp*2+int(sp*.3*2)}")
