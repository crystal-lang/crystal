require "spec"

struct CallStack # allow clone and equality
  def_clone
  def_equals @callstack
end

describe "raise" do
  it "should set exception's callstack" do
    new_ex = expect_raises Exception, "without callstack" do
      raise Exception.new "without callstack"
    end
    new_ex.callstack.should_not be_nil
  end

  it "shouldn't overwrite the callstack" do
    ex = Exception.new "with callstack"
    ex.callstack = CallStack.new
    callstack_to_match = ex.callstack.clone
    new_ex = expect_raises Exception, "with callstack" do
      raise ex
    end
    new_ex.callstack.should eq(callstack_to_match)
  end
end
