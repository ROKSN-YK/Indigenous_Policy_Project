cr=function(v,dd){dd=dd[!is.na(dd$w)&!is.na(dd[[v]]),]
m=lm(as.formula(paste(v,'~dose+factor(cell)+factor(y)')),dd,weights=w)
X=model.matrix(m)*sqrt(dd$w);e=resid(m)*sqrt(dd$w);B=solve(crossprod(X))
S=crossprod(rowsum(X*e,dd$cell));G=length(unique(dd$cell));Vc=B%*%S%*%B*G/(G-1)
c(b=unname(coef(m)[2]),se=sqrt(Vc[2,2]),ybar=weighted.mean(dd[[v]],dd$w),n=nrow(dd),G=G)}
a=D$age;f=D$fem;S=list(F=f&a>=25&a<=64,M=!f&a>=25&a<=64,F_yx=f&a>=25&a<=64&D$level<3,F45=f&a>=45&a<=64,P=a>=15&a<=24)
R=do.call(rbind,lapply(names(S),function(s)do.call(rbind,lapply(c('emp','lf','hw'),function(v)data.frame(s=s,v=v,t(round(cr(v,D[S[[s]]%in%TRUE,]),4)))))))
print(R);saveRDS(R,'Z:/meta/cell_R1.rds')
