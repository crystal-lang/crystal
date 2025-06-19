require "spec"
require "./spec_helper"

describe "PROGRAM_NAME" do
  it "works for UTF-8 name", tags: %w[slow] do
    with_tempfile("source_file") do |source_file|
      if ENV["IN_NIX_SHELL"]?
        pending! "Example is broken in Nix shell (#12332)"
      end

      # MSYS2: gcc/ld doesn't support unicode paths
      # https://github.com/msys2/MINGW-packages/issues/17812
      {% if flag?(:windows) %}
        if ENV["MSYSTEM"]?
          pending! "Example is broken in MSYS2 shell"
        end
      {% end %}

      File.write(source_file, "File.basename(PROGRAM_NAME).inspect(STDOUT)")

      compile_file(source_file, bin_name: "×‽😂") do |executable_file|
        output = IO::Memory.new
        Process.run(executable_file, output: output).success?.should be_true
        output.to_s.should eq(File.basename(executable_file).inspect)
      end
    end
  end
end

describe "ARGV" do
  it "accepts UTF-8 command-line arguments", tags: %w[slow] do
    with_tempfile("source_file") do |source_file|
      File.write(source_file, "ARGV.inspect(STDOUT)")

      compile_file(source_file) do |executable_file|
        args = ["×‽😂", "あ×‽😂い"]
        output = IO::Memory.new
        Process.run(executable_file, args, output: output).success?.should be_true
        output.to_s.should eq(args.inspect)
      end
    end
  end
end

describe "exit" do
  it "exits normally with status 0", tags: %w[slow] do
    status, _, _ = compile_and_run_source "exit"
    status.success?.should be_true
  end

  it "exits with given error code", tags: %w[slow] do
    status, _, _ = compile_and_run_source "exit 42"
    status.success?.should be_false
    status.exit_code.should eq(42)
  end
end

describe "at_exit" do
  it "runs handlers on normal program ending", tags: %w[slow] do
    status, output, _ = compile_and_run_source <<-CRYSTAL
      at_exit do
        print "handler code."
      end
    CRYSTAL

    status.success?.should be_true
    output.should eq("handler code.")
  end

  it "runs handlers on explicit program ending", tags: %w[slow] do
    status, output, _ = compile_and_run_source <<-'CRYSTAL'
      at_exit do |exit_code|
        print "handler code, exit code: #{exit_code}."
      end

      exit 42
    CRYSTAL

    status.exit_code.should eq(42)
    output.should eq("handler code, exit code: 42.")
  end

  it "runs handlers in reverse order", tags: %w[slow] do
    status, output, _ = compile_and_run_source <<-CRYSTAL
      at_exit do
        print "first handler code."
      end

      at_exit do
        print "second handler code."
      end
    CRYSTAL

    status.success?.should be_true
    output.should eq("second handler code.first handler code.")
  end

  it "runs all handlers maximum once", tags: %w[slow] do
    status, output, _ = compile_and_run_source <<-CRYSTAL
      at_exit do
        print "first handler code."
      end

      at_exit do
        print "second handler code, explicit exit!"
        exit

        print "not executed."
      end

      at_exit do
        print "third handler code."
      end
    CRYSTAL

    status.success?.should be_true
    output.should eq("third handler code.second handler code, explicit exit!first handler code.")
  end

  it "allows handlers to change the exit code with explicit `exit` call", tags: %w[slow] do
    status, output, _ = compile_and_run_source <<-'CRYSTAL'
      at_exit do |exit_code|
        print "first handler code, exit code: #{exit_code}."
      end

      at_exit do
        print "second handler code, re-exiting."
        exit 42

        print "not executed."
      end

      at_exit do |exit_code|
        print "third handler code, exit code: #{exit_code}."
      end
    CRYSTAL

    status.success?.should be_false
    status.exit_code.should eq(42)
    output.should eq("third handler code, exit code: 0.second handler code, re-exiting.first handler code, exit code: 42.")
  end

  it "allows handlers to change the exit code with explicit `exit` call (2)", tags: %w[slow] do
    status, output, _ = compile_and_run_source <<-'CRYSTAL'
      at_exit do |exit_code|
        print "first handler code, exit code: #{exit_code}."
      end

      at_exit do
        print "second handler code, re-exiting."
        exit 42

        print "not executed."
      end

      at_exit do |exit_code|
        print "third handler code, exit code: #{exit_code}."
      end

      exit 21
    CRYSTAL

    status.success?.should be_false
    status.exit_code.should eq(42)
    output.should eq("third handler code, exit code: 21.second handler code, re-exiting.first handler code, exit code: 42.")
  end

  it "changes final exit code when an handler raises an error", tags: %w[slow] do
    status, output, error = compile_and_run_source <<-'CRYSTAL'
      at_exit do |exit_code|
        print "first handler code, exit code: #{exit_code}."
      end

      at_exit do
        print "second handler code, raising."
        raise "Raised from at_exit handler!"

        print "not executed."
      end

      at_exit do |exit_code|
        print "third handler code, exit code: #{exit_code}."
      end
    CRYSTAL

    status.success?.should be_false
    status.exit_code.should eq(1)
    output.should eq("third handler code, exit code: 0.second handler code, raising.first handler code, exit code: 1.")
    error.should contain("Error running at_exit handler: Raised from at_exit handler!")
  end

  it "shows unhandled exceptions after at_exit handlers", tags: %w[slow] do
    status, _, error = compile_and_run_source <<-CRYSTAL
      at_exit do
        STDERR.print "first handler code."
      end

      at_exit do
        STDERR.print "second handler code."
      end

      raise "Kaboom!"
    CRYSTAL

    status.success?.should be_false
    error.should contain("second handler code.first handler code.Unhandled exception: Kaboom!")
  end

  it "can get unhandled exception in at_exit handler", tags: %w[slow] do
    status, _, error = compile_and_run_source <<-CRYSTAL
      at_exit do |_, ex|
        STDERR.print ex.try &.message
      end

      raise "Kaboom!"
    CRYSTAL

    status.success?.should be_false
    error.should contain("Kaboom!Unhandled exception: Kaboom!")
  end

  it "allows at_exit inside at_exit", tags: %w[slow] do
    status, output, _ = compile_and_run_source <<-CRYSTAL
      at_exit do
        print "1"
        at_exit do
          print "2"
        end
      end

      at_exit do
        print "3"
        at_exit do
          print "4"
        end
      end
    CRYSTAL

    status.success?.should be_true
    output.should eq("3412")
  end

  it "prints unhandled exception with cause", tags: %w[slow] do
    status, _, error = compile_and_run_source <<-CRYSTAL
      raise Exception.new("secondary", cause: Exception.new("primary"))
    CRYSTAL

    status.success?.should be_false
    error.should contain "Unhandled exception: secondary"
    error.should contain "Caused by: primary"
  end
end

{% if flag?(:openbsd) %}
  # FIXME: the segfault handler doesn't work on OpenBSD
  pending "hardware exception"
{% else %}
  describe "hardware exception" do
    it "reports invalid memory access", tags: %w[slow] do
      status, _, error = compile_and_run_source <<-'CRYSTAL'
        puts Pointer(Int64).null.value
      CRYSTAL

      status.success?.should be_false
      error.should contain("Invalid memory access")
      error.should_not contain("Stack overflow")
    end

    {% if flag?(:netbsd) %}
      # FIXME: on netbsd the process crashes with SIGILL after receiving SIGSEGV
      pending "detects stack overflow on the main stack"
      pending "detects stack overflow on a fiber stack"
    {% else %}
      it "detects stack overflow on the main stack", tags: %w[slow] do
        # This spec can take some time under FreeBSD where
        # the default stack size is 0.5G.  Setting a
        # smaller stack size with `ulimit -s 8192`
        # will address this.
        status, _, error = compile_and_run_source <<-'CRYSTAL'
          def foo
            y = StaticArray(Int8, 512).new(0)
            foo
          end
          foo
        CRYSTAL

        status.success?.should be_false
        error.should contain("Stack overflow")
      end

      it "detects stack overflow on a fiber stack", tags: %w[slow] do
        status, _, error = compile_and_run_source <<-'CRYSTAL'
          def foo
            y = StaticArray(Int8, 512).new(0)
            foo
          end

          spawn do
            foo
          end

          sleep 60.seconds
        CRYSTAL

        status.success?.should be_false
        error.should contain("Stack overflow")
      end
    {% end %}
  end
{% end %}
