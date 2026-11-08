write.csv(G,'Z:/meta/inv.csv',row.names=FALSE)
CS=read.csv(file.path(PP,'data/processed_data/05_reference/care_station_town_year_panel_long.csv'),encoding='UTF-8')
u8=function(...)intToUtf8(c(...))
OL=c(u8(33274,21271,32291),u8(26691,22290,32291),u8(33274,20013,32291),u8(33274,21335,32291),u8(39640,38596,32291))
NW=c(u8(26032,21271,24066),u8(26691,22290,24066),u8(33274,20013,24066),u8(33274,21335,24066),u8(39640,38596,24066))
nk=function(c3,t){c3=gsub(u8(21488),u8(33274),c3);t=gsub(u8(21488),u8(33274),t);i=match(c3,OL)
s3=c3==OL[5]&substr(t,1,2)==u8(19977,27665);c3[!is.na(i)]=NW[i[!is.na(i)]];ts=substr(t,1,nchar(t)-1);ts[s3]=u8(37027,29802,22799);paste(c3,ts)}
CS$key=nk(CS$station_county,CS$station_township);c(nrow(CS),length(unique(CS$key)))
sk=function(lab)nk(substr(lab,1,3),substr(lab,4,nchar(lab)))
TV2=c(TV[-1]);for(y in names(TV2)){x=P2[yy(P2)==as.integer(y)][1];l=attr(rd(x,5)[[TV2[[y]]]],'labels');k=sk(names(l));e=unique(CS$key[CS$care_station_first_year<=as.integer(y)-1]);cat(y,length(l),sum(k%in%CS$key),length(e),sum(e%in%k),'\n')}
