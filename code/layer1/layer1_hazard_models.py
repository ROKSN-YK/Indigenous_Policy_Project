import pandas as pd,numpy as np,statsmodels.api as sm,statsmodels.formula.api as smf,warnings
warnings.filterwarnings('ignore')
P=pd.read_csv('L1/panel.csv')
P['mount']=(P.area_type=='山地原住民鄉區').astype(int);P['plain']=(P.area_type=='平地原住民鄉鎮市').astype(int)
P['lpop']=np.log(P.pop_total);P['lind55']=np.log1p(P.indig_55plus);P['linc']=np.log(P.income_mean_k_fill)
P['sh65']=P.share_65plus*100;P['ish']=P.indig_share*100
b104=P[P.year_roc==104].set_index('town_code_moi')
for v in ['md_western_per10k','n_facility_per10k','beds_total_per10k']: P[v+'_104']=P.town_code_moi.map(b104[v])
lagv=['lpop','lind55','linc','sh65','ish','share_55plus']
P=P.sort_values(['town_code_moi','year_roc'])
for v in lagv: P['L_'+v]=P.groupby('town_code_moi')[v].shift(1)
# risk set: not yet adopted at start of year
R=P[(P.first_year.isna())|(P.year_roc<=P.first_year)].copy()
R['event']=((R.year_roc==R.first_year)).astype(int)
R=R[(R.year_roc>=93)&(R.year_roc<=113)]
R['period']=pd.cut(R.year_roc,[92,99,104,108,113],labels=['93-99','100-104','105-108','109-113'])
cl=R.county_std.astype('category').cat.codes
out=[]
def run(name,formula,data):
    d=data.dropna(subset=[c for c in ['L_lpop','L_lind55','L_linc','L_sh65','L_ish'] if c in formula]).copy(); d['period']=d.period.astype(str)
    m=smf.glm(formula,data=d,family=sm.families.Binomial(link=sm.families.links.CLogLog())).fit(cov_type='cluster',cov_kwds={'groups':d.county_std.astype('category').cat.codes})
    print('\n###',name,'N=',int(m.nobs),'events=',int(d.event.sum()),'towns=',d.town_code_moi.nunique())
    t=pd.DataFrame({'coef':m.params,'se':m.bse,'p':m.pvalues,'HR':np.exp(m.params)})
    print(t.round(3).to_string())
    t['model']=name;t['N']=int(m.nobs);t['events']=int(d.event.sum());out.append(t.reset_index().rename(columns={'index':'term'}))
f1='event ~ C(period) + mount + plain + L_ish + L_lind55 + L_lpop + L_sh65 + L_linc'
run('M1 全部鄉鎮 93–113',f1,R)
run('M2 全部鄉鎮 105–113（含104年醫療資源）',f1.replace('C(period)','C(period)')+' + md_western_per10k_104 + beds_total_per10k_104',R[R.year_roc>=105])
run('M3 55原鄉 93–113','event ~ C(period) + mount + L_ish + L_lind55 + L_lpop + L_sh65 + L_linc',R[R.area_type!='非原住民族地區'])
run('M4 非原鄉 93–113','event ~ C(period) + L_ish + L_lind55 + L_lpop + L_sh65 + L_linc',R[R.area_type=='非原住民族地區'])
pd.concat(out).to_csv('L1/hazard_results.csv',index=False,encoding='utf-8-sig')
# descriptive: adopters vs non by baseline 95
B=P[P.year_roc==95].copy();B['adopt_by_104']=(B.first_year<=104).astype(int);B['adopt_ever']=B.first_year.notna().astype(int)
g=B.groupby(['area_type','adopt_ever'])[['pop_total','ish','sh65','indig_55plus','income_mean_k_fill']].median().round(1)
print('\n',g.to_string())
print(B.groupby('area_type').agg(n=('town_code_moi','size'),ever=('adopt_ever','sum'),by104=('adopt_by_104','sum')))
