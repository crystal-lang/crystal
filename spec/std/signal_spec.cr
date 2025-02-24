{% skip_file if flag?(:wasm32) %}

require "./spec_helper"
require "signal"

{% skip_file if flag?(:interpreted) && !Crystal::Interpreter.has_method?(:signal) %}

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

  {% if flag?(:dragonfly) %}
    # FIXME: can't use SIGUSR1/SIGUSR2 because Boehm uses them + no
    # SIRTMIN/SIGRTMAX support => figure which signals we could use
    pending "runs a signal handler"
    pending "ignores a signal"
    pending "allows chaining of signals"
    pending "CHLD.reset sets default Crystal child handler"
    pending "CHLD.ignore sets default Crystal child handler"
    pending "CHLD.trap is called after default Crystal child handler"
    pending "CHLD.reset removes previously set trap"
  {% end %}

  {% unless flag?(:win32) || flag?(:dragonfly) %}
    # can't use SIGUSR1/SIGUSR2 on FreeBSD because Boehm uses them to suspend/resume threads
    signal1 = {% if flag?(:freebsd) %} Signal.new(LibC::SIGRTMAX - 1) {% else %} Signal::USR1 {% end %}
    signal2 = {% if flag?(:freebsd) %} Signal.new(LibC::SIGRTMAX - 2) {% else %} Signal::USR2 {% end %}

    it "runs a signal handler" do
      ran = false
      signal1.trap do
        ran = true
      end
      Process.signal signal1, Process.pid
      10.times do |i|
        break if ran
        sleep 0.1.seconds
      end
      ran.should be_true
    ensure
      signal1.reset
    end

    it "ignores a signal" do
      signal2.ignore
      Process.signal signal2, Process.pid
    end

    it "allows chaining of signals" do
      ran_first = false
      ran_second = false

      signal1.trap { ran_first = true }
      existing = signal1.trap_handler?

      signal1.trap do |signal|
        existing.try &.call(signal)
        ran_second = true
      end

      Process.signal signal1, Process.pid
      sleep 0.1.seconds
      ran_first.should be_true
      ran_second.should be_true
    ensure
      signal1.reset
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
