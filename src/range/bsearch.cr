private macro bsearch_search(exclusive, mid)
  saved_to = to
  satisfied = nil
  while from < to
    mid = {{ mid.id }}

    if yield mid
      satisfied = mid
      to = mid
    else
      from = mid + 1
    end
  end

  if ! {{ exclusive }} && from == saved_to && yield from
    satisfied = from
  end

  satisfied
end

{% for p in [64, 32] %}
  private def int_to_float(i : Int{{ p }})
    if i < 0
      i = -i
      -(pointerof(i) as Pointer(Float{{ p }})).value
    else
      (pointerof(i) as Pointer(Float{{ p }})).value
    end
  end

  private def float_to_int(f : Float{{ p }})
    if f < 0
      f = -f
      -(pointerof(f) as Pointer(Int{{ p }})).value
    else
      (pointerof(f) as Pointer(Int{{ p }})).value
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
    from = float_to_int from
    to = float_to_int to
    to -= 1 if exclusive

    bsearch_internal(from, to, false){ |i| yield int_to_float i }
      .try{ |i| int_to_float i }
  end

  private def bsearch_internal(from : Int{{ p }}, to : Int{{ p }}, exclusive, &block)
    bsearch_search(exclusive,
      "(from < 0) == (to < 0) ? from + (to - from) / 2
      : (from < -to) ? -((- from - to - 1) / 2 + 1) : (from + to) / 2")
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
  # (0..10).bsearch{ |x| x >= 5 } # => 5
  # (0..Float64::INFINITY).bsearch{ |x| x ** 4 >= 256 } # => 4
  # ```
  #
  # Returns `nil` if the block didn't return `true` for any value.
  def bsearch(&block)
    from = self.begin
    to = self.end

    {% for v in %w(from to) %}
      if {{ v.id }}.is_a?(Float::Primitive)
        return bsearch_internal from, to, self.excludes_end? do |value|
          yield value
        end
      end
    {% end %}

    bsearch_search(self.excludes_end?, "from + (to - from) / 2")
  end
end
