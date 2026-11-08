import cv2,numpy as np,subprocess,csv,io,re,sys,os,tempfile
def grp(a,gap=4):
    g=[]
    for x in a:
        if g and x-g[-1][-1]<=gap: g[-1].append(x)
        else: g.append([x])
    return [(min(z),max(z)) for z in g]
def tess(img,psm=6,wl='0123456789,',lang='eng'):
    fd,fn=tempfile.mkstemp(suffix='.png'); os.close(fd); cv2.imwrite(fn,img)
    cfg=['--psm',str(psm),'-l',lang]
    if wl: cfg+=['-c','tessedit_char_whitelist='+wl]
    out=subprocess.run(['tesseract',fn,'-']+cfg+['tsv'],capture_output=True,text=True).stdout
    os.remove(fn)
    rows=[r for r in csv.DictReader(io.StringIO(out),delimiter='\t',quoting=3) if r.get('text','').strip()]
    return [(int(r['top'])+int(r['height'])//2,int(r['left']),r['text'],float(r['conf'])) for r in rows]
def deskew(im):
    b=(im<160).astype(np.uint8)
    v=cv2.morphologyEx(b,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_RECT,(1,40)))
    xs=[int(np.mean(x)) for x in grp(np.where(v[800:2600].sum(0)>500)[0])]
    sl=[]
    for x0 in xs:
        pts=[]
        for y in range(700,2800,200):
            seg=v[y:y+200,max(0,x0-20):x0+20].sum(0)
            if seg.max()>50: pts.append((y+100,int(np.argmax(seg))))
        if len(pts)>=5:
            a=np.polyfit([p[0] for p in pts],[p[1] for p in pts],1)[0]; sl.append(a)
    if not sl: return im,0
    ang=float(np.degrees(np.arctan(np.median(sl))))
    H,W=im.shape; Mx=cv2.getRotationMatrix2D((W/2,H/2),-ang,1.0)
    return cv2.warpAffine(im,Mx,(W,H),flags=cv2.INTER_LINEAR,borderValue=255),ang
def analyze(path):
    im=cv2.imread(path,0); im,_ang=deskew(im); H,W=im.shape
    b=(im<160).astype(np.uint8)
    hz=cv2.morphologyEx(b,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_RECT,(300,1)))
    hl=[int(np.mean(x)) for x in grp(np.where(hz.sum(1)>600)[0])]
    v=cv2.morphologyEx(b,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_RECT,(1,60)))
    y0,y1=hl[-2]+5,hl[-1]-5
    vl=[int(np.mean(x)) for x in grp(np.where(v[y0:y1].sum(0)>600)[0])]
    clean=b.copy(); clean[v>0]=0; clean[hz>0]=0
    for x in vl: clean[:, max(0,x-3):x+4]=0
    clean=cv2.dilate(clean,np.ones((1,1),np.uint8))
    img=255-clean*255
    # text row bands from projection over numeric region
    xs=vl[1] if len(vl)<14 else 0
    proj=clean[y0:y1, (vl[1] if len(vl)<14 else 0):].sum(1)
    bands=[(a+y0,b_+y0) for a,b_ in grp(np.where(proj>8)[0],gap=3) if b_-a>=12]
    sp=[]
    for a,b_ in bands:
        h=b_-a
        n=max(1,int(round((h+7)/37.0))) if h>45 else 1
        for k in range(n): sp.append((int(a+k*(h/n)),int(a+(k+1)*(h/n))))
    bands=sp
    return im,img,hl,vl,(y0,y1),bands
if __name__=='__main__':
    im,img,hl,vl,yy,bands=analyze(sys.argv[1]); print(hl,vl,yy,len(bands),bands[:6])

def extract(path):
    im,img,hl,vl,(y0,y1),bands=analyze(path)
    left = len(vl)<14
    if left:
        edges=vl[1:]+[vl[-1]+140]   # numeric columns start at sex col end
        edges=[vl[1]]+vl[2:]+[vl[-1]+150]
    else:
        edges=[max(0,vl[0]-135)]+vl+[min(img.shape[1],vl[-1]+110)]
    cols=list(zip(edges[:-1],edges[1:]))
    centers=[(a+b)//2 for a,b in bands]
    M=[['' for _ in cols] for _ in bands]
    for j,(a,b) in enumerate(cols):
        strip=img[y0:y1, a+4:b-2]
        strip=cv2.copyMakeBorder(strip,20,20,20,20,cv2.BORDER_CONSTANT,value=255)
        for yc,x,t,c in tess(strip,psm=6):
            y=yc-20+y0
            i=int(np.argmin([abs(y-cc) for cc in centers]))
            if abs(y-centers[i])<25: M[i][j]=(M[i][j]+t) if M[i][j] else t
    return left,bands,M

def extract_rows(path,scale=1):
    im,img,hl,vl,(y0,y1),bands=analyze(path)
    left = len(vl)<14
    if left: edges=[vl[1]]+vl[2:]
    else: edges=[max(0,vl[0]-140)]+vl+[min(img.shape[1],vl[-1]+115)]
    cols=list(zip(edges[:-1],edges[1:]))
    x0,x1=cols[0][0],cols[-1][1]
    M=[]
    for (a,b) in bands:
        r=img[max(0,a-4):b+4, x0:x1]
        r=cv2.copyMakeBorder(r,30,30,60,60,cv2.BORDER_CONSTANT,value=255)
        if scale!=1: r=cv2.resize(r,None,fx=scale,fy=scale,interpolation=cv2.INTER_CUBIC)
        row=['']*len(cols)
        for yc,x,t,c in tess(r,psm=7):
            xx=x/scale-60+x0
            # assign by right edge-ish: use token left x
            for j,(ca,cb) in enumerate(cols):
                if ca-10<=xx<cb: row[j]=row[j]+t; break
        for j,(ca,cb) in enumerate(cols):
            c=img[max(0,a-4):b+4, ca+trim[0]:cb-trim[1]]
            ink=(c<128).sum()
            if ink>12 and (row[j]=='' or len(re.sub(r'\D','',row[j]))<2):
                cc=cv2.resize(c,None,fx=3,fy=3,interpolation=cv2.INTER_CUBIC)
                cc=cv2.copyMakeBorder(cc,40,40,60,60,cv2.BORDER_CONSTANT,value=255)
                ys,xs=np.where(c<128)
                tt=c[ys.min():ys.max()+1, xs.min():xs.max()+1]
                if tt.shape[1]>2.5*tt.shape[0] and tt.shape[0]<8: continue
                cc=cv2.copyMakeBorder(cv2.resize(tt,None,fx=3,fy=3,interpolation=cv2.INTER_CUBIC),40,40,40,40,cv2.BORDER_CONSTANT,value=255)
                got=''.join(t for _,_,t,_ in tess(cc,psm=7)) or ''.join(t for _,_,t,_ in tess(cc,psm=10))
                if got and (row[j]=='' or len(got)>len(row[j])): row[j]=got
        M.append(row)
    return left,bands,cols,M

def extract_rows2(path,gap=80,trim=(10,5),scale=1.0,rext=140):
    im,img,hl,vl,(y0,y1),bands=analyze(path)
    left = len(vl)<14
    if left: edges=[vl[1]]+vl[2:]
    else: edges=[max(0,vl[0]-140)]+vl+[min(img.shape[1],vl[-1]+rext)]
    cols=list(zip(edges[:-1],edges[1:]))
    M=[]; 
    for (a,b) in bands:
        pieces=[];spans=[];x=gap
        for (ca,cb) in cols:
            c=img[max(0,a-4):b+4, ca+trim[0]:cb-trim[1]]
            pieces.append(np.full((c.shape[0],gap),255,np.uint8)); pieces.append(c)
            spans.append((x,x+c.shape[1])); x+=c.shape[1]+gap
        pieces.append(np.full((c.shape[0],gap),255,np.uint8))
        r=np.hstack(pieces); r=cv2.copyMakeBorder(r,30,30,0,0,cv2.BORDER_CONSTANT,value=255)
        if scale!=1: r=cv2.resize(r,None,fx=scale,fy=scale,interpolation=cv2.INTER_CUBIC)
        row=['']*len(cols)
        for yc,xl,t,cf in tess(r,psm=7):
            xl=xl/scale
            for j,(sa,sb) in enumerate(spans):
                if sa-gap/2<=xl<sb: row[j]+=t; break
        for j,(ca,cb) in enumerate(cols):
            c=img[max(0,a-4):b+4, ca+trim[0]:cb-trim[1]]
            ink=(c<128).sum()
            if ink>12 and (row[j]=='' or len(re.sub(r'\D','',row[j]))<2):
                cc=cv2.resize(c,None,fx=3,fy=3,interpolation=cv2.INTER_CUBIC)
                cc=cv2.copyMakeBorder(cc,40,40,60,60,cv2.BORDER_CONSTANT,value=255)
                ys,xs=np.where(c<128)
                tt=c[ys.min():ys.max()+1, xs.min():xs.max()+1]
                if tt.shape[1]>2.5*tt.shape[0] and tt.shape[0]<8: continue
                cc=cv2.copyMakeBorder(cv2.resize(tt,None,fx=3,fy=3,interpolation=cv2.INTER_CUBIC),40,40,40,40,cv2.BORDER_CONSTANT,value=255)
                got=''.join(t for _,_,t,_ in tess(cc,psm=7)) or ''.join(t for _,_,t,_ in tess(cc,psm=10))
                if got and (row[j]=='' or len(got)>len(row[j])): row[j]=got
        M.append(row)
    return left,bands,cols,M
