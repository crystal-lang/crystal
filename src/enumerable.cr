# The Enumerable mixin provides collection classes with several traversal, searching,
# filtering and querying methods.
#
# Including types must provide an `each` method, which yields successive members of
# the collection.
#
# For example:
#
# ```
# class Three
#   include Enumerable(Int32)
#
#   def each
#     yield 1
#     yield 2
#     yield 3
#   end
# end
#
# three = Three.new
# three.to_a                # => [1, 2, 3]
# three.select &.odd?       # => [1, 3]
# three.all? { |x| x < 10 } # => true
# ```
#
# Note that most search and filter methods traverse an Enumerable eagerly,
# producing an `Array` as the result. For a lazy alternative refer to
# the `Iterator` and `Iterable` modules.
module Enumerable(T)
  # Must yield this collection's elements to the block.
  abstract def each(&block : T -> _)

  # Returns `true` if the passed block returns a value other than `false` or `nil` for all elements of the collection.
  #
  #     ["ant", "bear", "cat"].all? { |word| word.size >= 3 }  #=> true
  #     ["ant", "bear", "cat"].all? { |word| word.size >= 4 }  #=> false
  #
  def all?
    each { |e| return false unless yield e }
    true
  end

  # Returns `true` if none of the elements of the collection is `false` or `nil`.
  #
  #     [nil, true, 99].all?  #=> false
  #     [15].all?             #=> true
  #
  def all?
    all? &.itself
  end

  # Returns `true` if the passed block returns a value other than `false` or `nil` for at least one element of the collection.
  #
  #     ["ant", "bear", "cat"].any? { |word| word.size >= 4 }  #=> true
  #     ["ant", "bear", "cat"].any? { |word| word.size > 4 }   #=> false
  #
  def any?
    each { |e| return true if yield e }
    false
  end

  # Returns `true` if at least one of the collection members is not `false` or `nil`.
  #
  #     [nil, true, 99].any?  #=> true
  #     [nil, false].any?     #=> false
  #
  def any?
    any? &.itself
  end

  # Returns an array with the results of running the block against each element of the collection, removing `nil` values.
  #
  #     ["Alice", "Bob"].map { |name| name.match(/^A./) }         #=> [#<Regex::MatchData "Al">, nil]
  #     ["Alice", "Bob"].compact_map { |name| name.match(/^A./) } #=> [#<Regex::MatchData "Al">]
  #
  def compact_map
    ary = [] of typeof((yield first).not_nil!)
    each do |e|
      v = yield e
      unless v.is_a?(Nil)
        ary << v
      end
    end
    ary
  end

  # Returns the number of elements in the collection for which the passed block returns `true`.
  #
  #     [1, 2, 3, 4].count { |i| i % 2 == 0 }  #=> 2
  #
  def count
    count = 0
    each { |e| count += 1 if yield e }
    count
  end

  # Returns the number of times that the passed item is present in the collection.
  #
  #     [1, 2, 3, 4].count(3)  #=> 1
  #
  def count(item)
    count { |e| e == item }
  end

  # Calls the given block for each element in this enumerable forever.
  def cycle
    loop { each { |x| yield x } }
  end

  # Calls the given block for each element in this enumerable *n* times.
  def cycle(n)
    n.times { each { |x| yield x } }
  end

  # Iterates over the collection yielding chunks of size *count*, but advancing one by one.
  #
  #     [1, 2, 3, 4, 5].each_cons(2) do |cons|
  #       puts cons
  #     end
  #
  # Prints:
  #
  #     [1, 2]
  #     [2, 3]
  #     [3, 4]
  #     [4, 5]
  #
  def each_cons(count : Int)
    cons = Array(T).new(count)
    each do |elem|
      cons << elem
      cons.shift if cons.size > count
      if cons.size == count
        yield cons.dup
      end
    end
    nil
  end

  # Iterates over the collection in slices of size *count*, and runs the block for each of those.
  #
  #     [1, 2, 3, 4, 5].each_slice(2) do |slice|
  #       puts slice
  #     end
  #
  # Prints:
  #
  #     [1, 2]
  #     [3, 4]
  #     [5]
  #
  # Note that the last one can be smaller.
  def each_slice(count : Int)
    slice = Array(T).new(count)
    each do |elem|
      slice << elem
      if slice.size == count
        yield slice
        slice = Array(T).new(count)
      end
    end
    yield slice unless slice.empty?
    nil
  end

  # Iterates over the collection, yielding both the elements and their index.
  #
  #     ["Alice", "Bob"].each_with_index do |user, i|
  #       puts "User ##{i}: #{user}"
  #     end
  #
  # Prints:
  #
  #     User #0: Alice
  #     User #1: Bob
  #
  # Accepts an optional *offset* parameter, which tells it to start counting from there. So, a more human
  # friendly version of the previous snippet would be:
  #
  #     ["Alice", "Bob"].each_with_index(1) do |user, i|
  #       puts "User ##{i}: #{user}"
  #     end
  #
  # Which would print:
  #
  #     User #1: Alice
  #     User #2: Bob
  #
  def each_with_index(offset = 0)
    i = offset
    each do |elem|
      yield elem, i
      i += 1
    end
  end

  # Iterates over the collection, passing each element and the initial object *obj*. Returns that object.
  #
  #     ["Alice", "Bob"].each_with_object({} of String => Int32) do |user, sizes|
  #       sizes[user] = user.size
  #     end  #=> {"Alice" => 5, "Bob" => 3}
  #
  def each_with_object(obj)
    each do |elem|
      yield elem, obj
    end
    obj
  end

  # Returns the first element in the collection for which the passed block is `true`.
  #
  # Accepts an optional parameter *if_none*, to set what gets returned if no element is found (defaults to `nil`).
  #
  #     [1, 2, 3, 4].find { |i| i > 2 }      #=> 3
  #     [1, 2, 3, 4].find { |i| i > 8 }      #=> nil
  #     [1, 2, 3, 4].find(-1) { |i| i > 8 }  #=> -1
  #
  def find(if_none = nil)
    each do |elem|
      return elem if yield elem
    end
    if_none
  end

  # Returns the first element in the collection. Raises `Enumerable::EmptyError` if the collection is empty.
  def first
    each { |e| return e }
    raise Enumerable::EmptyError.new
  end

  # Returns the first element in the collection. When the collection is empty, returns `nil`.
  def first?
    each { |e| return e }
    nil
  end

  # Returns a new array with the concatenated results of running the block (which is expected to return arrays) once for
  # every element in the collection.
  #
  #     ["Alice", "Bob"].flat_map do |user|
  #       user.chars
  #     end  #=> ['A', 'l', 'i', 'c', 'e', 'B', 'o', 'b']
  def flat_map(&block : T -> Array(U))
    ary = [] of U
    each { |e| ary.concat(yield e) }
    ary
  end

  # Returns an array with all the elements in the collection that match the `RegExp` *pattern*.
  #
  #     ["Alice", "Bob"].grep(/^A/)  #=> ["Alice"]
  #
  def grep(pattern)
    select { |elem| pattern === elem }
  end

  # Returns a `Hash` whose keys are each different value that the passed block returned when run for each element in the
  # collection, and which values are an array of the elements for which the block returned that value.
  #
  #     ["Alice", "Bob", "Ary"].group_by { |name| name.size }  #=> {5 => ["Alice"], 3 => ["Bob", "Ary"]}
  #
  def group_by(&block : T -> U)
    h = Hash(U, Array(T)).new
    each do |e|
      v = yield e
      if h.has_key?(v)
        h[v].push(e)
      else
        h[v] = [e]
      end
    end
    h
  end

  # Returns an `Array` with chunks in the given size, eventually filled up with given value or nil.
  #
  #     [1, 2, 3].in_groups_of(2, 0) #=> [[1, 2], [3, 0]]
  #     [1, 2, 3].in_groups_of(2) #=> [[1, 2], [3, nil]]
  #
  def in_groups_of(size : Int, filled_up_with : U = nil)
    raise ArgumentError.new("size must be positive") if size <= 0

    # TODO: this consumes the enumerable twice, fix
    parts_count = (self.size.to_f / size).ceil.to_i
    ary = Array(Array(T | U)).new(parts_count)
    parts_count.times do |i|
      ary << Array(T | U).new(size, filled_up_with)
    end

    each_with_index do |e, i|
      ary[i / size][i % size] = e
    end

    ary
  end

  # Yields a block with the chunks in the given size.
  #
  #     [1, 2, 4].in_groups_of(2, 0) { |e| p e.sum }
  #     #=> 3
  #     #=> 4
  #
  def in_groups_of(size : Int, filled_up_with : U = nil)
    raise ArgumentError.new("size must be positive") if size <= 0
    ary = Array(T | U).new(size, filled_up_with)

    # TODO: this consumes the enumerable twice, fix
    count = self.size

    each_with_index do |e, i|
      ary[i % size] = e
      if i % size == size - 1 || i == count - 1
        yield ary
        ary = Array(T | U).new(size, filled_up_with)
      end
    end
  end

  # Returns `true` if the collection contains *obj*, `false` otherwise.
  #
  #     [1, 2, 3].includes?(2)  #=> true
  #     [1, 2, 3].includes?(5)  #=> false
  #
  def includes?(obj)
    any? { |e| e == obj }
  end

  # Returns the index of the first element for which the passed block returns `true`.
  #
  #     ["Alice", "Bob"].index { |name| name.size < 4 }  #=> 1 (Bob's index)
  #
  # Returns `nil` if the block didn't return `true`for any element.
  def index
    each_with_index do |e, i|
      return i if yield e
    end
    nil
  end

  # Returns the index of the object *obj* in the collection.
  #
  #     ["Alice", "Bob"].index("Alice")  #=> 0
  #
  # Returns `nil` if *obj* is not in the collection.
  def index(obj)
    index { |e| e == obj }
  end

  # Converts an Enumerable to a hash by using the value returned by the block
  # as the hash key.
  # Be aware, if two elements return the same value as a key one will override
  # the other. If you want to keep all values, then you should probably use
  # `group_by` instead.
  #
  #     ["Anna", "Ary", "Alice"].index_by {|e| e.size }
  #     #=> {4=>"Anna", 3=>"Ary", 5=>"Alice"}
  #     ["Anna", "Ary", "Alice", "Bob"].index_by {|e| e.size }
  #     # => {4=>"Anna", 3=>"Bob", 5=>"Alice"}
  #
  #
  def index_by(&block : T -> U)
    hash = {} of U => T
    each do |elem|
      hash[yield elem] = elem
    end
    hash
  end

  # Combines all elements in the collection by applying a binary operation, specified by a block, so as
  # to reduce them to a single value.
  #
  # For each element in the collection the block is passed an accumulator value (*memo*) and the element. The
  # result becomes the new value for *memo*. At the end of the iteration, the final value of *memo* is
  # the return value for the method. The initial value for the accumulator is the first element in the collection.
  #
  #     [1, 2, 3, 4, 5].reduce { |acc, i| acc + i }  #=> 15
  #
  def reduce
    memo = uninitialized T
    found = false

    each do |elem|
      memo = found ? (yield memo, elem) : elem
      found = true
    end

    found ? memo : raise Enumerable::EmptyError.new
  end

  # Just like the other variant, but you can set the initial value of the accumulator.
  #
  #     [1, 2, 3, 4, 5].reduce(10) { |acc, i| acc + i }  #=> 25
  #
  def reduce(memo)
    each do |elem|
      memo = yield memo, elem
    end
    memo
  end

  # Returns a `String` created by concatenating the elements in the collection, separated by *separator* (defaults to none).
  #
  #     [1, 2, 3, 4, 5].join(", ")  #=> "1, 2, 3, 4, 5"
  #
  def join(separator = "")
    String.build do |io|
      join separator, io
    end
  end

  # Returns a `String` created by concatenating the results of passing the elements in the collection to the passed
  # block, separated by *separator* (defaults to none).
  #
  #     [1, 2, 3, 4, 5].join(", ") { |i| -i }  #=> "-1, -2, -3, -4, -5"
  #
  def join(separator = "")
    String.build do |io|
      join(separator, io) do |elem|
        io << yield elem
      end
    end
  end

  # Prints to *io* all the elements in the collection, separated by *separator*.
  #
  #     [1, 2, 3, 4, 5].join(", ", STDOUT)
  #
  # Prints:
  #
  #     1, 2, 3, 4, 5
  #
  def join(separator, io)
    join(separator, io) do |elem|
      elem.to_s(io)
    end
  end

  # Prints to *io* the concatenation of the elements, with the possibility of controlling how the printing is
  # done via a block.
  #
  #     [1, 2, 3, 4, 5].join(", ", STDOUT) { |i, io| io << "(#{i})" }
  #
  # Prints:
  #
  #     (1), (2), (3), (4), (5)
  def join(separator, io)
    each_with_index do |elem, i|
      io << separator if i > 0
      yield elem, io
    end
  end

  # Returns an array with the results of running the block against each element of the collection.
  #
  #     [1, 2, 3].map { |i| i * 10 }  #=> [10, 20, 30]
  #
  def map(&block : T -> U)
    ary = [] of U
    each { |e| ary << yield e }
    ary
  end

  # Like `map`, but the block gets passed both the element and its index.
  #
  #     ["Alice", "Bob"].map_with_index { |name, i| "User ##{i}: #{name}" }  #=> ["User #0: Alice", "User #1: Bob"]
  #
  def map_with_index(&block : T, Int32 -> U)
    ary = [] of U
    each_with_index { |e, i| ary << yield e, i }
    ary
  end

  # Returns the element with the maximum value in the collection.
  #
  # It compares using `>` so it will work for any type that supports that method.
  #
  #     [1, 2, 3].max         #=> 3
  #     ["Alice", "Bob"].max  #=> "Bob"
  #
  # Raises `Enumerable::EmptyError` if the collection is empty.
  def max
    max_by &.itself
  end

  # Like `max` but returns nil if the collection is empty.
  def max?
    max_by? &.itself
  end

  # Returns the element for which the passed block returns with the maximum value.
  #
  # It compares using `>` so the block must return a type that supports that method
  #
  #     ["Alice", "Bob"].max_by { |name| name.size }  #=> "Alice"
  #
  # Raises `Enumerable::EmptyError` if the collection is empty.
  def max_by(&block : T -> U)
    found, value = max_by_internal { |value| yield value }
    raise Enumerable::EmptyError.new unless found
    value
  end

  # Like `max_by` but returns nil if the collection is empty.
  def max_by?(&block : T -> U)
    found, value = max_by_internal { |value| yield value }
    found ? value : nil
  end

  private def max_by_internal(&block : T -> U)
    max = uninitialized U
    obj = uninitialized T
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value > max
        max = value
        obj = elem
      end
      found = true
    end

    {found, obj}
  end

  # Like `max_by` but instead of the element, returns the value returned by the block.
  #
  #     ["Alice", "Bob"].max_of { |name| name.size }  #=> 5 (Alice's size)
  #
  def max_of(&block : T -> U)
    found, value = max_of_internal { |value| yield value }
    raise Enumerable::EmptyError.new unless found
    value
  end

  # Like `max_of` but returns nil if the collection is empty.
  def max_of?(&block : T -> U)
    found, value = max_of_internal { |value| yield value }
    found ? value : nil
  end

  private def max_of_internal(&block : T -> U)
    max = uninitialized U
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value > max
        max = value
      end
      found = true
    end

    {found, max}
  end

  # Returns the element with the minimum value in the collection.
  #
  # It compares using `<` so it will work for any type that supports that method.
  #
  #     [1, 2, 3].min         #=> 1
  #     ["Alice", "Bob"].min  #=> "Alice"
  #
  # Raises `Enumerable::EmptyError` if the collection is empty.
  def min
    min_by &.itself
  end

  # Like `min` but returns nil if the collection is empty.
  def min?
    min_by? &.itself
  end

  # Returns the element for which the passed block returns with the minimum value.
  #
  # It compares using `<` so the block must return a type that supports that method
  #
  #     ["Alice", "Bob"].min_by { |name| name.size }  #=> "Bob"
  #
  # Raises `Enumerable::EmptyError` if the collection is empty.
  def min_by(&block : T -> U)
    found, value = min_by_internal { |value| yield value }
    raise Enumerable::EmptyError.new unless found
    value
  end

  # Like `min_by` but returns nil if the collection is empty.
  def min_by?(&block : T -> U)
    found, value = min_by_internal { |value| yield value }
    found ? value : nil
  end

  private def min_by_internal(&block : T -> U)
    min = uninitialized U
    obj = uninitialized T
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value < min
        min = value
        obj = elem
      end
      found = true
    end

    {found, obj}
  end

  # Like `min_by` but instead of the element, returns the value returned by the block.
  #
  #     ["Alice", "Bob"].min_of { |name| name.size }  #=> 3 (Bob's size)
  #
  def min_of(&block : T -> U)
    found, value = min_of_internal { |value| yield value }
    raise Enumerable::EmptyError.new unless found
    value
  end

  # Like `min_of` but returns nil if the collection is empty.
  def min_of?(&block : T -> U)
    found, value = min_of_internal { |value| yield value }
    found ? value : nil
  end

  private def min_of_internal(&block : T -> U)
    min = uninitialized U
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value < min
        min = value
      end
      found = true
    end

    {found, min}
  end

  # Returns a tuple with both the minimum and maximum value.
  #
  #     [1, 2, 3].minmax  #=> {1, 3}
  #
  # Raises `Enumerable::EmptyError` if the collection is empty.
  def minmax
    minmax_by &.itself
  end

  # Like `minmax` but returns `{nil, nil}` if the collection is empty.
  def minmax?
    minmax_by? &.itself
  end

  # Returns a tuple with both the minimum and maximum values according to the passed block.
  #
  #     ["Alice", "Bob", "Carl"].minmax_by { |name| name.size }  #=> {"Bob", "Alice"}
  #
  # Raises `Enumerable::EmptyError` if the collection is empty.
  def minmax_by(&block : T -> U)
    found, value = minmax_by_internal { |value| yield value }
    raise Enumerable::EmptyError.new unless found
    value
  end

  # Like `minmax_by` but returns `{nil, nil}` if the collection is empty.
  def minmax_by?(&block : T -> U)
    found, value = minmax_by_internal { |value| yield value }
    found ? value : {nil, nil}
  end

  private def minmax_by_internal(&block : T -> U)
    min = uninitialized U
    max = uninitialized U
    objmin = uninitialized T
    objmax = uninitialized T
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value < min
        min = value
        objmin = elem
      end
      if i == 0 || value > max
        max = value
        objmax = elem
      end
      found = true
    end

    {found, {objmin, objmax}}
  end

  # Returns a tuple with both the minimum and maximum value the block returns when passed the elements in the
  # collection.
  #
  #     ["Alice", "Bob", "Carl"].minmax_of { |name| name.size }  #=> {3, 5}
  #
  # Raises `Enumerable::EmptyError` if the collection is empty.
  def minmax_of(&block : T -> U)
    found, value = minmax_of_internal { |value| yield value }
    raise Enumerable::EmptyError.new unless found
    value
  end

  # Like `minmax_of` but returns `{nil, nil}` if the collection is empty.
  def minmax_of?(&block : T -> U)
    found, value = minmax_of_internal { |value| yield value }
    found ? value : {nil, nil}
  end

  private def minmax_of_internal(&block : T -> U)
    min = uninitialized U
    max = uninitialized U
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value < min
        min = value
      end
      if i == 0 || value > max
        max = value
      end
      found = true
    end

    {found, {min, max}}
  end

  # Returns `true` if the passed block returns `true` for none of the elements of the collection.
  #
  #     [1, 2, 3].none? { |i| i > 5 }  #=> true
  #
  # It's the opposite of `all?`.
  def none?
    each { |e| return false if yield(e) }
    true
  end

  # Returns `true` if all of the elements of the collection are `false` or `nil`.
  #
  #     [nil, false].none?        #=> true
  #     [nil, false, true].none?  #=> false
  #
  # It's the opposite of `all?`.
  def none?
    none? &.itself
  end

  # Returns `true` if the passed block returns `true` for exactly one of the elements of the collection.
  #
  #     [1, 2, 3].one? { |i| i > 2 }  #=> true
  #     [1, 2, 3].one? { |i| i > 1 }  #=> false
  #
  def one?
    c = 0
    each do |e|
      c += 1 if yield(e)
      return false if c > 1
    end
    c == 1
  end

  # Returns a tuple with two arrays. The first one contains the elements in the collection for which the passed block
  # returned `true`, and the second one those for which it returned `false`.
  #
  #     [1, 2, 3, 4, 5, 6].partition { |i| i % 2 == 0}  #=> {[2, 4, 6], [1, 3, 5]}
  #
  def partition
    a, b = [] of T, [] of T
    each do |e|
      value = yield(e)
      value ? a.push(e) : b.push(e)
    end
    {a, b}
  end

  # Returns an array with all the elements in the collection for which the passed block returns `false`.
  #
  #     [1, 2, 3, 4, 5, 6].reject { |i| i % 2 == 0}  #=> [1, 3, 5]
  #
  def reject(&block : T ->)
    ary = [] of T
    each { |e| ary << e unless yield e }
    ary
  end

  # Returns an array with all the elements in the collection for which the passed block returns `true`.
  #
  #     [1, 2, 3, 4, 5, 6].select { |i| i % 2 == 0}  #=> [2, 4, 6]
  #
  def select(&block : T ->)
    ary = [] of T
    each { |e| ary << e if yield e }
    ary
  end

  # Returns the number of elements in the collection.
  #
  #     [1, 2, 3, 4].size  #=> 4
  #
  def size
    count { true }
  end

  # Returns an array with the first *count* elements removed from the original collection.
  #
  # If *count* is bigger than the number of elements in the collection, returns an empty array.
  #
  #     [1, 2, 3, 4, 5, 6].skip(3)  #=> [4, 5, 6]
  def skip(count : Int)
    raise ArgumentError.new("attempt to skip negative size") if count < 0

    array = Array(T).new
    each_with_index do |e, i|
      array << e if i >= count
    end
    array
  end

  # Skips elements up to, but not including, the first element for which the block returns nil or false and returns an array containing the remaining elements.
  #
  #     [1, 2, 3, 4, 5, 0].skip_while {|i| i < 3} #=> [3, 4, 5, 0]
  #
  def skip_while
    result = Array(T).new
    block_returned_false = false
    each do |x|
      block_returned_false = true unless block_returned_false || yield x
      result << x if block_returned_false
    end
    result
  end

  # Adds all the elements in the collection together.
  #
  # Only collections of numbers (objects that can be added via an `+` method) are supported.
  #
  #     [1, 2, 3, 4, 5, 6].sum  #=> 21
  #
  # If the collection is empty, returns zero.
  #
  #     ([] of Int32).sum #=> 0
  def sum
    sum Reflect(T).first.zero
  end

  # Adds *initial* and all the elements in the collection together.
  #
  # Only collections of numbers (objects that can be added via an `+` method) are supported.
  #
  #     [1, 2, 3, 4, 5, 6].sum(7)  #=> 28
  #
  # If the collection is empty, returns *initial*.
  #
  #     ([] of Int32).sum(7) #=> 7
  def sum(initial)
    sum initial, &.itself
  end

  # Adds all results of the passed block for each element in the collection.
  #
  #     ["Alice", "Bob"].sum { |name| name.size }  #=> 8 (5 + 3)
  #
  # If the collection is empty, returns zero.
  #
  #     ([] of Int32).sum { |x| x + 1 } #=> 0
  def sum(&block)
    sum(Reflect(typeof(yield first)).first.zero) do |value|
      yield value
    end
  end

  # Adds *initial* and all results of the passed block for each element in the collection.
  #
  #     ["Alice", "Bob"].sum(1) { |name| name.size }  #=> 9 (1 + 5 + 3)
  #
  # If the collection is empty, returns zero.
  #
  #     ([] of String).sum(1) { |name| name.size } #=> 1
  def sum(initial, &block)
    reduce(initial) { |memo, e| memo + (yield e) }
  end

  # Returns an array with the first *count* elements in the collection.
  #
  # If *count* is bigger than the number of elements in the collection, returns as many as possible. This
  # include the case of calling it over an empty collection, in which case it returns an empty array.
  def first(count : Int)
    raise ArgumentError.new("attempt to take negative size") if count < 0

    ary = Array(T).new(count)
    each_with_index do |e, i|
      break if i == count
      ary << e
    end
    ary
  end

  # Passes elements to the block until the block returns nil or false, then stops iterating and returns an array of all prior elements.
  #
  #     [1, 2, 3, 4, 5, 0].take_while {|i| i < 3} #=> [1, 2]
  #
  def take_while
    result = Array(T).new
    each do |x|
      break unless yield x
      result << x
    end
    result
  end

  # Returns an array with all the elements in the collection.
  #
  #     (1..5).to_a  #=> [1, 2, 3, 4, 5]
  #
  def to_a
    ary = [] of T
    each { |e| ary << e }
    ary
  end

  # Creates a hash out of an Enumerable where each element is a
  # 2 element structure (for instance a Tuple or an Array)
  #
  #     [[:a, :b], [:c, :d]].to_h => {a: :b, c: :d}
  #     Tuple.new({:a, 1}, {:c, 2}).to_h => {a: 1, c: 2}
  #
  def to_h
    each_with_object(Hash(typeof(first[0]), typeof(first[1])).new) do |item, hash|
      hash[item[0]] = item[1]
    end
  end
end
