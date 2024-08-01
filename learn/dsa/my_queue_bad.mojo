from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)
from my_linked_list import MyLinkedList
from testing import assert_true


trait QType(CollectionElement, EqualityComparable, RepresentableCollectionElement):
    pass

# enqueue, dequeue, peek, is_empty, size
struct MyQueueArr[T:QType]:
    var data:UnsafePointer[T]
    var size:Int
    var capacity:Int

    fn __init__(inout self,):
        self.data = UnsafePointer[T]()
        self.size = 0
        self.capacity = 0
    
    @always_inline
    fn __del__(owned self):
        for i in range(self.size):
            destroy_pointee(self.data + i)
        if self.data:
            self.data.free()

    fn enqueue(inout self, owned value:T):
        if self.size>=self.capacity:
            self._realloc(max(1,self.capacity*2))
        initialize_pointee_move(self.data+self.size, value^)
        self.size += 1

    fn dequeue(inout self) raises-> T:
        if self.size==0:
            raise Error("Dequeuing empty queue, aborting ...")

        var value = move_from_pointee(self.data)
        # this is wrong, should not deallocate entire block of memory!
        if self.data:
            self.data.free()
        self.data = self.data+1
        self.size -= 1
        return value
    
    fn peek(self) -> T:
        return self.data[]
    
    fn len(self) -> Int:
        return self.size
    
    fn is_empty(self) -> Bool:
        return not self.size>0

    fn __copyinit__(inout self, existing: Self):
        self = Self()
        for i in range(existing.size):
            self.enqueue((existing.data+i)[])

    fn __moveinit__(inout self, owned existing: Self):
        self.data = existing.data
        self.size = existing.size
        self.capacity = existing.capacity

    fn __len__(self) -> Int:
        return self.size
    
    fn __str__(self) -> String:
        var result:String = "[ "
        for i in range(self.size):
            result += repr((self.data+i)[]) + ", "
        result = result + " ]"
        return result
    
    fn __repr__(self)->String:
        return self.__str__()
    
    fn _realloc(inout self, new_capcity:Int):
        var new_data = UnsafePointer[T].alloc(new_capcity)
        for i in range(self.size):
            move_pointee(src=self.data+i, dst=new_data+i)
        
        if self.data:
            self.data.free()
        self.data = new_data
        self.capacity = new_capcity


alias MyQueue = MyQueueArr

fn test_initialization() raises:
    var queue = MyQueue[Int]()
    assert_true(queue.len() == 0, "Queue length should be 0 after initialization")
    assert_true(queue.is_empty() == True, "Queue should be empty after initialization")

fn test_enqueue() raises:
    var queue = MyQueue[Int]()
    queue.enqueue(1)
    assert_true(queue.len() == 1, "Queue length should be 1 after enqueuing one item")
    assert_true(queue.peek() == 1, "Peek should return the enqueued value")
    queue.enqueue(2)
    assert_true(queue.len() == 2, "Queue length should be 2 after enqueuing another item")
    assert_true(queue.peek() == 1, "Peek should return the first enqueued value")

fn test_dequeue() raises:
    var queue = MyQueue[Int]()
    queue.enqueue(1)
    queue.enqueue(2)
    var value = queue.dequeue()
    assert_true(value == 1, "Dequeued value should be 1")
    assert_true(queue.len() == 1, "Queue length should be 1 after dequeue")
    assert_true(queue.peek() == 2, "Peek should return the next value after dequeue")
    value = queue.dequeue()
    assert_true(value == 2, "Dequeued value should be 2")
    assert_true(queue.len() == 0, "Queue length should be 0 after dequeueing all items")
    assert_true(queue.is_empty() == True, "Queue should be empty after dequeueing all items")

fn test_peek() raises:
    var queue = MyQueue[Int]()
    queue.enqueue(1)
    queue.enqueue(2)
    assert_true(queue.peek() == 1, "Peek should return the first element without removing it")
    _ = queue.dequeue()
    assert_true(queue.peek() == 2, "Peek should return the next element after dequeue")

fn test_queue_expansion() raises:
    var queue = MyQueue[Int]()
    for i in range(10):  #// Assuming initial capacity is less than 10
        queue.enqueue(i)
    print((queue.data+2)[])
    assert_true(queue.len() == 10, "Queue length should be 10 after enqueuing 10 items")
    assert_true(queue.peek() == 0, "Peek should return the first element")
    print("Queue: ", queue.__str__())

fn test_copy_initialization() raises:
    var original = MyQueue[Int]()
    original.enqueue(1)
    original.enqueue(2)
    var copy = MyQueue[Int]()
    copy = original
    assert_true(copy.len() == 2, "Copy should have length 2")
    assert_true(copy.peek() == 1, "Peek on copy should return the first element")
    assert_true(copy.dequeue() == 1, "Dequeue on copy should return the first element")
    assert_true(copy.peek() == 2, "Peek on copy after dequeue should return the second element")

fn test_move_initialization() raises:
    var original = MyQueue[Int]()
    original.enqueue(1)
    original.enqueue(2)
    var moved = MyQueue[Int]()
    moved = original^

    # assert_true(original.len() == 0, "Original queue should be empty after move")
    assert_true(moved.len() == 2, "Moved queue should have length 2")
    assert_true(moved.peek() == 1, "Peek on moved queue should return the first element")

fn test_string_representation() raises:
    var queue = MyQueue[Int]()
    queue.enqueue(1)
    queue.enqueue(2)
    queue.enqueue(3)
    queue.enqueue(4)
    queue.enqueue(5)
    queue.enqueue(6)
    _=queue.dequeue()
    var str = queue.__str__()
    print(str)
    # assert_true(str == "[ 1, 2, ]", "String representation of the queue is incorrect")

fn test_dequeue_from_empty_queue() raises:
    var queue = MyQueue[Int]()
    try:
        _ = queue.dequeue()
        assert_true(False, "Should have raised an error when dequeuing from an empty queue")
    except:
        assert_true(True, "Expected exception when dequeuing from an empty queue")

fn test_peek_from_empty_queue() raises:
    var queue = MyQueue[Int]()
    try:
        print(queue.peek())
        assert_true(False, "Should have raised an error when peeking from an empty queue")
    except:
        assert_true(True, "Expected exception when peeking from an empty queue")

# // Run all test cases
def main():
    test_initialization()
    test_enqueue()
    test_dequeue()
    test_peek()
    test_queue_expansion()
    test_copy_initialization()
    test_move_initialization()
    test_string_representation()
    test_dequeue_from_empty_queue()
    test_peek_from_empty_queue()
