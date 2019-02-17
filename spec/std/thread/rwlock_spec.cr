require "spec"
require "../../support/errno"

describe Thread::RWLock do
  it "synchronizes writes" do
    a = 0
    rwlock = Thread::RWLock.new

    writers = 10.times.map do
      Thread.new do
        rwlock.synchronize_write { a += 1 }
      end
    end.to_a

    writers.each(&.join)
    a.should eq(10)
  end

  it "allows many readers; writer waits until readers are unlocked" do
    a = 1
    rwlock = Thread::RWLock.new

    # lock main reader:
    rwlock.lock_read

    writer = Thread.new do
      rwlock.synchronize_write { a = 2 }
    end

    # readers can read the value:
    readers = 10.times.map do
      Thread.new do
        rwlock.synchronize_read { a.should eq(1) }
      end
    end.to_a
    readers.each(&.join)

    # unlock last reader, which allows the writer:
    rwlock.unlock
    writer.join

    a.should eq(2)
  end

  it "won't lock writes recursively" do
    rwlock = Thread::RWLock.new
    rwlock.try_lock_write.should be_true
    rwlock.try_lock_write.should be_false
    expect_raises_errno(Errno::EDEADLK, "pthread_rwlock_wrlock: ") { rwlock.lock_write }
    rwlock.unlock
  end
end
