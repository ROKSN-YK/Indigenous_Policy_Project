import re,sys,lxml.html
def parse(f):
    s=open(f,'rb').read().decode('cp950',errors='replace')
    doc=lxml.html.fromstring(s)
    toks=[re.sub(r'[\s　]','',td.text_content()) for td in doc.iter('td','th')]
    out=[]; NUM=re.compile(r'^-?[\d,]+(\.\d+)?$')
    for i in range(1,len(toks)-38):
        if toks[i]=='合計' and toks[i-1] and not NUM.match(toks[i-1]) and toks[i-1] not in ('男','女','計','平地','山地','地區別','性別','合計'):
            vals=toks[i+1:i+37]
            if not all(NUM.match(v) for v in vals): continue
            nums=[float(v.replace(',','')) for v in vals]
            tot=nums[0]; g=nums[2::2]  # 17 groups counts
            if len(g)<17: continue
            out.append((toks[i-1].replace('台','臺').replace('芩雅','苓雅'),int(tot),int(sum(g[11:17])),int(sum(g[13:17])),int(sum(g[0:3]))))
    return out
if __name__=='__main__':
    r=parse(sys.argv[1]); print(len(r)); print(r[:8]); print([x for x in r if x[0] in('仁愛鄉','三民鄉','那瑪夏鄉','全國')])
