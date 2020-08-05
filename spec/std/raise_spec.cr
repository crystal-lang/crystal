require "./spec_helper"

describe "raise" do
  callstack_on_rescue = nil

  pending_win32 "should set exception's callstack" do
    exception = expect_raises Exception, "without callstack" do
      raise "without callstack"
    end
    exception.callstack.should_not be_nil
  end

  pending_win32 "shouldn't overwrite the callstack on re-raise" do
    exception_after_reraise = expect_raises Exception, "exception to be rescued" do
      begin
        raise "exception to be rescued"
      rescue exception_on_rescue
        callstack_on_rescue = exception_on_rescue.callstack
        raise exception_on_rescue
      end
    end
    exception_after_reraise.callstack.should_not be_nil
    exception_after_reraise.callstack.should eq(callstack_on_rescue)
  end
end
