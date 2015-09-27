require "spec"

describe Mutex do
  it "locks recursively" do
    mutex = Mutex.new :recursive
    mutex.synchronize do
      mutex.synchronize do
        mutex.try_lock.should be_true
        mutex.unlock
      end
    end
  end

  it "try_lock" do
    mutex = Mutex.new :recursive
    mutex.synchronize do
      thread = Thread.new do
        mutex.try_lock.should be_false
        nil
      end
      thread.join
    end
  end
end
