from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)
from benchmark import keep

trait QType(CollectionElement, EqualityComparable, RepresentableCollectionElement):
    pass


struct MyQueue[T:QType]:
    var data:UnsafePointer[T]
    var size:Int
    var capacity:Int

    fn __init__(inout self,):
        self.data = UnsafePointer[T]()
        self.size = 0
        self.capacity = 0

    # fn __init__(inout self, *, capacity:Int):
    #     self.data = UnsafePointer[T].alloc(capacity)
    #     self.size = 0
    #     self.capacity = capacity
    
    # fn __init__(inout self, *values: T):
    #     self = Self(capacity = len(values))
    #     for i in range(self.capacity):
    #         self.append(values[i])
    
    @always_inline
    fn __del__(owned self):
        for i in range(self.size):
            destroy_pointee(self.data + i)
        if self.data:
            self.data.free()


    fn __getitem__(self, index:Int) -> T:
        var _index = self.normalized_index(index)
        return self.data.offset(_index)[]
    
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
        return self.data.offset(offset)
    
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
    
    # fn insert(inout self, index:Int, owned value:T):
    #     var _index = self.normalized_index(index)
        
    #     var temp = move_from_pointee(self.pointer_at(self.size-1))

    #     for i in reversed(range(_index, self.size-1)):
    #         move_pointee(src=self.pointer_at(i), dst=self.pointer_at(i+1))
        
    #     initialize_pointee_move(self.pointer_at(index), value^)
    #     self.append(temp^)

