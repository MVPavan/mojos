from tensor import Tensor, TensorSpec, TensorShape


def main():
    var spec1 = TensorSpec(DType.float32, 256, 128)
    var t1 = Tensor[DType.float32](spec1)
    var spec2 = TensorSpec(DType.float32, 128, 256)
    var t2 = Tensor[DType.float32](spec2)
    print(t1.shape())
    print(t2.shape())
    var t3 = t1@t2
    print(t3.shape())