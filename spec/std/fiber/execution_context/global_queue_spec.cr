require "./spec_helper"
require "../../../support/thread"

describe Fiber::ExecutionContext::GlobalQueue do
  it "#initialize" do
    q = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
    q.empty?.should be_true
  end

  it "#unsafe_push and #unsafe_pop" do
    f1 = new_fake_fiber("f1")
    f2 = new_fake_fiber("f2")
    f3 = new_fake_fiber("f3")

    q = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
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
      q = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      runnables = Fiber::ExecutionContext::Runnables(6).new(q)
      q.unsafe_grab?(runnables, 4).should be_nil
    end

    it "grabs fibers" do
      q = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      fibers = Array.new(10) { |i| new_fake_fiber("f#{i}") }
      fibers.each { |f| q.unsafe_push(f) }

      runnables = Fiber::ExecutionContext::Runnables(6).new(q)
      fiber = q.unsafe_grab?(runnables, 4)

      # returned the last enqueued fiber
      fiber.should be(fibers[9])

      # enqueued the next 2 fibers
      runnables.size.should eq(2)
      runnables.shift?.should be(fibers[8])
      runnables.shift?.should be(fibers[7])

      # the remaining fibers are still there:
      6.downto(0).each do |i|
        q.unsafe_pop?.should be(fibers[i])
      end
    end

    it "can't grab more than available" do
      f = new_fake_fiber
      q = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      q.unsafe_push(f)

      # dequeues the unique fiber
      runnables = Fiber::ExecutionContext::Runnables(6).new(q)
      fiber = q.unsafe_grab?(runnables, 4)
      fiber.should be(f)

      # had nothing left to dequeue
      runnables.size.should eq(0)
    end

    it "clamps divisor to 1" do
      f = new_fake_fiber
      q = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)
      q.unsafe_push(f)

      # dequeues the unique fiber
      runnables = Fiber::ExecutionContext::Runnables(6).new(q)
      fiber = q.unsafe_grab?(runnables, 0)
      fiber.should be(f)

      # had nothing left to dequeue
      runnables.size.should eq(0)
    end
  end

  # interpreter doesn't support threads yet (#14287)
  pending_interpreted describe: "thread safety" do
    it "one by one" do
      fibers = StaticArray(Fiber::ExecutionContext::FiberCounter, 763).new do |i|
        Fiber::ExecutionContext::FiberCounter.new(new_fake_fiber("f#{i}"))
      end

      n = 7
      increments = 15

      queue = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)

      Fiber::ExecutionContext.stress_test(
        n,
        iteration: ->(i : Int32) {
          if fiber = queue.pop?
            fc = fibers.find! { |x| x.@fiber == fiber }
            queue.push(fiber) if fc.increment < increments
            return :next
          end

          # done?
          if fibers.all? { |fc| fc.counter >= increments }
            return :break
          end
        },
        publish: -> {
          fibers.each_with_index do |fc, i|
            queue.push(fc.@fiber)
            Thread.sleep(10.nanoseconds) if i % 10 == 9
          end
        },
      )

      # must have dequeued each fiber exactly X times
      fibers.each { |fc| fc.counter.should eq(increments) }
    end

    it "bulk operations" do
      n = 7
      increments = 15

      fibers = StaticArray(Fiber::ExecutionContext::FiberCounter, 765).new do |i| # 765 can be divided by 3 and 5
        Fiber::ExecutionContext::FiberCounter.new(new_fake_fiber("f#{i}"))
      end

      queue = Fiber::ExecutionContext::GlobalQueue.new(Thread::Mutex.new)

      runnables = Array.new(n) { Fiber::ExecutionContext::Runnables(3).new(queue) }
      batches = Array.new(n) { Fiber::List.new }

      reenqueue = ->(batch : Pointer(Fiber::List)) {
        if batch.value.size > 0
          queue.bulk_push(batch)
          names = [] of String?
          batch.value.each { |f| names << f.name }
          batch.value.clear
        end
      }

      execute = ->(fiber : Fiber, batch : Pointer(Fiber::List)) {
        fc = fibers.find! { |x| x.@fiber == fiber }

        if fc.increment < increments
          batch.value.push(fc.@fiber)
        end
      }

      Fiber::ExecutionContext.stress_test(
        n,
        iteration: ->(i : Int32) {
          r = runnables[i]
          batch = batches.to_unsafe + i

          if fiber = r.shift?
            execute.call(fiber, batch)
            return :next
          end

          if fiber = queue.grab?(r, 1)
            reenqueue.call(batch)
            execute.call(fiber, batch)
            return :next
          end

          # done?
          if fibers.all? { |fc| fc.counter >= increments }
            return :break
          end

          reenqueue.call(batch)
        },
        publish: -> {
          # enqueue in batches of 5
          0.step(to: fibers.size - 1, by: 5) do |i|
            list = Fiber::List.new
            5.times { |j| list.push(fibers[i + j].@fiber) }
            queue.bulk_push(pointerof(list))
            Thread.sleep(10.nanoseconds) if i % 4 == 3
          end
        }
      )

      # must have dequeued each fiber exactly X times (no less, no more)
      fibers.each { |fc| fc.counter.should eq(increments) }
    end
  end
end
