import re,csv,glob,sys
sys.path.insert(0,'.')
import xlrd, pandas as pd
from parse_cip_htm import parse as parse_htm
COUNTIES={'臺北縣','宜蘭縣','桃園縣','新竹縣','苗栗縣','臺中縣','彰化縣','南投縣','雲林縣','嘉義縣','臺南縣','高雄縣','屏東縣','臺東縣','花蓮縣','澎湖縣','基隆市','新竹市','臺中市','嘉義市','臺南市','臺北市','高雄市','金門縣','連江縣','新北市','桃園市'}
SKIP={'總計','臺灣地區','臺灣省','福建省','臺閩地區','全國','金馬地區'}
norm=lambda s:re.sub(r'[\s　]','',str(s)).replace('台','臺').replace('芩雅','苓雅')
def grid(f):
    if f.endswith('.xls'):
        s=xlrd.open_workbook(f).sheets()[0]; return [[s.cell_value(r,c) for c in range(s.ncols)] for r in range(s.nrows)]
    d=pd.read_excel(f,engine='odf',header=None); return d.fillna('').values.tolist()
def num(v):
    try: return float(v)
    except: return 0.0
def parse_sheet(f):
    g=grid(f)
    hdr=g[4]; ages={}
    for j,v in enumerate(hdr):
        try: ages[j]=int(float(v))
        except: pass
    jt=[norm(x) for x in hdr].index('總計')
    # identity blocks
    starts=[(r,norm(g[r][0])) for r in range(len(g)) if norm(g[r][0])]
    out={}
    for bi,(r0,ident) in enumerate(starts):
        r1=starts[bi+1][0] if bi+1<len(starts) else len(g)
        rows=[g[r] for r in range(r0,r1) if norm(g[r][2]) in ('計','男','女')]
        # group into triples by position: find 計 rows; name = nonblank among triple
        i=0; seq=[]
        while i+2<len(rows)+0 and i<len(rows):
            tri=rows[i:i+3]
            sexes=[norm(x[2]) for x in tri]
            name=next((norm(x[1]) for x in tri if norm(x[1])),'')
            k=next(x for x in tri if norm(x[2])=='計')
            tot=num(k[jt]); p55=sum(num(k[j]) for j,a in ages.items() if a>=55); p65=sum(num(k[j]) for j,a in ages.items() if a>=65); p014=sum(num(k[j]) for j,a in ages.items() if a<=14)
            seq.append((name,int(tot),int(p55),int(p65),int(p014))); i+=3
        out[ident]=seq
    return out
def assign(seq,y):
    cur=None; res=[]
    for name,tot,p55,p65,p014 in seq:
        if not name or name in SKIP: continue
        if name in COUNTIES and not (name=='桃園市' and cur in ('桃園縣','桃園市')): cur=name; continue
        res.append((cur,name,tot,p55,p65,p014))
    return res
rows=[]
for f in sorted(glob.glob('cip/cip_township_indig_*')):
    m=re.search(r'_(\d+)12\.(xls|ods|htm)$',f)
    if not m or 'areatype' in f: continue
    y=int(m.group(1)); ext=m.group(2)
    if ext=='htm':
        seq=[(a,b,c,d,e) for a,b,c,d,e in parse_htm(f)]
        for c,t,tot,p55,p65,p014 in assign(seq,y): rows.append([y,c,t,tot,p55,p65,p014,'','',f.split('/')[-1]])
    else:
        o=parse_sheet(f)
        tk=[k for k in o if '不分' in k][0]
        mt={(c,t):tot for c,t,tot,*_ in assign(o.get([k for k in o if '山地' in k and '不分' not in k][0],[]),y)}
        pl={(c,t):tot for c,t,tot,*_ in assign(o.get([k for k in o if '平地' in k and '不分' not in k][0],[]),y)}
        for c,t,tot,p55,p65,p014 in assign(o[tk],y): rows.append([y,c,t,tot,p55,p65,p014,pl.get((c,t),''),mt.get((c,t),''),f.split('/')[-1]])
w=csv.writer(open('township_indig_pop_092_114.csv','w',newline='',encoding='utf-8-sig'))
w.writerow(['year_roc','county_raw','town_raw','indig_total','indig_55plus','indig_65plus','indig_0_14','indig_plains','indig_mountain','source_file'])
w.writerows(sorted(rows))
from collections import Counter,defaultdict
print(sorted(Counter(r[0] for r in rows).items()))
s=defaultdict(int)
for r in rows: s[r[0]]+=r[3]
print(dict(s))
print([r for r in rows if r[2] in ('仁愛鄉',)][:30:4])
print('nocounty',[r[:3] for r in rows if r[1] is None][:5])
