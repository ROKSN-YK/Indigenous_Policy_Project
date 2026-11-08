WB=c(-sqrt(1.5),-1,-sqrt(.5),sqrt(.5),1,sqrt(1.5));set.seed(20261108)
wb=function(v,dd,B=999){dd=dd[!is.na(dd$w)&!is.na(dd[[v]]),];sw=sqrt(dd$w);g=dd$cell
yt=resid(lm(as.formula(paste(v,'~factor(cell)+factor(y)')),dd,weights=w))*sw
xt=resid(lm(dose~factor(cell)+factor(y),dd,weights=w))*sw;ug=unique(g);G=length(ug);sxx=sum(xt^2);gi=match(g,ug)
tf=function(u){b=sum(xt*u)/sxx;e=u-b*xt;s=sqrt(sum(rowsum(xt*e,gi)^2)*G/(G-1))/sxx;c(b,b/s)}
t0=tf(yt);ts=replicate(B,tf(yt*sample(WB,G,TRUE)[gi])[2]);round(c(b=t0[1],t=t0[2],p_cr=2*pt(-abs(t0[2]),G-1),p_wcb=mean(abs(ts)>=abs(t0[2])),G=G),4)}
a=D$age;f=D$fem;U=D[f&a>=25&a<=64&!is.na(a),];U2=U[U$level<3,]
WR=rbind(F_emp=wb('emp',U),F_hw=wb('hw',U),Fyx_emp=wb('emp',U2),Fyx_hw=wb('hw',U2));print(WR);saveRDS(WR,'Z:/meta/wcb.rds')
