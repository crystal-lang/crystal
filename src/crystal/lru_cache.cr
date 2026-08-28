class Crystal::LRUCache(K, V)
  private class Node(K, V)
    property key : K
    property value : V
    property? prev : Node(K, V)?
    property? next : Node(K, V)?

    def initialize(@key : K, @value : V)
    end
  end

  @hash : Hash(K, Node(K, V))
  @head : Node(K, V)? # most recently used
  @tail : Node(K, V)? # least recently used

  def initialize(@capacity : Int32 = 1024)
    @hash = Hash(K, Node(K, V)).new
  end

  def size : Int32
    @hash.size
  end

  def fetch?(key : K) : V?
    fetch(key) { nil }
  end

  def fetch(key : K, & : -> U) : V | U forall U
    if node = @hash[key]?
      move_to_head(node)
      node.value
    else
      yield
    end
  end

  def put(key : K, value : V) : Nil
    if node = @hash[key]?
      node.value = value
      move_to_head(node)
    elsif @hash.size < @capacity
      # fill to capacity
      node = Node.new(key, value)
      add_to_head(node)
      @tail ||= node
      @hash[key] = node
    else
      # evict tail
      node = @tail.not_nil!
      @hash.delete(node.key)

      # recycle node
      node.key = key
      node.value = value
      @hash[key] = node
      move_to_head(node)
    end
  end

  private def add_to_head(node)
    node.prev = nil
    node.next = @head
    if head = @head
      head.prev = node
    end
    @head = node
  end

  private def move_to_head(node)
    return if @head == node

    # detach node
    if prev = node.prev?
      prev.next = node.next?
    end
    if next_ = node.next?
      next_.prev = node.prev?
    end

    if node == @tail
      # set new tail
      @tail = node.prev?
    end

    add_to_head(node)
  end
end
