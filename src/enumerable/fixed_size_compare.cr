module Enumerable
  module FixedSizeCompare(T)
    # :nodoc:
    # Overrides Comparable.==
    # This version works with more objects because it doesn't rely on <=>.
    def ==(other: self)
      # optimize binary data comparisons
      if T.is_a?(UInt8.class)
        return false if size != other.size
        bs = LibC::SizeT.new(bytesize)
        LibC.memcmp(to_unsafe as Void*, other.to_unsafe as Void*, bs) == 0
      else
        equals?(other) { |x, y| x == y }
      end
    end

    # Iterates over both Enumerables comparing each value against other's values.
    # returns true if all elements are equal in both Enumerables.
    # return false otherwise.
    # ```
    # ary = [1, 2, 3]
    # ary == [1, 2, 3] # => true
    # ary == [2, 3] # => false
    # ```
    def ==(other : Enumerable)
      equals?(other) { |x, y| x == y }
    end

    # :nodoc:
    def ==(other)
      false
    end

    def equals?(other)
      return false if size != other.size
      each_with_index do |item, i|
        return false unless yield(item, other[i])
      end
      true
    end
  end
end

