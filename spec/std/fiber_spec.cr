require "./sync/spec_helper"

describe Fiber do
  it "#resumable?" do
    ch = Channel(Bool).new

    Sync::CONCURRENT.spawn do
      fiber = spawn do
        # not resumable: fiber is running (sent second)
        ch.send Fiber.current.resumable?
      end

      # resumable: fiber hasn't been resumed (sent first)
      ch.send fiber.resumable?
    end

    {true, false}.each do |expected|
      select
      when resumable = ch.receive
        resumable.should eq(expected)
      when timeout(1.second)
        raise "reached timeout"
      end
    end
  end

  describe ".timeout" do
    it "expires" do
      cancelation_token = nil
      channel = Channel(Fiber::TimeoutResult).new

      spawn do
        result = Fiber.timeout(10.milliseconds) { |token| cancelation_token = token }
        channel.send(result)
      end

      channel.receive.should eq(Fiber::TimeoutResult::EXPIRED)
    end

    it "is canceled" do
      cancelation_token = nil
      channel = Channel(Fiber::TimeoutResult).new

      fiber = spawn do
        result = Fiber.timeout(1.second) { |token| cancelation_token = token }
        channel.send(result)
      end

      until cancelation_token
        Fiber.yield
      end

      if fiber.try_cancel?(cancelation_token.not_nil!)
        fiber.enqueue
      end

      channel.receive.should eq(Fiber::TimeoutResult::CANCELED)
    end

    it "expires or is canceled" do
      tokens = Channel(Fiber::CancelationToken).new(1)
      results = Channel(Fiber::TimeoutResult).new(1)

      2000.times do
        suspended_fiber = spawn do
          result = Fiber.timeout(10.microseconds) { |token| tokens.send(token) }
          results.send(result)
        end

        token = tokens.receive
        sleep rand(9..11).microseconds

        canceled = suspended_fiber.try_cancel?(token)
        suspended_fiber.enqueue if canceled
        results.receive.should eq(canceled ? Fiber::TimeoutResult::CANCELED : Fiber::TimeoutResult::EXPIRED)
      end
    end

    it "invalidates the token if setup raises" do
      cancelation_token = nil

      expect_raises(Exception, "setup failed") do
        Fiber.timeout(1.second) do |token|
          cancelation_token = token
          raise "setup failed"
        end
      end

      Fiber.current.try_cancel?(cancelation_token.not_nil!).should be_false
    end

    it "waits for a claimed cancelation wakeup if setup raises" do
      fiber = Fiber.current
      resumed_setup = false
      enqueued = false

      expect_raises(Exception, "setup failed") do
        Fiber.timeout(1.second) do |token|
          fiber.try_cancel?(token).should be_true
          spawn do
            unless resumed_setup
              enqueued = true
              fiber.enqueue
            end
          end
          raise "setup failed"
        end
      end

      resumed_setup = true
      enqueued.should be_true
    end
  end
end
