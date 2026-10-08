# Deadlock algorithm as per DEADLOCKS AS RUNTIME EXCEPTIONS By Rafael Brandão
# Lôbo: https://scispace.com/pdf/deadlocks-as-runtime-exceptions-55xszs6s43.pdf
#
# Roughly:
#
# Whenever a lock is acquired, the lock object is added to the fiber local array
# `Fiber#owned_locks`, and consequently when a lock is released, the lock object
# is removed from that array.
#
# After failing to acquire a lock, the lock will iterate the list of acquired
# locks, and see if the current owner is waiting on any other held lock. If so,
# then we have identified a deadlock: the other fiber (waiting on the lock we
# own) is added to a "tainted" list of fibers on that lock, then the current
# fiber raises a deadlock exception.
#
# After acquiring a lock, the lock verifies whether the current fiber is in the
# lock's tainted list of fibers. If so, then we got a notified deadlock. The
# current fiber unlocks and raises a deadlock exception.

module Sync
  # :nodoc:
  module Deadlockable
    # While most usages could merely check `Fiber#owned_locks`, to be able to
    # check for deadlocks across multiple locks, we need to know the current
    # owner of the lock.
    @locked_by = Atomic(Fiber?).new(nil)

    protected def owns_lock? : Bool
      locked_by? == Fiber.current
    end

    private def locked_by? : Fiber?
      {% if flag?(:with_deadlocks) %}
        @locked_by.lazy_get
      {% else %}
        @locked_by.get(:relaxed)
      {% end %}
    end

    private def locked_by=(fiber : Fiber?)
      {% if flag?(:with_deadlocks) %}
        @locked_by.lazy_set(fiber)
      {% else %}
        @locked_by.set(fiber, :relaxed)
      {% end %}
    end

    private def set_owner(counter = 1, &) : Nil
      fiber = Fiber.current

      self.locked_by = fiber
      @counter = counter if @type.reentrant?

      {% unless flag?(:with_deadlocks) %}
        acquired_lock(fiber)
        detect_indirect_deadlock!(fiber) { yield }
      {% end %}
    end

    private def unset_owner : Nil
      self.locked_by = nil

      {% unless flag?(:with_deadlocks) %}
        released_lock(Fiber.current)
      {% end %}
    end

    {% unless flag?(:with_deadlocks) %}
      @mu : Sync::MU
      @tainted : Array({Fiber, Fiber, Deadlockable})?

      # Detects a deadlock involving multiple locks. For example 2 fibers
      # locking 2 mutexes in different order, each holding a lock that the other
      # is waiting on.
      private def detect_deadlock! : Nil
        # no owner? at worst the owner just unlocked and thus can't be waiting
        # on any lock owned by the current fiber (no deadlock)
        return unless owner = locked_by?

        fiber = Fiber.current
        Deadlockable.each_lock_owned_by(fiber) do |owned_lock|
          # is the lock's owner waiting on any lock we own?
          if owned_lock.waiting?(owner)
            # deadlock! taint the other fiber, so both sides will raise an
            # exception
            owned_lock.tainted(owner, fiber, self)
            raise Error.deadlock(fiber, owner, owned_lock, self)
          elsif owner != locked_by?
            # the owner changed: abort (no deadlock)
            return
          end
        end
      end

      # Detects a deadlock involving multiple locks as reported by the fiber on
      # the other side of the deadlock that noticed the deadlock.
      private def detect_indirect_deadlock!(fiber : Fiber, &) : Nil
        if result = tainted?(fiber)
          # the current fiber has been involved in a deadlock that has been
          # detected and avoided, unlock and raise an exception so both sides of
          # the deadlock fail with a backtrace
          _, other_fiber, other_lock = result
          yield
          raise Error.deadlock(fiber, other_fiber, other_lock, self)
        end
      end

      protected def tainted(fiber, other_fiber, other_lock) : Nil
        tainted = @tainted ||= [] of {Fiber, Fiber, Deadlockable}

        # there might be multiple deadlocks detected until fiber gets awoken, only
        # record the first notification
        unless tainted.any? { |(f, _, _)| f == fiber }
          tainted << {fiber, other_fiber, other_lock}
        end
      end

      private def tainted?(fiber)
        return unless tainted = @tainted

        # both sides may have detected a deadlock in parallel and notified the
        # other side that won't lock then check for taintness; we eventually
        # cleanup references to avoid leaking dead fiber objects
        tainted.reject! { |(f, _, _)| f.dead? }

        # search for a deadlock notification
        if index = tainted.index { |(f, _, _)| f == fiber }
          tainted.delete_at(index)
        end
      end

      protected def waiting?(fiber)
        @mu.waiting?(fiber)
      end

      # :nodoc:
      private def acquired_lock(fiber : Fiber) : Nil
        case lock_or_locks = fiber.owned_locks?
        when Nil
          fiber.owned_locks = self
        when Sync::Deadlockable
          fiber.owned_locks = [lock_or_locks, self]
        when Array
          lock_or_locks << self
        end
      end

      private def released_lock(fiber : Fiber) : Nil
        if (locks = fiber.owned_locks?).is_a?(Array)
          locks.delete(self)
        else
          fiber.owned_locks = nil
        end
      end

      protected def owns_lock?(fiber : Fiber) : Bool
        case lock_or_locks = fiber.owned_locks?
        when Sync::Deadlockable
          lock_or_locks == self
        when Array
          lock_or_locks.includes?(self)
        else
          false
        end
      end

      protected def self.each_lock_owned_by(fiber : Fiber, &) : Nil
        case lock_or_locks = fiber.owned_locks?
        when Sync::Deadlockable
          yield lock_or_locks
        when Array
          lock_or_locks.each { |lock| yield lock }
        end
      end
    {% end %}
  end
end
