class Channel(T)
  # :nodoc:
  module SelectAction(S)
    abstract def execute : DeliveryState
    abstract def wait(context : SelectContext(S))
    abstract def wait_result_impl(context : SelectContext(S))
    abstract def unwait_impl(context : SelectContext(S))
    abstract def result : S
    abstract def lock_object_id
    abstract def lock
    abstract def unlock

    def create_context_and_wait(shared_state)
      context = SelectContext.new(shared_state, self)
      self.wait(context)
      context
    end

    # wait_result overload allow implementors to define
    # wait_result_impl with the right type and Channel.select_impl
    # to allow dispatching over unions that will not happen
    def wait_result(context : SelectContext)
      raise "BUG: Unexpected call to #{typeof(self)}#wait_result(context : #{typeof(context)})"
    end

    def wait_result(context : SelectContext(S))
      wait_result_impl(context)
    end

    # idem wait_result/wait_result_impl
    def unwait(context : SelectContext)
      raise "BUG: Unexpected call to #{typeof(self)}#unwait(context : #{typeof(context)})"
    end

    def unwait(context : SelectContext(S))
      unwait_impl(context)
    end

    # Implementor that returns `Channel::UseDefault` in `#execute`
    # must redefine `#default_result`
    def default_result
      raise "Unreachable"
    end
  end
end
