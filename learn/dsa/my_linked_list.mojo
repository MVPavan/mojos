from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)


struct Node[T:CollectionElement]:
    var data:UnsafePointer[T]
    # var next_ptr:Reference[Self, True, __lifetime_of()]
    # var prev_ptr:Reference[Self, True, __lifetime_of()]
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
    
    fn 



struct MyLinkedList[T:RepresentableCollectionElement]:
    var head:Node[T]
    var tail:Node[T]

    fn __init__(inout self):
        self.head = Node[T]()
        self.tail = Node[T]()
    
    fn append(inout self, owned value:T):
        var new_node = Node[T](value)

        if not self.head.data:
            self.head = new_node
            self.tail = new_node
        else:
            var k = self.tail[]
            new_node.prev_ptr = Reference[self.tail,_,_]
            self.tail.next_ptr = new_node
            self.tail = new_node

    fn prepend(inout self, owned value:T):
        var new_node = Node[T](value)

        if not self.head.data:
            self.head = new_node
            self.tail = new_node
        else:
            new_node.next_ptr = self.head
            self.head.prev_ptr = new_node
            self.head = new_node
    
    fn display(self:MyLinkedList[T], backward:Bool=False) ->String:
        var current_node = Node[T]()
        var result:String = "[ " 
        if not backward:
            current_node=self.head
            while current_node.next_ptr:
                result += repr(current_node.data[]) + ", "
                current_node = current_node.next_ptr[]
        else:
            var current_node=self.tail
            while current_node.prev_ptr:
                result += repr(current_node.data[]) + ", "
                current_node = current_node.prev_ptr[]

        return result
            


from testing import assert_true, assert_equal

fn test_mylinkedlist() raises:
    var ll = MyLinkedList[Int]()
    ll.append(5)
    ll.append(12)
    ll.append(20)
    ll.append(42)
    ll.prepend(3)
    ll.append(51)

    print(ll.display())
    print(ll.display(backward=True))


def main():
    test_mylinkedlist()