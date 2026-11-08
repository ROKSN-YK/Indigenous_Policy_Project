cz=function(g){s=W$lev<3;tt=table(g[s],W$key[s]);Q=tt/rowSums(tt);n=rowSums(tt);round(c(maxsh=sum(apply(Q,1,max)*n)/sum(n),neff=sum(n/rowSums(Q^2))/sum(n)),3)}
st=function(g){s=W$lev<3;a=table(g[s&W$y<=96],W$key[s&W$y<=96]);b=table(g[s&W$y>=97],W$key[s&W$y>=97])
r=intersect(rownames(a),rownames(b));k=intersect(colnames(a),colnames(b));A2=a[r,k]/rowSums(a[r,k]);B2=b[r,k]/rowSums(b[r,k]);round(cor(as.vector(A2),as.vector(B2),use='c'),3)}
print(rbind(cell=c(cz(W$cell),stab=st(W$cell)),cxt=c(cz(W$tc),stab=st(W$tc))))
