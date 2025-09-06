require "spec"
require "../../../src/crystal/fd_lock"
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
      release = Channel(String).new

      spawn do
        lock.reference do
          ready.done

          select
          when release.send("ok")
          when timeout(1.second)
            release.send("timeout")
          end
        end
      end

      ready.wait
      lock.reference { }

      release.receive.should_not eq("timeout")
    end

    it "raises when closed" do
      lock = Crystal::FdLock.new
      lock.try_close? { }

      called = false
      expect_raises(IO::Error, "Closed") do
        lock.reference { called = true }
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

      ready = WaitGroup.new(10)
      exceptions = Channel(Exception).new(10)

      WaitGroup.wait do |wg|
        10.times do
          wg.spawn do
            begin
              lock.reference do
                ready.done
                Fiber.yield
              end
            rescue ex
              exceptions.send(ex)
            end
          end
        end

        ready.wait

        called = false
        lock.try_close? { called = true }.should eq(true)
        lock.closed?.should be_true
      end
      exceptions.close

      if ex = exceptions.receive?
        raise ex
      end
    end
  end

  it "#reset" do
    lock = Crystal::FdLock.new
    lock.try_close? { }
    lock.reset
    lock.try_close? { }.should eq(true)
  end
end
