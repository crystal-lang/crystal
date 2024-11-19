# :nodoc:
#
# Tree of `T` structs referenced as pointers.
# `T` must include `Crystal::PointerPairingHeap::Node`.
class Crystal::PointerPairingHeap(T)
  module Node
    macro included
      property? heap_previous : Pointer(self)?
      property? heap_next : Pointer(self)?
      property? heap_child : Pointer(self)?
    end

    # Compare self with other. For example:
    #
    # Use `<` to create a min heap.
    # Use `>` to create a max heap.
    abstract def heap_compare(other : Pointer(self)) : Bool
  end

  @head : T* | Nil

  private def head=(head)
    @head = head
    head.value.heap_previous = nil if head
    head
  end

  def empty?
    @head.nil?
  end

  def first? : T* | Nil
    @head
  end

  def shift? : T* | Nil
    if node = @head
      self.head = merge_pairs(node.value.heap_child?)
      node.value.heap_child = nil
      node
    end
  end

  def add(node : T*) : Bool
    if node.value.heap_previous? || node.value.heap_next? || node.value.heap_child?
      raise ArgumentError.new("The node is already in a Pairing Heap tree")
    end
    self.head = meld(@head, node)
    node == @head
  end

  def delete(node : T*) : {Bool, Bool}
    if node == @head
      self.head = merge_pairs(node.value.heap_child?)
      node.value.heap_child = nil
      return {true, true}
    end

    if remove?(node)
      subtree = merge_pairs(node.value.heap_child?)
      self.head = meld(@head, subtree)
      unlink(node)
      return {true, false}
    end

    {false, false}
  end

  private def remove?(node)
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

      true
    else
      false
    end
  end

  def clear : Nil
    if node = @head
      clear_recursive(node)
      @head = nil
    end
  end

  private def clear_recursive(node)
    child = node.value.heap_child?
    while child
      clear_recursive(child)
      child = child.value.heap_next?
    end
    unlink(node)
  end

  private def meld(a : T*, b : T*) : T*
    if a.value.heap_compare(b)
      add_child(a, b)
    else
      add_child(b, a)
    end
  end

  private def meld(a : T*, b : Nil) : T*
    a
  end

  private def meld(a : Nil, b : T*) : T*
    b
  end

  private def meld(a : Nil, b : Nil) : Nil
  end

  private def add_child(parent : T*, node : T*) : T*
    first_child = parent.value.heap_child?
    parent.value.heap_child = node

    first_child.value.heap_previous = node if first_child
    node.value.heap_previous = parent
    node.value.heap_next = first_child

    parent
  end

  # Twopass merge of the children of *node* into pairs of two.
  private def merge_pairs(a : T*) : T* | Nil
    a.value.heap_previous = nil

    if b = a.value.heap_next?
      a.value.heap_next = nil
      b.value.heap_previous = nil
    else
      return a
    end

    rest = merge_pairs(b.value.heap_next?)
    b.value.heap_next = nil

    pair = meld(a, b)
    meld(pair, rest)
  end

  private def merge_pairs(node : Nil) : Nil
  end

  private def unlink(node) : Nil
    node.value.heap_previous = nil
    node.value.heap_next = nil
    node.value.heap_child = nil
  end
end
