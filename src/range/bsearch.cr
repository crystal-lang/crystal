{% for p in [64, 32] %}
  # Cast integer as floating number value with keeping binary structure.
  private def int_as_float(i : Int{{ p }})
    # Integer uses two's complement to represent signed number, but
    # floating number value uses sign bit. This difference causes a
    # problem that it reproduce incorrect value when you sum positive
    # number and negative number. It fixes this problem.
    if i < 0
      i = -i
      -i.unsafe_as(Float{{ p }})
    else
      i.unsafe_as(Float{{ p }})
    end
  end

  # Cast floating number value as integer with keeping binary structure.
  private def float_as_int(f : Float{{ p }})
    if f < 0
      f = -f
      -f.unsafe_as(Int{{ p }})
    else
      f.unsafe_as(Int{{ p }})
    end
  end

  private def bsearch_internal(from : Float{{ p }}, to, exclusive, &block)
    bsearch_internal from, to.to_f{{ p }}, exclusive do |value|
      yield value
    end
  end

  private def bsearch_internal(from, to : Float{{ p }}, exclusive)
    bsearch_internal from.to_f{{ p }}, to, exclusive do |value|
      yield value
    end
  end

  private def bsearch_internal(from : Float{{ p }}, to : Float{{ p }}, exclusive)
    from = float_as_int from
    to = float_as_int to
    to -= 1 if exclusive

    bsearch_internal(from, to, false){ |i| yield int_as_float i }
      .try{ |i| int_as_float i }
  end

  private def bsearch_internal(from : Int{{ p }}, to : Int{{ p }}, exclusive)
    saved_to = to
    satisfied = nil
    while from < to
      mid = (from < 0) == (to < 0) ? from + (to - from) / 2
          : (from < -to) ? -((- from - to - 1) / 2 + 1) : (from + to) / 2

      if yield mid
        satisfied = mid
        to = mid
      else
        from = mid + 1
      end
    end

    if !exclusive && from == saved_to && yield from
      satisfied = from
    end

    satisfied
  end
{% end %}

struct Range(B, E)
  # By using binary search, returns the first value
  # for which the passed block returns `true`.
  #
  # If the block returns `false`, the finding value exists
  # behind. If the block returns `true`, the finding value
  # is itself or exists infront.
  #
  # ```
  # (0..10).bsearch { |x| x >= 5 }                       # => 5
  # (0..Float64::INFINITY).bsearch { |x| x ** 4 >= 256 } # => 4
  # ```
  #
  # Returns `nil` if the block didn't return `true` for any value.
  def bsearch
    from = self.begin
    to = self.end

    # If the range consists of floating value,
    # it uses specialized implementation for floating value.
    # This implementation is very fast. For example,
    # `(1..1e300).bsearch{ false }` loops over 2000 times in
    # popular implementation, but in this implementation loops 65 times
    # at most.
    {% for v in %w(from to) %}
      if {{ v.id }}.is_a?(Float::Primitive)
        return bsearch_internal from, to, self.excludes_end? do |value|
          yield value
        end
      end
    {% end %}

    saved_to = to
    satisfied = nil
    while from < to
      mid = from + (to - from) / 2

      if yield mid
        satisfied = mid
        to = mid
      else
        from = mid + 1
      end
    end

    if !self.excludes_end? && from == saved_to && yield from
      satisfied = from
    end

    satisfied
  end
end
