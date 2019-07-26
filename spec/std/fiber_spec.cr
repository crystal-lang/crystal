require "spec"

describe Fiber do
  it "can be woken up from sleep" do
    took = Time.measure do
      ch = Channel(Nil).new
      f = spawn do
        sleep 2
        ch.send nil
      end
      f.wakeup
      ch.receive
    end
    took.should be < 1.seconds
  end
end
