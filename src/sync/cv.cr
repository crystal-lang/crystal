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

require "crystal/pointer_linked_list"
require "./mu"
require "./waiter"

module Sync
  # :nodoc:
  struct CV
    SPINLOCK  = 1_u32
    NON_EMPTY = 2_u32

    def initialize
      @word = Atomic(UInt32).new(0_u32)
      @waiters = Crystal::PointerLinkedList(Waiter).new
    end

    # TODO: wait until deadline
    def wait(mu : Pointer(MU)) : Nil
      waiter = Waiter.new(waiter_type(mu), mu)
      waiter.waiting!

      old_word = acquire_spinlock(set: NON_EMPTY)
      @waiters.push(pointerof(waiter))
      release_spinlock(old_word | NON_EMPTY)

      # release mu
      if waiter.writer?
        mu.value.unlock
      else
        mu.value.runlock
      end

      # wait...
      waiter.wait
      # ...resumed

      if cv_mu = waiter.cv_mu
        # waiter was woken from cv, and must re-acquire mu
        if waiter.writer?
          cv_mu.value.lock
        else
          cv_mu.value.rlock
        end
      else
        # waiter was moved to mu's queue, then awoken from mu and is thus a
        # designated waker, but it doesn't locked yet and must enter the lock
        # loop, and clear the DESIGNATED_WAKER flag
        mu.value.lock_slow(pointerof(waiter), clear: MU::DESIGNATED_WAKER)
      end
    end

    def signal : Nil
      word = @word.get(:acquire)
      return if (word & NON_EMPTY) == 0

      wake = Crystal::PointerLinkedList(Waiter).new
      all_readers = false

      old_word = acquire_spinlock

      if first_waiter = @waiters.shift?
        wake.push(first_waiter)

        if first_waiter.value.reader?
          # first waiter is a reader: wake all readers, and one writer (if any),
          # this allows all shared accesses to be resumed, while still allowing
          # only one exclusive access
          all_readers = true
          woke_writer = false

          @waiters.each do |waiter|
            if waiter.value.writer?
              next if woke_writer
              all_readers = false
              woke_writer = true
            end

            @waiters.delete(waiter)
            wake.push(waiter)
          end
        end

        if @waiters.empty?
          old_word &= ~NON_EMPTY
        end
      end

      release_spinlock(old_word)

      wake_waiters pointerof(wake), all_readers
    end

    def broadcast : Nil
      word = @word.get(:acquire)
      return if (word & NON_EMPTY) == 0

      wake = Crystal::PointerLinkedList(Waiter).new
      all_readers = true

      old_word = acquire_spinlock

      # wake all waiters
      while waiter = @waiters.shift?
        all_readers = false if waiter.value.writer?
        wake.push(waiter)
      end

      release_spinlock(old_word & ~NON_EMPTY)

      wake_waiters pointerof(wake), all_readers
    end

    private def wake_waiters(wake, all_readers)
      return unless first_waiter = wake.value.first?

      if mu = first_waiter.value.cv_mu
        # try to transfer to mu's queue
        mu.value.try_transfer(wake, first_waiter, all_readers)
      end

      # wake waiters that didn't get transferred
      wake.value.consume_each(&.value.wake)
    end

    private def waiter_type(mu)
      is_writer = mu.value.held?
      is_reader = mu.value.rheld?

      if is_writer
        if is_reader
          raise "BUG: MU is held in reader and writer mode simultaneously on entry to CV#wait"
        end
        Waiter::Type::Writer
      elsif is_reader
        Waiter::Type::Reader
      else
        raise "BUG: MU not held on entry to CV#wait"
      end
    end

    private def acquire_spinlock(set = 0_u32, clear = 0_u32)
      attempts = 0

      while true
        word = @word.get(:relaxed)

        if (word & SPINLOCK) == 0
          _, success = @word.compare_and_set(word, (word | SPINLOCK | set) & ~clear, :acquire, :relaxed)
          return word if success
        end

        attempts = Thread.delay(attempts)
      end
    end

    private def release_spinlock(word)
      @word.set(word & ~SPINLOCK)
    end
  end
end
