require "spec"
require "wait_group"

describe Fiber do
  it "#resumable?" do
    done = false
    resumable = nil

    fiber = spawn do
      resumable = Fiber.current.resumable?
      done = true
    end

    fiber.resumable?.should be_true

    until done
      Fiber.yield
    end

    resumable.should be_false
  end

  describe ".sleep" do
    it "expires" do
      cancelation_token = nil
      channel = Channel(Fiber::TimeoutResult).new

      spawn do
        result = Fiber.sleep(10.milliseconds) { |token| cancelation_token = token }
        channel.send(result)
      end

      channel.receive.should eq(Fiber::TimeoutResult::EXPIRED)
    end

    it "is canceled" do
      cancelation_token = nil
      channel = Channel(Fiber::TimeoutResult).new

      fiber = spawn do
        result = Fiber.sleep(1.second) { |token| cancelation_token = token }
        channel.send(result)
      end

      until cancelation_token
        Fiber.yield
      end

      if fiber.resolve_timer?(cancelation_token.not_nil!)
        fiber.enqueue
      end

      channel.receive.should eq(Fiber::TimeoutResult::CANCELED)
    end

    it "expires or is canceled" do
      20.times do
        WaitGroup.wait do |wg|
          cancelation_token = nil

          suspended_fiber = wg.spawn do
            Fiber.sleep(10.milliseconds) do |token|
              # save the token so another fiber can try to cancel the timer
              cancelation_token = token
            end
          end

          sleep rand(9..11).milliseconds

          # let's try to cancel the timer
          if suspended_fiber.resolve_timer?(cancelation_token.not_nil!)
            # canceled: we must enqueue the fiber
            suspended_fiber.enqueue
          end
        end
      end
    end
  end
end
