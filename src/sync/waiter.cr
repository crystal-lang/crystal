require "crystal/pointer_linked_list"

module Sync
  # :nodoc:
  struct Waiter
    enum Type
      Reader
      Writer
    end

    # Waiting and Done correspond to nsync's waiting flag. After a timeout loses
    # the timeout cancelation race, Crystal's timer has already enqueued the
    # fiber once. ParkedAfterTimeout lets the fiber suspend again and tells the
    # notifier to enqueue it when wake completes, so the fiber need not poll.
    private enum State
      Waiting
      ParkedAfterTimeout
      Done
    end

    include Crystal::PointerLinkedList::Node

    property cv_mu : Pointer(MU)

    # nsync snapshots remove_count at insertion and compares it under the CV
    # spinlock to check whether notification already removed the waiter.
    # Crystal creates a fresh waiter for each CV wait and inserts it into the
    # CV queue once, so a boolean cleared on removal carries the same information.
    # After publication, this flag is accessed under the CV spinlock.
    property? queued_on_cv : Bool

    @cancelation_token : Fiber::CancelationToken

    def initialize(@type : Type, @cv_mu : Pointer(MU) = Pointer(MU).null, @cancelation_token = Fiber::CancelationToken.unarmed)
      @queued_on_cv = !@cv_mu.null?

      # protects against spurious wakeups (invalid manual fiber enqueues) that
      # could lead to insert a waiter in the list a second time (oops) or keep
      # the waiter in the list while the caller returned
      @state = Atomic(State).new(:waiting)
      @fiber = Fiber.current
    end

    def reader? : Bool
      @type.reader?
    end

    def writer? : Bool
      @type.writer?
    end

    def waiting! : Nil
      @cancelation_token = Fiber::CancelationToken.unarmed
      @state.set(:waiting, :relaxed)
    end

    def wait : Nil
      # we could avoid suspending the fiber if @waiting is already true but
      # #wake ALWAYS enqueues the fiber, so #wait MUST suspend
      while true
        Fiber.suspend
        break unless waiting?
      end
    end

    private def waiting? : Bool
      !@state.get(:acquire).done?
    end

    # Notification has removed this waiter from the CV. If wake is still
    # pending, hand responsibility for the next enqueue back to the waker.
    def wait_after_timeout : Nil
      _, parked = @state.compare_and_set(:waiting, :parked_after_timeout, :acquire, :acquire)
      wait if parked
    end

    def wake : Nil
      # The timeout may already have resumed the fiber. It can reclaim the
      # waiter once it observes that the wake is complete.
      fiber = @fiber
      enqueue = @cancelation_token.unarmed? || fiber.try_cancel?(@cancelation_token)
      previous = @state.swap(:done, :release)
      fiber.enqueue if enqueue || previous.parked_after_timeout?
    end

    def linked? : Bool
      !@previous.null?
    end
  end
end
