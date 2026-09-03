# :nodoc:
#
# Tree of `T` structs referenced as pointers.
# `T` must include `Crystal::PointerPairingHeap::Node`.
class Crystal::PointerPairingHeap(T)
  module Node
    macro included
      property? heap_previous : self* = Pointer(self).null
      property? heap_next : self* = Pointer(self).null
      property? heap_child : self* = Pointer(self).null
    end

    # Compare self with other. For example:
    #
    # Use `<` to create a min heap.
    # Use `>` to create a max heap.
    abstract def heap_compare(other : Pointer(self)) : Bool
  end

  @head : T* = Pointer(T).null

  private def head=(head)
    @head = head
    head.value.heap_previous = null if head
    head
  end

  def empty?
    @head.null?
  end

  def first? : Pointer(T)
    @head
  end

  def shift? : Pointer(T)
    if node = @head
      self.head = merge_pairs(node.value.heap_child?)
      node.value.heap_child = null
      node
    else
      null
    end
  end

  def add(node : Pointer(T)) : Nil
    if node.value.heap_previous? || node.value.heap_next? || node.value.heap_child?
      raise ArgumentError.new("The node is already in a Pairing Heap tree")
    end
    self.head = meld(@head, node)
  end

  def delete(node : Pointer(T)) : Nil
    if previous_node = node.value.heap_previous?
      next_sibling = node.value.heap_next?

      if previous_node.value.heap_next? == node
        previous_node.value.heap_next = next_sibling
      else
        previous_node.value.heap_child = next_sibling
      end

      if next_sibling
        next_sibling.value.heap_previous = previous_node
      end

      subtree = merge_pairs(node.value.heap_child?)
      clear(node)
      self.head = meld(@head, subtree)
    else
      # removing head
      self.head = merge_pairs(node.value.heap_child?)
      node.value.heap_child = null
    end
  end

  def clear : Nil
    if node = @head
      clear_recursive(node)
      @head = null
    end
  end

  private def clear_recursive(node)
    child = node.value.heap_child?
    while child
      clear_recursive(child)
      child = child.value.heap_next?
    end
    clear(node)
  end

  private def meld(a : Pointer(T), b : Pointer(T)) : Pointer(T)
    if a && b
      if a.value.heap_compare(b)
        add_child(a, b)
      else
        add_child(b, a)
      end
    else
      a || b
    end
  end

  private def add_child(parent : Pointer(T), node : Pointer(T)) : Pointer(T)
    first_child = parent.value.heap_child?
    parent.value.heap_child = node

    first_child.value.heap_previous = node if first_child
    node.value.heap_previous = parent
    node.value.heap_next = first_child

    parent
  end

  private def merge_pairs(node : Pointer(T)) : Pointer(T)
    return null unless node

    # 1st pass: meld children into pairs (left to right)
    tail = null

    while a = node
      if b = a.value.heap_next?
        node = b.value.heap_next?
        root = meld(a, b)
        root.value.heap_previous = tail
        tail = root
      else
        a.value.heap_previous = tail
        tail = a
        break
      end
    end

    # 2nd pass: meld the pairs back into a single tree (right to left)
    root = null

    while tail
      node = tail.value.heap_previous?
      root = meld(root, tail)
      tail = node
    end

    root.value.heap_next = null if root
    root
  end

  private def clear(node) : Nil
    node.value.heap_previous = null
    node.value.heap_next = null
    node.value.heap_child = null
  end

  private macro null
    Pointer(T).null
  end
end
