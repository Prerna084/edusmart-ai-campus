import urllib.request
import numpy as np
from app.face_engine import encode_face, find_best_match
import sys
from io import BytesIO

# download two different face images of the same person
url1 = "https://raw.githubusercontent.com/opencv/opencv/master/samples/data/lena.jpg"
resp1 = urllib.request.urlopen(url1)
img1_bytes = resp1.read()

# Let's just crop or change brightness of img1 to simulate a second photo
import cv2
img1_np = np.frombuffer(img1_bytes, np.uint8)
img1_cv = cv2.imdecode(img1_np, cv2.IMREAD_COLOR)

# darker
img2_cv = cv2.convertScaleAbs(img1_cv, alpha=0.8, beta=10)
_, img2_buf = cv2.imencode('.jpg', img2_cv)
img2_bytes = img2_buf.tobytes()

f1 = BytesIO(img1_bytes)
enc1 = encode_face(f1)

f2 = BytesIO(img2_bytes)
enc2 = encode_face(f2)

if enc1 is not None and enc2 is not None:
    match = find_best_match([enc1], enc2, tolerance=0.5)
    print("Match Result:", match)
else:
    print("Failed to encode")

# Also print distance
if enc1 is not None and enc2 is not None:
    dist = cv2.compareHist(np.array(enc1, dtype=np.float32), np.array(enc2, dtype=np.float32), cv2.HISTCMP_BHATTACHARYYA)
    print("Actual Distance:", dist)
