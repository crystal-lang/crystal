require "spec"
require "crystal/fd_lock"
require "wait_group"

describe Crystal::FdLock do
  describe "#read" do
    it "acquires read lock" do
      lock = Crystal::FdLock.new
      called = 0

      lock.read { called += 1 }
      lock.read { called += 1 }

      called.should eq(2)
    end

    it "acquires exclusive lock" do
      lock = Crystal::FdLock.new
      increment = 0

      WaitGroup.wait do |wg|
        10.times do
          wg.spawn do
            100_000.times do |i|
              lock.read do
                increment += 1
                # Fiber.yield if i % 100 == 1
              end
            end
          end
        end
      end

      increment.should eq(1_000_000)
    end

    it "raises when closed" do
      lock = Crystal::FdLock.new
      called = false

      lock.try_close? { }
      expect_raises(IO::Error, "Closed") { lock.read { called = true; Fiber.yield } }

      called.should eq(false)
    end
  end

  describe "#write" do
    it "acquires write lock" do
      lock = Crystal::FdLock.new
      called = 0

      lock.write { called += 1 }
      lock.write { called += 1 }

      called.should eq(2)
    end

    it "acquires exclusive lock" do
      lock = Crystal::FdLock.new
      increment = 0

      WaitGroup.wait do |wg|
        10.times do
          wg.spawn do
            100_000.times do |i|
              lock.write do
                increment += 1
                # Fiber.yield if i % 100 == 1
              end
            end
          end
        end
      end

      increment.should eq(1_000_000)
    end

    it "raises when closed" do
      lock = Crystal::FdLock.new
      called = false

      lock.try_close? { }
      expect_raises(IO::Error, "Closed") { lock.read { called = true } }

      called.should eq(false)
    end
  end

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

      release.receive.should eq("ok")
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
        lock.try_close? { called = true }.should be_true
        lock.closed?.should be_true
        called.should be_true
      end
      exceptions.close

      if ex = exceptions.receive?
        raise ex
      end
    end

    it "resumes waiters" do
      lock = Crystal::FdLock.new

      ready = WaitGroup.new(8)
      running = WaitGroup.new
      exceptions = Channel(Exception).new(8)

      # acquire locks
      lock.read do
        lock.write do
          # spawn concurrent fibers
          4.times do |i|
            running.spawn do
              ready.done
              lock.read { }
            rescue ex
              exceptions.send(ex)
            end

            running.spawn do
              ready.done
              lock.write { }
            rescue ex
              exceptions.send(ex)
            end
          end

          # wait for all the concurrent fibers to be trying to lock
          ready.wait
        end
      end

      # close, then wait for the fibers to be resumed (and fail)
      lock.try_close? { }.should eq(true)
      running.wait
      exceptions.close

      # fibers should have failed (unlikely: one may succeed to lock)
      failed = 0
      while ex = exceptions.receive?
        failed += 1
        ex.should be_a(IO::Error)
        ex.message.should eq("Closed")
      end
      failed.should be > 0
    end
  end

  it "locks read + write + shared reference" do
    lock = Crystal::FdLock.new
    called = 0

    lock.read do
      lock.write do
        lock.reference do
          called += 1
        end
      end
    end

    called.should eq(1)
  end

  it "#reset" do
    lock = Crystal::FdLock.new
    lock.try_close? { }
    lock.reset
    lock.try_close? { }.should eq(true)
  end
end
