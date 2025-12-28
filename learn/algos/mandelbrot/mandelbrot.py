
import numpy as np
import matplotlib.pyplot as plt

def mandelbrot(c, max_iter):
    """
    Determine if a point is in the Mandelbrot set.
    
    Parameters:
    c : complex
        The complex number to check.
    max_iter : int
        The maximum number of iterations.
    
    Returns:
    int
        The number of iterations before divergence, or max_iter if the point did not diverge.
    """
    z = 0
    for n in range(max_iter):
        if abs(z) > 2:
            return n
        z = z*z + c
    return max_iter

def mandelbrot_set(xmin, xmax, ymin, ymax, width, height, max_iter):
    """
    Generate the Mandelbrot set.
    
    Parameters:
    xmin, xmax : float
        The range of the real axis.
    ymin, ymax : float
        The range of the imaginary axis.
    width, height : int
        The dimensions of the output image.
    max_iter : int
        The maximum number of iterations.
    
    Returns:
    np.ndarray
        A 2D array representing the Mandelbrot set.
    """
    r1 = np.linspace(xmin, xmax, width)
    r2 = np.linspace(ymin, ymax, height)
    [[mandelbrot(complex(r, i), max_iter) for r in r1] for i in r2]
    # return (r1, r2, np.array([[mandelbrot(complex(r, i), max_iter) for r in r1] for i in r2]))

def plot_mandelbrot(xmin, xmax, ymin, ymax, width=800, height=800, max_iter=256):
    """
    Plot the Mandelbrot set.
    
    Parameters:
    xmin, xmax : float
        The range of the real axis.
    ymin, ymax : float
        The range of the imaginary axis.
    width, height : int
        The dimensions of the output image.
    max_iter : int
        The maximum number of iterations.
    """
    r1, r2, mandelbrot_set_data = mandelbrot_set(xmin, xmax, ymin, ymax, width, height, max_iter)
    plt.imshow(mandelbrot_set_data.T, extent=[xmin, xmax, ymin, ymax], cmap='hot', interpolation='bilinear')
    plt.colorbar()
    plt.title("Mandelbrot Set")
    plt.xlabel("Re(c)")
    plt.ylabel("Im(c)")
    # plt.show()
    plt.savefig("output/dummy_name.png")
    np.save("output/py_dump.npy", mandelbrot_set_data)

# Parameters for the Mandelbrot set plot
# xmin, xmax, ymin, ymax = -2.0, 0.6, -1.5, 1.5
# width, height = 960, 960
# max_iter = 200

xmin, xmax, ymin, ymax = -2.0, 0.47, -1.12, 1.12
width, height = 4096, 4096
max_iter = 1000
import time
st = time.perf_counter()
mandelbrot_set(xmin, xmax, ymin, ymax, width, height, max_iter)
print("time: ", time.perf_counter()-st)
# # Plot the Mandelbrot set
# plot_mandelbrot(xmin, xmax, ymin, ymax, width, height, max_iter)

# py_test = np.load("output/py_dump.npy")
# print(py_test.shape)
# mojo_test = np.load("output/mojo_dump.npy", allow_pickle=True)
# print(mojo_test.shape)
# print(np.all(py_test== mojo_test))