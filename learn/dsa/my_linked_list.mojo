from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)
from collections import Optional

struct Node[T:CollectionElement, is_mutable:Bool=True, life:AnyLifetime[is_mutable].type=MutableStaticLifetime]:
    var data:UnsafePointer[T]
    var next_ptr:Optional[Reference[Self, is_mutable, life]]
    var prev_ptr:Optional[Reference[Self, is_mutable, life]]

    fn __init__(inout self):
        self.data = UnsafePointer[T]()
        self.next_ptr = None
        self.prev_ptr = None
        # self.next_ptr = UnsafePointer[Self]()
        # self.prev_ptr = UnsafePointer[Self]()

    fn __init__(inout self, owned value:T):
        self = Self()
        self.data = self.data.alloc(1)
        initialize_pointee_move(self.data, value^)
    
    fn __copyinit__(inout self, existing:Self):
        # self = Self(value=existing.data[])
        self.data = existing.data
        self.next_ptr = existing.next_ptr
        self.prev_ptr = existing.prev_ptr


struct MyLinkedList[T:RepresentableCollectionElement]:
    var head:Node[T]
    var tail:Node[T]
    var new_node:Optional[Reference[Node[T],True,MutableStaticLifetime]]

    fn __init__(inout self):
        self.head = Node[T]()
        self.tail = Node[T]()
        self.new_node = None
    
    fn append(inout self, owned value:T):
        print("wow")
        self.new_node = Reference[Node[T],True,MutableStaticLifetime](value)

        # if not self[].head.data:
        #     self[].head = new_node
        #     self[].tail = new_node
        # else:
        #     new_node.prev_ptr = new_node.prev_ptr.address_of(self.tail)
        #     self.tail.next_ptr = self.tail.next_ptr.address_of(new_node)
        #     self[].tail = new_node

    # fn prepend(self:Reference[Self,True,_], owned value:T):
    #     var new_node = Node[T](value)

    #     if not self[].head.data:
    #         self[].head = new_node
    #         self[].tail = new_node
    #     else:
    #         new_node.next_ptr = new_node.next_ptr.address_of(self.head)
    #         self.head.prev_ptr = self.head.prev_ptr.address_of(new_node)
    #         self[].head = new_node
    
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
    # ll.append(5)
    # ll.append(12)
    # ll.append(20)
    # ll.append(42)
    # ll.prepend(3)
    # ll.append(51)

    # print(ll.display())
    # print(ll.display(backward=True))


def main():
    test_mylinkedlist()

            var k = UnsafePointer[Node[T]].alloc(1)
            var new_node_ref = Reference(new_node)
            # new_node.prev_ptr = new_node.prev_ptr.address_of(new_node)
            var t = new_node_ref[].data[]
            self.tail.next_ptr = new_node
            var y = self.tail.next_ptr[].data[]
            self.tail = new_node
            self.tail.next_ptr = k
            self.tail.next_ptr = new_node_ref
            var h = t
            var h1 = y