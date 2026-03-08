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
end
