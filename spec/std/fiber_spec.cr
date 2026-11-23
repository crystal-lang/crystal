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

  describe "cancelation" do
    it "creates a new token and cancels once" do
      fiber = Fiber.new { }
      token = fiber.arm_cancelation
      fiber.try_cancel?(token).should be_true
      fiber.try_cancel?(token).should be_false
    end

    it "invalidates previous token" do
      fiber = Fiber.new { }

      token1 = fiber.arm_cancelation
      token2 = fiber.arm_cancelation
      token2.should_not eq(token1)

      fiber.try_cancel?(token1).should be_false
      fiber.try_cancel?(token2).should be_true
    end
  end

  describe ".timeout" do
    it "expires" do
      fiber = Fiber.current
      token = fiber.arm_cancelation
      elapsed = Time.measure { Fiber.timeout(10.microseconds, token) }
      elapsed.should be >= 9.microseconds
    end

    it "is canceled" do
      fiber = Fiber.current
      token = fiber.arm_cancelation

      spawn do
        fiber.try_cancel?(token).should be_true
        fiber.enqueue
      end

      elapsed = Time.measure { Fiber.timeout(1.second, token) }
      elapsed.should be < 1.second
    end

    it "expires or is canceled" do
      {% if flag?(:"evloop=libevent") %}
        # µs is too fast for libevent where timeout always expires before we can cancel
        pending!
      {% end %}

      iterations = 20_000

      tokens = Channel(Fiber::CancelationToken).new(1)
      results = Channel(Fiber::TimeoutResult).new(1)

      iterations.times do
        suspended_fiber = spawn do
          token = Fiber.current.arm_cancelation
          tokens.send(token)

          result = Fiber.timeout(10.microseconds, token)
          results.send(result)
        end

        token = tokens.receive
        sleep rand(7..11).microseconds

        canceled = suspended_fiber.try_cancel?(token)
        suspended_fiber.enqueue if canceled
        results.receive.should eq(canceled ? Fiber::TimeoutResult::CANCELED : Fiber::TimeoutResult::EXPIRED)
      end
    end
  end
end
