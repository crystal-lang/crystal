require "./weak_ref"

# An `Enumerator` allows to lazily yield values from a block and consume them as `Iterator`.
#
# It is useful, if you have a block that generates values and needs to block in the middle
# of execution until the next value is consumed.
#
# You should use an `Iterator` instead, if you do not need this blocking behavior, since it
# is much more efficient.
#
# As an example, let's build a generator that yields numbers from the Fibonacci Sequence:
#
# ```
# fib = Enumerator(Int32).new do |y|
#   a = b = 1
#   loop do
#     y << a
#     a, b = b, a + b
#   end
# end
#
# fib.first(10).to_a # => [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
# ```
#
# Note that the above example works, but it would be much faster using an `Iterator`:
#
# ```
# a = b = 1
# fib = Iterator.of do
#   a.tap { a, b = b, a + b }
# end
#
# fib.first(10).to_a # => [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
# ```
# It is generally advisable to avoid `Enumerator` in cases where you have a large number
# of iterations and the computation inside the block is trivial, because the additional
# overhead of the blocking behavior that is implemented with `Fiber` under the hood will
# negatively impact performance.
#
# However for more complex examples you will find that it might not be possible to replace
# the loop with suspendable state and you would have to build your own blocking behavior
# using for example an `Iterator` and a `Channel`.
#
# Using `Enumerator` is the right fit for those cases and it handles a lot of the tricky
# edge cases like ensuring the block is not started until you consume the first value or
# aborted if you rewind or abandon the iterator.
class Enumerator(T)
  include Iterator(T)

  # :nodoc:
  getter! current_fiber

  @fiber : Fiber?
  @done : Bool?

  def initialize(&@block : Yielder(T) ->)
    @current_fiber = Fiber.current
    @stack = Deque(T).new(1)
    @yielder = Yielder(T).new(self)
    run
  end

  # Returns the next element yielded from the block or `Iterator::Stop::INSTANCE`
  # if there are no more elements.
  def next
    fetch_next
    stack.shift { stop }
  end

  # Rewinds the iterator and restarts the yielder block.
  def rewind
    fiber.kill
    run
    self
  end

  # Peeks at the next value without forwarding the iterator.
  def peek
    fetch_next
    if stack.empty?
      stop
    else
      stack[0]
    end
  end

  # :nodoc:
  def finalize
    fiber.kill
  end

  protected def <<(value : T)
    stack.push(value)
  end

  private getter stack
  private getter! fiber
  private getter? done

  private def fetch_next : Nil
    @current_fiber = Fiber.current
    fiber.resume if fiber.alive? && stack.empty?
  end

  private def run
    stack.clear

    block = @block
    yielder = @yielder.not_nil!

    @fiber = Fiber.new do
      block.call(yielder)
    end.on_finish do
      yielder.resume_current_fiber
    end
  end

  private struct Yielder(T)
    @enumerator : WeakRef(Enumerator(T))

    def initialize(enumerator : Enumerator(T))
      @enumerator = WeakRef.new(enumerator)
    end

    # Yields the next value to the enumerator.
    def <<(value : T)
      pass_to_enumerator(value)
      resume_current_fiber
      self
    end

    # :nodoc:
    def resume_current_fiber
      current_fiber = get_current_fiber
      current_fiber.try &.resume
    end

    private def pass_to_enumerator(value : T)
      @enumerator.value.try &.<< value
    end

    private def get_current_fiber
      @enumerator.value.try &.current_fiber
    end
  end
end
