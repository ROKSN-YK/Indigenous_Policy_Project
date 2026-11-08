import pandas as pd,numpy as np
B='/mnt/user-data/uploads/Indigenous_Policy_Project/data/processed_data/05_reference/township_features/by_source/'
k=['town_code_moi','county_std','town_std','year_roc','in_station_list_122']
p1=pd.read_csv(B+'population_090_095.csv');p2=pd.read_csv(B+'population_096_114.csv')
pop=pd.concat([p1,p2]).drop(columns=['raw_names'])
ind=pd.read_csv(B+'indigenous_092_114.csv').drop(columns=['raw_names'])
inc=pd.read_csv(B+'income_tax_101_112.csv').drop(columns=['raw_names'])
med=pd.read_csv('med/medical_resources_104_109_114.csv').drop(columns=['raw_names'])
area=pd.read_csv(B+'ref_indigenous_areas_55.csv')[['town_code_moi','area_type']]
grid=pop[k].copy()
M=grid.merge(pop.drop(columns=['county_std','town_std','in_station_list_122']),on=['town_code_moi','year_roc'],how='left')
M=M.merge(ind.drop(columns=['county_std','town_std','in_station_list_122']),on=['town_code_moi','year_roc'],how='left')
M=M.merge(inc.drop(columns=['county_std','town_std','in_station_list_122']),on=['town_code_moi','year_roc'],how='left')
M=M.merge(med.drop(columns=['county_std','town_std','in_station_list_122']),on=['town_code_moi','year_roc'],how='left')
M=M.merge(area,on='town_code_moi',how='left');M['area_type']=M.area_type.fillna('非原住民族地區')
# derived
M['share_55plus']=M.pop_55plus/M.pop_total;M['share_65plus']=M.pop_65plus/M.pop_total;M['share_0_14']=M.pop_0_14/M.pop_total
M['aging_index']=M.pop_65plus/M.pop_0_14*100;M['indig_share']=M.indig_total/M.pop_total
M['indig_share_55plus']=M.indig_55plus/M.pop_55plus
# income backcast: 90-100 use 101 values (method B, fixed baseline), flagged
incv=['tax_units','income_total_k','income_mean_k','income_median_k','income_q1_k','income_q3_k','income_sd_k','income_cv']
b101=M[M.year_roc==101].set_index('town_code_moi')[incv]
M['income_imputed']=0
for v in ['income_mean_k','income_median_k','income_q1_k','income_q3_k','income_cv']:
    M[v+'_fill']=M[v]
    m=M.year_roc<101
    M.loc[m,v+'_fill']=M.loc[m,'town_code_moi'].map(b101[v])
M.loc[M.year_roc<101,'income_imputed']=1
# medical per 10k (raw years only) + flag
for v in ['n_facility','beds_total','md_western','pers_total','nurse_total']:
    M[v+'_per10k']=M[v]/M.pop_total*1e4
M['medical_observed']=M.n_facility.notna().astype(int)
M['indig_observed']=M.indig_total.notna().astype(int)
M=M.sort_values(['town_code_moi','year_roc'])
print(M.shape, M.town_code_moi.nunique(), M.year_roc.min(), M.year_roc.max())
print(M.groupby('year_roc')[['pop_total','indig_total','income_mean_k','income_mean_k_fill','n_facility']].count().T.to_string())
assert (M.indig_total.fillna(0)<=M.pop_total).all()
M.to_csv('master/township_year_master_090_114.csv',index=False,encoding='utf-8-sig')
# codebook
cb=[('town_code_moi','鄉鎮代碼（114 年內政部代碼）','鍵值'),('year_roc','民國年（年底）','鍵值'),('in_station_list_122','是否為 122 個文健站鄉鎮','1/0'),('area_type','55 原住民族地區類型','山地／平地／非原住民族地區'),
('pop_total','總人口','90–114；90–95 為《臺閩地區人口統計》OCR'),('pop_male','男性人口',''),('pop_0_14','0–14 歲人口',''),('pop_55plus','55 歲以上人口',''),('pop_65plus','65 歲以上人口',''),
('share_55plus','55+ 比例','pop_55plus/pop_total'),('share_65plus','65+ 比例',''),('share_0_14','0–14 比例',''),('aging_index','老化指數','65+/0–14×100'),
('indig_total','原住民人口','92–114（90–91 無鄉鎮資料，留空）'),('indig_0_14','原住民 0–14 歲',''),('indig_55plus','原住民 55+',''),('indig_65plus','原住民 65+',''),('indig_plains','平地原住民',''),('indig_mountain','山地原住民',''),('indig_share','原住民比例',''),('indig_share_55plus','55+ 人口中原住民比例',''),
('tax_units','綜所稅申報單位數','101–112'),('income_mean_k','綜所稅所得平均數（千元）','101–112 實值'),('income_median_k','中位數（千元）',''),('income_q1_k','第一分位（千元）',''),('income_q3_k','第三分位（千元）',''),('income_sd_k','標準差（千元）',''),('income_cv','變異係數',''),
('income_*_fill','所得補值版','90–100 用 101 年值固定（回測驗證後採用的方法 B）；101–112 等於實值'),('income_imputed','所得是否為補值','1＝90–100 年'),
('n_facility','醫療院所數','104、109–114（衛福部醫事機構服務量縣市與鄉鎮統計表）'),('n_hospital','醫院數',''),('n_clinic','診所數',''),('beds_total','醫療院所病床數',''),('pers_total','執業醫事人員數（機構開執業）',''),('md_western','西醫師數',''),('md_chinese','中醫師數',''),('dentist','牙醫師數',''),('nurse_total','護理師＋護士',''),
('*_per10k','每萬人口醫療資源','以總人口計算'),('medical_observed','該年是否有醫療資料','105–108 與 90–103 無鄉鎮表'),('indig_observed','該年是否有原住民人口','')]
pd.DataFrame(cb,columns=['欄位','說明','年份／備註']).to_csv('master/township_year_master_codebook.csv',index=False,encoding='utf-8-sig')
