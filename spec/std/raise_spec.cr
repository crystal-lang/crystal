require "spec"

struct CallStack # allow clone and equality
  def_clone
  def_equals @callstack
end

describe "raise" do
  it "should throw exception with existing callstack if already set" do
    ex = Exception.new "with callstack"
    ex.callstack = CallStack.new
    callstack_to_match = ex.callstack.clone
    new_ex = expect_raises Exception, "with callstack" do
      raise ex
    end
    new_ex.callstack.should eq(callstack_to_match)
  end

  it "should throw exception with new callstack if not already set" do
    new_ex = expect_raises Exception, "without callstack" do
      raise Exception.new("without callstack")
    end
    new_ex.callstack.should_not be_nil
  end
end
