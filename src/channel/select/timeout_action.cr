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

    def initialize(@duration : Time::Span)
    end

    def execute : DeliveryState
      DeliveryState::None
    end

    def result : Nil
      nil
    end

    def wait(fiber : Fiber, token : Fiber::CancelationToken) : Time::Span
      @duration
    end

    def unwait : Nil
    end

    def delivery_state : DeliveryState
      DeliveryState::None
    end

    def lock_object_id : UInt64
      self.object_id
    end

    def lock
    end

    def unlock
    end
  end
end
