from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)
from mytype import MyType
from testing import assert_true


# trait QType(CollectionElement, EqualityComparable, RepresentableCollectionElement):
#     pass
alias QType = MyType

alias DEBUG_DELETE = True


struct Node[T:QType]:
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


struct MyQueueLL[T:QType](CollectionElement, Boolable):
    alias Node_Ptr = UnsafePointer[Node[T]]
    var head:Self.Node_Ptr
    var tail:Self.Node_Ptr
    var size:UInt16
    
    fn __init__(inout self):
        self.head = self.Node_Ptr()
        self.tail = self.Node_Ptr()
        self.size = 0

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
        if self.tail:
            var temp_ptr = self.tail[].prev_ptr
            while temp_ptr:
                self.destroy_and_free(temp_ptr[].next_ptr)
                temp_ptr = temp_ptr[].prev_ptr
            self.tail = temp_ptr
        self.destroy_and_free(self.head)
    
    @always_inline
    fn len(self) -> UInt16:
        var _len = 0
        var temp_ptr = self.head
        while temp_ptr:
            _len += 1
            temp_ptr = temp_ptr[].next_ptr
        return _len
    
    @always_inline
    fn is_empty(self) -> Bool:
        return self.size==0
    
    fn appendleft(inout self, owned value:T):
        if not self.tail:
            self.tail = self.tail.alloc(1)
            initialize_pointee_move(self.tail, Node[T](value))
            self.head = self.tail
        else:
            self.head[].prev_ptr = self.head[].prev_ptr.alloc(1)
            initialize_pointee_move(self.head[].prev_ptr, Node[T](value))
            self.head[].prev_ptr[].next_ptr = self.head
            self.head = self.head[].prev_ptr
        
        # self.size = self.len()
        self.size += 1

    fn appendright(inout self, owned value:T):
        if not self.head:
            self.head = self.head.alloc(1)
            initialize_pointee_move(self.head, Node[T](value))
            self.tail = self.head
        else:
            self.tail[].next_ptr = self.tail[].next_ptr.alloc(1)
            initialize_pointee_move(self.tail[].next_ptr, Node[T](value))
            self.tail[].next_ptr[].prev_ptr = self.tail
            self.tail = self.tail[].next_ptr
        
        self.size += 1

    fn popleft(inout self) raises -> T:
        if self.size == 0:
            raise Error("Index Error - Empty Queue")
        var value = move_from_pointee(self.head[].data)
        if self.size > 1:
            self.head = self.head[].next_ptr
            self.destroy_and_free(self.head[].prev_ptr)
        else:
            self.destroy_and_free(self.head)
            self.tail = self.Node_Ptr()
        self.size -= 1
        return value^
    
    
    fn popright(inout self) raises -> T:
        if self.size == 0:
            raise Error("Index Error - Empty Queue")
        var value = move_from_pointee(self.tail[].data)
        if self.size > 1:
            self.tail = self.tail[].prev_ptr
            self.destroy_and_free(self.tail[].next_ptr)
        else:
            self.destroy_and_free(self.tail)
            self.head = self.Node_Ptr()
        self.size -= 1
        return value^
    
    fn extendright(inout self, existing:Self):
        if existing.head:
            var temp_ptr = existing.head
            while temp_ptr:
                self.appendright(temp_ptr[].data[])
                temp_ptr = temp_ptr[].next_ptr
        elif existing.tail:
                self.appendright(existing.tail[].data[])
    
    fn extendleft(inout self, existing:Self):
        if existing.tail:
            var temp_ptr = existing.tail
            while temp_ptr:
                self.appendleft(temp_ptr[].data[])
                temp_ptr = temp_ptr[].prev_ptr
        elif existing.head:
                self.appendleft(existing.head[].data[])
    
    fn __copyinit__(inout self, existing:Self):
        self = Self()
        self.extendleft(existing)

    fn __moveinit__(inout self, owned existing:Self):
        self = Self()
        if existing.head:
            while existing.head:
                self.appendright(move_from_pointee(existing.head[].data))
                existing.head = existing.head[].next_ptr
        elif existing.tail:
                self.appendright(move_from_pointee(existing.tail[].data))
    
    fn insert(inout self, value:T, idx:UInt16) -> Bool:
        if  not (idx > 0 and idx < self.size) :
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

    fn remove(inout self, value:T) -> Bool:
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

    fn reverse(inout self):
        if self.head:
            var temp_ptr = self.head
            while temp_ptr:
                swap(temp_ptr[].next_ptr, temp_ptr[].prev_ptr)
                temp_ptr = temp_ptr[].prev_ptr # going back because of swap
            swap(self.head, self.tail)

    fn rotate(inout self, owned n:Int16):
        if n==0 or not self.head: return
        self.head[].prev_ptr = self.tail
        self.tail[].next_ptr = self.head
        n = (abs(n) % int(self.size))*(n/abs(n))
        var temp_ptr = self.head
        if n<0:
            for _ in range(0,abs(n)):
                temp_ptr = temp_ptr[].next_ptr
        else:
            for _ in range(0,abs(n)):
                temp_ptr = temp_ptr[].prev_ptr
        self.head = temp_ptr
        self.tail = self.head[].prev_ptr
        self.head[].prev_ptr = self.Node_Ptr()
        self.tail[].next_ptr = self.Node_Ptr()

    fn clear(inout self) :
        self.__del__()
        self = Self()
    
    fn clear_explicit(inout self) :
        if self.size==0: return
        elif self.size == 1:
            self.destroy_and_free(self.head)
            self.tail = self.head
        else:
            var temp_ptr = self.tail[].prev_ptr
            while temp_ptr:
                self.destroy_and_free(temp_ptr[].next_ptr)
                temp_ptr = temp_ptr[].prev_ptr
            self.tail = temp_ptr
            self.destroy_and_free(self.head)
        self.__init__()

    fn __str__(self) -> String:
        var result:String = "[ " 
        var temp_ptr = self.head
        while temp_ptr:
            result += repr(temp_ptr[].data[]) + ", "
            temp_ptr = temp_ptr[].next_ptr
        result += "]"
        return result
    
    fn __bool__(self) -> Bool:
        return not self.size==0

alias MyQueue = MyQueueLL

def test_queue_initialization():
    q = MyQueue[Int]()
    assert_true(q.len() == q.size)
    assert_true(q.is_empty())
    assert_true(q.len() == 0)
    print(q.__str__())
    assert_true(q.len() == q.size)
    print("test_queue_initialization passed.")

def test_appendleft_and_popleft():
    q = MyQueue[Int]()
    q.appendleft(10)
    assert_true(not q.is_empty())
    assert_true(q.len() == 1)
    print(q.__str__())
    assert_true(q.len() == q.size)
    
    q.appendleft(20)
    assert_true(q.len() == 2)
    print(q.__str__())
    assert_true(q.len() == q.size)
    
    q.print_memory()
    
    value = q.popleft()
    assert_true(value == 20)
    assert_true(q.len() == 1)
    print(q.__str__())
    assert_true(q.len() == q.size)
    
    q.print_memory()
    
    value = q.popleft()
    assert_true(value == 10)
    assert_true(q.is_empty())
    print(q.__str__())
    assert_true(q.len() == q.size)

    print("test_appendleft_and_popleft passed.")

def test_appendright_and_popright():
    q = MyQueue[Int]()
    q.appendright(10)
    assert_true(not q.is_empty())
    assert_true(q.len() == 1)
    print(q.__str__())
    assert_true(q.len() == q.size)
    
    q.appendright(20)
    assert_true(q.len() == 2)
    print(q.__str__())
    assert_true(q.len() == q.size)

    q.print_memory()

    value = q.popright()
    assert_true(value == 20)
    assert_true(q.len() == 1)
    print(q.__str__())
    assert_true(q.len() == q.size)
    
    q.print_memory()

    value = q.popright()
    assert_true(value == 10)
    assert_true(q.is_empty())
    print(q.__str__())
    assert_true(q.len() == q.size)
    print("test_appendright_and_popright passed.")

def test_mixed_operations():
    q = MyQueue[Int]()
    q.appendleft(14)
    q.appendright(16)
    q.appendleft(10)
    q.appendright(20)
    q.appendleft(5)
    q.appendright(25)
    assert_true(q.len() == 6)
    print(q.__str__())
    assert_true(q.len() == q.size)
    
    print("Popping: ", 5)
    value = q.popleft()
    assert_true(value == 5)
    assert_true(q.len() == 5)
    print(q.__str__())
    assert_true(q.len() == q.size)
    

    print("Popping: ", 25)
    value = q.popright()
    assert_true(value == 25)
    assert_true(q.len() == 4)
    print(q)
    assert_true(q.len() == q.size)

    q1 = q
    print("Copy: ", q1)

    q2 = q1^
    print("Move: ", q2)

    q.clear()
    assert_true(q.len() == q.size)
    print("clear q: ", q)

    _ = q2.popright()
    q.extendleft(q2)
    print("Extended left: ", q2, q)
    _ = q2.popleft()
    q.extendright(q2)
    print("Extended right: ", q2, q)
    _ = q2.popright()
    q.extendleft(q2)
    print("Extended left: ", q2, q)
    q.insert(100,3)
    print("Insert 100 at idx 3: ",q)
    print("contains 100: ", q.contains(100))
    print("contains 200: ", q.contains(200))
    print("Idx of 100: ", q.find(100))
    print("Idx of 200: ", q.find(200))
    q.reverse()
    print("reverse:", q)
    q.rotate(3)
    print("rotate 3:", q)
    q.rotate(-3)
    print("rotate -3:", q)
    q.remove(100)
    print("Remove 100 : ",q)
    q.clear()
    q2.clear()
    print("clear all: ",q2,q)
    print("test_mixed_operations passed.")

def test_empty_pop():
    q = MyQueue[Int]()
    try:
        q.popleft()
    except Error:
        assert_true(True)
    else:
        assert_true(False)
    
    try:
        q.popright()
    except Error:
        assert_true(True)
    else:
        assert_true(False)
    print("test_empty_pop passed.")


def test_move():
    q = MyQueue[Int]()
    q.appendleft(14)
    q.appendright(16)
    q.print_memory()
    q1 = q^
    q1.print_memory()
    print(q1)

def main():
    # Run tests
    # test_queue_initialization()
    # test_appendleft_and_popleft()
    # test_appendright_and_popright()
    # test_mixed_operations()
    # test_empty_pop()
    test_move()
