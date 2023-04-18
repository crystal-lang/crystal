# A Deque ("[double-ended queue](https://en.wikipedia.org/wiki/Double-ended_queue)") is a collection of objects of type
# T that behaves much like an Array.
#
# Deque has a subset of Array's API. It performs better than an `Array` when there are frequent insertions or deletions
# of items near the beginning or the end.
#
# The most typical use case of a Deque is a queue: use `push` to add items to the end of the queue and `shift` to get
# and remove the item at the beginning of the queue.
#
# This Deque is implemented with a [dynamic array](http://en.wikipedia.org/wiki/Dynamic_array) used as a
# [circular buffer](https://en.wikipedia.org/wiki/Circular_buffer).
class Deque(T)
  include Indexable::Mutable(T)

  # This Deque is based on a circular buffer. It works like a normal array, but when an item is removed from the left
  # side, instead of shifting all the items, only the start position is shifted. This can lead to configurations like:
  # [234---01] @start = 6, size = 5, @capacity = 8
  # (this Deque has 5 items, each equal to their index)

  @start = 0
  protected setter size
  protected getter buffer
  protected getter capacity

  # Creates a new empty Deque
  def initialize
    @size = 0
    @capacity = 0
    @buffer = Pointer(T).null
  end

  # Creates a new empty `Deque` backed by a buffer that is initially `initial_capacity` big.
  #
  # The `initial_capacity` is useful to avoid unnecessary reallocations of the internal buffer in case of growth. If you
  # have an estimate of the maximum number of elements a deque will hold, you should initialize it with that capacity
  # for improved execution performance.
  #
  # ```
  # deq = Deque(Int32).new(5)
  # deq.size # => 0
  # ```
  def initialize(initial_capacity : Int)
    if initial_capacity < 0
      raise ArgumentError.new("Negative deque capacity: #{initial_capacity}")
    end
    @size = 0
    @capacity = initial_capacity.to_i

    if @capacity == 0
      @buffer = Pointer(T).null
    else
      @buffer = Pointer(T).malloc(@capacity)
    end
  end

  # Creates a new `Deque` of the given size filled with the same value in each position.
  #
  # ```
  # Deque.new(3, 'a') # => Deque{'a', 'a', 'a'}
  # ```
  def initialize(size : Int, value : T)
    if size < 0
      raise ArgumentError.new("Negative deque size: #{size}")
    end
    @size = size.to_i
    @capacity = size.to_i

    if @capacity == 0
      @buffer = Pointer(T).null
    else
      @buffer = Pointer(T).malloc(@capacity, value)
    end
  end

  # Creates a new `Deque` of the given size and invokes the block once for
  # each index of the deque, assigning the block's value in that index.
  #
  # ```
  # Deque.new(3) { |i| (i + 1) ** 2 } # => Deque{1, 4, 9}
  # ```
  def self.new(size : Int, & : Int32 -> T)
    if size < 0
      raise ArgumentError.new("Negative deque size: #{size}")
    end

    deque = Deque(T).new(size)
    deque.size = size
    size.to_i.times do |i|
      deque.buffer[i] = yield i
    end
    deque
  end

  # Creates a new `Deque` that copies its items from an Array.
  #
  # ```
  # Deque.new([1, 2, 3]) # => Deque{1, 2, 3}
  # ```
  def self.new(array : Array(T))
    Deque(T).new(array.size) { |i| array[i] }
  end

  # Returns `true` if it is passed a `Deque` and `equals?` returns `true`
  # for both deques, the caller and the argument.
  #
  # ```
  # deq = Deque{2, 3}
  # deq.unshift 1
  # deq == Deque{1, 2, 3} # => true
  # deq == Deque{2, 3}    # => false
  # ```
  def ==(other : Deque)
    equals?(other) { |x, y| x == y }
  end

  # Concatenation. Returns a new `Deque` built by concatenating
  # two deques together to create a third. The type of the new deque
  # is the union of the types of both the other deques.
  def +(other : Deque(U)) forall U
    Deque(T | U).new.concat(self).concat(other)
  end

  # :nodoc:
  def +(other : Deque(T))
    dup.concat other
  end

  # Returns the additive identity of this type.
  #
  # This is an empty deque.
  def self.additive_identity : self
    self.new
  end

  # Alias for `push`.
  def <<(value : T)
    push(value)
  end

  def unsafe_fetch(index : Int) : T
    index += @start
    index -= @capacity if index >= @capacity
    @buffer[index]
  end

  def unsafe_put(index : Int, value : T)
    index += @start
    index -= @capacity if index >= @capacity
    @buffer[index] = value
  end

  # Removes all elements from `self`.
  def clear
    Deque.half_slices(self) do |slice|
      slice.to_unsafe.clear(slice.size)
    end
    @size = 0
    @start = 0
    self
  end

  # Returns a new `Deque` that has this deque's elements cloned.
  # That is, it returns a deep copy of this deque.
  #
  # Use `#dup` if you want a shallow copy.
  def clone
    {% if T == ::Bool || T == ::Char || T == ::String || T == ::Symbol || T < ::Number::Primitive %}
      Deque(T).new(size) { |i| self[i].clone.as(T) }
    {% else %}
      exec_recursive_clone do |hash|
        clone = Deque(T).new(size)
        hash[object_id] = clone.object_id
        each do |element|
          clone << element.clone
        end
        clone
      end
    {% end %}
  end

  # Appends the elements of *other* to `self`, and returns `self`.
  #
  # ```
  # deq = Deque{"a", "b"}
  # deq.concat(Deque{"c", "d"})
  # deq # => Deque{"a", "b", "c", "d"}
  # ```
  def concat(other : Indexable) : self
    other_size = other.size

    resize_if_cant_insert(other_size)

    index = @start + @size
    index -= @capacity if index >= @capacity
    concat_indexable(other, index)

    @size += other_size

    self
  end

  private def concat_indexable(other : Deque, index)
    Deque.half_slices(other) do |slice|
      index = concat_indexable(slice, index)
    end
  end

  private def concat_indexable(other : Array | StaticArray, index)
    concat_indexable(Slice.new(other.to_unsafe, other.size), index)
  end

  private def concat_indexable(other : Slice, index)
    if index + other.size <= @capacity
      # there is enough space after the last element; one copy will suffice
      (@buffer + index).copy_from(other.to_unsafe, other.size)
      index += other.size
      index == @capacity ? 0 : index
    else
      # copy the first half of *other* to the end of the buffer, and then the
      # remaining half to the start, which must be available after a call to
      # `#resize_if_cant_insert`
      first_half_size = @capacity - index
      second_half_size = other.size - first_half_size
      (@buffer + index).copy_from(other.to_unsafe, first_half_size)
      @buffer.copy_from(other.to_unsafe + first_half_size, second_half_size)
      second_half_size
    end
  end

  private def concat_indexable(other, index)
    appender = (@buffer + index).appender
    buffer_end = @buffer + @capacity
    other.each do |elem|
      appender << elem
      appender = @buffer.appender if appender.pointer == buffer_end
    end
  end

  # :ditto:
  def concat(other : Enumerable(T)) : self
    other.each do |x|
      push x
    end
    self
  end

  # Removes all items from `self` that are equal to *obj*.
  #
  # ```
  # a = Deque{"a", "b", "b", "b", "c"}
  # a.delete("b") # => true
  # a             # => Deque{"a", "c"}
  # ```
  def delete(obj) : Bool
    match = internal_delete { |i| i == obj }
    !match.nil?
  end

  # Modifies `self`, keeping only the elements in the collection for which the
  # passed block is truthy. Returns `self`.
  #
  # ```
  # a = Deque{1, 6, 2, 4, 8}
  # a.select! { |x| x > 3 }
  # a # => Deque{6, 4, 8}
  # ```
  #
  # See also: `Deque#select`.
  def select!(& : T ->) : self
    reject! { |elem| !yield(elem) }
  end

  # Modifies `self`, keeping only the elements in the collection for which
  # `pattern === element`.
  #
  # ```
  # ary = [1, 6, 2, 4, 8]
  # ary.select!(3..7)
  # ary # => [6, 4]
  # ```
  #
  # See also: `Deque#select`.
  def select!(pattern) : self
    self.select! { |elem| pattern === elem }
  end

  # Modifies `self`, deleting the elements in the collection for which the
  # passed block is truthy. Returns `self`.
  #
  # ```
  # a = Deque{1, 6, 2, 4, 8}
  # a.reject! { |x| x > 3 }
  # a # => Deque{1, 2}
  # ```
  #
  # See also: `Deque#reject`.
  def reject!(& : T ->) : self
    internal_delete { |e| yield e }
    self
  end

  # Modifies `self`, deleting the elements in the collection for which
  # `pattern === element`.
  #
  # ```
  # a = Deque{1, 6, 2, 4, 8}
  # a.reject!(3..7)
  # a # => Deque{1, 2, 8}
  # ```
  #
  # See also: `Deque#reject`.
  def reject!(pattern) : self
    reject! { |elem| pattern === elem }
    self
  end

  # `reject!` and `delete` implementation:
  # returns the last matching element, or nil
  private def internal_delete(&)
    match = nil
    i = 0
    while i < @size
      e = self[i]
      if yield e
        match = e
        delete_at(i)
      else
        i += 1
      end
    end
    match
  end

  # Deletes the item that is present at the *index*. Items to the right
  # of this one will have their indices decremented.
  # Raises `IndexError` if trying to delete an element outside the deque's range.
  #
  # ```
  # a = Deque{1, 2, 3}
  # a.delete_at(1) # => 2
  # a              # => Deque{1, 3}
  # ```
  def delete_at(index : Int) : T
    if index < 0
      index += @size
    end
    unless 0 <= index < @size
      raise IndexError.new
    end
    return shift if index == 0
    return pop if index == @size - 1

    rindex = @start + index
    rindex -= @capacity if rindex >= @capacity
    value = @buffer[rindex]

    if index > @size // 2
      # Move following items to the left, starting with the first one
      # [56-01234] -> [6x-01235]
      dst = rindex
      finish = (@start + @size - 1) % @capacity
      loop do
        src = dst + 1
        src -= @capacity if src >= @capacity
        @buffer[dst] = @buffer[src]
        break if src == finish
        dst = src
      end
      (@buffer + finish).clear
    else
      # Move preceding items to the right, starting with the last one
      # [012345--] -> [x01345--]
      dst = rindex
      finish = @start
      @start += 1
      @start -= @capacity if @start >= @capacity
      loop do
        src = dst - 1
        src += @capacity if src < 0
        @buffer[dst] = @buffer[src]
        break if src == finish
        dst = src
      end
      (@buffer + finish).clear
    end

    @size -= 1
    value
  end

  # Returns a new `Deque` that has exactly this deque's elements.
  # That is, it returns a shallow copy of this deque.
  def dup
    Deque(T).new(size) { |i| self[i].as(T) }
  end

  # Yields each item in this deque, from first to last.
  #
  # Do not modify the deque while using this variant of `each`!
  def each(& : T ->) : Nil
    Deque.half_slices(self) do |slice|
      slice.each do |elem|
        yield elem
      end
    end
  end

  # Insert a new item before the item at *index*. Items to the right
  # of this one will have their indices incremented.
  #
  # ```
  # a = Deque{0, 1, 2}
  # a.insert(1, 7) # => Deque{0, 7, 1, 2}
  # ```
  def insert(index : Int, value : T) : self
    if index < 0
      index += @size + 1
    end
    unless 0 <= index <= @size
      raise IndexError.new
    end
    return unshift(value) if index == 0
    return push(value) if index == @size

    resize_if_cant_insert
    rindex = @start + index
    rindex -= @capacity if rindex >= @capacity

    if index > @size // 2
      # Move following items to the right, starting with the last one
      # [56-01234] -> [4560123^]
      dst = @start + @size
      dst -= @capacity if dst >= @capacity
      loop do
        src = dst - 1
        src += @capacity if src < 0
        @buffer[dst] = @buffer[src]
        break if src == rindex
        dst = src
      end
    else
      # Move preceding items to the left, starting with the first one
      # [01234---] -> [1^234--0]
      @start -= 1
      @start += @capacity if @start < 0
      rindex -= 1
      rindex += @capacity if rindex < 0
      dst = @start
      loop do
        src = dst + 1
        src -= @capacity if src >= @capacity
        @buffer[dst] = @buffer[src]
        break if src == rindex
        dst = src
      end
    end

    @size += 1
    @buffer[rindex] = value
    self
  end

  def inspect(io : IO) : Nil
    executed = exec_recursive(:inspect) do
      io << "Deque{"
      join io, ", ", &.inspect(io)
      io << '}'
    end
    io << "Deque{...}" unless executed
  end

  def pretty_print(pp)
    executed = exec_recursive(:inspect) do
      pp.list("Deque{", self, "}")
    end
    pp.text "Deque{...}" unless executed
  end

  # Returns the number of elements in the deque.
  #
  # ```
  # Deque{:foo, :bar}.size # => 2
  # ```
  def size : Int32
    @size
  end

  # Removes and returns the last item. Raises `IndexError` if empty.
  #
  # ```
  # a = Deque{1, 2, 3}
  # a.pop # => 3
  # a     # => Deque{1, 2}
  # ```
  def pop : T
    pop { raise IndexError.new }
  end

  # Removes and returns the last item, if not empty, otherwise executes
  # the given block and returns its value.
  def pop(&)
    if @size == 0
      yield
    else
      @size -= 1
      index = @start + @size
      index -= @capacity if index >= @capacity
      value = @buffer[index]
      (@buffer + index).clear
      value
    end
  end

  # Removes and returns the last item, if not empty, otherwise `nil`.
  def pop? : T?
    pop { nil }
  end

  # Removes the last *n* (at most) items in the deque.
  def pop(n : Int) : Nil
    if n < 0
      raise ArgumentError.new("Can't pop negative count")
    end
    n = Math.min(n, @size)
    n.times { pop }
    nil
  end

  # Adds an item to the end of the deque.
  #
  # ```
  # a = Deque{1, 2}
  # a.push 3 # => Deque{1, 2, 3}
  # ```
  def push(value : T)
    resize_if_cant_insert
    index = @start + @size
    index -= @capacity if index >= @capacity
    @buffer[index] = value
    @size += 1
    self
  end

  # :inherit:
  def rotate!(n : Int = 1) : Nil
    return if @size <= 1
    if @size == @capacity
      @start = (@start + n) % @capacity
    else
      # Turn *n* into an equivalent index in range -size/2 .. size/2
      half = @size // 2
      if n.abs >= half
        n = (n + half) % @size - half
      end
      while n > 0
        push(shift)
        n -= 1
      end
      while n < 0
        n += 1
        unshift(pop)
      end
    end
  end

  # Removes and returns the first item. Raises `IndexError` if empty.
  #
  # ```
  # a = Deque{1, 2, 3}
  # a.shift # => 1
  # a       # => Deque{2, 3}
  # ```
  def shift
    shift { raise IndexError.new }
  end

  # Removes and returns the first item, if not empty, otherwise executes
  # the given block and returns its value.
  def shift(&)
    if @size == 0
      yield
    else
      value = @buffer[@start]
      (@buffer + @start).clear
      @size -= 1
      @start += 1
      @start -= @capacity if @start >= @capacity
      value
    end
  end

  # Removes and returns the first item, if not empty, otherwise `nil`.
  def shift?
    shift { nil }
  end

  # Removes the first *n* (at most) items in the deque.
  def shift(n : Int) : Nil
    if n < 0
      raise ArgumentError.new("Can't shift negative count")
    end
    n = Math.min(n, @size)
    n.times { shift }
    nil
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end

  # Adds an item to the beginning of the deque.
  #
  # ```
  # a = Deque{1, 2}
  # a.unshift 0 # => Deque{0, 1, 2}
  # ```
  def unshift(value : T) : self
    resize_if_cant_insert
    @start -= 1
    @start += @capacity if @start < 0
    @buffer[@start] = value
    @size += 1
    self
  end

  # :nodoc:
  def self.half_slices(deque : Deque, &)
    # For [----] yields nothing
    # For contiguous [-012] yields @buffer[1...4]
    # For separated [234---01] yields @buffer[6...8], @buffer[0...3]

    return if deque.empty?
    a = deque.@start
    b = deque.@start + deque.size
    b -= deque.capacity if b > deque.capacity
    if a < b
      # TODO: this `typeof` is a workaround for 1.0.0; remove it eventually
      yield Slice(typeof(deque.buffer.value)).new(deque.buffer + a, deque.size)
    else
      yield Slice(typeof(deque.buffer.value)).new(deque.buffer + a, deque.capacity - a)
      yield Slice(typeof(deque.buffer.value)).new(deque.buffer, b)
    end
  end

  private INITIAL_CAPACITY = 4

  # behaves like `calculate_new_capacity(@capacity + 1)`
  private def calculate_new_capacity
    return INITIAL_CAPACITY if @capacity == 0

    @capacity * 2
  end

  private def calculate_new_capacity(new_size)
    new_capacity = @capacity == 0 ? INITIAL_CAPACITY : @capacity
    while new_capacity < new_size
      new_capacity *= 2
    end
    new_capacity
  end

  # behaves like `resize_if_cant_insert(1)`
  private def resize_if_cant_insert
    if @size >= @capacity
      resize_to_capacity(calculate_new_capacity)
    end
  end

  private def resize_if_cant_insert(insert_size)
    new_capacity = calculate_new_capacity(@size + insert_size)
    if new_capacity > @capacity
      resize_to_capacity(new_capacity)
    end
  end

  private def resize_to_capacity(capacity)
    old_capacity, @capacity = @capacity, capacity

    unless @buffer
      @buffer = Pointer(T).malloc(@capacity)
      return
    end

    @buffer = @buffer.realloc(@capacity)

    finish = @start + @size
    if finish > old_capacity
      # If the deque is separated into two parts, we get something like [2301----] after resize, so additional action is
      # needed, to turn it into [23----01] or [--0123--].
      # To do the moving we can use `copy_from` because the old and new locations will never overlap (assuming we're
      # multiplying the capacity by 2 or more). Due to the same assumption, we can clear all of the old locations.
      finish -= old_capacity
      if old_capacity - @start >= @start
        # [3012----] -> [-0123---]
        (@buffer + old_capacity).copy_from(@buffer, finish)
        @buffer.clear(finish)
      else
        # [1230----] -> [123----0]
        to_move = old_capacity - @start
        new_start = @capacity - to_move
        (@buffer + new_start).copy_from(@buffer + @start, to_move)
        (@buffer + @start).clear(to_move)
        @start = new_start
      end
    end
  end
end
