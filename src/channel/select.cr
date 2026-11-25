class Channel(T)
  # :nodoc:
  record NotReady

  private enum DeliveryState
    None
    Delivered
    Closed
  end

  # :nodoc:
  def self.select(*ops : SelectAction)
    self.select ops
  end

  # :nodoc:
  def self.select(ops : Indexable(SelectAction))
    i, m = select_impl(ops, false)
    raise "BUG: Blocking select returned not ready status" if m.is_a?(NotReady)
    return i, m
  end

  # :nodoc:
  def self.non_blocking_select(*ops : SelectAction)
    self.non_blocking_select ops
  end

  # :nodoc:
  def self.non_blocking_select(ops : Indexable(SelectAction))
    select_impl(ops, true)
  end

  private def self.select_impl(ops : Indexable(SelectAction), non_blocking)
    # ops_locks is a duplicate of ops that can be sorted without disturbing the
    # index positions of ops
    if ops.responds_to?(:unstable_sort_by!)
      # If the collection type implements `unstable_sort_by!` we can dup it.
      # This applies to two types:
      # * `Array`: `Array#to_a` does not dup and would return the same instance,
      #   thus we'd be sorting ops and messing up the index positions.
      # * `StaticArray`: This avoids a heap allocation because we can dup a
      #   static array on the stack.
      ops_locks = ops.dup
    elsif ops.responds_to?(:to_static_array)
      # If the collection type implements `to_static_array` we can create a
      # copy without allocating an array. This applies to `Tuple` types, which
      # the compiler generates for `select` expressions.
      ops_locks = ops.to_static_array
    else
      ops_locks = ops.to_a
    end

    # Sort the operations by the channel they contain
    # This is to avoid deadlocks between concurrent `select` calls
    ops_locks.unstable_sort_by!(&.lock_object_id)

    each_skip_duplicates(ops_locks, &.lock)

    ops.each_with_index do |op, index|
      state = op.execute

      case state
      in .delivered?
        each_skip_duplicates(ops_locks, &.unlock)
        return index, op.result
      in .closed?
        each_skip_duplicates(ops_locks, &.unlock)
        return index, op.default_result
      in .none?
        # do nothing
      end
    end

    if non_blocking
      each_skip_duplicates(ops_locks, &.unlock)
      return ops.size, NotReady.new
    end

    fiber = Fiber.current
    cancelation_token = fiber.arm_cancelation
    timeout = nil
    timeout_index = 0

    ops.each_with_index do |op, index|
      next unless duration = op.wait(fiber, cancelation_token)

      # There can be multiple timeout actions, pick the one expiring the soonest.
      if !timeout || duration < timeout
        timeout = duration
        timeout_index = index
      end
    end

    each_skip_duplicates(ops_locks, &.unlock)

    # A channel may already own the wakeup. Still suspend to consume its enqueue.
    expired = false
    begin
      if timeout
        expired = Fiber.timeout(timeout, cancelation_token).expired?
      else
        Fiber.suspend
      end
    ensure
      ops.each do |op|
        op.lock
        op.unwait
        op.unlock
      end
    end

    if expired
      return timeout_index, ops[timeout_index].result
    end

    ops.each_with_index do |op, index|
      case op.delivery_state
      in .delivered?
        return index, op.result
      in .closed?
        return index, op.default_result
      in .none?
        # skip
      end
    end

    raise "BUG: Fiber was awaken from select but no action was activated"
  end

  private def self.each_skip_duplicates(ops_locks, &)
    # Avoid deadlocks from trying to lock the same lock twice.
    # `ops_lock` is sorted by `lock_object_id`, so identical ones will be in
    # a row and we skip repeats while iterating.
    last_lock_id = nil
    ops_locks.each do |op|
      if op.lock_object_id != last_lock_id
        last_lock_id = op.lock_object_id
        yield op
      end
    end
  end
end

require "./select/select_action"
require "./select/timeout_action"
