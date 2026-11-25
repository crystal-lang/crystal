class Channel(T)
  # :nodoc:
  module SelectAction(S)
    abstract def execute : DeliveryState
    # Register a channel waiter or return the duration of a timeout.
    abstract def wait(fiber : Fiber, token : Fiber::CancelationToken) : Time::Span?
    abstract def unwait : Nil
    abstract def delivery_state : DeliveryState
    abstract def result : S
    abstract def lock_object_id
    abstract def lock
    abstract def unlock

    # Implementor that returns `Channel::UseDefault` in `#execute`
    # must redefine `#default_result`
    def default_result
      raise "Unreachable"
    end
  end
end
