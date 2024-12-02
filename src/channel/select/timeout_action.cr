# Timeout keyword for use in `select`.
#
# ```
# select
# when x = ch.receive
#   puts "got #{x}"
# when timeout(1.seconds)
#   puts "timeout"
# end
# ```
#
# NOTE: It won't trigger if the `select` has an `else` case (i.e.: a non-blocking select).
def timeout_select_action(timeout : Time::Span) : Channel::TimeoutAction
  Channel::TimeoutAction.new(timeout)
end

class Channel(T)
  # :nodoc:
  class TimeoutAction
    include SelectAction(Nil)

    # Total amount of time to wait
    @timeout : Time::Span
    @select_context : SelectContext(Nil)?

    def initialize(@timeout : Time::Span)
    end

    def execute : DeliveryState
      DeliveryState::None
    end

    def result : Nil
      nil
    end

    def wait(context : SelectContext(Nil)) : Nil
      @select_context = context
      Fiber.timeout(@timeout, self)
    end

    def wait_result_impl(context : SelectContext(Nil))
      nil
    end

    def unwait_impl(context : SelectContext(Nil))
      Fiber.cancel_timeout
    end

    def lock_object_id : UInt64
      self.object_id
    end

    def lock
    end

    def unlock
    end

    def time_expired(fiber : Fiber) : Nil
      fiber.enqueue if time_expired?
    end

    def time_expired? : Bool
      @select_context.try &.try_trigger || false
    end
  end
end
