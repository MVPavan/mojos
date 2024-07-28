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

@value
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



struct MyLinkedList[T:RepresentableCollectionElement]:
    alias Node_Ptr = UnsafePointer[Node[T]]
    var head:Self.Node_Ptr
    var tail:Self.Node_Ptr

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
            var new_node = self.Node_Ptr.alloc(1)
            initialize_pointee_move(new_node, Node[T](value))
            self.tail[].next_ptr = new_node
            new_node[].prev_ptr = self.tail
            self.tail = new_node

        var temp_ptr = self.head
        var result:String = "[ " 
        while temp_ptr:
            result += repr(temp_ptr[].data[]) + ", "
            temp_ptr = temp_ptr[].next_ptr
        result += "]"
        print(result)

    # @staticmethod
    fn __str__(self, backward:Bool=False) ->String:
        var temp_ptr = self.head
        var result:String = "[ " 
        # while temp_ptr:
        #     result += repr(temp_ptr[].data[]) + ", "
        #     temp_ptr = temp_ptr[].next_ptr
        result += "]"
        # print(result)
        return result
            

from testing import assert_true, assert_equal

fn test_mylinkedlist() raises:
    var k = Node[Int]()
    var ll = MyLinkedList[Int]()
    ll.append(5)
    ll.append(12)
    ll.append(20)
    ll.append(42)
    # ll.prepend(3)
    ll.append(51)
    ll.append(67)
    ll.append(84)
    ll.append(51)
    ll.append(67)
    ll.append(84)
    print(ll.__str__())
    ll.append(0)
    print(ll.__str__(backward=True))


def main():
    test_mylinkedlist()


# var h = self.head[]
# var t = self.tail[]
# var ht = h.next_ptr[]
# var th = t.prev_ptr[]
# print("wow")
# var h1=h
# var t1=t
# var ht1 = ht
# var th1 = th