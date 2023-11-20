require "spec"
require "spec/helpers/string"

private def exit_status(status)
  {% if flag?(:unix) %}
    status << 8
  {% else %}
    status.to_u32!
  {% end %}
end

describe Process::Status do
  it "#exit_code" do
    Process::Status.new(exit_status(0)).exit_code.should eq 0
    Process::Status.new(exit_status(1)).exit_code.should eq 1
    Process::Status.new(exit_status(127)).exit_code.should eq 127
    Process::Status.new(exit_status(128)).exit_code.should eq 128
    Process::Status.new(exit_status(255)).exit_code.should eq 255
  end

  it "#success?" do
    Process::Status.new(exit_status(0)).success?.should be_true
    Process::Status.new(exit_status(1)).success?.should be_false
    Process::Status.new(exit_status(127)).success?.should be_false
    Process::Status.new(exit_status(128)).success?.should be_false
    Process::Status.new(exit_status(255)).success?.should be_false
  end

  it "#normal_exit?" do
    Process::Status.new(exit_status(0)).normal_exit?.should be_true
    Process::Status.new(exit_status(1)).normal_exit?.should be_true
    Process::Status.new(exit_status(127)).normal_exit?.should be_true
    Process::Status.new(exit_status(128)).normal_exit?.should be_true
    Process::Status.new(exit_status(255)).normal_exit?.should be_true
  end

  it "#signal_exit?" do
    Process::Status.new(exit_status(0)).signal_exit?.should be_false
    Process::Status.new(exit_status(1)).signal_exit?.should be_false
    Process::Status.new(exit_status(127)).signal_exit?.should be_false
    Process::Status.new(exit_status(128)).signal_exit?.should be_false
    Process::Status.new(exit_status(255)).signal_exit?.should be_false
  end

  it "equality" do
    ok1 = Process::Status.new(exit_status(0))
    ok2 = Process::Status.new(exit_status(0))
    err1 = Process::Status.new(exit_status(1))
    err2 = Process::Status.new(exit_status(1))

    ok1.should eq(ok2)
    ok1.should_not eq(err2)
    err1.should_not eq(ok2)
    err1.should eq(err2)

    ok1.hash.should eq(ok2.hash)
    ok1.hash.should_not eq(err2.hash)
    err1.hash.should_not eq(ok2.hash)
    err1.hash.should eq(err2.hash)
  end

  {% if flag?(:unix) && !flag?(:wasi) %}
    it "#exit_signal" do
      Process::Status.new(Signal::HUP.value).exit_signal.should eq Signal::HUP
      Process::Status.new(Signal::INT.value).exit_signal.should eq Signal::INT
      last_signal = Signal.values[-1]
      Process::Status.new(last_signal.value).exit_signal.should eq last_signal
    end

    it "#normal_exit? with signal code" do
      Process::Status.new(0x00).normal_exit?.should be_true
      Process::Status.new(0x01).normal_exit?.should be_false
      Process::Status.new(0x7e).normal_exit?.should be_false
      Process::Status.new(0x7f).normal_exit?.should be_false
    end

    it "#signal_exit? with signal code" do
      Process::Status.new(0x00).signal_exit?.should be_false
      Process::Status.new(0x01).signal_exit?.should be_true
      Process::Status.new(0x7e).signal_exit?.should be_true
      Process::Status.new(0x7f).signal_exit?.should be_false
    end
  {% end %}

  {% if flag?(:win32) %}
    describe "#exit_reason" do
      it "returns Normal" do
        Process::Status.new(exit_status(0)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(1)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(127)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(128)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(255)).exit_reason.normal?.should be_true

        Process::Status.new(0x3FFFFFFF_u32).exit_reason.normal?.should be_true
        Process::Status.new(0x40001234_u32).exit_reason.normal?.should be_false
        Process::Status.new(0x80001234_u32).exit_reason.normal?.should be_false
        Process::Status.new(0xC0001234_u32).exit_reason.normal?.should be_false
      end

      it "returns Aborted" do
        Process::Status.new(LibC::STATUS_FATAL_APP_EXIT).exit_reason.aborted?.should be_true
      end

      it "returns Interrupted" do
        Process::Status.new(LibC::STATUS_CONTROL_C_EXIT).exit_reason.interrupted?.should be_true
      end

      it "returns Breakpoint" do
        Process::Status.new(LibC::STATUS_BREAKPOINT).exit_reason.breakpoint?.should be_true
      end

      it "returns AccessViolation" do
        Process::Status.new(LibC::STATUS_ACCESS_VIOLATION).exit_reason.access_violation?.should be_true
        Process::Status.new(LibC::STATUS_STACK_OVERFLOW).exit_reason.access_violation?.should be_true
      end

      it "returns BadMemoryAccess" do
        Process::Status.new(LibC::STATUS_DATATYPE_MISALIGNMENT).exit_reason.bad_memory_access?.should be_true
      end

      it "returns BadInstruction" do
        Process::Status.new(LibC::STATUS_ILLEGAL_INSTRUCTION).exit_reason.bad_instruction?.should be_true
        Process::Status.new(LibC::STATUS_PRIVILEGED_INSTRUCTION).exit_reason.bad_instruction?.should be_true
      end

      it "returns FloatException" do
        Process::Status.new(LibC::STATUS_FLOAT_DIVIDE_BY_ZERO).exit_reason.float_exception?.should be_true
        Process::Status.new(LibC::STATUS_FLOAT_INEXACT_RESULT).exit_reason.float_exception?.should be_true
        Process::Status.new(LibC::STATUS_FLOAT_INVALID_OPERATION).exit_reason.float_exception?.should be_true
        Process::Status.new(LibC::STATUS_FLOAT_OVERFLOW).exit_reason.float_exception?.should be_true
        Process::Status.new(LibC::STATUS_FLOAT_UNDERFLOW).exit_reason.float_exception?.should be_true
      end
    end
  {% elsif flag?(:unix) && !flag?(:wasi) %}
    describe "#exit_reason" do
      it "returns Normal" do
        Process::Status.new(exit_status(0)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(1)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(127)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(128)).exit_reason.normal?.should be_true
        Process::Status.new(exit_status(255)).exit_reason.normal?.should be_true

        Process::Status.new(0x01).exit_reason.normal?.should be_false
        Process::Status.new(0x7e).exit_reason.normal?.should be_false

        Process::Status.new(0x017f).exit_reason.normal?.should be_false
        Process::Status.new(0xffff).exit_reason.normal?.should be_false
      end

      it "returns Aborted" do
        Process::Status.new(Signal::ABRT.value).exit_reason.aborted?.should be_true
        Process::Status.new(Signal::HUP.value).exit_reason.aborted?.should be_true
        Process::Status.new(Signal::KILL.value).exit_reason.aborted?.should be_true
        Process::Status.new(Signal::QUIT.value).exit_reason.aborted?.should be_true
        Process::Status.new(Signal::TERM.value).exit_reason.aborted?.should be_true
      end

      it "returns Interrupted" do
        Process::Status.new(Signal::INT.value).exit_reason.interrupted?.should be_true
      end

      it "returns Breakpoint" do
        Process::Status.new(Signal::TRAP.value).exit_reason.breakpoint?.should be_true
      end

      it "returns AccessViolation" do
        Process::Status.new(Signal::SEGV.value).exit_reason.access_violation?.should be_true
      end

      it "returns BadMemoryAccess" do
        Process::Status.new(Signal::BUS.value).exit_reason.bad_memory_access?.should be_true
      end

      it "returns BadInstruction" do
        Process::Status.new(Signal::ILL.value).exit_reason.bad_instruction?.should be_true
      end

      it "returns FloatException" do
        Process::Status.new(Signal::FPE.value).exit_reason.float_exception?.should be_true
      end
    end
  {% end %}

  describe "#to_s" do
    it "with exit status" do
      assert_prints Process::Status.new(exit_status(0)).to_s, "0"
      assert_prints Process::Status.new(exit_status(1)).to_s, "1"
      assert_prints Process::Status.new(exit_status(127)).to_s, "127"
      assert_prints Process::Status.new(exit_status(128)).to_s, "128"
      assert_prints Process::Status.new(exit_status(255)).to_s, "255"
    end

    {% if flag?(:unix) && !flag?(:wasi) %}
      it "with exit signal" do
        assert_prints Process::Status.new(Signal::HUP.value).to_s, "HUP"
        last_signal = Signal.values[-1]
        assert_prints Process::Status.new(last_signal.value).to_s, last_signal.to_s
      end
    {% end %}
  end

  describe "#inspect" do
    it "with exit status" do
      assert_prints Process::Status.new(exit_status(0)).inspect, "Process::Status[0]"
      assert_prints Process::Status.new(exit_status(1)).inspect, "Process::Status[1]"
      assert_prints Process::Status.new(exit_status(127)).inspect, "Process::Status[127]"
      assert_prints Process::Status.new(exit_status(128)).inspect, "Process::Status[128]"
      assert_prints Process::Status.new(exit_status(255)).inspect, "Process::Status[255]"
    end

    {% if flag?(:unix) && !flag?(:wasi) %}
      it "with exit signal" do
        assert_prints Process::Status.new(Signal::HUP.value).inspect, "Process::Status[Signal::HUP]"
        last_signal = Signal.values[-1]
        assert_prints Process::Status.new(last_signal.value).inspect, "Process::Status[#{last_signal.inspect}]"
      end
    {% end %}
  end
end
