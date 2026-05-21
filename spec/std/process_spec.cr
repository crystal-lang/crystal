{% skip_file if flag?(:wasm32) %}

require "spec"
require "process"
require "./spec_helper"
require "../support/env"
require "../support/wait_for"

private def exit_code_command(code)
  {% if flag?(:win32) %}
    {"cmd.exe", {"/c", "exit #{code}"}}
  {% else %}
    {"/bin/sh", {"-c", "exit #{code}"}}
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

private def stdin_to_stderr_command(status = 0)
  {% if flag?(:win32) %}
    {"powershell.exe", {"-C", "[Console]::OpenStandardInput().CopyTo([Console]::OpenStandardError()); exit #{status}"}}
  {% else %}
    {"/bin/sh", {"-c", "cat 1>&2; exit #{status}"}}
  {% end %}
end

private def print_env_command
  {% if flag?(:win32) %}
    # cmd adds these by itself, clear them out before printing.
    shell_command("set COMSPEC=& set PATHEXT=& set PROMPT=& set PROCESSOR_ARCHITECTURE=& set")
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

private def path_search_command
  {% if flag?(:win32) %}
    {"cmd.exe"}
  {% else %}
    {"true"}
  {% end %}
end

private def newline
  {% if flag?(:win32) %}
    "\r\n"
  {% else %}
    "\n"
  {% end %}
end

private def to_ary(tuple)
  [tuple[0]].concat(tuple[1])
end

private def to_splat(cmd)
  # Splatting in literals was only introduced in Crystal 1.1
  # FIXME: The interpreter still doesn't support it (#13183).
  {% if compare_versions(Crystal::VERSION, "1.1.0") >= 0 && !flag?(:interpreted) %}
    {cmd[0], *cmd[1]}
  {% else %}
    args = cmd[1]
    {cmd[0], args[0], args[1]}
  {% end %}
end

# interpreted code doesn't receive SIGCHLD for `#wait` to work (#12241)
{% if flag?(:interpreted) && !flag?(:win32) %}
  pending Process
  {% skip_file %}
{% end %}

describe Process do
  describe ".new (args)" do
    it "raises if args is empty" do
      expect_raises(File::NotFoundError, "Error executing process: No command") do
        Process.new([] of String)
      end
    end

    it "raises if args[0] is empty" do
      expect_raises(IO::Error, /Error executing process: '(""|\\"\\")?'/) do
        Process.new([""] of String)
      end
    end

    it "raises if command doesn't exist" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.new(["foobarbaz"])
      end
    end

    it "raises for long path" do
      expect_raises(File::NotFoundError, "Error executing process: 'aaaaaaa") do
        Process.new(["a" * 1000])
      end
    end

    it "accepts nilable string for `chdir` (#13767)" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.new(["foobarbaz"], chdir: nil.as(String?))
      end
    end

    it "raises if command is a file path" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        expect_raises({% if flag?(:win32) %} File::BadExecutableError {% else %} File::AccessDeniedError {% end %}, "Error executing process: '#{path.inspect_unquoted}'") do
          Process.new([path])
        end
      end
    end

    it "raises if command is a dir path" do
      with_tempfile("crystal-spec-run") do |path|
        Dir.mkdir path
        expect_raises(File::AccessDeniedError, "Error executing process: '#{path.inspect_unquoted}'") do
          Process.new([path])
        end
      end
    end

    it "raises if command is a file's subpath" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        command = File.join(path, "foo")
        expect_raises(IO::Error, "Error executing process: '#{command.inspect_unquoted}'") do
          Process.new([command])
        end
      end
    end

    it "doesn't break if process is collected before completion", tags: %w[slow] do
      200.times { Process.new(to_ary(exit_code_command(0))) }

      # run the GC multiple times to unmap as much memory as possible
      10.times { GC.collect }

      # the processes above have now been queued after completion; if this last
      # one finishes at all, nothing was broken by the GC
      Process.run(*exit_code_command(0))
    end

    it "accepts tuple args" do
      Process.new({path_search_command[0]}).wait.success?.should be_true
    end
  end

  describe ".new (splat)" do
    it "works" do
      Process.new(*to_splat(exit_code_command(0))).wait.success?.should be_true
    end
  end

  describe ".new (command + args)" do
    it "raises if command doesn't exist" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.new("foobarbaz")
      end
    end

    it "raises for long path" do
      expect_raises(File::NotFoundError, "Error executing process: 'aaaaaaa") do
        Process.new("a" * 1000)
      end
    end

    it "accepts nilable string for `chdir` (#13767)" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.new("foobarbaz", chdir: nil.as(String?))
      end
    end

    it "raises if command is a file path" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        expect_raises({% if flag?(:win32) %} File::BadExecutableError {% else %} File::AccessDeniedError {% end %}, "Error executing process: '#{path.inspect_unquoted}'") do
          Process.new(path)
        end
      end
    end

    it "raises if command is a dir path" do
      with_tempfile("crystal-spec-run") do |path|
        Dir.mkdir path
        expect_raises(File::AccessDeniedError, "Error executing process: '#{path.inspect_unquoted}'") do
          Process.new(path)
        end
      end
    end

    it "raises if command is a file's subpath" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        command = File.join(path, "foo")
        expect_raises(IO::Error, "Error executing process: '#{command.inspect_unquoted}'") do
          Process.new(command)
        end
      end
    end

    it "doesn't break if process is collected before completion", tags: %w[slow] do
      200.times { Process.new(*exit_code_command(0)) }

      # run the GC multiple times to unmap as much memory as possible
      10.times { GC.collect }

      # the processes above have now been queued after completion; if this last
      # one finishes at all, nothing was broken by the GC
      Process.run(*exit_code_command(0))
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

  describe ".run?(args)" do
    it "waits for successful process" do
      status = Process.run?(to_ary(exit_code_command(0))).should be_a(Process::Status)
      status.exit_code.should eq(0)
    end

    it "waits for unsuccessful process" do
      status = Process.run?(to_ary(exit_code_command(1))).should be_a(Process::Status)
      status.exit_code.should eq(1)
    end

    it "returns nil if args[0] is empty" do
      Process.run?([""] of String).should be_nil
    end

    it "returns nil command doesn't exist" do
      Process.run?(["foobarbaz"]).should be_nil
    end

    it "returns nil for long path" do
      Process.run?(["a" * 1000]).should be_nil
    end

    it "returns nil if command is a file path" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        Process.run?([path]).should be_nil
      end
    end

    it "returns nil if command is a dir path" do
      with_tempfile("crystal-spec-run") do |path|
        Dir.mkdir path
        Process.run?([path]).should be_nil
      end
    end

    it "returns nil if command is a file's subpath" do
      with_tempfile("crystal-spec-run") do |path|
        File.touch path
        command = File.join(path, "foo")
        Process.run?([command]).should be_nil
      end
    end

    it "accepts tuple args" do
      Process.run({path_search_command[0]}).success?.should be_true
    end
  end

  describe ".run? (splat)" do
    it "works" do
      status = Process.run?(*to_splat(exit_code_command(0))).should be_a(Process::Status)
      status.exit_code.should eq(0)
    end
  end

  describe ".run" do
    it "waits for the process" do
      Process.run(to_ary(exit_code_command(0))).exit_code.should eq(0)
    end
  end

  describe ".run (splat)" do
    it "works" do
      status = Process.run(*to_splat(exit_code_command(0))).exit_code.should eq(0)
    end
  end

  describe ".run(args, &)" do
    it "waits for the process" do
      Process.run(to_ary(exit_code_command(0))) { }[0].exit_code.should eq(0)
    end

    it "returns block result" do
      Process.run(to_ary(exit_code_command(0))) { 42 }[1].should eq 42
    end
  end

  describe ".run(command, args)" do
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

    it "sends long output and error to IO" do
      output = IO::Memory.new
      error = IO::Memory.new
      Process.run(*shell_command("echo #{"." * 8000}"), output: output, error: error)
      output.to_s.should eq("." * 8000 + newline)
      error.to_s.should be_empty
    end

    it "controls process in block" do
      value = Process.run(*stdin_to_stdout_command, error: :inherit) do |proc|
        proc.input.puts "hello"
        proc.input.close
        proc.output.gets_to_end
      end
      value.should eq("hello#{newline}")
    end

    it "closes input after block" do
      Process.run(*stdin_to_stdout_command) { }
      $?.exit_code.should eq(0)
    end

    it "closes output and error after block" do
      reader, writer = IO.pipe
      channel = Channel(Process).new

      spawn do
        Process.run(*stdin_to_stdout_command, input: reader, output: :pipe, error: :pipe) do |process|
          channel.send process
          channel.receive
        end
        channel.close
      end

      process = channel.receive

      process.output.closed?.should be_false
      process.error.closed?.should be_false

      channel.send process

      # Wait a moment for the other fiber to continue and close the IOs
      wait_for { process.output.closed? && process.error.closed? }

      writer.close
      channel.receive?.should be_nil
    end

    it "forwards closed io" do
      closed_io = IO::Memory.new
      closed_io.close
      Process.run(*stdin_to_stdout_command, input: closed_io)
      Process.run(*stdin_to_stdout_command, output: closed_io)
      Process.run(*stdin_to_stdout_command, error: closed_io)
    end

    it "forwards non-blocking file" do
      with_tempfile("non-blocking-process-input.txt", "non-blocking-process-output.txt") do |in_path, out_path|
        File.open(in_path, "w+", blocking: false) do |input|
          File.open(out_path, "w+", blocking: false) do |output|
            input.puts "hello"
            input.rewind
            Process.run(*stdin_to_stdout_command, input: input, output: output)
            output.rewind
            output.gets_to_end.chomp.should eq("hello")
          end
        end
      end
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

    describe "does not execute batch files" do
      %w[.bat .Bat .BAT .cmd .cmD .CmD .bat\  .cmd\ ... .bat.\ .].each do |ext|
        it ext do
          with_tempfile "process_run#{ext}" do |path|
            File.write(path, "echo '#{ext}'\n")
            expect_raises {{ flag?(:win32) ? File::BadExecutableError : File::AccessDeniedError }}, "Error executing process" do
              Process.run(path)
            end
          end
        end
      end
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
        with_env("FOO": "bar") do
          value = Process.run(*print_env_command, env: {"FOO" => nil}) do |proc|
            proc.output.gets_to_end
          end
          value.should_not match /(*ANYCRLF)^FOO=/m
        end
      end

      {% if flag?(:win32) %}
        it "deletes existing environment variable case-insensitive" do
          with_env("FOO": "bar") do
            value = Process.run(*print_env_command, env: {"foo" => nil}) do |proc|
              proc.output.gets_to_end
            end
            value.should_not match /(*ANYCRLF)^FOO=/mi
          end
        end
      {% end %}

      it "preserves existing environment variable" do
        with_env("FOO": "bar") do
          value = Process.run(*print_env_command) do |proc|
            proc.output.gets_to_end
          end
          value.should match /(*ANYCRLF)^FOO=bar$/m
        end
      end

      it "preserves and sets an environment variable" do
        with_env("FOO": "bar") do
          value = Process.run(*print_env_command, env: {"FOO2" => "bar2"}) do |proc|
            proc.output.gets_to_end
          end
          value.should match /(*ANYCRLF)^FOO=bar$/m
          value.should match /(*ANYCRLF)^FOO2=bar2$/m
        end
      end

      it "overrides existing environment variable" do
        with_env("FOO": "bar") do
          value = Process.run(*print_env_command, env: {"FOO" => "different"}) do |proc|
            proc.output.gets_to_end
          end
          value.should match /(*ANYCRLF)^FOO=different$/m
        end
      end

      {% if flag?(:win32) %}
        it "overrides existing environment variable case-insensitive" do
          with_env("FOO": "bar") do
            value = Process.run(*print_env_command, env: {"fOo" => "different"}) do |proc|
              proc.output.gets_to_end
            end
            value.should_not match /(*ANYCRLF)^FOO=/m
            value.should match /(*ANYCRLF)^fOo=different$/m
          end
        end
      {% end %}

      it "finds binary in parent `$PATH`, not `env`" do
        Process.run(*print_env_command, env: {"PATH" => ""})
      end

      it "errors on invalid key" do
        expect_raises(ArgumentError, %(Invalid env key "")) do
          Process.run(*print_env_command, env: {"" => "baz"})
        end
        expect_raises(ArgumentError, %(Invalid env key "foo=bar")) do
          Process.run(*print_env_command, env: {"foo=bar" => "baz"})
        end
      end

      it "errors on zero char in key" do
        expect_raises({{ flag?(:win32) }} ? ArgumentError : RuntimeError, "String `key` contains null byte") do
          Process.run(*print_env_command, env: {"foo\0" => "baz"})
        end
      end

      it "errors on zero char in value" do
        expect_raises({{ flag?(:win32) }} ? ArgumentError : RuntimeError, "String `value` contains null byte") do
          Process.run(*print_env_command, env: {"foo" => "baz\0"})
        end
      end
    end

    it "errors with empty command" do
      {% begin %}
        expect_raises({% if flag?(:win32) %} IO::Error, "The parameter is incorrect" {% else %} File::NotFoundError{% end %}) do
          Process.run("")
        end
      {% end %}
    end

    it "errors with too long command" do
      pending! unless {{ flag?(:linux) }}

      path_max = {% if LibC.has_constant?(:PATH_MAX) %}
                   LibC::PATH_MAX
                 {% else %}
                   10_000
                 {% end %}

      expect_raises(IO::Error, /File ?name too long/) do
        Process.run("a" * (path_max + 1))
      end

      # The pathname itself is not too long, but it will be when combined with
      # any path prefix.
      expect_raises(IO::Error, /File ?name too long/) do
        Process.run("a" * path_max)
      end
    end

    describe "$PATH" do
      it "works with unset $PATH" do
        with_env("PATH": nil) do
          Process.run(*path_search_command)
        end
      end

      it "errors with empty $PATH" do
        pending! if {{ flag?(:win32) }}
        with_env("PATH": "") do
          expect_raises(File::NotFoundError) do
            Process.run(*path_search_command)
          end
        end
      end

      it "empty still finds in current directory" do
        pending! unless {{ flag?(:unix) }}

        with_tempfile("crystal-spec-run") do |dir|
          Dir.mkdir dir
          File.write(Path[dir, "foo"], "#!/bin/sh\necho bar")
          File.chmod(Path[dir, "foo"], 0o555)
          if {{ flag?(:darwin) }}
            String.build do |io|
              Process.run("foo", chdir: dir, output: io)
            end.should eq "bar\n"
          else
            expect_raises(File::NotFoundError) do
              Process.run("foo", chdir: dir)
            end
          end
        end
      end

      it "empty path entry means current directory" do
        pending! unless {{ flag?(:unix) }}

        with_tempfile("crystal-spec-run") do |dir|
          Dir.mkdir dir
          File.write(Path[dir, "foo"], "#!/bin/sh\necho bar")
          File.chmod(Path[dir, "foo"], 0o555)
          with_env("PATH": ":") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "::") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "/does/not/exist:") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": ":/does/not/exist") do
            Process.run("foo", chdir: dir)
          end
        end
      end

      it "finds path in relative directory" do
        pending! unless {{ flag?(:unix) }}

        with_tempfile("crystal-spec-run") do |dir|
          Dir.mkdir_p Path[dir, "bin"]
          Dir.mkdir_p Path[dir, "empty"]
          File.write(Path[dir, "bin", "foo"], "#!/bin/sh\necho bar")
          File.chmod(Path[dir, "bin", "foo"], 0o555)
          with_env("PATH": "bin") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "empty:bin") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "bin:empty") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "/does/not/exist:bin") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "bin:/does/not/exist") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": ":bin") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "::bin") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "/does/not/exist::bin") do
            Process.run("foo", chdir: dir)
          end
          with_env("PATH": "bin:/does/not/exist") do
            Process.run("foo", chdir: dir)
          end
        end
      end

      context "with shell: true" do
        it "errors with nonexist $PATH" do
          pending! unless {{ flag?(:unix) }}
          Process.run(*print_env_command, shell: true, env: {"PATH" => "/does/not/exist"}).success?.should be_false
        end

        it "empty path entry means current directory" do
          pending! unless {{ flag?(:unix) }}

          with_tempfile("crystal-spec-run") do |dir|
            Dir.mkdir dir
            File.write(Path[dir, "foo"], "#!/bin/sh\necho bar")
            File.chmod(Path[dir, "foo"], 0o555)
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => ":"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "::"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "/does/not/exist:"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => ":/does/not/exist"}).success?.should be_true
          end
        end

        it "finds path in relative directory" do
          pending! unless {{ flag?(:unix) }}

          with_tempfile("crystal-spec-run") do |dir|
            Dir.mkdir_p Path[dir, "bin"]
            Dir.mkdir_p Path[dir, "empty"]
            File.write(Path[dir, "bin", "foo"], "#!/bin/sh\necho bar")
            File.chmod(Path[dir, "bin", "foo"], 0o555)
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "bin"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "empty:bin"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "bin:empty"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "/does/not/exist:bin"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "bin:/does/not/exist"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => ":bin"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "::bin"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "/does/not/exist::bin"}).success?.should be_true
            Process.run("foo", chdir: dir, shell: true, env: {"PATH" => "bin:/does/not/exist"}).success?.should be_true
          end
        end
      end
    end

    it "can link processes together" do
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

  describe ".capture_result" do
    it "splat overload" do
      result = Process.capture_result(*to_splat(shell_command("echo hello")))
      result.status.success?.should be_true
      result.output?.should eq "hello#{newline}"
      result.error?.should eq ""
    end

    it "captures stdout" do
      result = Process.capture_result(to_ary(shell_command("echo hello")))
      result.status.success?.should be_true
      result.output?.should eq "hello#{newline}"
      result.error?.should eq ""
    end

    it "captures stdout from stdin" do
      result = Process.capture_result(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello"))
      result.status.success?.should be_true
      result.output.chomp.should eq "hello"
    end

    it "ignores stdout if output is IO" do
      io = IO::Memory.new
      result = Process.capture_result(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello"), output: io)
      result.status.success?.should be_true
      result.output?.should be_nil
      result.error?.should eq ""
      io.to_s.chomp.should eq "hello"
    end

    it "ignores stdout if output is FileDescriptor" do
      reader, writer = IO.pipe
      result = Process.capture_result(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello\n"), output: writer)
      result.status.success?.should be_true
      result.output?.should be_nil
      result.error?.should eq ""
      reader.gets.should eq "hello"
    end

    it "captures stderr" do
      result = Process.capture_result(to_ary(shell_command("1>&2 echo hello")))
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should eq "hello#{newline}"
    end

    it "ignores stderr if error is IO" do
      io = IO::Memory.new
      result = Process.capture_result(to_ary(shell_command("1>&2 echo hello")), error: io)
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should be_nil
      io.to_s.should eq "hello#{newline}"
    end

    it "ignores stderr if error is FileDescriptor" do
      reader, writer = IO.pipe
      result = Process.capture_result(to_ary(shell_command("1>&2 echo hello")), error: writer)
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should be_nil
      reader.gets.should eq "hello"
    end

    it "doesn't capture closed stdout" do
      result = Process.capture_result(to_ary(shell_command("echo hello")), output: :close)
      result.output?.should be_nil
      result.error?.should_not be_nil
    end

    it "doesn't capture closed stderr" do
      # FIXME: Autocasting breaks in the interpreter
      result = Process.capture_result(to_ary(shell_command("1>&2 echo hello")), error: Process::Redirect::Close)
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should be_nil
    end

    it "truncates error output", tags: %w[slow] do
      dashes32 = "-" * (32 << 10)
      input = IO::Memory.new("#{dashes32}X#{dashes32}")
      result = Process.capture_result(to_ary(stdin_to_stderr_command), input: input)
      result.status.success?.should be_true
      result.output?.should eq ""
      error = result.error.should be_a(String)
      error.should contain "\n...omitted 1 bytes...\n"
      error.count("-").should eq(32 << 11)
    end

    it "reports status" do
      Process.capture_result(to_ary(exit_code_command(0))).status.exit_code.should eq(0)
      Process.capture_result(to_ary(exit_code_command(123))).status.exit_code.should eq(123)
    end

    it "raises if process cannot execute" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.capture_result(["foobarbaz"])
      end
    end
  end

  describe ".capture_result?" do
    it "splat overload" do
      result = Process.capture_result?(*to_splat(shell_command("echo hello"))).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should eq "hello#{newline}"
      result.error?.should eq ""
    end

    it "captures stdout" do
      result = Process.capture_result?(to_ary(shell_command("echo hello"))).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should eq "hello#{newline}"
      result.error?.should eq ""
    end

    it "captures stdout from stdin" do
      result = Process.capture_result?(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello")).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output.chomp.should eq "hello"
    end

    it "ignores stdout if output is IO" do
      io = IO::Memory.new
      result = Process.capture_result?(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello"), output: io).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should be_nil
      result.error?.should eq ""
      io.to_s.chomp.should eq "hello"
    end

    it "ignores stdout if output is FileDescriptor" do
      reader, writer = IO.pipe
      result = Process.capture_result?(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello\n"), output: writer).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should be_nil
      result.error?.should eq ""
      reader.gets.should eq "hello"
    end

    it "captures stderr" do
      result = Process.capture_result?(to_ary(shell_command("1>&2 echo hello"))).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should eq "hello#{newline}"
    end

    it "ignores stderr if error is IO" do
      io = IO::Memory.new
      result = Process.capture_result?(to_ary(shell_command("1>&2 echo hello")), error: io).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should be_nil
      io.to_s.should eq "hello#{newline}"
    end

    it "ignores stderr if error is FileDescriptor" do
      reader, writer = IO.pipe
      result = Process.capture_result?(to_ary(shell_command("1>&2 echo hello")), error: writer).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should be_nil
      reader.gets.should eq "hello"
    end

    it "doesn't capture closed stdout" do
      result = Process.capture_result?(to_ary(shell_command("echo hello")), output: :close).should be_a(Process::Result)
      result.output?.should be_nil
      result.error?.should_not be_nil
    end

    it "doesn't capture closed stderr" do
      # FIXME: Autocasting breaks in the interpreter
      result = Process.capture_result?(to_ary(shell_command("1>&2 echo hello")), error: Process::Redirect::Close).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should eq ""
      result.error?.should be_nil
    end

    it "truncates error output", tags: %w[slow] do
      dashes32 = "-" * (32 << 10)
      input = IO::Memory.new("#{dashes32}X#{dashes32}")
      result = Process.capture_result?(to_ary(stdin_to_stderr_command), input: input).should be_a(Process::Result)
      result.status.success?.should be_true
      result.output?.should eq ""
      error = result.error.should be_a(String)
      error.should contain "\n...omitted 1 bytes...\n"
      error.count("-").should eq(32 << 11)
    end

    it "reports status" do
      result = Process.capture_result?(to_ary(exit_code_command(0))).should be_a(Process::Result)
      result.status.exit_code.should eq(0)
      result = Process.capture_result?(to_ary(exit_code_command(123))).should be_a(Process::Result)
      result.status.exit_code.should eq(123)
    end

    it "raises if process cannot execute" do
      Process.capture_result?(["foobarbaz"]).should be_nil
    end
  end

  describe ".capture" do
    it "splat overload" do
      Process.capture(*to_splat(shell_command("echo hello"))).should eq "hello#{newline}"
    end

    it "captures stdout" do
      Process.capture(to_ary(shell_command("echo hello"))).should eq "hello#{newline}"
    end

    it "captures stdout from stdin" do
      Process.capture(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello")).chomp.should eq "hello"
    end

    it "raises on non-zero exit status" do
      error = expect_raises(Process::ExitError, /^Command \[.*exit 1.*\] failed: Process exited with status 1$/) do
        Process.capture(to_ary(exit_code_command(1)))
      end
      error.result.status.exit_code.should eq 1
    end

    it "raises if process cannot execute" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.capture(["foobarbaz"])
      end
    end

    it "captures stderr in error message" do
      error = expect_raises(Process::ExitError) do
        Process.capture(to_ary(stdin_to_stderr_command(status: 1)), input: IO::Memory.new("hello"))
      end
      error.result.error.chomp.should eq "hello"
    end
  end

  describe ".capture?" do
    it "splat overload" do
      Process.capture?(*to_splat(shell_command("echo hello"))).should eq "hello#{newline}"
    end

    it "captures stdout" do
      Process.capture?(to_ary(shell_command("echo hello"))).should eq "hello#{newline}"
    end

    it "captures stdout from stdin" do
      Process.capture?(to_ary(stdin_to_stdout_command), input: IO::Memory.new("hello")).try(&.chomp).should eq "hello"
    end

    it "returns nil on unsuccessful exit" do
      Process.capture?(to_ary(exit_code_command(1))).should be_nil
    end

    it "returns nil on unsuccessful exit (splat)" do
      Process.capture?(*to_splat(exit_code_command(1))).should be_nil
    end

    it "raises if process cannot execute" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.capture(["foobarbaz"])
      end
    end
  end

  describe ".on_interrupt" do
    it "compiles" do
      typeof(Process.on_interrupt { })
      typeof(Process.ignore_interrupts!)
      typeof(Process.restore_interrupts!)
    end
  end

  describe ".on_terminate" do
    it "compiles" do
      typeof(Process.on_terminate { })
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

  describe ".debugger_present?" do
    it "compiles" do
      typeof(Process.debugger_present?)
    end
  end

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


  describe ".quiesce" do
    it "passes the block return value through" do
      Process.quiesce { 42 }.should eq(42)
    end

    it "fires before_quiesce_callbacks before the block and after_quiesce_callbacks after" do
      # Use a fresh pair of arrays so registered callbacks don't bleed between tests
      before_log = [] of String
      after_log = [] of String
      inside_log = [] of String

      before_cb = ->{ before_log << "before"; nil }
      after_cb  = ->{ after_log << "after"; nil }

      Process.before_quiesce_callbacks << before_cb
      Process.after_quiesce_callbacks  << after_cb

      begin
        Process.quiesce { inside_log << "inside"; nil }
      ensure
        Process.before_quiesce_callbacks.delete(before_cb)
        Process.after_quiesce_callbacks.delete(after_cb)
      end

      before_log.should eq(["before"])
      after_log.should eq(["after"])
      inside_log.should eq(["inside"])
    end

    {% unless flag?(:preview_mt) || flag?(:win32) %}
      it "provides a safe window for fork(2)" do
        pid, saved_errno = Process.quiesce { r = LibC.fork; {r, Errno.value} }
        raise RuntimeError.from_os_error("fork", saved_errno) if pid == -1

        case pid
        when 0
          ::Process.after_fork_child_callbacks.each(&.call)
          LibC._exit 0
        else
          wstatus = uninitialized Int32
          LibC.waitpid(pid, pointerof(wstatus), 0)
          pid.should be > 0
        end
      end
    {% end %}

    {% if flag?(:unix) && !flag?(:interpreted) %}
      it "fires callbacks and reinit_child works under -Dpreview_mt", tags: %w[slow] do
        status, output, _ = compile_and_run_source <<-'CRYSTAL', ["-Dpreview_mt"]
          # Verify quiesce callbacks fire under preview_mt
          log = [] of String
          before_cb = ->{ log << "before"; nil }
          after_cb  = ->{ log << "after"; nil }
          Process.before_quiesce_callbacks << before_cb
          Process.after_quiesce_callbacks  << after_cb

          result = Process.quiesce { log << "inside"; 99 }

          abort "FAIL: wrong result #{result}" unless result == 99
          abort "FAIL: wrong order #{log}" unless log == ["before", "inside", "after"]

          # Verify fork via quiesce + reinit_child under preview_mt
          fork_result = uninitialized LibC::PidT
          fork_errno  = uninitialized Errno

          Process.quiesce do
            fork_result = LibC.fork
            fork_errno  = Errno.value
            nil
          end

          case fork_result
          when 0
            Crystal::Scheduler.reinit_child
            ::Process.after_fork_child_callbacks.each(&.call)
            LibC._exit 0
          when -1
            raise RuntimeError.from_os_error("fork", fork_errno)
          else
            wstatus = uninitialized Int32
            LibC.waitpid(fork_result, pointerof(wstatus), 0)
            puts "ok"
          end
          CRYSTAL

        status.success?.should be_true
        output.chomp.should eq("ok")
      end

      it "reinit_child in child doesn't deadlock when workers held GC.lock_read at fork time", tags: %w[slow] do
        status, output, _ = compile_and_run_source <<-'CRYSTAL', ["-Dpreview_mt"]
          # Flood the scheduler with fiber switches so workers are highly likely to be
          # mid-swapcontext (holding GC.lock_read) when fork fires.
          stop = Atomic(Bool).new(false)
          256.times { spawn { until stop.get; Fiber.yield; end } }
          sleep 20.milliseconds

          # Pipe for child → parent result signaling; avoids waitpid races with
          # Crystal's SIGCHLD handler which reaps all children via waitpid(-1).
          pipe_fds = uninitialized StaticArray(Int32, 2)
          abort "pipe failed" unless LibC.pipe(pipe_fds) == 0

          # Repeat 10 times: ~60% deadlock rate per attempt means >99.99% detection.
          10.times do
            fork_result = uninitialized LibC::PidT
            fork_errno  = uninitialized Errno
            Process.quiesce do
              fork_result = LibC.fork
              fork_errno  = Errno.value
              nil
            end

            case fork_result
            when 0
              LibC.close(pipe_fds[0])
              Crystal::Scheduler.reinit_child
              ::Process.after_fork_child_callbacks.each(&.call)
              # Allocation calls GC.lock_write internally (preview_mt path).
              # If @readers > 0 was inherited from parent workers, this deadlocks.
              1_000.times { Array(Int32).new(100) { |i| i } }
              byte = 42u8
              LibC.write(pipe_fds[1], pointerof(byte).as(Pointer(Void)), 1)
              LibC.close(pipe_fds[1])
              LibC._exit 0
            when -1
              LibC.close(pipe_fds[0]); LibC.close(pipe_fds[1])
              raise RuntimeError.from_os_error("fork", fork_errno)
            else
              LibC.close(pipe_fds[1])
              reader = IO::FileDescriptor.new(pipe_fds[0])
              reader.read_timeout = 5.seconds
              begin
                buf = Bytes.new(1)
                reader.read(buf)
                unless buf[0] == 42u8
                  puts "FAIL: unexpected byte"
                  exit 1
                end
              rescue IO::TimeoutError
                LibC.kill(fork_result, Signal::KILL.value)
                puts "DEADLOCK"
                exit 1
              ensure
                reader.close
              end
            end

            # Re-open pipe for next iteration (child closed its end; parent closed both)
            abort "pipe failed" unless LibC.pipe(pipe_fds) == 0
          end

          stop.set(true)
          puts "ok"
          CRYSTAL

        status.success?.should be_true
        output.chomp.should eq("ok")
      end

      it "after_fork resets signal mutexes so child can use signal API after fork", tags: %w[slow] do
        status, output, _ = compile_and_run_source <<-'CRYSTAL', ["-Dpreview_mt"]
          # Reopen the modules to expose the private mutexes for testing.
          # This lets us deliberately hold them across a fork to simulate the
          # race where a worker thread holds a mutex at the moment fork fires.
          module Crystal::System::Signal
            def self.lock_for_testing : Nil
              @@mutex.lock
            end
            def self.unlock_for_testing : Nil
              @@mutex.unlock
            end
          end
          module Crystal::System::SignalChildHandler
            def self.lock_for_testing : Nil
              @@mutex.lock
            end
            def self.unlock_for_testing : Nil
              @@mutex.unlock
            end
          end

          pipe_fds = uninitialized StaticArray(Int32, 2)
          abort "pipe failed" unless LibC.pipe(pipe_fds) == 0

          # Two worker fibers each hold one of the signal mutexes while the
          # main fiber forks. Channel rendezvous ensures both locks are held
          # at the moment fork(2) is called.
          sig_held   = Channel(Nil).new
          schld_held = Channel(Nil).new
          release_sig   = Channel(Nil).new(1)
          release_schld = Channel(Nil).new(1)

          spawn(same_thread: false) do
            Crystal::System::Signal.lock_for_testing
            sig_held.send(nil)
            release_sig.receive
            Crystal::System::Signal.unlock_for_testing
          end

          spawn(same_thread: false) do
            Crystal::System::SignalChildHandler.lock_for_testing
            schld_held.send(nil)
            release_schld.receive
            Crystal::System::SignalChildHandler.unlock_for_testing
          end

          sig_held.receive
          schld_held.receive
          # Both mutexes are now held by worker threads on other OS threads.

          fork_result = uninitialized LibC::PidT
          fork_errno  = uninitialized Errno
          Process.quiesce do
            fork_result = LibC.fork
            fork_errno  = Errno.value
            nil
          end

          case fork_result
          when 0
            LibC.close(pipe_fds[0])
            Crystal::Scheduler.reinit_child
            ::Process.after_fork_child_callbacks.each(&.call)
            # Without the fix, both mutexes are still locked here (the worker
            # threads that held them no longer exist in the child). Each call
            # below will deadlock on the respective mutex.
            Signal::USR1.trap { }                              # needs Signal.@@mutex
            _ = Crystal::System::SignalChildHandler.wait(-1)  # needs SignalChildHandler.@@mutex
            byte = 42u8
            LibC.write(pipe_fds[1], pointerof(byte).as(Pointer(Void)), 1)
            LibC.close(pipe_fds[1])
            LibC._exit 0
          when -1
            LibC.close(pipe_fds[0]); LibC.close(pipe_fds[1])
            raise RuntimeError.from_os_error("fork", fork_errno)
          else
            release_sig.send(nil)
            release_schld.send(nil)
            LibC.close(pipe_fds[1])
            reader = IO::FileDescriptor.new(pipe_fds[0])
            reader.read_timeout = 5.seconds
            begin
              buf = Bytes.new(1)
              reader.read(buf)
              puts buf[0] == 42u8 ? "ok" : "FAIL"
            rescue IO::TimeoutError
              LibC.kill(fork_result, Signal::KILL.value)
              puts "DEADLOCK"
              exit 1
            ensure
              reader.close
            end
          end
          CRYSTAL

        status.success?.should be_true
        output.chomp.should eq("ok")
      end
    {% end %}
  end

  describe ".exec" do
    it "redirects STDIN and STDOUT to files", tags: %w[slow] do
      with_tempfile("crystal-exec-stdin", "crystal-exec-stdout") do |stdin_path, stdout_path|
        File.write(stdin_path, "foobar")

        status, _, _ = compile_and_run_source <<-CRYSTAL
          command = #{stdin_to_stdout_command[0].inspect}
          args = #{stdin_to_stdout_command[1].to_a} of String
          stdin_path = #{stdin_path.inspect}
          stdout_path = #{stdout_path.inspect}
          File.open(stdin_path) do |input|
            File.open(stdout_path, "w") do |output|
              Process.exec(command, args, input: input, output: output)
            end
          end
          CRYSTAL

        status.success?.should be_true
        File.read(stdout_path).chomp.should eq("foobar")
      end
    end

    it "gets error from exec" do
      expect_raises(File::NotFoundError, "Error executing process: 'foobarbaz'") do
        Process.exec("foobarbaz")
      end
    end

    it "raises if chdir doesn't exist" do
      expect_raises(File::NotFoundError, "Error while changing directory: 'doesnotexist'") do
        Process.exec(*exit_code_command(1), chdir: "doesnotexist")
      end
    end

    it "does not change directory if exec fails" do
      with_tempfile("exec_chdir") do |path|
        Dir.mkdir_p(path)
        previous_cwd = Dir.current
        expect_raises(File::NotFoundError, "Error executing process: 'doesnotexist':") do
          Process.exec("doesnotexist", chdir: path)
        end
        Dir.current.should eq previous_cwd
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
          rescue ex : RuntimeError
            puts ex.os_error
          end
        CRYSTAL

        status.success?.should be_true
        output.should eq("EPERM\n")
      end
    {% end %}
  end
end

