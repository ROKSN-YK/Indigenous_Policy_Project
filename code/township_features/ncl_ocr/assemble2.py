import json,sys,csv
sys.path.insert(0,'.')
from build_year import ref_for,COUNTIES,AGG
from solver import solve,residuals
OV=json.load(open('overrides.json'))
IDX=[1,2]+list(range(7,27))
FUJIAN={'金門縣','連江縣'}; MUNI={'臺北市','高雄市'}
def run(y):
    B=json.load(open(f'gblocks_{y}.json')); ref=ref_for(y); assert len(B)==len(ref)
    R96=json.load(open('ref96.json'))
    recs=[];cur=None
    for name,b in zip(ref,B):
        v=b['fixed']; status='ok' if b['log']==[] else ('autofixed' if b['log'] else 'UNRESOLVED')
        key=f"{y}|{b['page']}|{b['k']}"
        if key in OV:
            v=[r[:] for r in b['v']]
            for j,c,val in OV[key]: v[j][c]=val
            if residuals(v):
                v2,log,_=solve(v,b['raw'],maxk=2)
                if log is None: status='UNRESOLVED'
                else: v=v2; status='manual+autofix' if log else 'manual'
            else: status='manual'
        level='agg' if name in AGG else ('county' if name in COUNTIES else 'town')
        if level=='county': cur=name
        recs.append({'name':name,'level':level,'county':cur if level=='town' else (name if level=='county' else ''),'v':v,'status':status,'page':b['page'],'blk':b['k'],'nfix':len(b['log']) if b['log'] else 0})
    towns=[r for r in recs if r['level']=='town']
    def sumv(sel):
        s=[[0]*27 for _ in range(3)]
        for r in sel:
            for j in range(3):
                for c in range(27): s[j][c]+=r['v'][j][c]
        return s
    checks=[]
    for r in recs:
        if r['level']=='town': continue
        if r['level']=='county': sel=[t for t in towns if t['county']==r['name']]
        elif r['name']=='總計': sel=towns
        elif r['name']=='臺灣地區': sel=[t for t in towns if t['county'] not in FUJIAN]
        elif r['name']=='臺灣省': sel=[t for t in towns if t['county'] not in FUJIAN|MUNI]
        elif r['name']=='福建省': sel=[t for t in towns if t['county'] in FUJIAN]
        s=sumv(sel)
        diff=sum(abs(s[j][c]-r['v'][j][c]) for j in range(3) for c in range(27))
        if r['status']=='UNRESOLVED': r['v']=s; r['status']='derived_from_towns'
        elif diff: checks.append((r['name'],diff)); r['v']=s; r['status']='derived_from_towns'
        r['children_diff']=diff
    rows=[]
    for pos,r in enumerate(recs):
        T=r['v'][0]; g=[T[c] for c in IDX]
        rows.append(dict(year_roc=y,level=r['level'],county_raw=r['county'] if r['level']=='town' else '',name_raw=r['name'],pop_total=T[0],pop_male=r['v'][1][0],pop_female=r['v'][2][0],
            pop_0_14=sum(g[0:4]),pop_55plus=sum(g[12:]),pop_65plus=sum(g[14:]),
            **{f'age_{lab}':T[c] for lab,c in zip(['0','1_4','5_9','10_14','15_19','20_24','25_29','30_34','35_39','40_44','45_49','50_54','55_59','60_64','65_69','70_74','75_79','80_84','85_89','90_94','95_99','100plus'],IDX)},
            ocr_status=r['status'],n_autofixed_cells=r['nfix'],aggregate_vs_towns_absdiff=r.get('children_diff',''),source_page=r['page'].split('/')[-1],block=r['blk']))
    return rows,checks
if __name__=='__main__':
    allr=[]
    for y in [90,91,92,93,94,95]:
        rows,checks=run(y); allr+=rows
        from collections import Counter
        print(y,Counter(r['ocr_status'] for r in rows),'agg mismatches',checks, 'total',[r['pop_total'] for r in rows if r['name_raw']=='總計'])
    w=csv.DictWriter(open('ncl_township_pop_090_095.csv','w',newline='',encoding='utf-8-sig'),fieldnames=list(allr[0].keys())); w.writeheader(); w.writerows(allr)
