from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)
# from benchmark import keep

alias DEBUG_DELETE = False

trait LLType(CollectionElement, EqualityComparable, RepresentableCollectionElement):
    pass

struct Node[T:LLType]:
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
        if self.data:
            if DEBUG_DELETE:
                print("deleting and freeing data: ", self.data, repr(self.data[]))
            destroy_pointee(self.data)
            self.data.free()
        self.next_ptr = UnsafePointer[Self]()
        self.prev_ptr = UnsafePointer[Self]()
        self.data = UnsafePointer[T]()
        if DEBUG_DELETE:
            print("Nulling Node ptrs: ",self.data, self.prev_ptr, self.next_ptr)
    

    fn __str__(self) -> String:
        return repr(self.data[])

struct MyLinkedList[T:LLType]:
    alias Node_Ptr = UnsafePointer[Node[T]]
    var head:Self.Node_Ptr
    var tail:Self.Node_Ptr

    @always_inline    
    @staticmethod
    fn destroy_and_free(inout ptr:Self.Node_Ptr):
        if ptr:
            if DEBUG_DELETE:
                print("deleting node: ", ptr)
            destroy_pointee(ptr)
            if DEBUG_DELETE:
                print("Freeing node: ", ptr)
            ptr.free()
            ptr = Self.Node_Ptr()
            if DEBUG_DELETE:
                print("Nulling node ptr: ", ptr)
    
    @always_inline
    fn print_memory(self):
        if DEBUG_DELETE: 
            var temp_ptr = self.head
            while temp_ptr:
                print("node: ", temp_ptr, temp_ptr[].data, temp_ptr[].prev_ptr, temp_ptr[].next_ptr)
                temp_ptr = temp_ptr[].next_ptr


    @always_inline
    fn __del__(owned self):
        self.print_memory()
        var temp_ptr = self.tail[].prev_ptr
        while temp_ptr:
            self.destroy_and_free(temp_ptr[].next_ptr)
            temp_ptr = temp_ptr[].prev_ptr
        self.destroy_and_free(self.head)


    fn __init__(inout self):
        self.head = self.Node_Ptr()
        self.tail = self.Node_Ptr()
    
    fn append(inout self, owned value:T):
        if not self.head:
            self.head = self.head.alloc(1)
            initialize_pointee_move(self.head, Node[T](value))
            self.tail = self.head
            # self.head = self.Node_Ptr.address_of(Node[T](value))
        # elif not self.tail:
        #     self.tail = self.tail.alloc(1)
        #     initialize_pointee_move(self.tail, Node[T](value))
        #     # self.tail = self.Node_Ptr.address_of(Node[T](value))
        #     self.head[].next_ptr = self.tail
        #     self.tail[].prev_ptr = self.head
        else:
            self.tail[].next_ptr = self.tail[].next_ptr.alloc(1)
            initialize_pointee_move(self.tail[].next_ptr, Node[T](value))
            self.tail[].next_ptr[].prev_ptr = self.tail
            self.tail = self.tail[].next_ptr

    fn prepend(inout self, owned value:T):
        if not self.tail:
            self.tail = self.tail.alloc(1)
            initialize_pointee_move(self.tail, Node[T](value))
            self.head = self.tail
        # elif not self.head:
        #     self.head = self.head.alloc(1)
        #     initialize_pointee_move(self.head, Node[T](value))
        #     self.head[].next_ptr = self.tail
        #     self.tail[].prev_ptr = self.head
        else:
            self.head[].prev_ptr = self.head[].prev_ptr.alloc(1)
            initialize_pointee_move(self.head[].prev_ptr, Node[T](value))
            self.head[].prev_ptr[].next_ptr = self.head
            self.head = self.head[].prev_ptr

    fn insert(inout self, value:T, idx:Int) -> Bool:
        if  not 0 < idx < self.size():
            print("Insert index out of size, should be between 0 and len-1")
            return False
        
        var temp_ptr = self.head
        for _ in range(idx-1):
            temp_ptr = temp_ptr[].next_ptr
        
        var new_node = self.Node_Ptr.alloc(1)
        initialize_pointee_move(new_node, Node[T](value))
        new_node[].next_ptr = temp_ptr[].next_ptr
        new_node[].prev_ptr = temp_ptr
        temp_ptr[].next_ptr[].prev_ptr = new_node
        temp_ptr[].next_ptr = new_node
        return True

    fn delete(inout self, value:T) -> Bool:
        var temp_ptr = self.head
        while temp_ptr:
            if temp_ptr[].data[] == value:
                temp_ptr[].prev_ptr[].next_ptr = temp_ptr[].next_ptr
                temp_ptr[].next_ptr[].prev_ptr = temp_ptr[].prev_ptr
                self.destroy_and_free(temp_ptr)
                return True
            temp_ptr = temp_ptr[].next_ptr
        return False
    
    @always_inline
    fn contains(self, value:T) -> Bool:
        var idx = self.find(value)
        if idx>=0:
            return True
        return False

    fn find(self, value:T) -> Int:
        var idx:Int = -1
        var temp_ptr = self.head
        while temp_ptr:
            idx += 1
            if temp_ptr[].data[] == value:
                return idx
            temp_ptr = temp_ptr[].next_ptr
        return -1
    
    fn __str__(self, backward:Bool=False) -> String:
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
        return result
    
    
    @always_inline
    fn size(self) -> Int:
        var _len = 0
        var temp_ptr = self.head
        while temp_ptr:
            _len += 1
            temp_ptr = temp_ptr[].next_ptr
        return _len
            

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

    print(ll.__str__())
    print(ll.__str__(backward=True))
    print(ll.size())

    print("Delete: ", ll.delete(10))
    print(ll.__str__())
    print(ll.size())

    print("Insert: ", ll.insert(value=108, idx=5))
    print(ll.__str__())
    print(ll.size())


def main():
    test_mylinkedlist()
