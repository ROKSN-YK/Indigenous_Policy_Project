E=data.frame(city=rep(K,each=10),level=rep(V,each=10),y=rep(103:112,39),dose=X/10)
h=function(x){y=yy(x);d=rd(x,Inf)
s=as.numeric(if(y==110)d$b1 else d$b1_1)
w=as.numeric(if(y==105)d$weight else d$w1)
if(y==105){e=s%in%7:10;u=s==11;hw=s==2}else{e=s%in%1:4;u=s==5;hw=s==8}
data.frame(y=y,city=as.numeric(d$city),level=as.numeric(d$level),fem=as.numeric(d$a2)==2,age=as.numeric(d$a3_4),emp=e,lf=e|u,hw=hw,w=w)}
D=do.call(rbind,lapply(P3,h));n0=nrow(D);D=merge(D,E);D$cell=paste(D$city,D$level)
c(n0,nrow(D),length(unique(D$cell)),sum(is.na(D$age)),sum(is.na(D$w)))
round(t(sapply(split(D,D$y),function(z)c(n=nrow(z),age=mean(z$age,na.rm=T),emp=weighted.mean(z$emp,z$w),hw=weighted.mean(z$hw,z$w)))),3)
