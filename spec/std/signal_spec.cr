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

  it "CHLD.reset sets default Crystal child handler" do
    Signal::CHLD.reset
    child = Process.new("true", shell: true)
    child.wait # doesn't block forever
  end

  it "CHLD.ignore sets default Crystal child handler" do
    Signal::CHLD.ignore
    child = Process.new("true", shell: true)
    child.wait # doesn't block forever
  end

  it "CHLD.trap is called after default Crystal child handler" do
    called = false
    child = nil

    Signal::CHLD.trap do
      called = true
      Process.exists?(child.not_nil!.pid).should be_false
    end

    child = Process.new("true", shell: true)
    child.not_nil!.wait # doesn't block forever
    called.should be_true
  end

  # TODO: test Signal::X.reset
end
