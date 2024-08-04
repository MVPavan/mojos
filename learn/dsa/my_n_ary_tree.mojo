from collections import List
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

trait NTreeType(CollectionElement, EqualityComparable, RepresentableCollectionElement):
    pass

alias DEBUG_DELETE = True

struct Node[T:NTreeType]:
    var data:UnsafePointer[T]
    var children:List[UnsafePointer[Self]]

    fn __init__(inout self):
        self.data = UnsafePointer[T]()
        self.children = List[UnsafePointer[Self]]()

    fn __init__(inout self, owned value:T):
        self = Self()
        self.data = self.data.alloc(1)
        initialize_pointee_copy(self.data, value)
    
    fn __copyinit__(inout self, existing:Self):
        self = Self(value=existing.data[])
        self.children = existing.children
    
    fn __moveinit__(inout self, owned existing:Self):
        self = Self()
        self.data = self.data.alloc(1)
        move_pointee(src=existing.data, dst=self.data)
        self.children = existing.children^
    
    fn add_children(inout self, child_ptr:UnsafePointer[Self]):
        self.children.append(child_ptr)


    @always_inline
    fn __del__(owned self):
        if self.data:
            if DEBUG_DELETE:
                print("deleting and freeing data: ", self.data, repr(self.data[]))
            destroy_pointee(self.data)
            self.data.free()
        self.children = List[UnsafePointer[T]]()
        self.data = UnsafePointer[T]()
        if DEBUG_DELETE:
            print("Nulling Node ptrs: ",self.data)
            for child_ptr in self.children:
                print(child_ptr[])
    
    fn __str__(self) -> String:
        return repr(self.data[])


struct MyNTree[T:NTreeType]:
    alias Node_Ptr = UnsafePointer[Node[T]]
    var root:Self.Node_Ptr
    var size:UInt16
    
    fn __init__(inout self, value:T):
        self.root = self.Node_Ptr()
        self.root = self.root.alloc(1)
        initialize_pointee_move(self.root, Node[T](value))
        self.size = 0

    fn find(self, node_ptr:Self.Node_Ptr, value:T) -> Self.Node_Ptr:
        if not node_ptr: return Self.Node_Ptr()

        if node_ptr[].data[]==value:
            return node_ptr
        
        for child in node_ptr[].children:
            var found = self.find(child[], value)
            if found:
                return found

        return Self.Node_Ptr()
    
    fn add_child_using_data(self, parent_data:T, child_data:T):
        var parent_node = self.find(self.root, parent_data)
        if parent_node:
            var temp_node = self.Node_Ptr.alloc(1)
            initialize_pointee_copy(temp_node, Node[T](child_data))
            parent_node[].children.append(temp_node)
        else:
            print("Parent data not found: ", repr(parent_data))