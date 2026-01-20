# from memory import UnsafePointer
from memory.reference import Reference
from memory.unsafe import (
    DTypePointer,
    LegacyPointer
)
from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)

trait ArrayType(CollectionElement, RepresentableCollectionElement, EqualityComparable):
    pass

# @register_passable('trivial')
# @value
struct MyArray[T:ArrayType]:
    var data:UnsafePointer[T]
    var size:Int
    var capacity:Int

    fn __init__(inout self,):
        self.data = UnsafePointer[T]()
        self.size = 0
        self.capacity = 0

    fn __init__(inout self, *, capacity:Int):
        self.data = UnsafePointer[T].alloc(capacity)
        self.size = 0
        self.capacity = capacity
    
    fn __init__(inout self, *values: T):
        self = Self(capacity = len(values))
        for i in range(self.capacity):
            self.append(values[i])
    
    @always_inline
    fn __del__(owned self):
        for i in range(self.size):
            destroy_pointee(self.data + i)
        if self.data:
            self.data.free()

    @always_inline
    fn normalized_index(self, index:Int) -> Int:
        var _index = index
        if _index < 0:
            _index = self.size+index
        debug_assert(0<= _index < self.size, "Index out of range")
        return _index


    fn __getitem__(self, index:Int) -> T:
        var _index = self.normalized_index(index)
        return (self.data+_index)[]
    
    fn __setitem__(self, index:Int, owned value:T):
        var _index = self.normalized_index(index)
        destroy_pointee(self.pointer_at(_index))
        initialize_pointee_move(self.pointer_at(_index), value^)


    fn __copyinit__(inout self, existing: Self):
        self = Self(capacity=existing.capacity)
        for i in range(existing.size):
            self.append(existing[i])

    fn __moveinit__(inout self, owned existing: Self):
        self.data = existing.data
        self.size = existing.size
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.size
    
    fn __str__(self) -> String:
        var result:String = "[ "
        for i in range(self.size):
            result += repr(self[i]) + ", "
        result += "]"
        return result
    
    fn __repr__(self)->String:
        return self.__str__()
    
    @always_inline
    fn pointer_at(self, offset:Int)->UnsafePointer[T]:
        return self.data+offset
    
    fn _realloc(inout self, new_capcity:Int):
        var new_data = UnsafePointer[T].alloc(new_capcity)
        for i in range(self.size):
            move_pointee(src=self.data+i, dst=new_data+i)
        
        if self.data:
            self.data.free()
        self.data = new_data
        self.capacity = new_capcity
    
    @always_inline
    fn append(inout self, owned value:T):
        if self.size>=self.capacity:
            self._realloc(max(1,self.capacity*2))

        initialize_pointee_move(self.data+self.size, value^)
        self.size +=1
    
    fn insert(inout self, index:Int, owned value:T):
        var _index = self.normalized_index(index)
        
        var temp = move_from_pointee(self.pointer_at(self.size-1))

        for i in reversed(range(_index, self.size-1)):
            move_pointee(src=self.pointer_at(i), dst=self.pointer_at(i+1))
        
        initialize_pointee_move(self.pointer_at(index), value^)
        self.append(temp^)


from testing import assert_true, assert_equal
# Test Initialization
fn test_myarray_initialization() raises:
    var arr = MyArray[Int]()
    assert_true(arr.size == 0)
    assert_true(arr.capacity == 0)

    var arr_with_capacity = MyArray[Int](capacity=5)
    assert_true(arr_with_capacity.size == 0)
    assert_true(arr_with_capacity.capacity == 5)

    var arr_with_values = MyArray[Int](1, 2, 3)
    assert_true(arr_with_values.size == 3)
    assert_true(arr_with_values.capacity == 3)
    assert_true(arr_with_values[0] == 1)
    assert_true(arr_with_values[1] == 2)
    assert_true(arr_with_values[2] == 3)

# Test Element Access
fn test_myarray_element_access() raises:
    var arr = MyArray[Int](1, 2, 3)
    assert_true(arr[0] == 1)
    assert_true(arr[1] == 2)
    assert_true(arr[2] == 3)
    arr[1] = 10
    assert_true(arr[1] == 10)

fn test_myarray_append() raises:
    var arr = MyArray[Int]()
    arr.append(1)
    assert_true(arr.size == 1)
    assert_true(arr[0] == 1)
    # print(arr.capacity)
    arr.append(2)
    assert_true(arr.size == 2)
    assert_true(arr[1] == 2)
    # print(arr.capacity)
    arr.append(3)
    # print(arr.capacity)

fn test_myarray_insert() raises:
    var arr = MyArray[Int](1,2,5,8,9,4,0)
    arr.insert(2, 3)
    assert_true(arr.size == 8)
    assert_true(arr[2] == 3)
    assert_true(arr[4] == 8)
    print(arr.__str__())

def main():
    test_myarray_initialization()
    test_myarray_element_access()
    test_myarray_append()
    test_myarray_insert()