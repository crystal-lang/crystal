module Spec::Methods
  # Spec helper for generic iteration methods which tests both yielding and
  # iterator overloads.
  #
  # This helper creates two spec examples named *description* with suffixes
  # `" yielding"` and `" iterator"`.
  # The yielding example calls *method* with a block and expects the iteration
  # elements to be yielded to the block. The iterator example calls *method*
  # without a block and expects it to return an `Iterator` which it then consumes.
  #
  # The iterated elements are collected in an array and compared to *expected*,
  # ensuring type-equality of the elements.
  #
  # By default, both examples make sure that the iteration is finished after
  # iterating all elements from *expected*. If the iteration is infinite,
  # passing `infinite: true` skips that check and allows to test a finite sample
  # of an infinite iteration.
  #
  # ```
  # require "spec/helpers/iterate"
  #
  # it_iterates "Array#each", [1, 2, 3], (1..3).each
  # it_iterates "infinite #cycle", [1, 2, 3, 1, 2, 3, 1], (1..3).cycle, infinite: true
  # ```
  #
  # If the iteration elements are tuples (i.e. multiple values), the yielding
  # variant by default only catches the first value because of the block argument
  # mechanics. Passing `tuple: true` ensures all yielded arguments are collected
  # using a splat.
  #
  # ```
  # require "spec/helpers/iterate"
  #
  # it_iterates "Array#each_with_index", [{1, 0}, {2, 1}, {3, 2}], (1..3).each_with_index, tuple: true
  # ```
  macro it_iterates(description, expected, method, *, infinite = false, tuple = false, file = __FILE__, line = __LINE__)
    it {{ "#{description} yielding" }}, file: {{ file }}, line: {{ line }} do
      assert_iterates_yielding {{ expected }}, {{ method }}, infinite: {{ infinite }}, tuple: {{ tuple }}
    end
    it {{ "#{description} iterator" }}, file: {{ file }}, line: {{ line }} do
      assert_iterates_iterator {{ expected }}, {{ method }}, infinite: {{ infinite }}
    end
  end

  # Calls *method* with a block and compares yielded values with *expected*.
  #
  # See `.it_iterates` for details.
  macro assert_iterates_yielding(expected, method, *, infinite = false, tuple = false)
    %remaining = ({{ expected }}).size
    %ary = [] of typeof(::Enumerable.element_type({{ expected }}))
    {{ method.id }} do |{% if tuple %}*{% end %}x|
      if %remaining == 0
        if {{ infinite }}
          break
        else
          fail "Reached iteration limit #{({{ expected }}).size} receiving value #{x.inspect}"
        end
      end

      %ary << x
      %remaining -= 1
    end

    %ary.should eq({{ expected }})
    %ary.zip({{ expected }}).each_with_index do |(actual, expected), i|
      if actual.class != expected.class
        fail "Mismatching type, expected: #{expected} (#{expected.class}), got: #{actual} (#{actual.class}) at #{i}"
      end
    end
  end

  # Calls *method* expecting an iterator and compares iterated values with *expected*.
  #
  # See `.it_iterates` for details.
  macro assert_iterates_iterator(expected, method, *, infinite = false)
    %ary = [] of typeof(::Enumerable.element_type({{ expected }}))
    %iter = {{ method.id }}
    ({{ expected }}).size.times do
      %v = %iter.next
      if %v.is_a?(::Iterator::Stop)
        # Compare the actual value directly. Since there are less
        # then expected values, the expectation will fail and raise.
        %ary.should eq({{ expected }})
        raise "Unreachable"
      end
      %ary << %v
    end
    unless {{ infinite }}
      %iter.next.should be_a(::Iterator::Stop)
    end

    %ary.should eq({{ expected }})
    %ary.zip({{ expected }}).each_with_index do |(actual, expected), i|
      if actual.class != expected.class
        fail "Mismatching type, expected: #{expected} (#{expected.class}), got: #{actual} (#{actual.class}) at #{i}"
      end
    end
  end
end
