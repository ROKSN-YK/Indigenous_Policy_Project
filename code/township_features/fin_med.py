import pandas as pd,sys
R=pd.read_csv('med_raw.csv');R=R[~R.town.str.contains('醫療|人員')].copy()
pop=pd.read_csv('/mnt/user-data/uploads/Indigenous_Policy_Project/data/processed_data/05_reference/township_features/by_source/population_096_114.csv')
ref=pop[pop.year_roc==114][['town_code_moi','county_std','town_std','in_station_list_122']].drop_duplicates()
key={(r.county_std,r.town_std):r.town_code_moi for r in ref.itertuples()}
fix={('屏東縣','三地鄉'):'三地門鄉',('金門縣','金寧鎮'):'金寧鄉'}
for i,r in R[R.town_code_moi.isna()].iterrows(): R.loc[i,'town_code_moi']=key[(r.county,fix[(r.county,r.town)])]
R['town_code_moi']=R.town_code_moi.astype(int)
R=R.merge(ref,on='town_code_moi',how='left');R['raw_names']=R.county+R.town
R['nurse_total']=R[['nurse_rn','nurse']].sum(axis=1,min_count=1)
cols=['town_code_moi','county_std','town_std','year_roc','in_station_list_122','n_facility','n_hospital','n_clinic','beds_total','pers_total','md_western','md_chinese','dentist','nurse_total','raw_names']
R=R[cols].sort_values(['town_code_moi','year_roc'])
print(R.groupby('year_roc').size().to_dict(),R.isna().sum()[R.isna().sum()>0].to_dict())
print(R.groupby('year_roc')[['n_facility','n_hospital','n_clinic','beds_total','pers_total','md_western','nurse_total']].sum().astype(int))
R.to_csv('medical_resources_104_109_114.csv',index=False,encoding='utf-8-sig')
