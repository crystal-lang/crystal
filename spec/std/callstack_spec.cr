require "spec"
require "tempfile"

describe "Backtrace" do
  it "prints file line:colunm" do
    tempfile = Tempfile.new("compiler_spec_output")
    tempfile.close
    sample = "#{__DIR__}/data/backtrace_sample"

    # CallStack tries to make files relative to the current dir,
    # so we do the same for tests
    current_dir = Dir.current
    current_dir += File::SEPARATOR unless current_dir.ends_with?(File::SEPARATOR)
    sample = sample.lchop(current_dir)

    `bin/crystal build --debug #{sample.inspect} -o #{tempfile.path.inspect}`
    File.exists?(tempfile.path).should be_true

    {% if flag?(:darwin) %}
      `dsymutil --flat #{tempfile.path}`
    {% end %}

    output = `#{tempfile.path}`

    # resolved file line:column
    output.should match(/#{sample}:3:10 in 'callee1'/)

    # The first line is the old (incorrect) behaviour,
    # the second line is the new (correct) behaviour.
    # TODO: keep only the second one after Crystal 0.23.1
    unless output =~ /#{sample}:15:3 in 'callee3'/ ||
           output =~ /#{sample}:13:5 in 'callee3'/
      fail "didn't find callee3 in the backtrace"
    end

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
