require "spec"
require "crystal/fd_lock"
require "wait_group"

describe Crystal::FdLock do
  describe "#reference" do
    it "acquires" do
      lock = Crystal::FdLock.new
      called = 0

      lock.reference { called += 1 }
      lock.reference { called += 1 }

      called.should eq(2)
    end

    it "allows reentrancy (side effect)" do
      lock = Crystal::FdLock.new
      called = 0

      lock.reference { called += 1 }
      lock.reference do
        lock.reference { called += 1 }
      end

      called.should eq(2)
    end

    it "acquires shared reference" do
      lock = Crystal::FdLock.new

      ready = WaitGroup.new(1)
      spawn do
        ready.done
        lock.reference { sleep 100.milliseconds }
      end

      ready.wait
      elapsed = Time.measure { lock.reference { } }

      elapsed.should be < 100.milliseconds
    end

    it "raises when closed" do
      lock = Crystal::FdLock.new
      lock.try_close? { }

      called = false
      expect_raises(IO::Error, "Closed") do
        lock.reference { called = false }
      end

      called.should be_false
    end
  end

  describe "#try_close?" do
    it "closes" do
      lock = Crystal::FdLock.new
      lock.closed?.should be_false

      called = false
      lock.try_close? { called = true }.should be_true
      lock.closed?.should be_true
      called.should be_true
    end

    it "closes once" do
      lock = Crystal::FdLock.new

      called = 0

      WaitGroup.wait do |wg|
        10.times do
          wg.spawn do
            lock.try_close? { called += 1 }
            lock.try_close? { called += 1 }
          end
        end
      end

      called.should eq(1)
    end

    it "waits for all references to return" do
      lock = Crystal::FdLock.new

      wg = WaitGroup.new
      exception = nil

      wg.spawn do
        lock.try_close? { }.should eq(true)
      rescue ex
        exception = ex
      end

      elapsed = Time.measure do
        lock.reference { }
        lock.reference { sleep(10.milliseconds) }
        wg.wait
      end

      if ex = exception
        raise ex
      end

      lock.closed?.should be_true
      elapsed.should be > 10.milliseconds
    end
  end

  it "#reset" do
    lock = Crystal::FdLock.new
    lock.try_close? { }
    lock.reset
    lock.try_close? { }.should eq(true)
  end
end
