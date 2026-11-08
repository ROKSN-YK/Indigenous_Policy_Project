import json,glob,sys,re,csv
sys.path.insert(0,'.')
from reconcile import toint
from solver import solve,residuals
COUNTIES={'臺北縣','宜蘭縣','桃園縣','新竹縣','苗栗縣','臺中縣','彰化縣','南投縣','雲林縣','嘉義縣','臺南縣','高雄縣','屏東縣','臺東縣','花蓮縣','澎湖縣','基隆市','新竹市','臺中市','嘉義市','臺南市','臺北市','高雄市','金門縣','連江縣'}
AGG={'總計','臺灣地區','臺灣省','福建省'}
def blocks_of(y):
    pages=sorted(glob.glob(f'pages/{y}/pg-*.json')); out=[]; issues=[]
    for i in range(0,len(pages)-1,2):
        L=json.load(open(pages[i])); R=json.load(open(pages[i+1]))
        lr=[r for r in L['M'] if any(r)]; rr=[r for r in R['M'] if any(r)]
        if len(lr)!=len(rr) or len(lr)%3: issues.append((pages[i],len(lr),len(rr)))
        n=min(len(lr),len(rr))//3*3
        for k in range(0,n,3):
            raw=[lr[k+j][:11]+rr[k+j][:16] for j in range(3)]
            raw=[r+['']*(27-len(r)) for r in raw]
            v=[[toint(x) for x in r] for r in raw]
            out.append({'page':pages[i],'k':k//3,'raw':raw,'v':v})
    return out,issues
def ref_for(y):
    ref=[n for n,_ in json.load(open('ref96.json'))]
    if y<=92:
        i=ref.index('臺南市'); j=ref.index('臺北市')
        ref=ref[:i+1]+['東區','南區','西區','北區','中區','安南區','安平區']+ref[j:]
    return ref
if __name__=='__main__':
    y=int(sys.argv[1]); B,iss=blocks_of(y); ref=ref_for(y)
    print(y,'blocks',len(B),'ref',len(ref),'page issues',iss)
    nfix=0;bad=[]
    for b in B:
        v,log,cost=solve(b['v'],b['raw'],maxk=2)
        if log is None: v,log,cost=solve(b['v'],b['raw'],maxk=3)
        b['fixed']=v; b['log']=log; b['cost']=cost
        if log is None: bad.append(b)
        elif log: nfix+=len(log)
    print('unresolved',len(bad),'autofixed cells',nfix, 'highcost',sum(1 for b in B if b['cost'] and b['cost']>2))
    json.dump(B,open(f'blocks_{y}.json','w'),ensure_ascii=False)
