import numpy as np
import math
from timeit import timeit
import cv2
from pyresize import bilinear_interpolation
np.random
def bench(org_shape=(640,640,3), resize_shape=(256,256)):
	rng = np.random.default_rng(seed=42)

	# original_img = np.random.randint(0,255,org_shape).astype(np.uint8)
	original_img = rng.integers(0,255,org_shape).astype(np.uint8)
	# original_img = np.ones(org_shape).astype(np.uint8)
	cv2_resize = cv2.resize(original_img, resize_shape[::-1], interpolation=cv2.INTER_LINEAR)
	custom_resize = bilinear_interpolation(original_img,resize_shape)
	err_rate = np.average(abs(cv2_resize-custom_resize))
	print(f"Bilinear resize from {org_shape} to {resize_shape}:", )
	print(f"Error rate: {err_rate}")
	counter = int(10)
	dt_cv = timeit(lambda: cv2.resize(original_img,resize_shape, interpolation=cv2.INTER_LINEAR), number=counter) / counter
	print(f"Opencv: {dt_cv} s", )

	dt_bi = timeit(lambda: bilinear_interpolation(original_img,resize_shape), number=counter) / counter
	print(f"Python: {dt_bi} s", )
	print(f"cv2 resize is {dt_bi/dt_cv} times faster than python")

if __name__ == "__main__":
	bench(org_shape=(640,640,3), resize_shape=(256,256))
	# bench(org_shape=(2160,3840,3), resize_shape=(480,854))
