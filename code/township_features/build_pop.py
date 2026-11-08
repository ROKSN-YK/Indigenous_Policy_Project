import xlrd, csv, re, sys
src=sys.argv[1]; out=sys.argv[2]
b=xlrd.open_workbook(src)
COUNTIES={'臺北縣','宜蘭縣','桃園縣','新竹縣','苗栗縣','臺中縣','彰化縣','南投縣','雲林縣','嘉義縣','臺南縣','高雄縣','屏東縣','臺東縣','花蓮縣','澎湖縣','基隆市','新竹市','臺中市','嘉義市','臺南市','臺北市','高雄市','金門縣','連江縣','新北市','桃園市'}
SKIP={'總計','臺灣地區','臺灣省','福建省','臺閩地區'}
def norm(s): return re.sub(r'[\s　]','',str(s)).replace('台','臺')
rows=[]
for sh in b.sheets():
    y=int(sh.name)
    h3=[norm(c.value) for c in sh.row(3)]; h4=sh.row(4)
    has_code = '區域代碼' in h3
    ia = 2 if has_code else 1
    itot = h3.index('總計')
    agecol={}
    for j,c in enumerate(h4):
        v=c.value
        if j>itot and v!='' :
            try: agecol[int(float(v))]=j
            except: pass
    # 100+ column = last column
    j100=sh.ncols-1
    cur=None
    for r in range(5,sh.nrows):
        sex=norm(sh.cell_value(r,0)); name=norm(sh.cell_value(r,ia))
        if sex not in ('男','女') or not name: continue
        code = str(int(float(sh.cell_value(r,1)))) if has_code and sh.cell_value(r,1)!='' else ''
        if name in SKIP: continue
        if name in COUNTIES and (not has_code or code.endswith('000')) and not (name=='桃園市' and y<103):
            # county row; with codes, county codes like 65000000 / 10002000? treat by name membership and code pattern
            cur=name; continue
        def v(j):
            x=sh.cell_value(r,j); return float(x) if x!='' else 0.0
        tot=v(itot)
        ages={a:v(j) for a,j in agecol.items()}
        a100=v(j100) if j100 not in agecol.values() else 0
        p65=sum(x for a,x in ages.items() if a>=65)+a100
        p55=sum(x for a,x in ages.items() if a>=55)+a100
        p014=sum(x for a,x in ages.items() if a<=14)
        rows.append([y,cur,name,code,sex,tot,p014,p55,p65])
# aggregate sexes
agg={}
for y,c,t,code,sex,tot,p014,p55,p65 in rows:
    k=(y,c,t); a=agg.setdefault(k,[code,0,0,0,0,0])
    a[0]=a[0] or code; a[1]+=tot; a[2]+=p014; a[3]+=p55; a[4]+=p65
    if sex=='男': a[5]+=tot
with open(out,'w',newline='',encoding='utf-8-sig') as f:
    w=csv.writer(f); w.writerow(['year_roc','year_ad','county_std','town_std','town_code_moi','pop_total','pop_male','pop_0_14','pop_55plus','pop_65plus','share_0_14','share_55plus','share_65plus','aging_index_65_per_0_14'])
    for (y,c,t),(code,tot,p014,p55,p65,m) in sorted(agg.items()):
        w.writerow([y,y+1911,c,t,code,int(tot),int(m),int(p014),int(p55),int(p65),round(p014/tot,4) if tot else '',round(p55/tot,4) if tot else '',round(p65/tot,4) if tot else '',round(p65/p014*100,1) if p014 else ''])
print(len(agg))
from collections import Counter
print(sorted(Counter(k[0] for k in agg).items()))
