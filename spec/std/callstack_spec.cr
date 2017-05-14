require "../spec_helper"
require "tempfile"

describe "Backtrace" do
  it "prints file line:colunm" do
    tempfile = Tempfile.new("compiler_spec_output")
    tempfile.close
    sample = "#{__DIR__}/data/backtrace_sample"

    `bin/crystal build --debug #{sample.inspect} -o #{tempfile.path.inspect}`
    File.exists?(tempfile.path).should be_true

    {% if flag?(:darwin) %}
      `dsymutil --flat #{tempfile.path}`
    {% end %}

    output = `#{tempfile.path}`

    # resolved file line:column
    output.should match(/callee1 at #{sample} 3:10/)
    output.should match(/callee3 at #{sample} 15:3/)
    output.should match(/__crystal_main at #{sample} 17:1/)

    # skipped internal details
    output.should_not match(/src\/callstack\.cr/)
    output.should_not match(/src\/exception\.cr/)
    output.should_not match(/src\/raise\.cr/)
  end

  it "prints exception backtrace to stderr" do
    tempfile = Tempfile.new("compiler_spec_output")
    tempfile.close
    sample = "#{__DIR__}/data/exception_backtrace_sample"

    `bin/crystal build --debug #{sample.inspect} -o #{tempfile.path.inspect}`
    File.exists?(tempfile.path).should be_true

    output, error = {IO::Memory.new, IO::Memory.new}.tap do |outio, errio|
      Process.run tempfile.path, output: outio, error: errio
    end

    output.to_s.empty?.should be_true
    error.to_s.should contain("IndexError")
  end

  it "prints crash backtrace to stderr" do
    tempfile = Tempfile.new("compiler_spec_output")
    tempfile.close
    sample = "#{__DIR__}/data/crash_backtrace_sample"

    `bin/crystal build --debug #{sample.inspect} -o #{tempfile.path.inspect}`
    File.exists?(tempfile.path).should be_true

    output, error = {IO::Memory.new, IO::Memory.new}.tap do |outio, errio|
      Process.run tempfile.path, output: outio, error: errio
    end

    output.to_s.empty?.should be_true
    error.to_s.should contain("Invalid memory access")
  end
end
