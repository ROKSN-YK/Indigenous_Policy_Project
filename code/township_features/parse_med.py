import pandas as pd,glob,re,os,sys,warnings
warnings.filterwarnings('ignore')
sys.path.insert(0,'/mnt/user-data/uploads/Indigenous_Policy_Project/code/township_features')
from harmonize import cur
pop=pd.read_csv('/mnt/user-data/uploads/Indigenous_Policy_Project/data/processed_data/05_reference/township_features/by_source/population_096_114.csv')
ref=pop[pop.year_roc==114][['town_code_moi','county_std','town_std','in_station_list_122']].drop_duplicates()
key={(r.county_std,r.town_std):r.town_code_moi for r in ref.itertuples()}
def norm(s): return str(s).replace('台','臺').replace(' ','').replace('　','').strip()
def rows_of(df):
    out=[]
    for r in df.itertuples(index=False):
        n=norm(r[0])
        if len(n)>=5 and n[:3].endswith(('縣','市')) and n[3:]!='' :
            try: float(str(r[1]).replace(',',''))
            except: continue
            out.append([n[:3],n[3:]]+list(r[1:]))
    return out
def hdr_idx(df,names):
    # find column index by header text in first 10 rows
    idx={}
    for i in range(min(10,len(df))):
        for j,c in enumerate(df.iloc[i].tolist()):
            t=norm(c)
            for nm in names:
                if nm not in idx and t==nm: idx[nm]=j
    return idx
recs=[]
def handle(df,kind,year):
    rr=rows_of(df)
    if kind=='fac':
        for r in rr: recs.append(dict(year_roc=year,county=r[0],town=r[1],n_facility=r[2],n_hospital=r[3],n_clinic=r[4],beds_total=r[5]))
    else:
        ix=hdr_idx(df,['西醫師','中醫師','牙醫師','護理師','護士','合計'])
        for r0 in df.itertuples(index=False):
            n=norm(r0[0])
            if not(len(n)>=5 and n[:3].endswith(('縣','市'))): continue
            try: float(str(r0[1]).replace(',',''))
            except: continue
            g=lambda k: r0[ix[k]] if k in ix else None
            recs.append(dict(year_roc=year,county=n[:3],town=n[3:],pers_total=r0[1],md_western=g('西醫師'),md_chinese=g('中醫師'),dentist=g('牙醫師'),nurse_rn=g('護理師'),nurse=g('護士')))
# 104 zip
for f in glob.glob('z104/醫療機構及其他醫事機構現況/醫療院所數及各類病床數*/*'):
    if re.search(r'\.(xlsx|xls)$',f,re.I): handle(pd.read_excel(f,header=None,sheet_name=0),'fac',104)
for f in glob.glob('z104/醫療機構及其他醫事機構現況/機構開(執)業人員數按地區別分/*'):
    if re.search(r'\.(xlsx|xls)$',f,re.I): handle(pd.read_excel(f,header=None,sheet_name=0),'pers',104)
for y in [109,110,111,112,113,114]:
    x=pd.read_excel(f'mohw_{y}_township.xlsx',header=None,sheet_name=None)
    for n,df in x.items():
        if n.startswith('5.'): handle(df,'fac',y)
        elif n.startswith('3.'): handle(df,'pers',y)
R=pd.DataFrame(recs)
num=[c for c in R.columns if c not in('year_roc','county','town')]
for c in num: R[c]=pd.to_numeric(R[c].astype(str).str.replace(',','').replace({'-':'0','－':'0','nan':None}),errors='coerce')
R=R.groupby(['year_roc','county','town'],as_index=False).agg({c:'max' for c in num})
def code(r):
    c,t=cur(r.county,r.town,r.year_roc)
    return key.get((c,t))
R['town_code_moi']=R.apply(code,axis=1)
print(R.groupby('year_roc').agg(n=('town','size'),matched=('town_code_moi',lambda s:s.notna().sum())))
print(R[R.town_code_moi.isna()][['year_roc','county','town']].drop_duplicates(['county','town']).head(30).to_string())
R.to_csv('med_raw.csv',index=False)
