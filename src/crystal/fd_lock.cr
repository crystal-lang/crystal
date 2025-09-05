# :nodoc:
#
# Tracks active references over a system file descriptor (fd).
#
# The fdlock can be closed at any time, but the actual system close will wait
# until there are no more references left. This avoids potential races when a
# thread might try to read a fd that has been closed and has been reused by the
# OS.
struct Crystal::FdLock
  CLOSED = 1_u32      # the fdlock has been closed
  REF    = 2_u32      # the ref counter increment
  MASK   = ~(REF - 1) # mask for the ref counter

  @m = Atomic(UInt32).new(0_u32)
  @closing : Fiber?

  # Borrows a reference for the duration of the block. Raises if the fdlock is
  # closed while trying to borrow.
  def reference(& : -> F) : F forall F
    m, success = @m.compare_and_set(0_u32, REF, :acquire, :relaxed)
    increment_slow(m) unless success

    begin
      yield
    ensure
      m = @m.sub(REF, :release)
      handle_last_ref(m)
    end
  end

  private def increment_slow(m)
    while true
      if (m & CLOSED) == CLOSED
        raise IO::Error.new("Closed")
      end
      m, success = @m.compare_and_set(m, m + REF, :acquire, :relaxed)
      break if success
    end
  end

  private def handle_last_ref(m)
    return unless (m & CLOSED) == CLOSED # is closed?
    return unless (m & MASK) == REF      # was the last ref?

    # the last ref after close is responsible to resume the closing fiber
    @closing.not_nil!("BUG: expected a closing fiber to resume.").enqueue
  end

  # Closes the fdlock. Blocks for as long as there are references.
  #
  # Returns true if the fdlock has been closed: no fiber can acquire a reference
  # anymore, the calling fiber fully owns the fd and can safely close it.
  #
  # Returns false if the fdlock has already been closed: the calling fiber
  # doesn't own the fd and musn't close it (there might still be active
  # references).
  def try_close?(&before_close : ->) : Bool
    m = @m.get(:relaxed)

    # increment ref and close (abort if already closed)
    while true
      if (m & CLOSED) == CLOSED
        return false
      end
      m, success = @m.compare_and_set(m, (m + REF) | CLOSED, :acquire, :relaxed)
      break if success
    end

    # set the current fiber as the closing fiber (to be resumed by the last ref)
    # then decrement ref
    @closing = Fiber.current
    m = @m.sub(REF, :release)

    begin
      # before close callback
      yield
    ensure
      # wait for the last ref... unless we're the last ref!
      Fiber.suspend unless (m & MASK) == REF
    end

    @closing = nil

    true
  end

  # Resets the fdlock back to its pristine state so it can be used again.
  # Assumes the caller owns the fdlock. This is required by
  # `TCPSocket#initialize`.
  def reset : Nil
    @m.lazy_set(0_u32)
    @closing = nil
  end

  def closed? : Bool
    (@m.get(:relaxed) & CLOSED) == CLOSED
  end
end
