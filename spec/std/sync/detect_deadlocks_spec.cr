{% skip_file if flag?(:with_deadlocks) %}

require "./spec_helper"

describe Sync::Deadlockable do
  {% for type, method in {Sync::Mutex => :synchronize, Sync::RWLock => :write} %}
    {% for protection in [:Checked, :Reentrant] %}
      {% name = type.name.split("::").last.downcase.id %}

      it "detects lock order mismatch ({{name}}, {{protection.downcase.id}})" do
        ready = WaitGroup.new(1)
        l1 = {{type}}.new(Sync::Type::{{protection.id}})
        l2 = {{type}}.new(Sync::Type::{{protection.id}})

        f1, ch1 = Sync.async_channel("f1") do
          l1.{{method.id}} do
            ready.wait
            l2.{{method.id}} { fail "expected fiber1 to raise before locking {{name}}2" }
          end
        end

        f2, ch2 = Sync.async_channel("f2") do
          l2.{{method.id}} do
            ready.done
            l1.{{method.id}} { fail "expected fiber2 to raise before locking {{name}}1" }
          end
        end

        2.times do
          select
          when ex1 = ch1.receive
            Sync.expect_deadlock(ex1, f1, f2, l1, l2)
          when ex2 = ch2.receive
            Sync.expect_deadlock(ex2, f2, f1, l2, l1)
          when timeout(1.second)
            fail "timeout: deadlock not detected within 1 second"
          end
        end

        l1.@mu.held?.should be_false, "expected {{name}} l1 to have been unlocked"
        l2.@mu.held?.should be_false, "expected {{name}} l2 to have been unlocked"
      end
    {% end %}
  {% end %}

  it "detects lock order mismatch between mutex and rwlock" do
    ready = WaitGroup.new(1)
    mutex = Sync::Mutex.new
    rwlock = Sync::RWLock.new

    f1, ch1 = Sync.async_channel("f1") do
      mutex.synchronize do
        ready.wait
        rwlock.write { fail "expected fiber1 to raise before locking rwlock" }
      end
    end

    f2, ch2 = Sync.async_channel("f2") do
      rwlock.write do
        ready.done
        mutex.synchronize { fail "expected fiber2 to raise before locking mutex" }
      end
    end

    2.times do
      select
      when ex1 = ch1.receive
        Sync.expect_deadlock(ex1, f1, f2, mutex, rwlock)
      when ex2 = ch2.receive
        Sync.expect_deadlock(ex2, f2, f1, rwlock, mutex)
      when timeout(1.second)
        fail "timeout: deadlock not detected within 1 second"
      end
    end

    mutex.@mu.held?.should be_false, "expected mutex to have been unlocked"
    rwlock.@mu.held?.should be_false, "expected rwlock to have been write unlocked"
  end

  describe "rwlock reentrancy" do
    it "lock_read -> lock_read" do
      expect_raises(Sync::Error::Deadlock, "Can't acquire read lock recursively") do
        Sync.timeout do
          rwlock = Sync::RWLock.new
          rwlock.read do
            rwlock.read { fail "expected nested lock_read to raise" }
          end
        end
      end
    end

    it "lock_write -> lock_read" do
      expect_raises(Sync::Error::Deadlock, "Can't acquire read lock while holding the write lock") do
        Sync.timeout do
          rwlock = Sync::RWLock.new
          rwlock.write do
            rwlock.read { fail "expected nested lock_read to raise" }
          end
        end
      end
    end

    it "lock_read -> lock_write" do
      expect_raises(Sync::Error::Deadlock, "Can't acquire write lock while holding the read lock") do
        Sync.timeout do
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
