require "./spec_helper"

private def compile_and_run_file(source_file)
  with_tempfile("executable_file") do |executable_file|
    Process.run("bin/crystal", ["build", "--release", "-o", executable_file, source_file])
    File.exists?(executable_file).should be_true

    output, error = IO::Memory.new, IO::Memory.new
    Process.run executable_file, output: output, error: error

    {output.to_s, error.to_s}
  end
end

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

  it "inspects with cause" do
    cause = Exception.new("inner")
    ex = expect_raises(Exception, "wrapper") do
      begin
        raise cause
      rescue ex
        raise Exception.new("wrapper", cause: ex)
      end
    end

    ex.cause.should be(cause)
    ex.inspect_with_backtrace.should contain("wrapper")
    ex.inspect_with_backtrace.should contain("Caused by")
    ex.inspect_with_backtrace.should contain("inner")
  end

  {% unless flag?(:win32) %}
    it "collect memory within ensure block" do
      sample = datapath("collect_within_ensure")

      output, error = compile_and_run_file(sample)

      output.to_s.empty?.should be_true
      error.to_s.should contain("Unhandled exception: Oh no! (Exception)")
      error.to_s.should_not contain("Invalid memory access")
      error.to_s.should_not contain("Illegal instruction")
    end
  {% end %}
end
