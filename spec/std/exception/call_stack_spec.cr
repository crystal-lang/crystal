require "../spec_helper"

describe "Backtrace" do
  it "prints file line:column", tags: %w[slow] do
    source_file = datapath("backtrace_sample")

    # CallStack tries to make files relative to the current dir,
    # so we do the same for tests
    current_dir = Dir.current
    current_dir += File::SEPARATOR unless current_dir.ends_with?(File::SEPARATOR)
    source_file = source_file.lchop(current_dir)

    _, output, _ = compile_and_run_file(source_file)

    # resolved file:line:column (no column for MSVC PDB because of poor support
    # by external tooling in general)
    {% if flag?(:msvc) %}
      output.should match(/^#{Regex.escape(source_file)}:3 in 'callee1'/m)
      output.should match(/^#{Regex.escape(source_file)}:13 in 'callee3'/m)
    {% else %}
      output.should match(/^#{Regex.escape(source_file)}:3:10 in 'callee1'/m)
      output.should match(/^#{Regex.escape(source_file)}:13:5 in 'callee3'/m)
    {% end %}

    # skipped internal details
    output.should_not contain("src/callstack.cr")
    output.should_not contain("src/exception.cr")
    output.should_not contain("src/raise.cr")
  end

  it "doesn't relativize paths outside of current dir (#10169)", tags: %w[slow] do
    with_tempfile("source_file") do |source_file|
      source_path = Path.new(source_file)
      source_path.absolute?.should be_true

      File.write source_file, <<-CRYSTAL
        def callee1
          puts caller.join('\n')
        end

        callee1
        CRYSTAL
      _, output, _ = compile_and_run_file(source_file)

      output.should match /\A(#{Regex.escape(source_path.to_s)}):/
    end
  end

  it "prints exception backtrace to stderr", tags: %w[slow] do
    sample = datapath("exception_backtrace_sample")

    _, output, error = compile_and_run_file(sample)

    output.to_s.should be_empty
    error.to_s.should contain("IndexError")
  end

  {% if flag?(:openbsd) %}
    # FIXME: the segfault handler doesn't work on OpenBSD
    pending "prints crash backtrace to stderr"
  {% else %}
    it "prints crash backtrace to stderr", tags: %w[slow] do
      sample = datapath("crash_backtrace_sample")

      _, output, error = compile_and_run_file(sample)

      output.to_s.should be_empty
      error.to_s.should contain("Invalid memory access")
    end
  {% end %}

  # Do not test this on platforms that cannot remove the current working
  # directory of the process:
  #
  # Solaris: https://man.freebsd.org/cgi/man.cgi?query=rmdir&sektion=2&manpath=SunOS+5.10
  # Windows: https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/rmdir-wrmdir?view=msvc-170#remarks
  {% unless flag?(:win32) || flag?(:solaris) %}
    it "print exception with non-existing PWD", tags: %w[slow] do
      source_file = datapath("blank_test_file.txt")
      compile_file(source_file) do |executable_file|
        output, error = IO::Memory.new, IO::Memory.new
        with_tempfile("non-existent") do |path|
          Dir.mkdir path
          Dir.cd(path) do
            Dir.delete(path)
            status = Process.run executable_file

            status.success?.should be_true
          end
        end
      end
    end
  {% end %}
end
