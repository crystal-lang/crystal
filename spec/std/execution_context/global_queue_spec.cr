require "./spec_helper"

describe ExecutionContext::GlobalQueue do
  it "#initialize" do
    q = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
    q.empty?.should be_true
  end

  it "#unsafe_push and #unsafe_pop" do
    f1 = Fiber.new(name: "f1") { }
    f2 = Fiber.new(name: "f2") { }
    f3 = Fiber.new(name: "f3") { }

    q = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
    q.unsafe_push(f1)
    q.size.should eq(1)

    q.unsafe_push(f2)
    q.unsafe_push(f3)
    q.size.should eq(3)

    q.unsafe_pop?.should be(f3)
    q.size.should eq(2)

    q.unsafe_pop?.should be(f2)
    q.unsafe_pop?.should be(f1)
    q.unsafe_pop?.should be_nil
    q.size.should eq(0)
    q.empty?.should be_true
  end

  describe "#unsafe_grab?" do
    it "can't grab from empty queue" do
      q = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      runnables = ExecutionContext::Runnables(6).new(q)
      q.unsafe_grab?(runnables, 4).should be_nil
    end

    it "grabs fibers" do
      q = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      fibers = 10.times.map { |i| Fiber.new(name: "f#{i}") { } }.to_a
      fibers.each { |f| q.unsafe_push(f) }

      runnables = ExecutionContext::Runnables(6).new(q)
      fiber = q.unsafe_grab?(runnables, 4)

      # returned the last enqueued fiber
      fiber.should be(fibers[9])

      # enqueued the next 2 fibers
      runnables.size.should eq(2)
      runnables.get?.should be(fibers[8])
      runnables.get?.should be(fibers[7])

      # the remaining fibers are still there:
      6.downto(0).each do |i|
        q.unsafe_pop?.should be(fibers[i])
      end
    end

    it "can't grab more than available" do
      f = Fiber.new { }
      q = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      q.unsafe_push(f)

      # dequeues the unique fiber
      runnables = ExecutionContext::Runnables(6).new(q)
      fiber = q.unsafe_grab?(runnables, 4)
      fiber.should be(f)

      # had nothing left to dequeue
      runnables.size.should eq(0)
    end

    it "clamps divisor to 1" do
      f = Fiber.new { }
      q = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      q.unsafe_push(f)

      # dequeues the unique fiber
      runnables = ExecutionContext::Runnables(6).new(q)
      fiber = q.unsafe_grab?(runnables, 0)
      fiber.should be(f)

      # had nothing left to dequeue
      runnables.size.should eq(0)
    end
  end

  # interpreter doesn't support threads yet (#14287)
  pending_interpreted describe: "thread safety" do
    it "one by one" do
      fibers = StaticArray(ExecutionContext::FiberCounter, 763).new do |i|
        ExecutionContext::FiberCounter.new(Fiber.new(name: "f#{i}") { })
      end

      n = 7
      increments = 15
      queue = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      ready = Thread::WaitGroup.new(n)
      shutdown = Thread::WaitGroup.new(n)

      n.times do |i|
        Thread.new(name: "ONE-#{i}") do |thread|
          slept = 0
          ready.done

          loop do
            if fiber = queue.pop?
              fc = fibers.find { |x| x.@fiber == fiber }.not_nil!
              queue.push(fiber) if fc.increment < increments
              slept = 0
            elsif slept < 100
              slept += 1
              Thread.sleep(1.nanosecond) # don't burn CPU
            else
              break
            end
          end
        rescue exception
          Crystal::System.print_error "\nthread: #{thread.name}: exception: #{exception}"
        ensure
          shutdown.done
        end
      end
      ready.wait

      fibers.each_with_index do |fc, i|
        queue.push(fc.@fiber)
        Thread.sleep(10.nanoseconds) if i % 10 == 9
      end

      shutdown.wait

      # must have dequeued each fiber exactly X times
      fibers.each { |fc| fc.counter.should eq(increments) }
    end

    it "bulk operations" do
      n = 7
      increments = 15

      fibers = StaticArray(ExecutionContext::FiberCounter, 765).new do |i| # 765 can be divided by 3 and 5
        ExecutionContext::FiberCounter.new(Fiber.new(name: "f#{i}") { })
      end

      queue = ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      ready = Thread::WaitGroup.new(n)
      shutdown = Thread::WaitGroup.new(n)

      n.times do |i|
        Thread.new(name: "BULK-#{i}") do |thread|
          slept = 0

          r = ExecutionContext::Runnables(3).new(queue)

          batch = Fiber::Queue.new
          size = 0

          reenqueue = -> {
            if size > 0
              queue.bulk_push(pointerof(batch))
              names = [] of String?
              batch.each { |f| names << f.name }
              batch.clear
              size = 0
            end
          }

          execute = ->(fiber : Fiber) {
            fc = fibers.find { |x| x.@fiber == fiber }.not_nil!

            if fc.increment < increments
              batch.push(fc.@fiber)
              size += 1
            end
          }

          ready.done

          loop do
            if fiber = r.get?
              execute.call(fiber)
              slept = 0
              next
            end

            if fiber = queue.grab?(r, 1)
              reenqueue.call
              execute.call(fiber)
              slept = 0
              next
            end

            if slept >= 100
              break
            end

            reenqueue.call
            slept += 1
            Thread.sleep(1.nanosecond) # don't burn CPU
          end
        rescue exception
          Crystal::System.print_error "\nthread #{thread.name} raised: #{exception}"
        ensure
          shutdown.done
        end
      end
      ready.wait

      # enqueue in batches of 5
      0.step(to: fibers.size - 1, by: 5) do |i|
        q = Fiber::Queue.new
        5.times { |j| q.push(fibers[i + j].@fiber) }
        queue.bulk_push(pointerof(q))
        Thread.sleep(10.nanoseconds) if i % 4 == 3
      end

      shutdown.wait

      # must have dequeued each fiber exactly X times (no less, no more)
      fibers.each { |fc| fc.counter.should eq(increments) }
    end
  end
end
