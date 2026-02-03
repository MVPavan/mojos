# Test resize_fast module
from mojovision.resize_fast import (
    resize_fast,
    InterpolationMode,
)
from mojovision.image import ImageTensor

fn main():
    print("Testing resize_fast...")
    
    # Create test image
    comptime UI8 = DType.uint8
    var src = ImageTensor[UI8].rand(100, 150, 3)
    print("Source: " + src.shape())
    
    # Test nearest
    var dst_nn = resize_fast(src, 50, 75, InterpolationMode.NEAREST)
    print("Nearest: " + dst_nn.shape())
    
    # Test bilinear
    var dst_bil = resize_fast(src, 50, 75, InterpolationMode.BILINEAR)
    print("Bilinear: " + dst_bil.shape())
    
    # Test bicubic
    var dst_bic = resize_fast(src, 50, 75, InterpolationMode.BICUBIC)
    print("Bicubic: " + dst_bic.shape())
    
    print("All tests passed!")
