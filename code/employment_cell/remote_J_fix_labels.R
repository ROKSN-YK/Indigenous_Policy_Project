l9=attr(rd(P2[yy(P2)==90][1],5)$place,'labels');C$lab=gsub('-','',names(l9)[match(an(d$town3),l9)])
CN=unique(tl(rd(P2[yy(P2)==91][1],Inf)$no2))
sw=function(s)ifelse(substr(s,1,3)%in%CN,s,paste0(substring(s,nchar(s)-2),substr(s,1,nchar(s)-3)))
A$lab=sw(A$lab);C$lab=sw(C$lab);B$lab=ifelse(substr(B$lab,4,6)==substr(B$lab,1,3),paste0(substr(B$lab,1,3),substring(B$lab,7)),B$lab)
