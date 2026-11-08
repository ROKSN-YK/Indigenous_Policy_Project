saveRDS(R2,'Z:/meta/val_R2.rds');F$fy=CS$care_station_first_year[match(F$key,CS$key)]
F$et=pmin(pmax(F$y-1-F$fy,-4),4);K=F[F$lev<3&!is.na(F$et),];K$e=relevel(factor(K$et),'-1')
es=function(v)cre(as.formula(paste(v,'~e+factor(key)+factor(y)')),K,K$key,'^e')
ES=cbind(es('emp'),es('hw'));print(ES);saveRDS(ES,'Z:/meta/es.rds');table(K$et)
