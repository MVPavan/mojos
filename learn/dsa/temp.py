class NaryTreeNode:
    def __init__(self, value):
        self.value = value
        self.children = []

    def add_child(self, child_node):
        self.children.append(child_node)

def print_tree_ascii(node, prefix="", is_last=True):
    connector = "└── " if is_last else "├── "
    new_prefix = ""
    for char in prefix:
        new_prefix += char

    if is_last:
        new_prefix += "    "
    else:
        new_prefix += "│   "

    print(prefix + connector + str(node.value))
    child_count = len(node.children)
    for i, child in enumerate(node.children):
        is_last_child = i == (child_count - 1)
        print_tree_ascii(child, new_prefix, is_last_child)

# Example Usage
root = NaryTreeNode(1)
child1 = NaryTreeNode(2)
child2 = NaryTreeNode(3)
child3 = NaryTreeNode(4)

root.add_child(child1)
root.add_child(child2)
root.add_child(child3)

child1.add_child(NaryTreeNode(5))
child1.add_child(NaryTreeNode(6))

print_tree_ascii(root)
