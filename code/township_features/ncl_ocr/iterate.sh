set -e
for y in 90 91 92 93 94 95; do python3 read_glyphs.py $y > rg_$y.log 2>&1 & done; wait
cat rg_*.log
python3 selftrain.py
python3 - <<'PY'
import numpy as np,pickle
from sklearn.svm import SVC
X=np.load('trX.npy');Y=np.load('trY.npy')
rs=np.random.RandomState(1); idx=rs.permutation(len(X))[:30000]
pickle.dump(SVC(C=10,gamma='scale').fit(X[idx],Y[idx]),open('svc.pkl','wb')); print('retrained')
PY
