import csv,re
from collections import defaultdict
exec(open('harmonize.py').read())
pop=list(csv.DictReader(open('township_population_age_096_114.csv',encoding='utf-8-sig')))
code={(x['county_std'],x['town_std']):x['town_code_moi'] for x in pop if x['year_roc']=='114'}
st={(x['station_county'].replace('台','臺'),x['station_township'].replace('台','臺')) for x in csv.DictReader(open('/mnt/user-data/uploads/Indigenous_Policy_Project/data/processed_data/05_reference/care_station_town_year_panel_long.csv',encoding='utf-8-sig'))}
def harm(rows,cc,tc,vals,out,extra=()):
    agg=defaultdict(lambda: defaultdict(float)); raw=defaultdict(set); bad=[]
    for x in rows:
        y=int(x['year_roc']); k=cur(x[cc],x[tc],y)
        if k not in code: bad.append((y,x[cc],x[tc])); continue
        for v in vals:
            if x[v]!='': agg[(y,)+k][v]+=float(x[v])
        raw[(y,)+k].add(x[cc]+x[tc])
    with open(out,'w',newline='',encoding='utf-8-sig') as f:
        w=csv.writer(f); w.writerow(['town_code_moi','county_std','town_std','year_roc','in_station_list_122']+vals+['raw_names'])
        for (y,c,t),d in sorted(agg.items(),key=lambda z:(code[z[0][1:]],z[0][0])):
            w.writerow([code[(c,t)],c,t,y,int((c,t) in st)]+[('%g'%d[v]) if v in d else '' for v in vals]+['|'.join(sorted(raw[(y,c,t)]))])
    return bad
print('pop bad',harm(pop,'county_std','town_std',['pop_total','pop_male','pop_0_14','pop_55plus','pop_65plus'],'H_population_096_114.csv'))
ind=list(csv.DictReader(open('township_indig_pop_092_114.csv',encoding='utf-8-sig')))
print('indig bad',harm(ind,'county_raw','town_raw',['indig_total','indig_0_14','indig_55plus','indig_65plus','indig_plains','indig_mountain'],'H_indigenous_092_114.csv'))
inc=[x for x in csv.DictReader(open('township_income_tax_101_112.csv',encoding='utf-8-sig')) if x['town_std']!='其他']
print('inc bad',harm(inc,'county_std','town_std',['tax_units','income_total_k','income_mean_k','income_median_k','income_q1_k','income_q3_k','income_sd_k','income_cv'],'H_income_tax_101_112.csv'))
