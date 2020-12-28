require "../spec_helper"

describe "Backtrace" do
  pending_win32 "prints file line:column" do
    source_file = datapath("backtrace_sample")

    # CallStack tries to make files relative to the current dir,
    # so we do the same for tests
    current_dir = Dir.current
    current_dir += File::SEPARATOR unless current_dir.ends_with?(File::SEPARATOR)
    source_file = source_file.lchop(current_dir)

    _, output, _ = compile_and_run_file(source_file)

    # resolved file line:column
    output.should match(/#{source_file}:3:10 in 'callee1'/)

    unless output =~ /#{source_file}:13:5 in 'callee3'/
      fail "didn't find callee3 in the backtrace"
    end

    # skipped internal details
    output.should_not match(/src\/callstack\.cr/)
    output.should_not match(/src\/exception\.cr/)
    output.should_not match(/src\/raise\.cr/)
  end

  it "prints exception backtrace to stderr" do
    sample = datapath("exception_backtrace_sample")

    _, output, error = compile_and_run_file(sample)

    output.to_s.empty?.should be_true
    error.to_s.should contain("IndexError")
  end

  pending_win32 "prints crash backtrace to stderr" do
    sample = datapath("crash_backtrace_sample")

    _, output, error = compile_and_run_file(sample)

    output.to_s.empty?.should be_true
    error.to_s.should contain("Invalid memory access")
  end
end
