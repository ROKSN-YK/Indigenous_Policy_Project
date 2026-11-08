saveRDS(WR2,'Z:/meta/wcb2.rds');H0=F[F$lev<3,];H0$one=1
A0=aggregate(cbind(emp,hw,one)~key+y,H0,sum);A0$G=CS$care_station_first_year[match(A0$key,CS$key)]+1
YS=sort(unique(A0$y));mm=function(A,s,yy,v){x=A[s&A$y==yy,];sum(x[[v]])/sum(x$one)}
att=function(A,v){r=NULL;for(g in sort(unique(A$G[A$G<=102&A$G>min(YS)]))){b=max(YS[YS<g])
for(t in YS[YS!=b]){tr=A$G==g;co=A$G>max(t,b);if(!any(co&A$y==t)|!any(co&A$y==b)|!any(tr&A$y==t)|!any(tr&A$y==b))next
r=rbind(r,c(g,t,t-g,(mm(A,tr,t,v)-mm(A,tr,b,v))-(mm(A,co,t,v)-mm(A,co,b,v)),sum(A$one[tr&A$y==t])))}};r}
ag=function(r){e=r[,3];a=r[,4];w=r[,5];f=function(s)sum(a[s]*w[s])/sum(w[s])
c(pf=f(e<=-5),pn=f(e>=-4&e<0),p01=f(e>=0&e<=1),p23=f(e>=2&e<=3),p4=f(e>=4),post=f(e>=0))}
r0=att(A0,'emp');print(dim(r0));print(table(A0$G[!duplicated(A0$key)]));print(round(ag(r0),4))
ks=unique(A0$key);bs=function(v,B=199){o=replicate(B,{s=sample(ks,replace=TRUE)
Ab=do.call(rbind,lapply(seq_along(s),function(i){z=A0[A0$key==s[i],];z$key=paste(z$key,i);z}));ag(att(Ab,v))})
rbind(est=ag(att(A0,v)),se=apply(o,1,sd,na.rm=TRUE))}
set.seed(1108);CSR=rbind(emp=bs('emp'),hw=bs('hw'));print(round(CSR,4));saveRDS(CSR,'Z:/meta/cs_90_102.rds')
