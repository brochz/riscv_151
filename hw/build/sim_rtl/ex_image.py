import numpy as np
import matplotlib.pyplot as plt
import tensorflow as tf
img_size = 784
file_name = "lenet_weight.mif"
image_addr = 0x1754
image = np.zeros(img_size)
conv_1_filter_1 = np.array([
  9,
20,
-38,
-45,
-28,
49,
16,
-7,
-50,
-30,
42,
32,
-56,
-69,
-52,
48,
73,
34,
-37,
-34,
35,
84,
54,
66,
15,
12,
34,
-26,
-18,
-7,
-14,
28,
-19,
-15,
-25,
-36,
-23,
26,
15,
16,
4,
-20,
3,
-26,
-16,
-5,
24,
25,
-2,
9,
-2,
10,
0,
0,
6,
-34,
3,
-2,
11,
4,
-31,
-7,
-3,
72,
61,
-44,
-14,
30,
127,
118,
-39,
-6,
38,
101,
87,
34,
26,
-7,
-3,
-41,][0:25])

conv_1_filter_1 = np.reshape(conv_1_filter_1, [5,5,1,1])

with open(file_name, "r") as f:
  lines = f.readlines()
  for i in range(int(image_addr/4), int(image_addr/4) + int(img_size/4)):
    line = lines[i][:-1]
    for j in range(4):  #(0, 1, 2, 3)
      s = line[(3-j)*2:(3-j+1)*2]
      image[i*4 - image_addr + j] = int(s, 16)

# #print 5x5 ifm
# for i in range(5):
#   for j in range(86,86+5):
#     print(image[j + i*28], " ", end= " ")
#   print(" ")


image2d = np.reshape(image, [1, 28, 28, 1])

ofm = tf.nn.conv2d(image2d, conv_1_filter_1, [1,1,1,1], "VALID")
ofm = np.round(ofm.numpy())
ofm = ofm.flatten()
for i, v in enumerate(ofm):
  print(i, " " ,v)
print(ofm.size)
