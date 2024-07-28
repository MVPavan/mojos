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

# @value
struct Node[T:CollectionElement]:
    var data:UnsafePointer[T]
    var next_ptr:UnsafePointer[Self]
    var prev_ptr:UnsafePointer[Self]

    fn __init__(inout self):
        self.data = self.data.alloc(1)
        self.next_ptr = UnsafePointer[Self]()
        self.prev_ptr = UnsafePointer[Self]()

    fn __init__(inout self, owned value:T):
        # self = Self()
        self.data = self.data.alloc(1)
        initialize_pointee_move(self.data, value^)
        self.next_ptr = UnsafePointer[Self]()
        self.prev_ptr = UnsafePointer[Self]()
    
    fn __copyinit__(inout self, existing:Self):
        # self = Self(value=existing.data[])
        self.data = existing.data
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
        var new_node = self.Node_Ptr.alloc(1)
        # (Node[T]value)
        var k = Reference(new_node)
        print("wow")
        var s = k
        var k1 = Reference(new_node)

        # if not self.tail.data:
        #     self.tail = Node[T](value)
        #     self.head.next_ptr = self.tail
        #     self.tail.prev_ptr = self.head
        # else:
        #     var temp_node = Node[T](value)
        #     var k = Reference(temp_node)
        #     # move_pointee(self.tail
        #     # self.tail = 
        #     self.tail.prev_ptr = temp_node
        #     temp_node.next_ptr = k
        # print("here")
        # var k = new_node.data[]

    
    # fn append_old(inout self, owned value:T):
    #     var new_node = Node[T](value)
    #     if not self.head.data:
    #         self.head = new_node
    #         # self.tail = new_node
    #     else:
    #         if not self.tail.data:
    #             self.tail = new_node
    #             self.head.next_ptr = self.tail
    #             self.tail.prev_ptr = self.head
    #         else:
    #             new_node.prev_ptr = self.tail
    #             self.tail = new_node
    #     print("here")
    #     var k = new_node.data[]
        

    # fn prepend(inout self, owned value:T):
    #     var new_node = Node[T](value)

    #     if not self.head.data:
    #         self.head = new_node
    #         self.tail = new_node
    #     else:
    #         new_node.next_ptr = new_node.next_ptr.address_of(self.head)
    #         self.head.prev_ptr = self.head.prev_ptr.address_of(new_node)
    #         self.head = new_node
    
    # fn display(self:MyLinkedList[T], backward:Bool=False) ->String:
    #     var current_node = Node[T]()
    #     var result:String = "[ " 
    #     if not backward:
    #         current_node=self.head
    #         while current_node.next_ptr:
    #             result += repr(current_node.data[]) + ", "
    #             current_node = current_node.next_ptr[]
    #     else:
    #         var current_node=self.tail
    #         while current_node.prev_ptr:
    #             result += repr(current_node.data[]) + ", "
    #             current_node = current_node.prev_ptr[]

    #     return result
            


from testing import assert_true, assert_equal

fn test_mylinkedlist() raises:
    var ll = MyLinkedList[Int]()
    ll.append(5)
    ll.append(12)
    ll.append(20)
    ll.append(42)
    # ll.prepend(3)
    ll.append(51)
    ll.append(67)
    ll.append(84)

    # print(ll.display())
    # print(ll.display(backward=True))


def main():
    test_mylinkedlist()
