require "spec"

describe Mutex do
  it "locks and unlocks" do
    mutex = Mutex.new
    mutex.lock
    mutex.unlock
  end

  it "raises if unlocks without lock" do
    mutex = Mutex.new
    expect_raises(Exception, "Attempt to unlock a mutex which is not locked") do
      mutex.unlock
    end
  end

  it "can be locked many times from the same fiber" do
    mutex = Mutex.new
    mutex.lock
    mutex.lock
    mutex.unlock
    mutex.unlock
  end

  it "can lock and unlock from multiple fibers" do
    mutex = Mutex.new

    a = 1
    two = false
    three = false
    four = false
    ch = Channel(Nil).new

    spawn do
      mutex.synchronize do
        a = 2
        Fiber.yield
        two = a == 2
      end
      ch.send(nil)
    end

    spawn do
      mutex.synchronize do
        a = 3
        Fiber.yield
        three = a == 3
      end
      ch.send(nil)
    end

    spawn do
      mutex.synchronize do
        a = 4
        Fiber.yield
        four = a == 4
      end
      ch.send(nil)
    end

    3.times { ch.receive }

    two.should be_true
    three.should be_true
    four.should be_true
  end
end
