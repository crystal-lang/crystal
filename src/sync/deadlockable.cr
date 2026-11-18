module Sync
  # :nodoc:
  module Deadlockable
    private property? locked_by : Fiber?

    protected def owns_lock? : Bool
      @locked_by == Fiber.current
    end

    private def set_owner(counter = 1) : Nil
      @locked_by = Fiber.current
      @counter = counter if @type.reentrant?
    end

    private def unset_owner : Nil
      @locked_by = nil
    end
  end
end
