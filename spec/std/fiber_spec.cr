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
end
