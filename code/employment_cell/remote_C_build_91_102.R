TP=list(c(38463,32654),c(25746,22855),c(27888,38597),c(22826,39791),c(36093,24503),c(25490,28771),c(24067,36786),c(21329,21335),c(39791,20977),37138,c(25289,38463),c(21345,37027),c(36093,22799),c(38597,32654),c(36948,24735),37045,c(22134,29802))
TG=c(1,1,2,2,2,3,4,5,6,7,7,7,8,9,9,10,11)
tg=function(nm){g=rep(0,length(nm));for(j in seq_along(TP)){h=grepl(u8(TP[[j]]),nm)&g==0;g[h]=TG[j]};g}
SP=list('93'=c('q2','age','q7','q1','county','w3'),'95'=c('vq2','vq3','vq7','vq1','vn13','w1'),'96'=c('q2','q3','q7','q1','town','wp'),'97'=c('a2','a3_age','b7','e44','id_county','x'),'98'=c('a2','age','b1','e1','town','w'),'99'=c('a2','age','b1','e1','countya','x'),'100'=c('a2','age','b1','e1','town','w1'),'102'=c('a2','a3y','b1','a7','town','wt1'))
W=NULL;for(y in names(SP)){v=SP[[y]];x=P2[yy(P2)==as.integer(y)][1];d=rd(x,Inf)
s=as.numeric(d[[v[3]]]);em=if(y=='93')1:5 else 1:4;un=if(y=='93')6 else 5;hw=c('93'=10,'95'=9,'96'=9)[y];if(is.na(hw))hw=8
tl=attr(d[[v[4]]],'labels');tb=tg(names(tl))[match(as.numeric(d[[v[4]]]),tl)]
ll=attr(d[[v[5]]],'labels');lab=names(ll)[match(as.numeric(d[[v[5]]]),ll)];ag=as.numeric(d[[v[2]]]);if(y=='102')ag=ifelse(ag<200,102-ag,2013-ag)
wt=if(v[6]%in%names(d))as.numeric(d[[v[6]]]) else NA
W=rbind(W,data.frame(y=as.integer(y),fem=as.numeric(d[[v[1]]])==2,age=ag,emp=s%in%em,lf=s%in%c(em,un),hw=s==hw,tribe=tb,lab=lab,wt=wt))}
W$key=sk(W$lab);W$lev=ifelse(grepl(MT,W$lab),1,ifelse(grepl(PL,W$lab),2,3));W$cell=paste(substr(W$key,1,3),W$lev);CS$y1=CS$survey_roc_year+1
dk=function(k,y){m=match(paste(k,y),paste(CS$key,CS$y1));ifelse(is.na(m),0,CS$care_station_count[m])}
W$cnt=dk(W$key,W$y);W$any=W$cnt>0
print(t(sapply(split(W,W$y),function(z)c(n=nrow(z),na_lab=sum(is.na(z$lab)),tr0=mean(z$tribe==0),age=mean(z$age,na.rm=T),emp=mean(z$emp),hw=mean(z$hw),any=mean(z$any),towns=length(unique(z$key))))))
