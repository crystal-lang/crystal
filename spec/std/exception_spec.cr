require "spec"

private class FooError < Exception
  def message
    "#{super || ""} -- bar!"
  end
end

describe "Exception" do
  it "allows subclassing #message" do
    ex = FooError.new("foo?")
    ex.message.should eq("foo? -- bar!")
    ex.to_s.should eq("foo? -- bar!")
    ex.inspect_with_backtrace.should contain("foo? -- bar!")
  end

  it "inspects" do
    ex = FooError.new("foo?")
    ex.inspect.should eq("#<FooError:foo? -- bar!>")
  end
end
