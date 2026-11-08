import sys,os,json,glob,pickle
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import cv2,numpy as np
from ocr_page import analyze
FW,FH=16,24
def page_cells(png):
    im,img,hl,vl,(y0,y1),bands=analyze(png)
    left=len(vl)<14
    if left: edges=[vl[1]]+vl[2:]
    else: edges=[max(0,vl[0]-140)]+vl+[min(img.shape[1],vl[-1]+230)]
    cols=list(zip(edges[:-1],edges[1:]))
    B=(img<128).astype(np.uint8)
    rows=[]
    for (a,b) in bands:
        cells=[]
        for (ca,cb) in cols:
            c=B[max(0,a-5):b+5, ca+3:cb]
            cells.append(segment(c))
        rows.append(cells)
    return left,bands,rows
def segment(c):
    n,lab,st,cen=cv2.connectedComponentsWithStats(c,8)
    comps=[(st[i,0],st[i,1],st[i,2],st[i,3],st[i,4],i) for i in range(1,n) if st[i,4]>=6]
    if not comps: return {'dash':False,'g':[]}
    hmax=max(h for x,y,w,h,a,i in comps)
    # dash: wide thin
    if hmax<9 and any(w>15 for x,y,w,h,a,i in comps): return {'dash':True,'g':[]}
    digits=[k for k in comps if k[3]>=0.6*hmax]
    # merge overlapping in x
    digits.sort()
    merged=[]
    for k in digits:
        if merged and k[0] < merged[-1][0]+merged[-1][2]-3:
            x,y,w,h=merged[-1][:4]; nx=min(x,k[0]); ny=min(y,k[1]); nw=max(x+w,k[0]+k[2])-nx; nh=max(y+h,k[1]+k[3])-ny
            merged[-1]=[nx,ny,nw,nh,merged[-1][4]+[k[5]]]
        else: merged.append([k[0],k[1],k[2],k[3],[k[5]]])
    gl=[]
    for x,y,w,h,ids in merged:
        m=np.isin(lab[y:y+h,x:x+w],ids).astype(np.uint8)
        gl.append((x,w,h,m))
    return {'dash':False,'g':gl,'hmax':int(hmax)}
from skimage.feature import hog
def feat(m):
    h,w=m.shape
    s=max(h,w); pad=np.zeros((s,s),np.float32); pad[(s-h)//2:(s-h)//2+h,(s-w)//2:(s-w)//2+w]=m
    r=cv2.resize(pad,(28,28),interpolation=cv2.INTER_AREA)
    f=hog(r,orientations=9,pixels_per_cell=(7,7),cells_per_block=(2,2))
    return np.concatenate([f,[w/h]])
if __name__=='__main__':
    y=sys.argv[1]; out={}
    for png in sorted(glob.glob(f'pages/{y}/pg-*.png')):
        left,bands,rows=page_cells(png)
        # store compact: per cell list of (x,w,h,bitmap as packed)
        out[png]={'left':left,'rows':[[{'dash':c['dash'],'g':[(int(x),int(w),int(h),np.packbits(m).tolist(),m.shape) for x,w,h,m in c['g']]} for c in r] for r in rows]}
    pickle.dump(out,open(f'glyphs_{y}.pkl','wb'))
    print(y,'done',len(out))
