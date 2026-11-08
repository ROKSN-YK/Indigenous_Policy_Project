import pandas as pd,numpy as np,sys,glob
sys.path.insert(0,'/mnt/user-data/uploads/Indigenous_Policy_Project/code/township_features')
from harmonize import cur
M=pd.read_csv('master/township_year_master_090_114.csv')
f=glob.glob('/root/.claude/projects/-home-claude/f24ed35e-238b-5699-a7c4-deaf6a3202a4/tool-results/project-file-b844605d*.csv')[0]
S=pd.read_csv(f)
S['county']=S['縣市'].str.replace('台','臺');S['town']=S['行政區']
ref=M[M.year_roc==114][['town_code_moi','county_std','town_std']]
key={(r.county_std,r.town_std):r.town_code_moi for r in ref.itertuples()}
S['code']=[key.get((c,t)) or key.get(cur(c,t,114)) for c,t in zip(S.county,S.town)]
print('unmatched',S[S.code.isna()][['county','town']].values.tolist())
L=S.melt(id_vars=['code'],value_vars=[f'民國{y}' for y in range(90,115)],var_name='y',value_name='stations')
L['year_roc']=L.y.str.replace('民國','').astype(int);L=L.drop(columns='y').rename(columns={'code':'town_code_moi'})
P=M.merge(L,on=['town_code_moi','year_roc'],how='left');P['stations']=P.stations.fillna(0)
P=P.sort_values(['town_code_moi','year_roc'])
P['ever']=(P.stations>0).astype(int)
first=P[P.ever==1].groupby('town_code_moi').year_roc.min()
P['first_year']=P.town_code_moi.map(first)
print('adopters',first.size,'by first year:',first.value_counts().sort_index().to_dict())
P.to_csv('L1/panel.csv',index=False)
