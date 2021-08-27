require "iterator"

# Implements a `#step` method for iterating from a value.
module Steppable
  # Iterates from `self` to *limit* incrementing by the amount of *step* on each
  # iteration.
  # If *exclusive* is `true`, *limit* is excluded from the iteration.
  #
  # ```
  # ary = [] of Int32
  # 1.step(to: 4, by: 2) do |x|
  #   ary << x
  # end
  # ary                                        # => [1, 3]
  # 1.step(to: 4, by: 2).to_a                  # => [1, 3]
  # 1.step(to: 4, by: 1).to_a                  # => [1, 2, 3, 4]
  # 1.step(to: 4, by: 1, exclusive: true).to_a # => [1, 2, 3]
  # ```
  #
  # The type of each iterated element is `typeof(self + step)`.
  #
  # If *to* is `nil`, iteration is open ended.
  #
  # The starting point (`self`) is always iterated as first element, with two
  # exceptions:
  # * if `self` and *to* don't compare (i.e. `(self <=> to).nil?`). Example:
  #   `1.0.step(Float::NAN)`
  # * if the direction of *to* differs from the direction of `by`. Example:
  #   `1.step(to: 2, by: -1)`
  #
  # In those cases the iteration is empty.
  def step(*, to limit = nil, by step, exclusive : Bool = false, &) : Nil
    # type of current should be the result of adding `step`:
    current = self + (step - step)

    if limit == current
      # Only yield current if it's also the limit.
      # Step size doesn't matter in this case: `1.step(to: 1, by: 0)` yields `1`
      yield current unless exclusive
      return
    end

    raise ArgumentError.new("Zero step size") if step.zero?

    direction = step.sign

    if limit
      # if limit and step size have different directions, we can't iterate
      return unless (limit <=> current).try(&.sign) == direction

      yield current

      while true
        # only proceed if difference to limit is at least as big as step size to
        # avoid potential overflow errors.
        sign = ((limit - step) <=> current).try(&.sign)
        break unless sign == direction || (sign == 0 && !exclusive)

        current += step
        yield current
      end
    else
      while true
        yield current
        current += step
      end
    end

    self
  end

  # :ditto:
  def step(*, to limit = nil, by step, exclusive : Bool = false)
    raise ArgumentError.new("Zero step size") if step.zero? && limit != self

    StepIterator.new(self + (step - step), limit, step, exclusive: exclusive)
  end

  class StepIterator(T, L, B)
    include Iterator(T)

    @current : T
    @limit : L
    @step : B
    @at_start = true
    @reached_end = false

    def initialize(@current : T, @limit : L, @step : B, @exclusive : Bool)
    end

    def next
      return stop if @reached_end
      limit = @limit

      if @at_start
        @at_start = false

        if limit
          sign = (limit <=> @current).try(&.sign)
          @reached_end = sign == 0

          # iteration is empty if limit and step are in different directions
          if (!@reached_end && sign != @step.sign) || (@reached_end && @exclusive)
            @reached_end = true
            return stop
          end
        end

        @current
      elsif limit
        # compare distance to current with step size
        case ((limit - @step) <=> @current).try(&.sign)
        when @step.sign
          # distance is more than step size, so iteration proceeds
          @current += @step
        when 0
          # distance is exactly step size, so we're at the end
          @reached_end = true
          if @exclusive
            stop
          else
            @current + @step
          end
        else
          # we've either overshot the limit or the comparison failed, so we can't
          # continue
          @reached_end = true

          stop
        end
      else
        @current += @step
      end
    end

    # Overrides `Enumerable#sum` to use more performant implementation on integer
    # ranges.
    def sum(initial)
      return super if @reached_end

      current = @current
      limit = @limit
      step = @step

      if current.is_a?(Int) && limit.is_a?(Int) && step.is_a?(Int)
        limit -= 1 if @exclusive
        n = (limit - current) // step + 1
        if n >= 0
          limit = current + (n - 1) * step
          initial + n * (current + limit) // 2
        else
          initial
        end
      else
        super
      end
    end
  end
end
