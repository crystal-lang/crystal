{% skip_file if flag?(:interpreted) || !flag?(:execution_context) %}

require "./spec_helper"
require "wait_group"

describe ExecutionContext::Isolated do
  describe "#initialize" do
    it "#stack_pool" do
      test = ExecutionContext::Isolated.new("TEST") { }
      expect_raises(NotImplementedError) { test.stack_pool }
    end

    it "#execution_context" do
      test = ExecutionContext::Isolated.new("TEST") { }
      test.execution_context.should eq(test)
    end

    it "runs a block in a dedicated thread" do
      timeout = ExecutionContext::TestTimeout.new
      thread = nil

      ExecutionContext::Isolated.new("RUN") do
        thread = Thread.current
        timeout.cancel
      end

      timeout.sleep
      thread.should_not be_nil
      thread.should_not eq(Thread.current)
    end
  end

  describe "#spawn" do
    it "spawns into the default context" do
      timeout = ExecutionContext::TestTimeout.new
      execution_context = nil

      ExecutionContext::Isolated.new("TEST") do
        spawn do
          execution_context = ExecutionContext.current
          timeout.cancel
        end
      end

      timeout.sleep
      execution_context.should eq(ExecutionContext.current)
    end

    it "spawns into the specified context" do
      timeout = ExecutionContext::TestTimeout.new
      execution_context = nil
      test_execution_context = nil

      other = ExecutionContext::SingleThreaded.new("STX")
      other.spawn(name: "StFiber") do
        execution_context = ExecutionContext.current
        timeout.cancel
      end

      timeout.sleep
      timeout.reset

      ExecutionContext::Isolated.new("UNQ", spawn_context: other) do
        spawn(name: "UnqFiber") do
          test_execution_context = ExecutionContext.current
          timeout.cancel
        end
      end

      timeout.sleep
      test_execution_context.should eq(execution_context)
    end
  end

  describe "#enqueue" do
    it "enqueues the isolated fiber" do
      timeout = ExecutionContext::TestTimeout.new(1.second)

      test = ExecutionContext::Isolated.new("TEST") do
        sleep
        timeout.cancel
      end
      test.enqueue(test.@main_fiber.not_nil!)
      timeout.sleep
    end

    it "raises when trying to enqueue another fiber" do
      test = ExecutionContext::Isolated.new("TEST") { sleep }
      fiber = Fiber.new { }
      expect_raises(RuntimeError) { test.enqueue(fiber) }
      test.enqueue(test.@main_fiber.not_nil!) # terminate the thread
    end
  end

  it "waits on the event loop" do
    timeout = ExecutionContext::TestTimeout.new(1.second)

    ExecutionContext::Isolated.new("TEST") do
      sleep 50.milliseconds
      timeout.cancel
    end

    elapsed = Time.measure { timeout.sleep }
    elapsed.should be > 50.milliseconds
    elapsed.should be < 1.second
  end

  describe "cross execution context synchronization" do
    test_channels = ->(q : Channel(Int32), r : Channel(Int32), n : Int32) {
      timeout = ExecutionContext::TestTimeout.new
      last_value = -1

      ExecutionContext::Isolated.new("CLIENT") do
        1000.times do |i|
          q.send(i)
          last_value = r.receive.tap(&.should eq(i))
        end
        q.close
        timeout.cancel
      end

      ExecutionContext::Isolated.new("SERVER") do
        j = -1
        while i = q.receive?
          i.should eq(j += 1)
          r.send(i)
        end
        r.close
      end

      timeout.sleep
      last_value.should eq(n - 1)
    }

    it "unbuffered channel" do
      q, r = Channel(Int32).new, Channel(Int32).new
      test_channels.call(q, r, 1000)
    end

    it "buffered channel" do
      q, r = Channel(Int32).new(13), Channel(Int32).new(61)
      test_channels.call(q, r, 1000)
    end

    it "mutex" do
      mutex = Mutex.new
      value = 0
      n, count = 4, 250_000
      expected = n * count

      n.times do |i|
        ExecutionContext::Isolated.new("MTX-#{i}") do
          count.times do
            mutex.synchronize { value += 1 }
          end
        end
      end

      timeout = ExecutionContext::TestTimeout.new
      until timeout.done?
        timeout.cancel if value == expected
        sleep 250.milliseconds
      end

      value.should eq(n * count)
    end

    it "wait group" do
      timeout = ExecutionContext::TestTimeout.new
      wg = WaitGroup.new(2)
      ready = WaitGroup.new(2)

      ExecutionContext::Isolated.new("WG-1") do
        ready.done
        wg.done
      end

      ExecutionContext::Isolated.new("WG-2") do
        ready.wait
        wg.done
      end

      spawn(name: "WG-X") do
        ready.done
        wg.wait
        timeout.cancel
      end

      timeout.sleep
    end
  end
end
