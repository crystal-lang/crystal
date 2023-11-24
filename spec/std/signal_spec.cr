{% skip_file if flag?(:wasm32) %}

require "spec"
require "signal"

describe "Signal" do
  typeof(Signal::ABRT.reset)
  typeof(Signal::ABRT.ignore)
  typeof(Signal::ABRT.trap { 1 })

  it "has constants required by C" do
    Signal::INT.should be_a(Signal)
    Signal::ILL.should be_a(Signal)
    Signal::FPE.should be_a(Signal)
    Signal::SEGV.should be_a(Signal)
    Signal::TERM.should be_a(Signal)
    Signal::ABRT.should be_a(Signal)
  end

  {% unless flag?(:win32) %}
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
      existed = Channel(Bool).new

      Signal::CHLD.trap do
        child_process = chan.receive
        existed.send(Process.exists?(child_process.pid))
      end

      child = Process.new("true", shell: true)
      child.wait # doesn't block forever
      chan.send(child)
      existed.receive.should be_false
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
  {% end %}
end
