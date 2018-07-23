require "./spec_helper"

describe "Backtrace" do
  it "prints file line:colunm" do
    with_tempfile("compiler_spec_output") do |path|
      sample = datapath("backtrace_sample")

      # CallStack tries to make files relative to the current dir,
      # so we do the same for tests
      current_dir = Dir.current
      current_dir += File::SEPARATOR unless current_dir.ends_with?(File::SEPARATOR)
      sample = sample.lchop(current_dir)

      `bin/crystal build --debug #{sample.inspect} -o #{path.inspect}`
      File.exists?(path).should be_true

      {% if flag?(:darwin) %}
        `dsymutil --flat #{path}`
      {% end %}

      output = `#{path}`

      # resolved file line:column
      output.should match(/#{sample}:3:10 in 'callee1'/)

      unless output =~ /#{sample}:13:5 in 'callee3'/
        fail "didn't find callee3 in the backtrace"
      end

      # skipped internal details
      output.should_not match(/src\/callstack\.cr/)
      output.should_not match(/src\/exception\.cr/)
      output.should_not match(/src\/raise\.cr/)
    end
  end

  it "prints exception backtrace to stderr" do
    with_tempfile("compiler_spec_output") do |path|
      sample = datapath("exception_backtrace_sample")

      `bin/crystal build --debug #{sample.inspect} -o #{path.inspect}`
      File.exists?(path).should be_true

      output, error = {IO::Memory.new, IO::Memory.new}.tap do |outio, errio|
        Process.run path, output: outio, error: errio
      end

      output.to_s.empty?.should be_true
      error.to_s.should contain("IndexError")
    end
  end

  it "prints crash backtrace to stderr" do
    with_tempfile("compiler_spec_output") do |path|
      sample = datapath("crash_backtrace_sample")

      `bin/crystal build --debug #{sample.inspect} -o #{path.inspect}`
      File.exists?(path).should be_true

      output, error = {IO::Memory.new, IO::Memory.new}.tap do |outio, errio|
        Process.run path, output: outio, error: errio
      end

      output.to_s.empty?.should be_true
      error.to_s.should contain("Invalid memory access")
    end
  end
end
