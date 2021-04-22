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
    output.should match(/^#{source_file}:3:10 in 'callee1'/m)
    output.should match(/^#{source_file}:13:5 in 'callee3'/m)

    # skipped internal details
    output.should_not contain("src/callstack.cr")
    output.should_not contain("src/exception.cr")
    output.should_not contain("src/raise.cr")
  end

  pending_win32 "doesn't relativize paths outside of current dir (#10169)" do
    with_tempfile("source_file") do |source_file|
      source_path = Path.new(source_file)
      source_path.absolute?.should be_true

      File.write source_file, <<-EOF
        def callee1
          puts caller.join('\n')
        end

        callee1
        EOF
      _, output, _ = compile_and_run_file(source_file)

      output.should match /\A(#{source_path}):/
    end
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
