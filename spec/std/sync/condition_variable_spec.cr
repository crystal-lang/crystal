require "./spec_helper"
require "sync/mutex"
require "sync/rw_lock"
require "sync/condition_variable"

describe Sync::ConditionVariable do
  it "#signal" do
    m = Sync::Mutex.new
    c = Sync::ConditionVariable.new(m)

    m.synchronize do
      spawn do
        m.synchronize { c.signal }
      end

      c.wait
    end
  end

  it "#signal mutex" do
    m = Sync::Mutex.new
    c = Sync::ConditionVariable.new(m)
    done = waiting = 0
    n = 100

    n.times do
      spawn do
        m.synchronize do
          waiting += 1
          c.wait
          done += 1
        end
      end
    end
    Sync.eventually { waiting.should eq(n) }

    # resume fibers one by one
    n.times do |i|
      Sync.eventually { done.should eq(i) }
      c.signal
      Fiber.yield
    end

    Sync.eventually { done.should eq(n) }
  end

  it "#signal rwlock" do
    l = Sync::RWLock.new
    c = Sync::ConditionVariable.new(l)

    r = 50
    w = 10
    done = waiting = 0

    r.times do
      spawn do
        until done == w
          l.read { c.wait }
        end
      end
    end

    w.times do
      spawn do
        l.write do
          waiting += 1
          c.wait
          done += 1
        end
      end
    end

    Sync.eventually { waiting.should eq(w) }

    # resumes at most one writer per signal
    w.times do |i|
      Sync.eventually { done.should eq(i) }
      c.signal
      Fiber.yield
    end

    # wake any pending readers
    c.broadcast
  end

  it "#broadcast mutex" do
    m = Sync::Mutex.new
    c = Sync::ConditionVariable.new(m)
    done = waiting = 0

    100.times do
      spawn do
        m.synchronize do
          waiting += 1
          c.wait
          done += 1
        end
      end
    end
    Sync.eventually { waiting.should eq(100) }
    done.should eq(0)

    # resume all fibers at once (synchronize so all fibers are waiting)
    m.synchronize { c.broadcast }
    Sync.eventually { done.should eq(100) }
  end

  it "#broadcast rwlock" do
    l = Sync::RWLock.new
    c = Sync::ConditionVariable.new(l)
    done = waiting = 0
    r = 50
    w = 100

    r.times do |i|
      spawn(name: "cv:read_#{i}") do
        l.read { c.wait }
      end
    end

    w.times do |i|
      spawn(name: "cv:write_#{i}") do
        l.write do
          waiting += 1
          c.wait
          done += 1
        end
      end
    end
    Sync.eventually { waiting.should eq(w) }
    done.should eq(0)

    # resume all fibers at once (lock read so all writers are waiting)
    l.read { c.broadcast }

    Sync.eventually { done.should eq(w) }
  end

  it "producer consumer pattern" do
    m = Sync::Mutex.new
    c = Sync::ConditionVariable.new(m)

    state = -1
    ready = false

    spawn(name: "cv:consumer") do
      m.synchronize do
        ready = true
        c.wait
        state.should eq(1)
        state = 2
      end
    end

    spawn(name: "cv:producer") do
      Sync.eventually { ready.should be_true, "expected consumer to eventually be ready" }
      m.synchronize { state = 1 }
      c.signal
    end

    Sync.eventually { state.should eq(2) }
  end

  it "reentrant mutex" do
    m = Sync::Mutex.new(:reentrant)
    c = Sync::ConditionVariable.new(m)

    m.lock
    m.lock

    spawn do
      m.lock
      c.signal
      m.unlock
    end

    c.wait

    m.unlock
    m.unlock # musn't raise (can't unlock Sync::Mutex that isn't locked)
  end

  it "reentrant rwlock" do
    m = Sync::RWLock.new(:reentrant)
    c = Sync::ConditionVariable.new(m)

    m.lock_write
    m.lock_write

    spawn do
      m.lock_write
      c.signal
      m.unlock_write
    end

    c.wait

    m.unlock_write
    m.unlock_write # musn't raise (can't unlock Sync::RWLock that isn't locked)
  end

  describe "#wait with a deadline" do
    it "expires at a future deadline and reacquires the lock" do
      lock = Sync::Mutex.new
      cv = Sync::ConditionVariable.new(lock)

      lock.synchronize do
        deadline = Time.instant + 10.milliseconds
        expired = false
        cv.wait(deadline) { expired = true }
        expired.should be_true
        Time.instant.should be >= deadline
      end
    end

    it "expires at a future deadline and reacquires a read lock" do
      lock = Sync::RWLock.new
      cv = Sync::ConditionVariable.new(lock)

      lock.read do
        deadline = Time.instant + 10.milliseconds
        expired = false
        cv.wait(deadline) { expired = true }
        expired.should be_true
        Time.instant.should be >= deadline
      end
    end

    it "expires and restores a reentrant mutex" do
      lock = Sync::Mutex.new(:reentrant)
      cv = Sync::ConditionVariable.new(lock)

      lock.synchronize do
        lock.synchronize do
          expired = false
          cv.wait(Time.instant - 1.second) { expired = true }
          expired.should be_true
        end
      end
    end

    it "returns success when signaled before the deadline" do
      lock = Sync::Mutex.new
      cv = Sync::ConditionVariable.new(lock)

      lock.synchronize do
        # expired wait
        expired = false
        cv.wait(Time.instant) { expired = true }
        expired.should be_true

        spawn do
          # signal must wake the blocked wait (below) not the expired wait (above)
          lock.synchronize { cv.signal }
        end

        # blocked wait
        expired = false
        cv.wait(Time.instant + 1.second) { expired = true }
        expired.should be_false
      end
    end

    it "returns success if broadcast transfers a waiter before expiry" do
      mutex = Sync::Mutex.new
      cv = Sync::ConditionVariable.new(mutex)
      ready = Channel(Time::Instant).new
      result = Channel(Bool).new(1)
      returned = WaitGroup.new(1)

      spawn do
        mutex.synchronize do
          deadline = Time.instant + 100.milliseconds
          ready.send(deadline)

          expired = false
          cv.wait(deadline) { expired = true }
          result.send(expired)
        end
        returned.done
      end

      deadline = ready.receive

      mutex.synchronize do
        cv.broadcast

        # Keep the mutex held past the deadline after transferring the waiter.
        sleep(deadline.duration_since(Time.instant) + 10.milliseconds)

        select
        when result.receive
          fail "wait returned before reacquiring the lock"
        else
          # skip
        end
      end

      result.receive.should be_false

      returned.wait
    end
  end
end
