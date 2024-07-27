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

# @register_passable('trivial')
# @value
struct MyArray[T:CollectionElement]:
    var data:UnsafePointer[T]
    var size:Int
    var capacity:Int

    fn __init__(inout self):
        self.data = UnsafePointer[T]()
        self.size = 0
        self.capacity = 0

    fn __init__(inout self, capacity:Int=10):
        self.data = UnsafePointer[T].alloc(capacity)
        self.size = 0
        self.capacity = capacity

    fn __moveinit__(inout self, owned existing: Self):
        """Move data of an existing list into a new one.

        Args:
            existing: The existing list.
        """
        self.data = existing.data
        self.size = existing.size
        self.capacity = existing.capacity

    # fn __copyinit__(inout self, existing: Self):
    #     """Creates a deepcopy of the given list.

    #     Args:
    #         existing: The list to copy.
    #     """
    #     self = Self(capacity=existing.capacity)
    #     for i in range(len(existing)):
    #         self.append(existing[i])
    
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
    
    @always_inline
    fn insert(inout self, index:Int, owned value:T):
        self.append(value)
        # TODO: check the self.data offset range (0->size-1) or (1->size)
        var left_ptr = self.data.offset(self.size-2)
        var right_ptr = self.data.offset(self.size-1)
        
        var temp = move_from_pointee(right_ptr)

        for i in range(index, self.size-1):
            move_pointee(src=self.data.offset(self.size-2-i), dst=self.data.offset(self.size-1-i))
        
        initialize_pointee_move(self.data.offset(index), value^)




