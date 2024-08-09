require "spec"
require "wait_group"

private def block_until_pending_waiter(wg)
  while wg.@waiting.empty?
    Fiber.yield
  end
end

private def forge_counter(wg, value)
  wg.@counter.set(value)
end

describe WaitGroup do
  describe "#add" do
    it "can't decrement to a negative counter" do
      wg = WaitGroup.new
      wg.add(5)
      wg.add(-3)
      expect_raises(RuntimeError, "Negative WaitGroup counter") { wg.add(-5) }
    end

    it "resumes waiters when reaching negative counter" do
      wg = WaitGroup.new(1)
      spawn do
        block_until_pending_waiter(wg)
        wg.add(-2)
      rescue RuntimeError
      end
      expect_raises(RuntimeError, "Negative WaitGroup counter") { wg.wait }
    end

    it "can't increment after reaching negative counter" do
      wg = WaitGroup.new
      forge_counter(wg, -1)

      # check twice, to make sure the waitgroup counter wasn't incremented back
      # to a positive value!
      expect_raises(RuntimeError, "Negative WaitGroup counter") { wg.add(5) }
      expect_raises(RuntimeError, "Negative WaitGroup counter") { wg.add(3) }
    end
  end

  describe "#done" do
    it "can't decrement to a negative counter" do
      wg = WaitGroup.new
      wg.add(1)
      wg.done
      expect_raises(RuntimeError, "Negative WaitGroup counter") { wg.done }
    end

    it "resumes waiters when reaching negative counter" do
      wg = WaitGroup.new(1)
      spawn do
        block_until_pending_waiter(wg)
        forge_counter(wg, 0)
        wg.done
      rescue RuntimeError
      end
      expect_raises(RuntimeError, "Negative WaitGroup counter") { wg.wait }
    end
  end

  describe "#wait" do
    it "immediately returns when counter is zero" do
      channel = Channel(Nil).new(1)

      spawn do
        wg = WaitGroup.new(0)
        wg.wait
        channel.send(nil)
      end

      select
      when channel.receive
        # success
      when timeout(1.second)
        fail "expected #wait to not block the fiber"
      end
    end

    it "immediately raises when counter is negative" do
      wg = WaitGroup.new(0)
      expect_raises(RuntimeError) { wg.done }
      expect_raises(RuntimeError, "Negative WaitGroup counter") { wg.wait }
    end

    it "raises when counter is positive after wake up" do
      wg = WaitGroup.new(1)
      waiter = Fiber.current

      spawn do
        block_until_pending_waiter(wg)
        waiter.enqueue
      end

      expect_raises(RuntimeError, "Positive WaitGroup counter (early wake up?)") { wg.wait }
    end
  end

  it "waits until concurrent executions are finished" do
    wg1 = WaitGroup.new
    wg2 = WaitGroup.new

    8.times do
      wg1.add(16)
      wg2.add(16)
      exited = Channel(Bool).new(16)

      16.times do
        spawn do
          wg1.done
          wg2.wait
          exited.send(true)
        end
      end

      wg1.wait

      16.times do
        select
        when exited.receive
          fail "WaitGroup released group too soon"
        else
        end
        wg2.done
      end

      16.times do
        select
        when x = exited.receive
          x.should eq(true)
        when timeout(1.millisecond)
          fail "Expected channel to receive value"
        end
      end
    end
  end

  it "increments the counter from executing fibers" do
    wg = WaitGroup.new(16)
    extra = Atomic(Int32).new(0)

    16.times do
      spawn do
        wg.add(2)

        2.times do
          spawn do
            extra.add(1)
            wg.done
          end
        end

        wg.done
      end
    end

    wg.wait
    extra.get.should eq(32)
  end

  it "takes a block to WaitGroup.wait" do
    fiber_count = 10
    completed = Array.new(fiber_count) { false }

    WaitGroup.wait do |wg|
      fiber_count.times do |i|
        wg.spawn { completed[i] = true }
      end
    end

    completed.should eq [true] * 10
  end

  # the test takes far too much time for the interpreter to complete
  {% unless flag?(:interpreted) %}
    it "stress add/done/wait" do
      wg = WaitGroup.new

      1000.times do
        counter = Atomic(Int32).new(0)

        2.times do
          wg.add(1)

          spawn do
            counter.add(1)
            wg.done
          end
        end

        wg.wait
        counter.get.should eq(2)
      end
    end
  {% end %}
end
