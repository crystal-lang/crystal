require "./spec_helper"

private class RaiseTestError < Exception
end

private class RaiseOtherError < Exception
end

private def return_from_rescue(steps)
  raise RaiseTestError.new
rescue RaiseTestError
  return 42
ensure
  steps << 1
end

describe "raise" do
  callstack_on_rescue = nil

  it "should set exception's callstack" do
    exception = expect_raises Exception, "without callstack" do
      raise "without callstack"
    end
    exception.callstack.should_not be_nil
  end

  it "shouldn't overwrite the callstack on re-raise" do
    exception_after_reraise = expect_raises Exception, "exception to be rescued" do
      raise "exception to be rescued"
    rescue exception_on_rescue
      callstack_on_rescue = exception_on_rescue.callstack
      raise exception_on_rescue
    end
    exception_after_reraise.callstack.should_not be_nil
    exception_after_reraise.callstack.should eq(callstack_on_rescue)
  end

  it "catches a typed exception across a call" do
    raise RaiseTestError.new("test")
  rescue RaiseOtherError
    fail "wrong rescue"
  rescue ex : RaiseTestError
    ex.message.should eq("test")
  end

  it "propagates unmatched exceptions through ensure" do
    steps = [] of Int32
    error = RaiseTestError.new("same")
    expect_raises(RaiseTestError) do
      begin
        begin
          raise error
        rescue RaiseOtherError
          fail "wrong rescue"
        ensure
          steps << 1
        end
      ensure
        steps << 2
      end
    end.should be(error)
    steps.should eq([1, 2])
  end

  it "runs ensure when rescue raises a replacement" do
    steps = [] of Int32
    expect_raises(RaiseOtherError, "replacement") do
      raise RaiseTestError.new
    rescue RaiseTestError
      raise RaiseOtherError.new("replacement")
    ensure
      steps << 1
    end
    steps.should eq([1])
  end

  it "handles nested rescue inside ensure" do
    rescued = false
    expect_raises(RaiseTestError, "original") do
      raise RaiseTestError.new("original")
    ensure
      begin
        raise RaiseOtherError.new
      rescue RaiseOtherError
        rescued = true
      end
    end
    rescued.should be_true
  end

  it "preserves a replacement exception through a nested rescue in ensure" do
    rescued = false
    error = RaiseOtherError.new("replacement")
    expect_raises(RaiseOtherError) do
      raise RaiseTestError.new
    rescue RaiseTestError
      raise error
    ensure
      begin
        raise RaiseTestError.new
      rescue RaiseTestError
        rescued = true
      end
    end.should be(error)
    rescued.should be_true
  end

  it "propagates an exception raised inside ensure" do
    error = RaiseOtherError.new("replacement")
    expect_raises(RaiseOtherError) do
      raise RaiseTestError.new
    ensure
      raise error
    end.should be(error)
  end

  it "runs ensure on return from rescue" do
    steps = [] of Int32
    return_from_rescue(steps).should eq(42)
    steps.should eq([1])
  end
end
