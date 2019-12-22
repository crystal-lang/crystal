require "spec"

describe Mutex do
  it "locks and unlocks" do
    mutex = Mutex.new
    mutex.lock
    mutex.unlock
  end

  it "works with multiple threads" do
    x = 0
    mutex = Mutex.new

    fibers = 10.times.map do
      spawn do
        100.times do
          mutex.synchronize { x += 1 }
        end
      end
    end.to_a

    fibers.each do |f|
      while !f.dead?
        Fiber.yield
      end
    end

    x.should eq(1000)
  end

  describe "checked" do
    it "raises if locked recursively" do
      mutex = Mutex.new
      mutex.lock
      expect_raises(Exception, "Attempt to lock a mutex recursively (deadlock)") do
        mutex.lock
      end
    end

    it "raises if unlocks without lock" do
      mutex = Mutex.new
      expect_raises(Exception, "Attempt to unlock a mutex which is not locked") do
        mutex.unlock
      end
    end

    it "can't be unlocked by another fiber" do
      mutex = nil

      spawn do
        mutex = Mutex.new
        mutex.not_nil!.lock
      end

      until mutex
        Fiber.yield
      end

      expect_raises(Exception, "Attempt to unlock a mutex locked by another fiber") do
        mutex.not_nil!.unlock
      end
    end
  end

  describe "reentrant" do
    it "can be locked many times from the same fiber" do
      mutex = Mutex.new(:reentrant)
      mutex.lock
      mutex.lock
      mutex.unlock
      mutex.unlock
    end

    it "raises if unlocks without lock" do
      mutex = Mutex.new(:reentrant)
      expect_raises(Exception, "Attempt to unlock a mutex which is not locked") do
        mutex.unlock
      end
    end

    it "can't be unlocked by another fiber" do
      mutex = nil

      spawn do
        mutex = Mutex.new(:reentrant)
        mutex.not_nil!.lock
      end

      until mutex
        Fiber.yield
      end

      expect_raises(Exception, "Attempt to unlock a mutex locked by another fiber") do
        mutex.not_nil!.unlock
      end
    end
  end

  describe "unchecked" do
    it "can lock and unlock from multiple fibers" do
      mutex = Mutex.new(:unchecked)

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
end
