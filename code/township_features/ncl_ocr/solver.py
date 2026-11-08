import itertools,re
PARTS=[1,2]+list(range(7,27))
def residuals(v):
    res={}
    for c in range(27):
        d=v[0][c]-v[1][c]-v[2][c]
        if d: res[('c',c)]=d
    for r in range(3):
        d=v[r][0]-sum(v[r][c] for c in PARTS)
        if d: res[('r',r)]=d
        d=v[r][2]-sum(v[r][3:7])
        if d: res[('s',r)]=d
    return res
def coef(r,c):
    """residual change per +1 change at cell"""
    e={('c',c):(1 if r==0 else -1)}
    if c==0: e[('r',r)]=1
    elif c in PARTS: e[('r',r)]=-1
    if c==2: e[('s',r)]=1
    elif 3<=c<=6: e[('s',r)]=-1
    return e
def lev(a,b):
    d=list(range(len(b)+1))
    for i,x in enumerate(a,1):
        p,d[0]=d[0],i
        for j,y in enumerate(b,1):
            p,d[j]=d[j],min(d[j]+1,d[j-1]+1,p+(x!=y))
    return d[-1]
def plaus(raw,new):
    rd=re.sub(r'\D','',raw or '')
    return lev(rd,str(new))
def solve(v,raw,maxk=3):
    res=residuals(v)
    if not res: return v,[],0
    cells=[(r,c) for r in range(3) for c in range(27) if any(k in res for k in coef(r,c))]
    best=None
    for k in range(1,maxk+1):
        for combo in itertools.combinations(cells,k):
            # solve deltas greedily: need sum_i delta_i*coef_i + res = 0 for all eqs
            eqs=set(res)
            for cell in combo: eqs|=set(coef(*cell))
            # linear system small: brute via numpy lstsq
            import numpy as np
            E=sorted(eqs); A=np.array([[coef(*cell).get(e,0) for cell in combo] for e in E],float); bvec=-np.array([res.get(e,0) for e in E],float)
            x,*_=np.linalg.lstsq(A,bvec,rcond=None)
            xi=np.round(x).astype(int)
            if not np.allclose(A@xi,bvec): continue
            if any(xi==0): continue
            nv=[row[:] for row in v]; ok=True; cost=0
            for (r,c),d in zip(combo,xi):
                nv[r][c]+=int(d)
                if nv[r][c]<0: ok=False
                cost+=plaus(raw[r][c],nv[r][c])
            if ok and not residuals(nv):
                if best is None or cost<best[0]: best=(cost,nv,[(r,c,v[r][c],nv[r][c],raw[r][c]) for (r,c) in combo])
        if best: return best[1],best[2],best[0]
    return v,None,None
