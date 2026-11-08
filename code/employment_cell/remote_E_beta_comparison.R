cre=function(f,dd,cl,pat){m=lm(f,dd);X=model.matrix(m);e=resid(m);B=solve(crossprod(X))
S=crossprod(rowsum(X*e,cl));G=length(unique(cl));V=B%*%S%*%B*G/(G-1);j=grep(pat,colnames(X))
data.frame(term=colnames(X)[j],b=round(coef(m)[j],4),se=round(sqrt(diag(V))[j],4),n=nrow(dd),G=G)}
F=W[W$fem&W$age>=25&W$age<=64&!is.na(W$p2)&!is.na(W$p1),]
fm=function(v,x,fe)as.formula(paste(v,'~',x,'+factor(',fe,')+factor(y)'))
R2=NULL;for(s in c('all','yx')){H=if(s=='all')F else F[F$lev<3,];for(v in c('emp','lf','hw')){
R2=rbind(R2,cbind(s,v,'exact',cre(fm(v,'cnt','key'),H,H$key,'^cnt')),cbind(s,v,'cell',cre(fm(v,'p1','cell'),H,H$cell,'^p1')),cbind(s,v,'cxt',cre(fm(v,'p2','cell'),H,H$cell,'^p2')))}}
print(R2,row.names=F);saveRDS(R2,'Z:/meta/val_R2.rds')
