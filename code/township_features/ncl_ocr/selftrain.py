import json,pickle,sys,numpy as np
sys.path.insert(0,'.')
from glyphs import feat
from read_glyphs import pieces
X=[];Y=[]
for y in ['90','91','92','93','94','95']:
    G=pickle.load(open(f'glyphs_{y}.pkl','rb')); B=json.load(open(f'gblocks_{y}.json'))
    pages=sorted(G)
    # rebuild nonempty row lists same as read_glyphs
    def nonempty(rows,n): return [r for r in rows if any(c['g'] or c['dash'] for c in r[:n])]
    NE={p:nonempty(G[p]['rows'],11 if G[p]['left'] else 16) for p in pages}
    for b in B:
        if b['log'] is None: continue
        V=b['fixed']
        i=pages.index(b['page']); L=NE[pages[i]]; R=NE[pages[i+1]]
        for j in range(3):
            cells=L[b['k']*3+j][:11]+R[b['k']*3+j][:16]
            for c,cell in enumerate(cells):
                s=str(V[j][c]) if V[j][c] else ''
                ps=pieces(cell,b.get('strict',True))
                if s and len(ps)==len(s):
                    for m,ch in zip(ps,s):
                        X.append(feat(m)); Y.append(int(ch))
X=np.array(X,np.float32);Y=np.array(Y)
# subsample per class to cap size
rs=np.random.RandomState(0); keep=[]
for d in range(10):
    ii=np.where(Y==d)[0]; keep+=list(rs.choice(ii,min(len(ii),6000),replace=False))
np.save('trX.npy',X[keep]); np.save('trY.npy',Y[keep]); print(len(X),len(keep),np.bincount(Y[keep]))
