require "spec"

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
      Process::Status.new(0x01).normal_exit?.should be_false
      Process::Status.new(0x7f).normal_exit?.should be_false
    end

    it "#signal_exit? with signal code" do
      Process::Status.new(0x01).signal_exit?.should be_true

      # 0x7f raises arithmetic error due to overflow, but this shouldn't
      # matter because actual signal values don't expand to that range
      Process::Status.new(0x7e).signal_exit?.should be_true
    end
  {% end %}
end
