import json,statistics,collections
zones=json.load(open('zones.json'))
tot=collections.Counter()
for zid,z in zones.items():
    rows=z['rows']
    lv=sorted(r['lo'] for r in rows if 0<r['lo']<100)
    med=statistics.median(lv) if lv else 0
    out=[r for r in rows if r['hi']>=med+20 or r['hi']>=9999 or r['lo']<0]
    fa=sum(1 for r in rows if r['f']=='A'); fh=sum(1 for r in rows if r['f']=='H')
    tot['out']+=len(out); tot['fA']+=fa; tot['fH']+=fh
    tot['9999']+=sum(1 for r in rows if r['hi']>=9999 or r['lo']<0)
    if zid in ('1411','1429','1426','1412'): print(z['name'],'median',med,'out',len(out),'friendlyA',fa,'friendlyH',fh, [ (r['npc'],r['lo'],r['hi'],r['rank']) for r in out][:8])
print(dict(tot))
