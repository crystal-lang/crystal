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
    Process.signal Signal::USR1, Process.pid
    10.times do |i|
      break if ran
      sleep 0.1
    end
    ran.should be_true
  end

  it "ignores a signal" do
    Signal::USR2.ignore
    Process.signal Signal::USR2, Process.pid
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
    chan = Channel(Process).new

    Signal::CHLD.trap do
      child_process = chan.receive
      Process.exists?(child_process.pid).should be_false
    end

    child = Process.new("true", shell: true)
    child.wait # doesn't block forever
    chan.send(child)
  ensure
    Signal::CHLD.reset
  end

  it "CHLD.reset removes previously set trap" do
    call_count = 0

    Signal::CHLD.trap do
      call_count += 1
    end

    Process.new("true", shell: true).wait
    Fiber.yield

    call_count.should eq(1)

    Signal::CHLD.reset

    Process.new("true", shell: true).wait
    Fiber.yield

    call_count.should eq(1)
  end

  # TODO: test Signal::X.reset
end
