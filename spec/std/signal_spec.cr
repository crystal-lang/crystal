require "spec"
require "signal"

describe "Signal" do
  typeof(Signal::PIPE.reset)
  typeof(Signal::PIPE.ignore)
  typeof(Signal::PIPE.trap { 1 })

  it "runs a signal handler" do
    ran = false
    Signal::USR1.trap do
      ran = true
    end
    Process.kill Signal::USR1, Process.pid
    10.times do |i|
      break if ran
      sleep 0.1
    end
    ran.should be_true
  end

  it "ignores a signal" do
    Signal::USR2.ignore
    Process.kill Signal::USR2, Process.pid
  end

  # TODO: test Signal::X.reset
end
