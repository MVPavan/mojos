from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)
from collections import Optional
from benchmark import keep
from memory import Arc

# @value
struct Node[T:RepresentableCollectionElement]:
    var data:UnsafePointer[T]
    var next_ptr:UnsafePointer[Self]
    var prev_ptr:UnsafePointer[Self]

    fn __init__(inout self):
        self.data = UnsafePointer[T]()
        self.next_ptr = UnsafePointer[Self]()
        self.prev_ptr = UnsafePointer[Self]()

    fn __init__(inout self, owned value:T):
        self = Self()
        self.data = self.data.alloc(1)
        initialize_pointee_move(self.data, value^)
    
    fn __copyinit__(inout self, existing:Self):
        # self = Self(value=existing.data[])
        self.data = existing.data
        self.next_ptr = existing.next_ptr
        self.prev_ptr = existing.prev_ptr
    
    fn __moveinit__(inout self, owned existing:Self):
        self = Self()
        self.data = self.data.alloc(1)
        move_pointee(src=existing.data, dst=self.data)
        self.next_ptr = existing.next_ptr
        self.prev_ptr = existing.prev_ptr

    @always_inline
    fn __del__(owned self):
        destroy_pointee(self.data)
        # destroy_pointee(self.next_ptr)
        # destroy_pointee(self.prev_ptr)
        if self.data:
            self.data.free()
        if self.next_ptr:
            self.next_ptr.free()
        if self.prev_ptr:
            self.prev_ptr.free()



struct MyLinkedList[T:RepresentableCollectionElement]:
    alias Node_Ptr = UnsafePointer[Node[T]]
    var head:Self.Node_Ptr
    var tail:Self.Node_Ptr

    @always_inline
    fn __del__(owned self):
        destroy_pointee(self.head)
        destroy_pointee(self.tail)
        if self.head:
            self.head.free()
        if self.tail:
            self.tail.free()

    fn __init__(inout self):
        self.head = self.Node_Ptr()
        self.tail = self.Node_Ptr()
    
    fn append(inout self, owned value:T):
        if not self.head:
            self.head = self.head.alloc(1)
            initialize_pointee_move(self.head, Node[T](value))
            # self.head = self.Node_Ptr.address_of(Node[T](value))
        elif not self.tail:
            self.tail = self.tail.alloc(1)
            initialize_pointee_move(self.tail, Node[T](value))
            # self.tail = self.Node_Ptr.address_of(Node[T](value))
            self.head[].next_ptr = self.tail
            self.tail[].prev_ptr = self.head
        else:
            self.tail[].next_ptr = self.tail[].next_ptr.alloc(1)
            initialize_pointee_move(self.tail[].next_ptr, Node[T](value))
            self.tail[].next_ptr[].prev_ptr = self.tail
            self.tail = self.tail[].next_ptr
    

    fn prepend(inout self, owned value:T):
        if not self.tail:
            self.tail = self.tail.alloc(1)
            initialize_pointee_move(self.tail, Node[T](value))
        elif not self.head:
            self.head = self.head.alloc(1)
            initialize_pointee_move(self.head, Node[T](value))
            self.head[].next_ptr = self.tail
            self.tail[].prev_ptr = self.head
        else:
            self.head[].prev_ptr = self.head[].prev_ptr.alloc(1)
            initialize_pointee_move(self.head[].prev_ptr, Node[T](value))
            self.head[].prev_ptr[].next_ptr = self.head
            self.head = self.head[].prev_ptr

    # @staticmethod
    fn __str__(inout self, backward:Bool=False) ->String:
        var result:String = "[ " 
        if not backward:
            var temp_ptr = self.head
            while temp_ptr:
                result += repr(temp_ptr[].data[]) + ", "
                temp_ptr = temp_ptr[].next_ptr
        else:
            var temp_ptr = self.tail
            while temp_ptr:
                result += repr(temp_ptr[].data[]) + ", "
                temp_ptr = temp_ptr[].prev_ptr
        result += "]"
        # print(result)
        return result
            

from testing import assert_true, assert_equal

fn test_mylinkedlist() raises:
    var ll = MyLinkedList[Int]()
    ll.append(5)
    ll.append(10)
    ll.append(20)
    ll.append(30)
    ll.append(40)
    ll.prepend(-5)
    ll.prepend(-10)
    ll.prepend(-20)
    ll.prepend(-30)
    ll.prepend(-40)

    print(ll.__str__(backward=False))
    print(ll.__str__(backward=True))


def main():
    test_mylinkedlist()
