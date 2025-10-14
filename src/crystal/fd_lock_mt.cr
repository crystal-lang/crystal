# The general design is influenced by fdMutex in Go (LICENSE: BSD 3-Clause,
# Copyright Google):
# https://github.com/golang/go/blob/go1.25.1/src/internal/poll/fd_mutex.go

# :nodoc:
#
# Tracks active references over a system file descriptor (fd) and serializes
# reads and writes.
#
# Every access to the fd that may affect its system state or system buffers must
# acquire a shared lock.
#
# The fdlock can be closed at any time, but the actual system close will wait
# until there are no more references left. This avoids potential races when a
# thread might try to read a fd that has been closed and has been reused by the
# OS for example.
#
# FIXME: the interpreter segfaults when interpreted code uses this type; for now
# it uses the thread unsafe alternative (fd_lock_no_mt).
struct Crystal::FdLock
  CLOSED = 1_u32 << 0 # the fdlock has been closed
  REF    = 1_u32 << 1 # the reference counter increment
  MASK   = ~(REF - 1) # mask for the reference counter

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
  # The *callback* block must cancel any external waiters (e.g. pending evloop
  # reads or writes).
  #
  # Returns true if the fdlock has been closed: no fiber can acquire a reference
  # anymore, the calling fiber fully owns the fd and can safely close it.
  #
  # Returns false if the fdlock has already been closed: the calling fiber
  # doesn't own the fd and musn't close it, as there might still be active
  # references and another fiber will close anyway.
  def try_close?(&callback : ->) : Bool
    attempts = 0

    while true
      m = @m.get(:relaxed)

      if (m & CLOSED) == CLOSED
        # already closed: abort
        return false
      end

      # close + increment ref
      m, success = @m.compare_and_set(m, (m + REF) | CLOSED, :acquire, :relaxed)
      break if success

      attempts = Thread.delay(attempts)
    end

    # set the current fiber as the closing fiber (to be resumed by the last ref)
    @closing = Fiber.current

    # decrement the last ref
    m = @m.sub(REF, :release)

    begin
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
