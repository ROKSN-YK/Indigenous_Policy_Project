W=rbind(W[,names(A)],A,B,C);W$tribe[is.na(W$tribe)]=0;W$key=sk(W$lab)
W$lev=ifelse(grepl(MT,W$lab),1,ifelse(grepl(PL,W$lab),2,3));W$cell=paste(substr(W$key,1,3),W$lev)
W$cnt=dk(W$key,W$y);W$any=W$cnt>0;W$tc=paste(W$cell,W$tribe);W$p1=pv(W$cell);W$p2=pv(W$tc)
print(table(W$y,W$lev));print(rbind(all=ms(TRUE),mt=ms(W$lev==1),pl=ms(W$lev==2)))
