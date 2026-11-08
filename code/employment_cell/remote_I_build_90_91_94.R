g9=function(y,lab,sx,ag,st,tr,wt,em,un,hw)data.frame(y=y,fem=sx==2,age=ag,emp=st%in%em,lf=st%in%c(em,un),hw=st==hw,tribe=tr,lab=lab,wt=wt)
tl=function(v){l=attr(v,'labels');trimws(names(l)[match(as.numeric(v),l)])}
tt=function(v){l=attr(v,'labels');tg(names(l))[match(as.numeric(v),l)]}
an=as.numeric;d=rd(P2[yy(P2)==90][1],Inf);x=tl(d$place)
A=g9(90,paste0(sub('-.*','',x),sub('.*-','',x)),an(d$q2),an(d$q3),an(d$q7),tt(d$q6),an(d$w7),1:4,5,8)
d=rd(P2[yy(P2)==91][1],Inf)
B=g9(91,paste0(tl(d$no2),tl(d$place1)),an(d$q2),an(d$q3),an(d$q7),tt(d$q1),an(d$w),1:4,5,8)
d=rd(P2[yy(P2)==94][1],Inf);x=tl(d$town3)
C=g9(94,paste0(sub('.*-','',x),sub('-.*','',x)),an(d$q2),an(d$q3),an(d$q7),tt(d$q1),an(d$w1),1:5,6,10)
for(Z in list(A,B,C)){k=sk(Z$lab);e=unique(CS$key[CS$care_station_first_year<=Z$y[1]-1]);cat(Z$y[1],nrow(Z),head(unique(Z$lab),3),sum(unique(k)%in%CS$key),length(e),sum(e%in%k),'\n')}
