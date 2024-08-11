from collections import List
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

alias NTreeType = MyType

alias DEBUG_DELETE = True

struct TNode[T:NTreeType]:
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
        self.children = List[UnsafePointer[Self]]()
        self.data = UnsafePointer[T]()
        if DEBUG_DELETE:
            print("Nulling TNode ptrs: ",self.data)
            for child_ptr in self.children:
                print(child_ptr[])
    
    fn __str__(self) -> String:
        return repr(self.data[])


struct MyNTree[T:NTreeType]:
    alias Node_Ptr = UnsafePointer[TNode[T]]
    alias SizeType = UInt16
    var root:Self.Node_Ptr
    # var size:UInt16
    
    fn __init__(inout self, value:T):
        self.root = self.Node_Ptr()
        self.root = self.root.alloc(1)
        initialize_pointee_move(self.root, TNode[T](value))

    fn find(self, node_ptr:Self.Node_Ptr, value:T) -> Self.Node_Ptr:
        if not node_ptr: return Self.Node_Ptr()

        if node_ptr[].data[]==value:
            return node_ptr
        
        for child in node_ptr[].children:
            var found = self.find(child[], value)
            if found:
                return found

        return Self.Node_Ptr()
    
    fn contains(self, value:T) -> Bool:
        var found_node = self.find(node_ptr=self.root, value=value)
        if found_node:
            return True
        else:
            return False
    
    fn add_child_using_data(self, parent_data:T, child_data:T):
        var parent_node = self.find(self.root, parent_data)
        if parent_node:
            var temp_node = self.Node_Ptr.alloc(1)
            initialize_pointee_move(temp_node, TNode[T](child_data))
            parent_node[].children.append(temp_node)
        else:
            print("Parent data not found: ", repr(parent_data))
    
    fn total_nodes(self, node_ptr:Self.Node_Ptr) -> Self.SizeType:
        if node_ptr:
            var counter:self.SizeType = 1
            for child in node_ptr[].children:
                counter += self.total_nodes(child[])
            return counter
        else:
            return 0
    
    fn pre_order_traversal(self, node_ptr:Self.Node_Ptr)->List[T]:
        var nodes_list = List[T]()
        if not node_ptr: return nodes_list
        nodes_list.append(node_ptr[].data[])
        for child in node_ptr[].children:
            nodes_list += self.pre_order_traversal(child[])
        return nodes_list
    
    fn post_order_traversal(self, node_ptr:Self.Node_Ptr)->List[T]:
        var nodes_list = List[T]()
        if not node_ptr: return nodes_list
        for child in node_ptr[].children:
            nodes_list += self.post_order_traversal(child[])
        nodes_list.append(node_ptr[].data[])
        return nodes_list
    
    fn level_order_traversal(self, node_ptr:Self.Node_Ptr, reverse:Bool=False)->List[T]:
        var nodes_list = List[T]()
        if not node_ptr: return nodes_list
        var _q = List[Int]()
        var temp_ptr:Self.Node_Ptr
        _q.append(int(node_ptr))
        while _q:
            temp_ptr = self.Node_Ptr(address = _q.pop(0))
            nodes_list.append(temp_ptr[].data[])
            for child in temp_ptr[].children:
                _q.append(int(child[]))
        if reverse:
            nodes_list.reverse()
        return nodes_list
    
    fn reverse_level_order_traversal(self, node_ptr:Self.Node_Ptr)->List[T]:
        var nodes_list = List[T]()
        if not node_ptr: return nodes_list
        var _q = List[Int]()
        var _stack = List[Int]()
        var temp_ptr:Self.Node_Ptr
        var addr:Int
        _q.append(int(node_ptr))
        while _q:
            addr = _q.pop(0)
            _stack.append(addr)
            temp_ptr = self.Node_Ptr(address = addr)
            for child in temp_ptr[].children:
                _q.append(int(child[]))
        while _stack:
            nodes_list.append(self.Node_Ptr(address = _stack.pop(-1))[].data[])
        return nodes_list
        
    fn print_tree(self, node_ptr:Self.Node_Ptr, owned prefix:String='', is_last:Bool=True):
        var connector:String = '└── ' if is_last else '|── '
        if is_last:
            prefix += "     "
        else:
            prefix += "|    "
        print(prefix+connector+repr(node_ptr[].data[]))
        var child_count = len(node_ptr[].children)
        for i in range(child_count):
            self.print_tree(
                node_ptr = node_ptr[].children[i],
                prefix = prefix,
                is_last = i==(child_count-1)
            )

# Define the test cases
fn test_initialization() raises:
    var tree = MyNTree[Int](value=1)
    assert_true(tree.root[].data[] == 1, "Root node should be initialized with value 1")

fn test_add_child() raises:
    var tree = MyNTree[Int](value=1)
    tree.add_child_using_data(parent_data=1, child_data=2)
    assert_true(len(tree.root[].children) == 1, "Root should have 1 child")
    assert_true(tree.root[].children[0][].data[] == 2, "Child node should have value 2")

fn test_find_existing_node() raises:
    var tree = MyNTree[Int](value=1)
    tree.add_child_using_data(parent_data=1, child_data=2)
    var found_node = tree.find(tree.root, 2)
    assert_true(found_node[].data[] == 2, "TNode with value 2 should be found")

fn test_find_non_existing_node() raises:
    var tree = MyNTree[Int](value=1)
    var found_node = tree.find(tree.root, 99)
    assert_true(found_node == MyNTree[Int].Node_Ptr(), "TNode with value 99 should not be found")

fn test_print_tree():
    var tree = MyNTree[Int](value=1)
    tree.add_child_using_data(parent_data=1, child_data=10)
    tree.add_child_using_data(parent_data=1, child_data=11)
    tree.add_child_using_data(parent_data=1, child_data=12)
    tree.add_child_using_data(parent_data=1, child_data=13)
    tree.add_child_using_data(parent_data=11, child_data=111)
    tree.add_child_using_data(parent_data=111, child_data=1111)
    tree.add_child_using_data(parent_data=111, child_data=1112)
    tree.add_child_using_data(parent_data=111, child_data=1113)
    tree.add_child_using_data(parent_data=11, child_data=112)
    tree.add_child_using_data(parent_data=11, child_data=113)
    tree.add_child_using_data(parent_data=11, child_data=114)
    tree.add_child_using_data(parent_data=12, child_data=121)
    tree.add_child_using_data(parent_data=121, child_data=1211)
    tree.add_child_using_data(parent_data=121, child_data=1212)

    print("Total nodes: ",tree.total_nodes(tree.root))
    tree.print_tree(tree.root)
    print("Pre order traversal: ")
    print(tree.pre_order_traversal(tree.root).__str__())
    print("Post order traversal: ")
    print(tree.post_order_traversal(tree.root).__str__())
    print("Level order traversal: ")
    print(tree.level_order_traversal(tree.root).__str__())
    print("Reverse Level order traversal: ")
    print(tree.level_order_traversal(tree.root, reverse=True).__str__())
    print("Reverse Level order traversal: ")
    print(tree.reverse_level_order_traversal(tree.root).__str__())
    # print("Total nodes: ",tree.total_nodes(tree.root))
    # tree.print_tree(tree.root)
    # Expected Output:
    # └── 1
    #     ├── 2
    #     │   └── 4
    #     └── 3
    # Note: This output would need to be manually verified as it prints to the console.

def main():
    # Execute the test cases
    # test_initialization()
    # test_add_child()
    # test_find_existing_node()
    # test_find_non_existing_node()
    test_print_tree()
    print("Finished")


