W$age[i]=96-q;W$tc=paste(W$cell,W$tribe)
pv=function(g){pr=rep(NA,nrow(W));for(y in unique(W$y)){o=W$y!=y;tt=table(g[o],W$key[o])
Q=tt/rowSums(tt);e=as.vector(Q%*%dk(colnames(tt),y));names(e)=rownames(tt);j=W$y==y;pr[j]=e[g[j]]};pr}
W$p1=pv(W$cell);W$p2=pv(W$tc)
ev=function(p,s){k=!is.na(p)&s;round(c(n=sum(k),r2=cor(p[k],W$cnt[k])^2,r2a=cor(p[k],W$any[k])^2),3)}
print(rbind(all1=ev(W$p1,TRUE),all2=ev(W$p2,TRUE),yx1=ev(W$p1,W$lev<3),yx2=ev(W$p2,W$lev<3)))
