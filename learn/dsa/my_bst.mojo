from collections import List
from memory.unsafe_pointer import (
    UnsafePointer,
    move_pointee,
    move_from_pointee,
    initialize_pointee_copy,
    initialize_pointee_move,
    destroy_pointee
)
# from mytype import MyType
from testing import assert_true

trait MyType(CollectionElement, EqualityComparable, RepresentableCollectionElement, ComparableCollectionElement):
    pass
alias NTreeType = MyType

alias DEBUG_DELETE = True

struct BSTNode[T:NTreeType]:
    var data:UnsafePointer[T]
    var left:UnsafePointer[Self]
    var right:UnsafePointer[Self]

    fn __init__(inout self):
        self.data = UnsafePointer[T]()
        self.right = UnsafePointer[Self]()
        self.left = UnsafePointer[Self]()

    fn __init__(inout self, owned value:T):
        self = Self()
        self.data = self.data.alloc(1)
        initialize_pointee_copy(self.data, value)
    
    fn __copyinit__(inout self, existing:Self):
        self = Self(value=existing.data[])
        self.right = existing.right
        self.left = existing.left
    
    fn __moveinit__(inout self, owned existing:Self):
        self = Self()
        self.data = self.data.alloc(1)
        move_pointee(src=existing.data, dst=self.data)
        self.right = existing.right
        self.left = existing.left
    

    @always_inline
    fn __del__(owned self):
        if self.data:
            if DEBUG_DELETE:
                print("deleting and freeing data: ", self.data, repr(self.data[]))
            destroy_pointee(self.data)
            self.data.free()
        self.right = UnsafePointer[Self]()
        self.left = UnsafePointer[Self]()
        self.data = UnsafePointer[T]()
        if DEBUG_DELETE:
            print("Nulling BSTNode ptrs: ",self.left, self.data, self.right)
    
    fn __str__(self) -> Optional[String]:
        if self.data:
            return repr(self.data[])
        return


struct MyBSTree[T:NTreeType]:
    alias Node_Ptr = UnsafePointer[BSTNode[T]]
    alias SizeType = UInt16
    var root:Self.Node_Ptr
    # var size:UInt16
    
    fn __init__(inout self, value:T):
        self.root = self.Node_Ptr()
        self.root = self.root.alloc(1)
        initialize_pointee_move(self.root, BSTNode[T](value))

    fn find(self, node_ptr:Self.Node_Ptr, value:T) -> Self.Node_Ptr:
        if not node_ptr: return Self.Node_Ptr()

        if node_ptr[].data[]==value:
            return node_ptr
        var found = Self.Node_Ptr()
        if node_ptr[].left:
            found = self.find(node_ptr[].left, value)
            if found: return found
        if node_ptr[].left:
            found = self.find(node_ptr[].left, value)
            if found: return found
        return found
    
    fn contains(self, value:T) -> Bool:
        var found_node = self.find(node_ptr=self.root, value=value)
        if found_node:
            return True
        else:
            return False
    
    fn insert(self, value:T) -> Bool:
        var temp_ptr = self.root
        var _data:T
        while temp_ptr:
            _data = temp_ptr[].data[]
            if value<_data:
                if temp_ptr[].left:
                    temp_ptr = temp_ptr[].left
                else:
                    temp_ptr[].left = temp_ptr[].left.alloc(1)
                    initialize_pointee_move(temp_ptr[].left, BSTNode[T](value))
                    return True

            elif value>_data:
                if temp_ptr[].left:
                    temp_ptr = temp_ptr[].right
                else:
                    temp_ptr[].right = temp_ptr[].right.alloc(1)
                    initialize_pointee_move(temp_ptr[].right, BSTNode[T](value))
                    return True
            else:
                print("Element already exists!")
                return False
        return True        
    
    fn total_nodes(self, node_ptr:Self.Node_Ptr) -> Int:
        if node_ptr:
            var counter:Int = 1
            if node_ptr[].left:
                print(node_ptr[].left)
                print(self.total_nodes(node_ptr[].left))
                # counter = counter + self.total_nodes(node_ptr[].left)
            if node_ptr[].right:
                print(node_ptr[].right)
            #     counter += self.total_nodes(node_ptr[].right)
            print("internal: ",counter)
            return counter
        else:
            return 0
    

    # fn pre_order_traversal(self, node_ptr:Self.Node_Ptr)->List[T]:
    #     var nodes_list = List[T]()
    #     if not node_ptr: return nodes_list
    #     nodes_list.append(node_ptr[].data[])
    #     for child in node_ptr[].children:
    #         nodes_list += self.pre_order_traversal(child[])
    #     return nodes_list
    
    # fn post_order_traversal(self, node_ptr:Self.Node_Ptr)->List[T]:
    #     var nodes_list = List[T]()
    #     if not node_ptr: return nodes_list
    #     for child in node_ptr[].children:
    #         nodes_list += self.post_order_traversal(child[])
    #     nodes_list.append(node_ptr[].data[])
    #     return nodes_list
    
    # fn level_order_traversal(self, node_ptr:Self.Node_Ptr, reverse:Bool=False)->List[T]:
    #     var nodes_list = List[T]()
    #     if not node_ptr: return nodes_list
    #     var _q = List[Int]()
    #     var temp_ptr:Self.Node_Ptr
    #     _q.append(int(node_ptr))
    #     while _q:
    #         temp_ptr = self.Node_Ptr(address = _q.pop(0))
    #         nodes_list.append(temp_ptr[].data[])
    #         for child in temp_ptr[].children:
    #             _q.append(int(child[]))
    #     if reverse:
    #         nodes_list.reverse()
    #     return nodes_list
    
    # fn reverse_level_order_traversal(self, node_ptr:Self.Node_Ptr)->List[T]:
    #     var nodes_list = List[T]()
    #     if not node_ptr: return nodes_list
    #     var _q = List[Int]()
    #     var _stack = List[Int]()
    #     var temp_ptr:Self.Node_Ptr
    #     var addr:Int
    #     _q.append(int(node_ptr))
    #     while _q:
    #         addr = _q.pop(0)
    #         _stack.append(addr)
    #         temp_ptr = self.Node_Ptr(address = addr)
    #         for child in temp_ptr[].children:
    #             _q.append(int(child[]))
    #     while _stack:
    #         nodes_list.append(self.Node_Ptr(address = _stack.pop(-1))[].data[])
    #     return nodes_list
        
    fn print_tree(self, node_ptr:Self.Node_Ptr, owned prefix:String='', is_last:Bool=True):
        var connector:String = '└── ' if is_last else '|── '
        if is_last:
            prefix += "     "
        else:
            prefix += "|    "
        print(prefix+connector+repr(node_ptr[].data[]))
        if node_ptr[].left or node_ptr[].right:
            if node_ptr[].left and node_ptr[].right:
                self.print_tree(node_ptr[].left, prefix, False)
                self.print_tree(node_ptr[].right, prefix, True)
            elif node_ptr[].left:
                self.print_tree(node_ptr[].left, prefix, True)
            elif node_ptr[].right:
                self.print_tree(node_ptr[].right, prefix, True)

# Define the test cases
fn test_initialization() raises:
    var tree = MyBSTree[Int](value=1)
    assert_true(tree.root[].data[] == 1, "Root node should be initialized with value 1")

fn test_add_child() raises:
    var tree = MyBSTree[Int](value=1)
    tree.insert(value=2)
    tree.insert(value=0)
    print(tree.root,tree.root[].left, tree.root[].right)
    # print(tree.total_nodes(tree.root))
    # print(tree.total_nodes(tree.root[].left))
    # print(tree.total_nodes(tree.root[].right))
    # assert_true(tree.total_nodes(tree.root) == 3, "Root should have 3 nodes")
    assert_true(tree.root[].right[].data[] == 2, "Child node should have value 2")

fn test_find_existing_node() raises:
    var tree = MyBSTree[Int](value=1)
    tree.insert(value=2)
    var found_node = tree.find(tree.root, 2)
    assert_true(found_node[].data[] == 2, "BSTNode with value 2 should be found")

fn test_find_non_existing_node() raises:
    var tree = MyBSTree[Int](value=1)
    var found_node = tree.find(tree.root, 99)
    assert_true(found_node == MyBSTree[Int].Node_Ptr(), "BSTNode with value 99 should not be found")

fn test_print_tree():
    var tree = MyBSTree[Int](value=1)
    tree.insert(value=10)
    tree.insert(value=11)
    tree.insert(value=12)
    tree.insert(value=13)
    tree.insert(value=111)
    tree.insert(value=1111)
    tree.insert(value=1112)
    tree.insert(value=1113)
    tree.insert(value=112)
    tree.insert(value=113)
    tree.insert(value=114)
    tree.insert(value=121)
    tree.insert(value=1211)
    tree.insert(value=1212)

    # print("Total nodes: ",tree.total_nodes(tree.root))
    # tree.print_tree(tree.root)
    # print("Pre order traversal: ")
    # print(tree.pre_order_traversal(tree.root).__str__())
    # print("Post order traversal: ")
    # print(tree.post_order_traversal(tree.root).__str__())
    # print("Level order traversal: ")
    # print(tree.level_order_traversal(tree.root).__str__())
    # print("Reverse Level order traversal: ")
    # print(tree.level_order_traversal(tree.root, reverse=True).__str__())
    # print("Reverse Level order traversal: ")
    # print(tree.reverse_level_order_traversal(tree.root).__str__())
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


