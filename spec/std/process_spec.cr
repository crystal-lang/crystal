{% skip_file if flag?(:wasm32) %}

require "spec"
require "process"
require "./spec_helper"

private def exit_code_command(code)
  {% if flag?(:win32) %}
    {"cmd.exe", {"/c", "exit #{code}"}}
  {% else %}
    case code
    when 0
      {"true", [] of String}
    when 1
      {"false", [] of String}
    else
      {"/bin/sh", {"-c", "exit #{code}"}}
    end
  {% end %}
end

private def shell_command(command)
  {% if flag?(:win32) %}
    {"cmd.exe", {"/c", command}}
  {% else %}
    {"/bin/sh", {"-c", command}}
  {% end %}
end

private def stdin_to_stdout_command
  {% if flag?(:win32) %}
    {"powershell.exe", {"-C", "$Input"}}
  {% else %}
    {"/bin/cat", [] of String}
  {% end %}
end

private def print_env_command
  {% if flag?(:win32) %}
    # cmd adds these by itself, clear them out before printing.
    shell_command("set COMSPEC=& set PATHEXT=& set PROMPT=& set")
  {% else %}
    {"env", [] of String}
  {% end %}
end

private def standing_command
  {% if flag?(:win32) %}
    {"cmd.exe"}
  {% else %}
    {"yes"}
  {% end %}
end

private def newline
  {% if flag?(:win32) %}
    "\r\n"
  {% else %}
    "\n"
  {% end %}
end

describe Process do
  describe ".new" do
    it "raises if command doesn't exist" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.new("foobarbaz")
      end
    end

    it "accepts nilable string for `chdir` (#13767)" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.new("foobarbaz", chdir: nil.as(String?))
      end
    end

    it "raises if command is not executable" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        expect_raises({% if flag?(:win32) %} File::BadExecutableError {% else %} File::AccessDeniedError {% end %}, "Error executing process: '#{path.inspect_unquoted}'") do
          Process.new(path)
        end
      end
    end

    it "raises if command is not executable" do
      with_tempfile("crystal-spec-run") do |path|
        Dir.mkdir path
        expect_raises(File::AccessDeniedError, "Error executing process: '#{path.inspect_unquoted}'") do
          Process.new(path)
        end
      end
    end

    it "raises if command could not be executed" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        command = File.join(path, "foo")
        expect_raises(IO::Error, "Error executing process: '#{command.inspect_unquoted}'") do
          Process.new(command)
        end
      end
    end
  end

  describe "#wait" do
    it "successful exit code" do
      process = Process.new(*exit_code_command(0))
      process.wait.exit_code.should eq(0)
    end

    it "unsuccessful exit code" do
      process = Process.new(*exit_code_command(1))
      process.wait.exit_code.should eq(1)
    end
  end

  describe ".run" do
    it "waits for the process" do
      Process.run(*exit_code_command(0)).exit_code.should eq(0)
    end

    it "runs true in block" do
      Process.run(*exit_code_command(0)) { }
      $?.exit_code.should eq(0)
    end

    it "receives arguments in array" do
      command, args = exit_code_command(123)
      Process.run(command, args.to_a).exit_code.should eq(123)
    end

    it "receives arguments in tuple" do
      command, args = exit_code_command(123)
      Process.run(command, args.as(Tuple)).exit_code.should eq(123)
    end

    it "redirects output to /dev/null" do
      # This doesn't test anything but no output should be seen while running tests
      command, args = {% if flag?(:win32) %}
                        {"cmd.exe", {"/c", "dir"}}
                      {% else %}
                        {"/bin/ls", [] of String}
                      {% end %}
      Process.run(command, args, output: Process::Redirect::Close).exit_code.should eq(0)
    end

    it "gets output" do
      value = Process.run(*shell_command("echo hello")) do |proc|
        proc.output.gets_to_end
      end
      value.should eq("hello#{newline}")
    end

    it "sends input in IO" do
      value = Process.run(*stdin_to_stdout_command, input: IO::Memory.new("hello")) do |proc|
        proc.input?.should be_nil
        proc.output.gets_to_end
      end
      value.chomp.should eq("hello")
    end

    it "sends output to IO" do
      output = IO::Memory.new
      Process.run(*shell_command("echo hello"), output: output)
      output.to_s.should eq("hello#{newline}")
    end

    it "sends error to IO" do
      error = IO::Memory.new
      Process.run(*shell_command("1>&2 echo hello"), error: error)
      error.to_s.should eq("hello#{newline}")
    end

    it "controls process in block" do
      value = Process.run(*stdin_to_stdout_command, error: :inherit) do |proc|
        proc.input.puts "hello"
        proc.input.close
        proc.output.gets_to_end
      end
      value.should eq("hello#{newline}")
    end

    it "closes ios after block" do
      Process.run(*stdin_to_stdout_command) { }
      $?.exit_code.should eq(0)
    end

    it "sets working directory with string" do
      parent = File.dirname(Dir.current)
      command = {% if flag?(:win32) %}
                  "cmd.exe /c echo %cd%"
                {% else %}
                  "pwd"
                {% end %}
      value = Process.run(command, shell: true, chdir: parent, output: Process::Redirect::Pipe) do |proc|
        proc.output.gets_to_end
      end
      value.should eq "#{parent}#{newline}"
    end

    it "sets working directory with path" do
      parent = Path.new File.dirname(Dir.current)
      command = {% if flag?(:win32) %}
                  "cmd.exe /c echo %cd%"
                {% else %}
                  "pwd"
                {% end %}
      value = Process.run(command, shell: true, chdir: parent, output: Process::Redirect::Pipe) do |proc|
        proc.output.gets_to_end
      end
      value.should eq "#{parent}#{newline}"
    end

    pending_win32 "disallows passing arguments to nowhere" do
      expect_raises ArgumentError, /args.+@/ do
        Process.run("foo bar", {"baz"}, shell: true)
      end
    end

    pending_win32 "looks up programs in the $PATH with a shell" do
      proc = Process.run(*exit_code_command(0), shell: true, output: Process::Redirect::Close)
      proc.exit_code.should eq(0)
    end

    pending_win32 "allows passing huge argument lists to a shell" do
      proc = Process.new(%(echo "${@}"), {"a", "b"}, shell: true, output: Process::Redirect::Pipe)
      output = proc.output.gets_to_end
      proc.wait
      output.should eq "a b\n"
    end

    pending_win32 "does not run shell code in the argument list" do
      proc = Process.new("echo", {"`echo hi`"}, shell: true, output: Process::Redirect::Pipe)
      output = proc.output.gets_to_end
      proc.wait
      output.should eq "`echo hi`\n"
    end

    describe "environ" do
      it "clears the environment" do
        value = Process.run(*print_env_command, clear_env: true) do |proc|
          proc.output.gets_to_end
        end
        value.should eq("")
      end

      it "clears and sets an environment variable" do
        value = Process.run(*print_env_command, clear_env: true, env: {"FOO" => "bar"}) do |proc|
          proc.output.gets_to_end
        end
        value.should eq("FOO=bar#{newline}")
      end

      it "sets an environment variable" do
        value = Process.run(*print_env_command, env: {"FOO" => "bar"}) do |proc|
          proc.output.gets_to_end
        end
        value.should match /(*ANYCRLF)^FOO=bar$/m
      end

      it "sets an empty environment variable" do
        value = Process.run(*print_env_command, env: {"FOO" => ""}) do |proc|
          proc.output.gets_to_end
        end
        value.should match /(*ANYCRLF)^FOO=$/m
      end

      it "deletes existing environment variable" do
        ENV["FOO"] = "bar"
        value = Process.run(*print_env_command, env: {"FOO" => nil}) do |proc|
          proc.output.gets_to_end
        end
        value.should_not match /(*ANYCRLF)^FOO=/m
      ensure
        ENV.delete("FOO")
      end

      {% if flag?(:win32) %}
        it "deletes existing environment variable case-insensitive" do
          ENV["FOO"] = "bar"
          value = Process.run(*print_env_command, env: {"foo" => nil}) do |proc|
            proc.output.gets_to_end
          end
          value.should_not match /(*ANYCRLF)^FOO=/mi
        ensure
          ENV.delete("FOO")
        end
      {% end %}

      it "preserves existing environment variable" do
        ENV["FOO"] = "bar"
        value = Process.run(*print_env_command) do |proc|
          proc.output.gets_to_end
        end
        value.should match /(*ANYCRLF)^FOO=bar$/m
      ensure
        ENV.delete("FOO")
      end

      it "preserves and sets an environment variable" do
        ENV["FOO"] = "bar"
        value = Process.run(*print_env_command, env: {"FOO2" => "bar2"}) do |proc|
          proc.output.gets_to_end
        end
        value.should match /(*ANYCRLF)^FOO=bar$/m
        value.should match /(*ANYCRLF)^FOO2=bar2$/m
      ensure
        ENV.delete("FOO")
      end

      it "overrides existing environment variable" do
        ENV["FOO"] = "bar"
        value = Process.run(*print_env_command, env: {"FOO" => "different"}) do |proc|
          proc.output.gets_to_end
        end
        value.should match /(*ANYCRLF)^FOO=different$/m
      ensure
        ENV.delete("FOO")
      end

      {% if flag?(:win32) %}
        it "overrides existing environment variable case-insensitive" do
          ENV["FOO"] = "bar"
          value = Process.run(*print_env_command, env: {"fOo" => "different"}) do |proc|
            proc.output.gets_to_end
          end
          value.should_not match /(*ANYCRLF)^FOO=/m
          value.should match /(*ANYCRLF)^fOo=different$/m
        ensure
          ENV.delete("FOO")
        end
      {% end %}
    end

    # TODO: this spec gives "WaitForSingleObject: The handle is invalid."
    # is this because standard streams on windows aren't async?
    pending_win32 "can link processes together" do
      buffer = IO::Memory.new
      Process.run(*stdin_to_stdout_command) do |cat|
        Process.run(*stdin_to_stdout_command, input: cat.output, output: buffer) do
          1000.times { cat.input.puts "line" }
          cat.close
        end
      end
      buffer.to_s.chomp.lines.size.should eq(1000)
    end
  end

  describe ".on_interrupt" do
    it "compiles" do
      typeof(Process.on_interrupt { })
      typeof(Process.ignore_interrupts!)
      typeof(Process.restore_interrupts!)
    end
  end

  {% unless flag?(:win32) %}
    describe "#signal(Signal::KILL)" do
      it "kills a process" do
        process = Process.new(*standing_command)
        process.signal(Signal::KILL).should be_nil
      ensure
        process.try &.wait
      end

      it "kills many process" do
        process1 = Process.new(*standing_command)
        process2 = Process.new(*standing_command)
        process1.signal(Signal::KILL).should be_nil
        process2.signal(Signal::KILL).should be_nil
      ensure
        process1.try &.wait
        process2.try &.wait
      end
    end
  {% end %}

  it "#terminate" do
    process = Process.new(*standing_command)
    process.exists?.should be_true
    process.terminated?.should be_false

    process.terminate
  ensure
    process.try(&.wait)
  end

  typeof(Process.new(*standing_command).terminate(graceful: false))

  it ".exists?" do
    # On Windows killing a parent process does not reparent its children to
    # another existing process, so the following isn't guaranteed to work
    {% unless flag?(:win32) %}
      # We can't reliably check whether it ever returns false, since we can't predict
      # how PIDs are used by the system, a new process might be spawned in between
      # reaping the one we would spawn and checking for it, using the now available
      # pid.
      Process.exists?(Process.ppid).should be_true
    {% end %}

    process = Process.new(*standing_command)
    process.exists?.should be_true
    process.terminated?.should be_false

    # Kill, zombie now
    process.terminate
    {% if flag?(:win32) %}
      # Windows has no concept of zombie processes
      process.exists?.should be_false
      process.terminated?.should be_true
    {% else %}
      process.exists?.should be_true
      process.terminated?.should be_false
    {% end %}

    # Reap, gone now
    process.wait
    process.exists?.should be_false
    process.terminated?.should be_true
  end

  {% unless flag?(:win32) %}
    it ".pgid" do
      process = Process.new(*standing_command)
      Process.pgid(process.pid).should be_a(Int64)
      process.terminate
      Process.pgid.should eq(Process.pgid(Process.pid))
    ensure
      process.try(&.wait)
    end
  {% end %}

  {% unless flag?(:preview_mt) || flag?(:win32) %}
    describe ".fork" do
      it "executes the new process with exec" do
        with_tempfile("crystal-spec-exec") do |path|
          File.exists?(path).should be_false

          fork = Process.fork do
            Process.exec("/usr/bin/env", {"touch", path})
          end
          fork.wait

          File.exists?(path).should be_true
        end
      end
    end
  {% end %}

  describe ".exec" do
    it "gets error from exec" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.exec("foobarbaz")
      end
    end
  end

  describe ".chroot" do
    {% if flag?(:unix) && !flag?(:android) %}
      it "raises when unprivileged", tags: %w[slow] do
        status, output, _ = compile_and_run_source <<-'CRYSTAL'
          # Try to drop privileges. Ignoring any errors because dropping is only
          # necessary for a privileged user and it doesn't matter when it fails
          # for an unprivileged one.
          # This particular UID is often attributed to the `nobody` user.
          LibC.setuid(65534)

          begin
            Process.chroot(".")
            puts "FAIL"
          rescue ex
            puts ex.inspect
          end
        CRYSTAL

        status.success?.should be_true
        output.should eq("#<RuntimeError:Failed to chroot: Operation not permitted>\n")
      end
    {% end %}
  end
end
