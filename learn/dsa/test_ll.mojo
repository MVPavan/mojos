

@value
struct Node[T:CollectionElement]:
    var value: T
    var next: Node[T]

struct LinkedList[T:CollectionElement]:
    var head: Node[T]

    fn append(inout self, value: T):
        if self.head == None:
            self.head = Node**T** (value, None)
        else:
            var current = self.head
            while current?.next != None:
                current = current?.next
            current?.next = Node**T** (value, None)

    fn print(inout self):
        var current = self.head
        while current != None:
            print(current?.value)
            current = current?.next