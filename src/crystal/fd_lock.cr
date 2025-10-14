# The general design is influenced by fdMutex in Go (LICENSE: BSD 3-Clause,
# Copyright Google):
# https://github.com/golang/go/blob/go1.25.1/src/internal/poll/fd_mutex.go
#
# The internal details (spinlock, designated waker) of the locks are heavily
# influenced by the nsync library (LICENSE: Apache-2.0, Copyright Google):
# https://github.com/google/nsync

# :nodoc:
#
# Tracks active references over a system file descriptor (fd) and serializes
# reads and writes.
#
# Every read on the fd must lock read, every write must lock write and every
# other operation (fcntl, setsockopt, ...) must acquire a shared lock. There can
# be at most one reader + one writer + many references (other operations) at the
# same time.
#
# The fdlock can be closed at any time, but the actual system close will wait
# until there are no more references left. This avoids potential races when a
# thread might try to read a fd that has been closed and has been reused by the
# OS for example.
#
# Serializes reads and writes: only one attempt to read (or write) at a time can
# go through, which avoids situations where 2 readers are waiting, then the
# first reader is resumed but doesn't consume everything, then the second reader
# will never be resumed. With this lock, a waiting reader will always be resumed.
#
# Lock concepts
#
# Spinlock: slow-path for lock/unlock will spin until it acquires the spinlock
# bit to add/remove waiters; the CPU is relaxed between each attempt.
#
# Designated waker: set on unlock to report that a waiter has been scheduler and
# there's no need to wake another one. It's unset when a waiter acquires or
# fails to acquire and adds itself again as a waiter. This leads to an
# impressive performance boost when the lock is contended.
struct Crystal::FdLock
  CLOSED = 1_u32 << 0 # the fdlock has been closed
  RLOCK  = 1_u32 << 1 # reader lock
  RWAIT  = 1_u32 << 2 # reader wait bit (at least one reader)
  RSPIN  = 1_u32 << 3 # reader spinlock (protects @readers)
  RWAKER = 1_u32 << 4 # reader designated waker (a reader is being awoken)
  WLOCK  = 1_u32 << 5 # writer lock
  WWAIT  = 1_u32 << 6 # writer wait bit (at least one writer)
  WSPIN  = 1_u32 << 7 # writer spinlock (protects @writers)
  WWAKER = 1_u32 << 8 # writer designated waker (a writer is being awoken)
  REF    = 1_u32 << 9 # the reference counter increment
  MASK   = ~(REF - 1) # mask for the reference counter

  @m = Atomic(UInt32).new(0_u32)
  @closing : Fiber?
  @readers = PointerLinkedList(Fiber::PointerLinkedListNode).new
  @writers = PointerLinkedList(Fiber::PointerLinkedListNode).new

  # Locks for read and increments the references by one for the duration of the
  # block. Raises if the fdlock is closed while trying to acquire the lock.
  def read(& : -> F) : F forall F
    m, success = @m.compare_and_set(0_u32, RLOCK + REF, :acquire, :relaxed)
    lock_slow(RLOCK, RWAIT, RSPIN, RWAKER, pointerof(@readers)) unless success

    begin
      yield
    ensure
      m, success = @m.compare_and_set(RLOCK + REF, 0_u32, :release, :relaxed)
      m = unlock_slow(RLOCK, RWAIT, RSPIN, RWAKER, pointerof(@readers)) unless success
      handle_last_ref(m)
    end
  end

  # Locks for write and increments the references by one for the duration of the
  # block. Raises if the fdlock is closed while trying to acquire the lock.
  def write(& : -> F) : F forall F
    m, success = @m.compare_and_set(0_u32, WLOCK + REF, :acquire, :relaxed)
    lock_slow(WLOCK, WWAIT, WSPIN, WWAKER, pointerof(@writers)) unless success

    begin
      yield
    ensure
      m, success = @m.compare_and_set(WLOCK + REF, 0_u32, :release, :relaxed)
      m = unlock_slow(WLOCK, WWAIT, WSPIN, WWAKER, pointerof(@writers)) unless success
      handle_last_ref(m)
    end
  end

  @[NoInline]
  private def lock_slow(xlock, xwait, xspin, xwaker, waiters)
    waiter = Fiber::PointerLinkedListNode.new(Fiber.current)
    attempts = 0
    clear = 0_u32

    while true
      m = @m.get(:relaxed)

      if (m & CLOSED) == CLOSED
        # abort
        raise IO::Error.new("Closed")
      elsif (m & xlock) == 0_u32
        # acquire the lock + increment ref
        m, success = @m.compare_and_set(m, ((m | xlock) + REF) & ~clear, :acquire, :relaxed)
        return if success
      elsif (m & xspin) == 0_u32
        # acquire spinlock + forward declare pending waiter
        m, success = @m.compare_and_set(m, (m | xspin | xwait) & ~clear, :acquire, :relaxed)
        if success
          waiters.value.push(pointerof(waiter))

          # release spinlock before suspending the fiber
          @m.and(~xspin, :release)

          Fiber.suspend

          # the designated waker has woken: clear the flag
          clear |= xwaker
        end
      end

      attempts = Thread.delay(attempts)
    end
  end

  @[NoInline]
  private def unlock_slow(xlock, xwait, xspin, xwaker, waiters)
    attempts = 0

    while true
      m = @m.get(:relaxed)

      if (m & CLOSED) == CLOSED
        # decrement ref and abort
        m = @m.sub(REF, :relaxed)
        return m
      elsif (m & xwait) == 0_u32 || (m & xwaker) != 0_u32
        # no waiter, or there is a designated waker (no need to wake another
        # one): unlock & decrement ref
        m, success = @m.compare_and_set(m, (m & ~xlock) - REF, :release, :relaxed)
        return m if success
      elsif (m & xspin) == 0_u32
        # there is a waiter and no designated waker: acquire spinlock + declare
        # a designated waker + release lock & decrement ref early
        m, success = @m.compare_and_set(m, ((m | xspin | xwaker) & ~xlock) - REF, :acquire_release, :relaxed)
        if success
          waiter = waiters.value.shift?

          # clear flags and release spinlock
          clear = xspin
          clear |= xwaker unless waiter          # no designated waker
          clear |= xwait if waiters.value.empty? # no more waiters
          @m.and(~clear, :release)

          waiter.value.enqueue if waiter

          # return the m that decremented ref (for #handle_last_ref)
          return m
        end
      end

      attempts = Thread.delay(attempts)
    end
  end

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
    if fiber = @closing
      fiber.enqueue
    else
      raise NilAssertionError.new("BUG: expected a closing fiber to resume.")
    end
  end

  # Closes the fdlock. Wakes waiting readers and writers. Blocks for as long as
  # there are references.
  #
  # The *callback* block must cancel any external waiters (e.g. pending evloop
  # reads or writes).
  #
  # Returns true if the fdlock has been closed: no fiber can lock for read,
  # write or acquire a reference anymore, the calling fiber fully owns the fd
  # and can safely close it.
  #
  # Returns false if the fdlock has already been closed: the calling fiber
  # doesn't own the fd and musn't close it, as there might still be active
  # references and another fiber will close anyway.
  def try_close?(&callback : ->) : Bool
    attempts = 0

    # close + increment ref + acquire both spinlocks so we own both @readers and
    # @writers; parallel attempts to acquire a spinlock will fail, notice that
    # the lock is closed, and abort
    while true
      m = @m.get(:relaxed)

      if (m & CLOSED) == CLOSED
        # already closed: abort
        return false
      end

      m, success = @m.compare_and_set(m, (m + REF) | CLOSED | RSPIN | WSPIN, :acquire, :relaxed)
      break if success

      attempts = Thread.delay(attempts)
    end

    # set the current fiber as the closing fiber (to be resumed by the last ref)
    @closing = Fiber.current

    # resume waiters so they can fail (the fdlock is closed); this is safe
    # because we acquired the spinlocks above:
    @readers.consume_each(&.value.enqueue)
    @writers.consume_each(&.value.enqueue)

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
