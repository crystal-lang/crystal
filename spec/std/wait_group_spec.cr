require "spec"
require "wait_group"

describe WaitGroup do
  describe "add" do
    it "can't decrement to a negative counter" do
      wg = WaitGroup.new
      wg.add(5)
      wg.add(-3)
      expect_raises(Exception) { wg.add(-5) }
    end
  end

  describe "done" do
    it "can't decrement to a negative counter" do
      wg = WaitGroup.new
      wg.add(1)
      wg.done
      expect_raises(Exception) { wg.done }
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
end
