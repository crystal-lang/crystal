require "spec"
require "sync"
require "wait_group"

{% unless flag?(:detect_deadlocks) %}
  {% nil.warning "WARNING: detecting deadlocks requires the -Ddetect_deadlock compilation flag" %}
{% end %}

class Sync::Error::Deadlock
  def_equals message, fiber1, fiber2, lock1, lock2
end

private def async(name, &block)
  channel = Channel(Exception).new

  fiber = spawn(name: name) do
    block.call
  rescue ex
    channel.send(ex)
  end

  {fiber, channel}
end

private def timeout(name = nil, &block)
  _, channel = async(name, &block)

  select
  when ex = channel.receive
    raise ex if ex
  when timeout(1.second)
    fail "timeout: didn't detect deadlock within 1.second"
  end
end

private def expect_deadlock(ex, f1, f2, l1, l2)
  if ex.is_a?(Sync::Error::Deadlock)
    ex.should eq Sync::Error.deadlock(f1, f2, l1, l2)
  else
    raise ex
  end
end

describe "detect_deadlocks" do
  describe "lock order" do
    it "between mutexes" do
      ready = WaitGroup.new(1)
      l1 = Sync::Mutex.new
      l2 = Sync::Mutex.new

      f1, ch1 = async("f1") do
        l1.synchronize do
          ready.wait
          l2.synchronize { fail "expected fiber1 to raise before locking mutex2" }
        end
      end

      f2, ch2 = async("f2") do
        l2.synchronize do
          ready.done
          l1.synchronize { fail "expected fiber2 to raise before locking mutex1" }
        end
      end

      2.times do
        select
        when ex1 = ch1.receive
          expect_deadlock(ex1, f1, f2, l1, l2)
        when ex2 = ch2.receive
          expect_deadlock(ex2, f2, f1, l2, l1)
        when timeout(1.second)
          fail "timeout: deadlock not detected within 1 second"
        end
      end

      l1.@mu.held?.should be_false, "expected mutex l1 to have been unlocked"
      l2.@mu.held?.should be_false, "expected mutex l2 to have been unlocked"
    end

    it "between rwlocks (write)" do
      ready = WaitGroup.new(1)
      l1 = Sync::RWLock.new
      l2 = Sync::RWLock.new

      f1, ch1 = async("f1") do
        l1.write do
          ready.wait
          l2.write { fail "expected fiber1 to raise before locking rwlock2" }
        end
      end

      f2, ch2 = async("f2") do
        l2.write do
          ready.done
          l1.write { fail "expected fiber2 to raise before locking rwlock1" }
        end
      end

      2.times do
        select
        when ex1 = ch1.receive
          expect_deadlock(ex1, f1, f2, l1, l2)
        when ex2 = ch2.receive
          expect_deadlock(ex2, f2, f1, l2, l1)
        when timeout(1.second)
          fail "timeout: deadlock not detected within 1 second"
        end
      end

      l1.@mu.held?.should be_false, "expected rwlock l1 to have been write unlocked"
      l2.@mu.held?.should be_false, "expected rwlock l2 to have been write unlocked"
    end

    it "between mutex and rwlock (write)" do
      ready = WaitGroup.new(1)
      mutex = Sync::Mutex.new
      rwlock = Sync::RWLock.new

      f1, ch1 = async("f1") do
        mutex.synchronize do
          ready.wait
          rwlock.write { fail "expected fiber1 to raise before locking rwlock" }
        end
      end

      f2, ch2 = async("f2") do
        rwlock.write do
          ready.done
          mutex.synchronize { fail "expected fiber2 to raise before locking mutex" }
        end
      end

      2.times do
        select
        when ex1 = ch1.receive
          expect_deadlock(ex1, f1, f2, mutex, rwlock)
        when ex2 = ch2.receive
          expect_deadlock(ex2, f2, f1, rwlock, mutex)
        when timeout(1.second)
          fail "timeout: deadlock not detected within 1 second"
        end
      end

      mutex.@mu.held?.should be_false, "expected mutex to have been unlocked"
      rwlock.@mu.held?.should be_false, "expected rwlock to have been write unlocked"
    end
  end

  describe "rwlock reentrancy" do
    it "lock_read -> lock_read" do
      expect_raises(Sync::Error::Deadlock, "Can't acquire read lock recursively") do
        timeout do
          rwlock = Sync::RWLock.new
          rwlock.read do
            rwlock.read { fail "expected nested lock_read to raise" }
          end
        end
      end
    end

    it "lock_write -> lock_read" do
      expect_raises(Sync::Error::Deadlock, "Can't acquire read lock while holding the write lock") do
        timeout do
          rwlock = Sync::RWLock.new
          rwlock.write do
            rwlock.read { fail "expected nested lock_read to raise" }
          end
        end
      end
    end

    it "lock_read -> lock_write" do
      expect_raises(Sync::Error::Deadlock, "Can't acquire write lock while holding the read lock") do
        timeout do
          rwlock = Sync::RWLock.new
          rwlock.read do
            rwlock.write { fail "expected nested lock_write to raise" }
          end
        end
      end
    end
  end

  describe "scenarios" do
    it "reentrant lock_read blocks lock_write" do
      lock = Sync::RWLock.new
      ch_wlock = Channel(Nil).new
      ch_rlock = Channel(Nil).new
      result = Channel(Exception?).new

      spawn(name: "lock") do
        ch_wlock.receive
        lock.lock_write # blocked by read lock
        result.send(nil)
        lock.unlock_write
      end

      fiber = spawn(name: "rlock_twice") do
        lock.read do
          ch_rlock.receive
          ch_rlock.receive?

          lock.lock_read
        end
      rescue ex
        result.send(ex)
      end

      ch_rlock.send(nil)
      ch_wlock.send(nil)
      ch_rlock.close

      2.times do
        select
        when ex = result.receive
          case ex
          when Nil
            break
          when Sync::Error::Deadlock
            ex.message.should eq "Can't acquire read lock recursively"
            ex.fiber1.should eq(fiber)
            ex.fiber2.should eq(fiber)
            ex.lock1.should eq(lock)
            ex.lock2.should eq(lock)
          else
            raise ex
          end
        when timeout(1.second)
          fail "timeout: deadlock not detected within 1 second"
        end
      end
    end
  end
end
