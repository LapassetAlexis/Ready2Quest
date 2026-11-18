import re,json,sys,collections
src=open(sys.argv[1],encoding='utf-8').read()
zones={}
for m in re.finditer(r'(?:-- ([^\n]*)\n)?Z\[(\d+)\] = \[\[\n(.*?)\n\]\]',src,re.S):
    name,zid,body=m.group(1),int(m.group(2)),m.group(3)
    rows=[]
    for line in body.split('\n'):
        p=line.split('\t')
        if len(p)>=6:
            rows.append(dict(npc=int(p[0]),lo=int(p[1]),hi=int(p[2]),rank=int(p[3]),f=(p[6] if len(p)>6 and p[6] else None)))
    zones[zid]=dict(name=name,rows=rows)
allnpc=set();rk=collections.Counter()
for z in zones.values():
    for r in z['rows']: allnpc.add(r['npc']); rk[r['rank']]+=1
print('zones',len(zones),'rows',sum(len(z['rows']) for z in zones.values()),'unique npcs',len(allnpc))
print('rank rows (0 normal,1 elite,2 rareelite,3 boss,4 rare):',dict(rk))
uniq={}
for z in zones.values():
    for r in z['rows']: uniq[r['npc']]=r['rank']
print('rank unique:',dict(collections.Counter(uniq.values())))
# per zone, alliance-view (exclude f=='A') and horde
for zid,z in sorted(zones.items(), key=lambda kv:-len(kv[1]['rows'])):
    a=[r for r in z['rows'] if r['f']!='A' and r['rank']!=3]
    lv=[r['lo'] for r in z['rows'] if r['lo']>0]
    print(zid,z['name'],len(z['rows']),'sealA',len(a),'rares',sum(1 for r in a if r['rank'] in (2,4)),'elite',sum(1 for r in a if r['rank']==1),'lvl',min(lv) if lv else '-',max(r['hi'] for r in z['rows']))
json.dump({k:v for k,v in zones.items()},open('zones.json','w'))
