# :nodoc:
#
# Doubly linked list of `T` structs referenced as pointers.
# `T` that must include `Crystal::PointerLinkedList::Node`.
struct Crystal::PointerLinkedList(T)
  @head : Pointer(T) = Pointer(T).null

  module Node
    macro included
      property previous : Pointer(self) = Pointer(self).null
      property next : Pointer(self) = Pointer(self).null
    end
  end

  @[AlwaysInline]
  protected def self.link(p : Pointer(T), q : Pointer(T)) : Nil
    p.value.next = q
    q.value.previous = p
  end

  @[AlwaysInline]
  protected def self.insert_impl(new : Pointer(T), prev : Pointer(T), _next : Pointer(T)) : Nil
    prev.value.next = new
    new.value.previous = prev
    new.value.next = _next
    _next.value.previous = new
  end

  # Returns `true` if the list is empty, otherwise false.
  def empty? : Bool
    @head.null?
  end

  # Appends a node to the tail of the list.
  def push(node : Pointer(T)) : Nil
    unless empty?
      typeof(self).insert_impl node, @head.value.previous, @head
    else
      node.value.previous = node
      node.value.next = node
      @head = node
    end
  end

  # Removes a node from the list.
  def delete(node : Pointer(T)) : Nil
    _next = node.value.next

    if node != _next
      @head = _next if @head == node
      typeof(self).link node.value.previous, _next
    else
      @head = Pointer(T).null
    end
  end

  # Removes and returns head from the list, yields if empty
  def shift(&)
    unless empty?
      @head.tap { |t| delete(t) }
    else
      yield
    end
  end

  # Returns and returns head from the list, `nil` if empty.
  def shift?
    shift { nil }
  end

  # Iterates the list.
  def each(&) : Nil
    return if empty?

    node = @head
    loop do
      _next = node.value.next
      yield node
      break if _next == @head
      node = _next
    end
  end
end
