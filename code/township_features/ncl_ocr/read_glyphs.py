import pickle,json,sys,numpy as np
sys.path.insert(0,'.')
from glyphs import feat
from solver import solve,residuals
X=np.load('trX.npy').astype(np.float32);Y=np.load('trY.npy'); sq=(X**2).sum(1)
W=1.25  # aspect*2 of typical digit (w/h*2)
import pickle as _pk
CLF=_pk.load(open('svc.pkl','rb'))
def classify(ms):
    if not ms: return [],[]
    F=np.array([feat(m) for m in ms],np.float32)
    d=CLF.decision_function(F); p=d.argmax(1)
    srt=np.sort(d,1); marg=srt[:,-1]-srt[:,-2]
    return [int(CLF.classes_[i]) for i in p],[float(10-m) for m in marg]
def pieces(cell,strict=True):
    if cell['dash'] or not cell['g']: return []
    masks=[]
    for x,w,h,bits,shape in cell['g']:
        if x<=3 and w<12: continue
        m=np.unpackbits(np.array(bits,np.uint8))[:shape[0]*shape[1]].reshape(shape)
        if strict and w<=5: continue
        if strict and w<=7:
            bot=m[int(0.8*m.shape[0]):]; 
            if bot.sum(1).max()<=4: continue
        masks.append(m)
    if not masks: return []
    hs=[m.shape[0] for m in masks if m.shape[1]/m.shape[0]*2<=1.6*W]
    Hd=int(np.median(hs)) if hs else 25
    ms=[]
    for m in masks:
        h=m.shape[0]
        if m.shape[1]/h*2<=1.6*W: ms.append(m); continue
        prof=m[:int(0.55*h)].sum(0)>0
        segs=[];st=None
        for i,p in enumerate(list(prof)+[False]):
            if p and st is None: st=i
            if not p and st is not None:
                if i-st>=3: segs.append((st,i))
                st=None
        for a_,b_ in segs:
            pm=m[:,a_:b_]; ys=np.where(pm.any(1))[0]; pm=pm[ys.min():ys.max()+1]
            if pm.shape[0]<0.6*h: continue
            if pm.shape[0]>Hd+1: pm=pm[:Hd+1]
            xs=np.where(pm.any(0))[0]; pm=pm[:,xs.min():xs.max()+1]
            pasp=pm.shape[1]/pm.shape[0]*2
            n=int(round(pasp/W)) if pasp>1.6*W else 1
            cw=pm.shape[1]/n
            for k in range(n): ms.append(pm[:,int(k*cw):int((k+1)*cw)])
    return ms
def cell_value(cell,strict=True):
    ms=pieces(cell,strict)
    if not ms: return 0,'',0.0
    ds,dist=classify(ms)
    s=''.join(map(str,ds)); return (int(s) if s else 0),s,max(dist) if dist else 0
def year_blocks(y):
    G=pickle.load(open(f'glyphs_{y}.pkl','rb'))
    pages=sorted(G); out=[]; issues=[]
    for i in range(0,len(pages)-1,2):
        L=G[pages[i]]; R=G[pages[i+1]]
        assert L['left'] and not R['left'],pages[i]
        def nonempty(rows,n): return [r for r in rows if any(c['g'] or c['dash'] for c in r[:n])]
        lr=nonempty(L['rows'],11); rr=nonempty(R['rows'],16)
        if len(lr)!=len(rr) or len(lr)%3: issues.append((pages[i],len(lr),len(rr)))
        n=min(len(lr),len(rr))//3*3
        for k in range(0,n,3):
            cand=[]
            for strict in (True,False):
                v=[];raw=[];dist=[]
                for j in range(3):
                    cells=lr[k+j][:11]+rr[k+j][:16]
                    vals=[cell_value(c,strict) for c in cells]
                    v.append([a for a,_,_ in vals]); raw.append([b for _,b,_ in vals]); dist.append([d for _,_,d in vals])
                cand.append({'page':pages[i],'k':k//3,'v':v,'raw':raw,'dist':dist,'strict':strict})
            out.append(cand)
    return out,issues
if __name__=='__main__':
    y=sys.argv[1]; B,iss=year_blocks(y)
    unres=0;fixed=0
    BB=[]
    for cand in B:
        best=None
        for b in cand:
            if not residuals(b['v']): v,log=b['v'],[]
            else: v,log,cost=solve(b['v'],b['raw'],maxk=2)
            b['fixed']=v; b['log']=log
            score=(log is None, len(log) if log else 0)
            if best is None or score<best[0]: best=(score,b)
        b=best[1]; BB.append(b)
        if b['log'] is None: unres+=1
        elif b['log']: fixed+=1
    B=BB
    print(y,'blocks',len(B),'issues',iss,'unresolved',unres,'blocks autofixed',fixed)
    json.dump(B,open(f'gblocks_{y}.json','w'))
