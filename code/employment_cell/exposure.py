import pandas as pd,numpy as np
p=pd.read_csv('L1/panel.csv')
cc={'新北市':1,'臺北市':2,'臺中市':3,'臺南市':4,'高雄市':5,'宜蘭縣':6,'桃園市':7,'新竹縣':8,'苗栗縣':9,'彰化縣':10,'南投縣':11,'雲林縣':12,'嘉義縣':13,'屏東縣':14,'臺東縣':15,'花蓮縣':16,'澎湖縣':17,'基隆市':18,'新竹市':19,'嘉義市':20,'連江縣':21,'金門縣':22}
lv={'山地原住民鄉區':1,'平地原住民鄉鎮市':2,'非原住民族地區':3}
p['city']=p.county_std.map(cc);p['level']=p.area_type.map(lv)
p=p.sort_values(['town_code_moi','year_roc'])
p['st_lag']=p.groupby('town_code_moi').stations.shift(1).fillna(0)
p['w']=p.indig_55plus.fillna(p.indig_total).fillna(0)
p['any']=(p.st_lag>0).astype(int)
g=p[(p.year_roc>=98)&(p.year_roc<=112)].groupby(['city','level','year_roc'])
E=g.apply(lambda d: pd.Series({'E_any':np.average(d['any'],weights=d.w) if d.w.sum()>0 else 0,
   'E_dose':1000*d.st_lag.sum()/max(d.w.sum(),1),'n_town':len(d),'w':d.w.sum()})).reset_index()
E.to_csv('cell/cell_exposure_98_112.csv',index=False)
# within-cell variation 103-112
e=E[E.year_roc>=103]
v=e.groupby(['city','level']).E_any.agg(['min','max','std']);v['range']=v['max']-v['min']
print(v.round(2).to_string())
print('cells',len(v))
