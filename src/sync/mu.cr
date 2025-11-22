# Crystal adaptation of "mu" from the "nsync" library with adaptations by
# Justine Alexandra Roberts Tunney in the "cosmopolitan" C library.
#
# Copyright 2016 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# References:
# - <https://github.com/google/nsync>
# - <https://github.com/jart/cosmopolitan/tree/master/third_party/nsync/>

require "./waiter"

module Sync
  # :nodoc:
  struct MU
    UNLOCKED         =   0_u32
    WLOCK            =   1_u32
    SPINLOCK         =   2_u32
    WAITING          =   4_u32
    WRITER_WAITING   =   8_u32
    LONG_WAIT        =  16_u32
    DESIGNATED_WAKER =  32_u32
    RLOCK            = 256_u32

    RMASK    = ~(RLOCK - 1_u32)
    ANY_LOCK = WLOCK | RMASK

    LONG_WAIT_THRESHOLD = 30

    def initialize
      @word = Atomic(UInt32).new(UNLOCKED)
      @waiters = Crystal::PointerLinkedList(Waiter).new
    end

    def synchronize(&) : Nil
      lock
      begin
        yield
      ensure
        unlock
      end
    end

    def try_lock? : Bool
      # uncontended
      word, success = @word.compare_and_set(UNLOCKED, WLOCK, :acquire, :relaxed)
      return true if success

      if (word & (ANY_LOCK | LONG_WAIT)) == 0
        # unlocked (no writer, no readers), no long waiter, try quick lock
        _, success = @word.compare_and_set(word, word + WLOCK, :acquire, :relaxed)
        success
      else
        false
      end
    end

    def try_rlock? : Bool
      # uncontended
      word, success = @word.compare_and_set(UNLOCKED, RLOCK, :release, :relaxed)
      return true if success

      if (word & (WLOCK | WRITER_WAITING | LONG_WAIT)) == 0
        # no locked writer, no writer waiting, no long waiter, try quick lock
        _, success = @word.compare_and_set(word, word + RLOCK, :acquire, :relaxed)
        success
      else
        false
      end
    end

    def lock : Nil
      lock_slow unless try_lock?
    end

    def rlock : Nil
      rlock_slow unless try_rlock?
    end

    def lock_slow
      waiter = Waiter.new(:writer)

      lock_slow_impl(pointerof(waiter),
        zero_to_acquire: ANY_LOCK,
        add_on_acquire: WLOCK,
        set_on_waiting: WRITER_WAITING,
        clear_on_acquire: WRITER_WAITING)
    end

    def rlock_slow
      waiter = Waiter.new(:reader)

      lock_slow_impl(pointerof(waiter),
        zero_to_acquire: WLOCK | WRITER_WAITING,
        add_on_acquire: RLOCK)
    end

    protected def lock_slow(waiter : Pointer(Waiter), clear : UInt32)
      if waiter.value.writer?
        zero_to_acquire = ANY_LOCK
        add_on_acquire = WLOCK
        set_on_waiting = WRITER_WAITING
        clear_on_acquire = WRITER_WAITING
      else
        zero_to_acquire = WLOCK | WRITER_WAITING
        add_on_acquire = RLOCK
        set_on_waiting = 0_u32
        clear_on_acquire = 0_u32
      end
      lock_slow_impl(waiter, zero_to_acquire, add_on_acquire, set_on_waiting, clear_on_acquire, clear)
    end

    private def lock_slow_impl(waiter, zero_to_acquire, add_on_acquire, set_on_waiting = 0_u32, clear_on_acquire = 0_u32, clear = 0_u32) : Nil
      long_wait = 0_u32
      zero_to_acquire |= LONG_WAIT
      set_on_waiting |= WAITING

      attempts = 0
      wait_count = 0

      while true
        word = @word.get(:relaxed)

        if (word & zero_to_acquire) == 0
          # unlocked, no long waiter, try to lock
          word, success = @word.compare_and_set(word, (word + add_on_acquire) & ~(long_wait | clear | clear_on_acquire), :acquire, :relaxed)
          return if success
        elsif (word & SPINLOCK) == 0
          # locked by another fiber or there is a long waiter, spinlock is
          # available, try to acquire spinlock
          _, success = @word.compare_and_set(word, (word | SPINLOCK | set_on_waiting | long_wait) & ~clear, :acquire, :relaxed)
          if success
            waiter.value.waiting!

            if wait_count == 0
              # first wait goes to the tail
              @waiters.push(waiter)
            else
              # subsequent ones go to the head
              @waiters.unshift(waiter)
            end
            release_spinlock

            # wait...
            waiter.value.wait
            # ...resumed

            attempts = 0
            wait_count += 1

            if wait_count == LONG_WAIT_THRESHOLD
              long_wait = LONG_WAIT
            end

            # woken fiber doesn't care about long wait or a writer waiting, and
            # must clear the designated waker flag
            zero_to_acquire &= ~(LONG_WAIT | WRITER_WAITING)
            clear = DESIGNATED_WAKER
          end
        end

        # yield the thread, not the fiber, because the above CAS are fighting
        # against fibers running in parallel threads, trying to (spin)lock /
        # unlock.
        attempts = Thread.delay(attempts)
      end
    end

    def unlock : Nil
      # uncontended
      word, success = @word.compare_and_set(WLOCK, UNLOCKED, :acquire, :relaxed)
      return true if success

      # sanity check
      if (word & WLOCK) == 0
        raise RuntimeError.new("Can't unlock Sync::MU that isn't held")
      end

      if (word & WAITING) == 0 && (word & DESIGNATED_WAKER) != 0
        # no waiters, or there is a designated waker already (no need to wake
        # another one), try quick unlock
        _, success = @word.compare_and_set(word, word &- WLOCK, :release, :relaxed)
        return if success
      end

      # must try to wakeup a waiter
      unlock_slow
    end

    def runlock : Nil
      # uncontended
      word, success = @word.compare_and_set(RLOCK, UNLOCKED, :release, :relaxed)
      return if success

      # sanity check
      if (word & RMASK) == 0
        raise RuntimeError.new("Can't runlock Sync::MU that isn't held")
      end

      if (word & WAITING) == 0 && (word & DESIGNATED_WAKER) != 0 && (word & RMASK) > RLOCK
        # no waiters, there is a designated waker already (no need to wake
        # another one), and there are still readers, try quick unlock
        _, success = @word.compare_and_set(word, word &- RLOCK, :release, :relaxed)
        return if success
      end

      # must try to wakeup a waiter
      runlock_slow
    end

    def unlock_slow : Nil
      unlock_slow_impl(sub_on_release: WLOCK)
    end

    def runlock_slow : Nil
      unlock_slow_impl(sub_on_release: RLOCK)
    end

    private def unlock_slow_impl(sub_on_release) : Nil
      attempts = 0

      while true
        word = @word.get(:relaxed)

        if (word & WAITING) == 0 || (word & DESIGNATED_WAKER) != 0 || (word & RMASK) > RLOCK
          # no waiters, there is a designated waker (no need to wake another
          # one), or there are still readers, try release lock
          word, success = @word.compare_and_set(word, word - sub_on_release, :release, :relaxed)
          return if success
        elsif (word & SPINLOCK) == 0
          # there might be a waiter, and no designated waker, try to acquire
          # spinlock, and release the lock (early)
          _, success = @word.compare_and_set(word, (word | SPINLOCK | DESIGNATED_WAKER) &- sub_on_release, :acquire_release, :relaxed)
          if success
            # spinlock is held, resume a single writer, or resume all readers
            wake = Crystal::PointerLinkedList(Waiter).new
            writer_waiting = 0_u32

            if first_waiter = @waiters.shift?
              wake.push(first_waiter)

              if first_waiter.value.reader?
                @waiters.each do |waiter|
                  if waiter.value.reader?
                    @waiters.delete(waiter)
                    wake.push(waiter)
                  else
                    # found a writer, prevent new readers from locking
                    writer_waiting = WRITER_WAITING
                  end
                end
              end
            end

            # update flags
            clear = 0_u32
            clear |= DESIGNATED_WAKER if wake.empty? # nothing to wake => no designated waker
            clear |= WAITING if @waiters.empty?      # no more waiters => nothing waiting

            release_spinlock(set: writer_waiting, clear: clear)

            wake.consume_each do |waiter|
              waiter.value.wake
            end

            return
          end
        end

        attempts = Thread.delay(attempts)
      end
    end

    def held? : Bool
      word = @word.get(:relaxed)
      (word & WLOCK) != 0
    end

    def rheld? : Bool
      word = @word.get(:relaxed)
      (word & RMASK) != 0
    end

    private def release_spinlock(set = 0_u32, clear = 0_u32)
      word = @word.get(:relaxed)

      while true
        word, success = @word.compare_and_set(word, (word | set) & ~(SPINLOCK | clear), :release, :relaxed)
        return if success
      end
    end
  end
end
