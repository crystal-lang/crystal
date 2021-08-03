module Sortable(T)
  # Returns a new instance with all elements sorted based on the return value of
  # their comparison method `T#<=>` (see `Comparable`), using a stable sort algorithm.
  #
  # ```
  # a = [3, 1, 2]
  # a.sort # => [1, 2, 3]
  # a      # => [3, 1, 2]
  # ```
  #
  # See `#sort!` for details on the sorting mechanism.
  def sort : self
    dup.sort!
  end

  # Returns a new instance with all elements sorted based on the return value of
  # their comparison method `T#<=>` (see `Comparable`).
  #
  # The sort is unstable.
  #
  # ```
  # a = [3, 1, 2]
  # a.sort # => [1, 2, 3]
  # a      # => [3, 1, 2]
  # ```
  #
  # See `#unstable_sort!` for details on the sorting mechanism.
  def unstable_sort : self
    dup.unstable_sort!
  end

  # Returns a new instance with all elements sorted based on the comparator in the
  # given block, using a stable sort algorithm.
  #
  # ```
  # a = [3, 1, 2]
  # b = a.sort { |a, b| b <=> a }
  #
  # b # => [3, 2, 1]
  # a # => [3, 1, 2]
  # ```
  #
  # See `#sort!(&block : T, T -> U)` for details on the sorting mechanism.
  def sort(&block : T, T -> U) : self forall U
    {% unless U <= Int32? %}
      {% raise "expected block to return Int32 or Nil, not #{U}" %}
    {% end %}

    dup.sort! &block
  end

  # Returns a new instance with all elements sorted based on the comparator in the
  # given block.
  #
  # ```
  # a = [3, 1, 2]
  # b = a.unstable_sort { |a, b| b <=> a }
  #
  # b # => [3, 2, 1]
  # a # => [3, 1, 2]
  # ```
  #
  # See `#unstable_sort!(&block : T, T -> U)` for details on the sorting mechanism.
  def unstable_sort(&block : T, T -> U) : self forall U
    {% unless U <= Int32? %}
      {% raise "expected block to return Int32 or Nil, not #{U}" %}
    {% end %}

    dup.unstable_sort!(&block)
  end

  # Sorts all elements in `self` based on the return value of the comparison
  # method `T#<=>` (see `Comparable`), using a stable sort algorithm.
  #
  # ```
  # a = [3, 1, 2]
  # a.sort!
  # a # => [1, 2, 3]
  # ```
  #
  # This sort operation modifies `self`. See `#sort` for a non-modifying option
  # that allocates a new instance.
  #
  # The sort mechanism is stable, which is typically a good default.
  #
  # Stablility means that two elements which compare equal (i.e. `a <=> b == 0`)
  # keep their original relation. Stable sort guarantees that `[a, b].sort!`
  # always results in `[a, b]` (given they compare equal). With unstable sort,
  # the result could also be `[b, a]`.
  #
  # If stability is expendable, `#unstable_sort!` performance advantage over
  # stable sort.
  abstract def sort! : Sortable(T)

  # Sorts all elements in `self` based on the return value of the comparison
  # method `T#<=>` (see `Comparable`).
  #
  # ```
  # a = [3, 1, 2]
  # a.unstable_sort!
  # a # => [1, 2, 3]
  # ```
  #
  # This sort operation modifies `self`. See `#unstable_sort` for a non-modifying
  # option that allocates a new instance.
  #
  # The sort mechanism does not guarantee stability between equally comparing
  # elements. This offers higher performance but may be unexpected in some situations.
  #
  # Stablility means that two elements which compare equal (i.e. `a <=> b == 0`)
  # keep their original relation. Stable sort guarantees that `[a, b].sort!`
  # always results in `[a, b]` (given they compare equal). With unstable sort,
  # the result could also be `[b, a]`.
  #
  # If stability is necessary, use  `#sort!` instead.
  abstract def unstable_sort! : Sortable(T)

  # Sorts all elements in `self` based on the comparator in the given block, using
  # a stable sort algorithm.
  #
  # The block must implement a comparison between two elements *a* and *b*,
  # where `a < b` returns `-1`, `a == b` returns `0`, and `a > b` returns `1`.
  # The comparison operator `<=>` can be used for this.
  #
  # ```
  # a = [3, 1, 2]
  # # This is a reverse sort (forward sort would be `a <=> b`)
  # a.sort! { |a, b| b <=> a }
  # a # => [3, 2, 1]
  # ```
  #
  # This sort operation modifies `self`. See `#sort(&block : T, T -> U)` for a
  # non-modifying option that allocates a new instance.
  #
  # The sort mechanism is stable, which is typically a good default.
  #
  # Stablility means that two elements which compare equal (i.e. `a <=> b == 0`)
  # keep their original relation. Stable sort guarantees that `[a, b].sort!`
  # always results in `[a, b]` (given they compare equal). With unstable sort,
  # the result could also be `[b, a]`.
  #
  # If stability is expendable, `#unstable_sort!(&block : T, T -> U)` performance
  # advantage over stable sort.
  abstract def sort!(&block : T, T -> U) : Sortable(T) forall U

  # Sorts all elements in `self` based on the comparator in the given block.
  #
  # The block must implement a comparison between two elements *a* and *b*,
  # where `a < b` returns `-1`, `a == b` returns `0`, and `a > b` returns `1`.
  # The comparison operator `<=>` can be used for this.
  #
  # ```
  # a = [3, 1, 2]
  # # This is a reverse sort (forward sort would be `a <=> b`)
  # a.unstable_sort! { |a, b| b <=> a }
  # a # => [3, 2, 1]
  # ```
  #
  # This sort operation modifies `self`. See `#unstable_sort(&block : T, T -> U)`
  # for a non-modifying option that allocates a new instance.
  #
  # The sort mechanism does not guarantee stability between equally comparing
  # elements. This offers higher performance but may be unexpected in some situations.
  #
  # Stablility means that two elements which compare equal (i.e. `a <=> b == 0`)
  # keep their original relation. Stable sort guarantees that `[a, b].sort!`
  # always results in `[a, b]` (given they compare equal). With unstable sort,
  # the result could also be `[b, a]`.
  #
  # If stability is necessary, use  `#sort!(&block : T, T -> U)` instead.
  abstract def unstable_sort!(&block : T, T -> U) : Sortable(T) forall U

  # Returns a new instance with all elements sorted by the output value of the
  # block. The output values are compared via the comparison method `T#<=>`
  # (see `Comparable`), using a stable sort algorithm.
  #
  # ```
  # a = %w(apple pear fig)
  # b = a.sort_by { |word| word.size }
  # b # => ["fig", "pear", "apple"]
  # a # => ["apple", "pear", "fig"]
  # ```
  #
  # See `#sort_by!(&block : T -> _)` for details on the sorting mechanism.
  def sort_by(&block : T -> _) : self
    dup.sort_by! { |e| yield(e) }
  end

  # Returns a new instance with all elements sorted by the output value of the
  # block. The output values are compared via the comparison method `#<=>`
  # (see `Comparable`).
  #
  # ```
  # a = %w(apple pear fig)
  # b = a.unstable_sort_by { |word| word.size }
  # b # => ["fig", "pear", "apple"]
  # a # => ["apple", "pear", "fig"]
  # ```
  #
  # See `#unstable_sort!(&block : T -> _)` for details on the sorting mechanism.
  def unstable_sort_by(&block : T -> _) : self
    dup.unstable_sort_by! { |e| yield(e) }
  end

  # Sorts all elements in `self` by the output value of the
  # block. The output values are compared via the comparison method `#<=>`
  # (see `Comparable`), using a stable sort algorithm.
  #
  # ```
  # a = %w(apple pear fig)
  # a.sort_by! { |word| word.size }
  # a # => ["fig", "pear", "apple"]
  # ```
  #
  # This sort operation modifies `self`. See `#sort_by(&block : T -> _)` for a
  # non-modifying option that allocates a new instance.
  #
  # The sort mechanism is stable, which is typically a good default.
  #
  # Stablility means that two elements which compare equal (i.e. `a <=> b == 0`)
  # keep their original relation. Stable sort guarantees that `[a, b].sort!`
  # always results in `[a, b]` (given they compare equal). With unstable sort,
  # the result could also be `[b, a]`.
  #
  # If stability is expendable, `#unstable_sort!(&block : T -> _)` performance
  # advantage over stable sort.
  abstract def sort_by!(&block : T -> _) : Sortable(T)

  # Sorts all elements in `self` by the output value of the
  # block. The output values are compared via the comparison method `#<=>`
  # (see `Comparable`).
  #
  # ```
  # a = %w(apple pear fig)
  # a.usntable_sort_by! { |word| word.size }
  # a # => ["fig", "pear", "apple"]
  # ```
  #
  # This sort operation modifies `self`. See `#unstable_sort_by(&block : T -> _)`
  # for a non-modifying option that allocates a new instance.
  #
  # The sort mechanism does not guarantee stability between equally comparing
  # elements. This offers higher performance but may be unexpected in some situations.
  #
  # Stablility means that two elements which compare equal (i.e. `a <=> b == 0`)
  # keep their original relation. Stable sort guarantees that `[a, b].sort!`
  # always results in `[a, b]` (given they compare equal). With unstable sort,
  # the result could also be `[b, a]`.
  #
  # If stability is necessary, use  `#sort_by!(&block : T -> _)` instead.
  abstract def unstable_sort_by!(&block : T -> _) : Sortable(T)
end
