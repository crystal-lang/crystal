require "./spec_helper"

private class FooError < Exception
  def message
    "#{super || ""} -- bar!"
  end
end

private class RaisingMessageError < Exception
  def message : String?
    raise ArgumentError.new("message")
  end
end

private class RaisingNameError < Exception
  def self.name : String
    raise "name"
  end
end

private def rescue_message(ex : Exception)
  ex.message
rescue error
  error.message
end

private def rescue_class_name(ex : Exception)
  ex.class.name
rescue error
  error.message
end

describe "Exception" do
  it "rescues an exception raised by an overridden #message" do
    rescue_message(RaisingMessageError.new).should eq("message")
  end

  it "rescues an exception raised by an overridden .name" do
    rescue_class_name(RaisingNameError.new).should eq("name")
  end

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

  it "inspects with cause" do
    cause = Exception.new("inner")
    ex = expect_raises(Exception, "wrapper") do
      raise cause
    rescue ex
      raise Exception.new("wrapper", cause: ex)
    end

    ex.cause.should be(cause)
    ex.inspect_with_backtrace.should contain("wrapper")
    ex.inspect_with_backtrace.should contain("Caused by")
    ex.inspect_with_backtrace.should contain("inner")
  end

  it "collect memory within ensure block", tags: %w[slow] do
    sample = datapath("collect_within_ensure")

    _, output, error = compile_and_run_file(sample, ["--release"])

    output.to_s.should be_empty
    error.to_s.should contain("Unhandled exception: Oh no! (Exception)")
    error.to_s.should_not contain("Invalid memory access")
    error.to_s.should_not contain("Illegal instruction")
  end
end
