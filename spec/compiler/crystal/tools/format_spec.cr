{% skip_file if flag?(:bits32) %}

require "spec"
require "compiler/crystal/formatter"
require "compiler/crystal/command/format"
require "../../../support/tempfile"

private class BuggyFormatCommand < Crystal::Command::FormatCommand
  def format(filename, source)
    raise "format command test"
  end
end

describe Crystal::Command::FormatCommand do
  it "formats stdin" do
    stdin = IO::Memory.new "if true\n1\nend"
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    format_command = Crystal::Command::FormatCommand.new(["-"], stdin: stdin, stdout: stdout, stderr: stderr)
    format_command.run
    format_command.status_code.should eq(0)
    stdout.to_s.should eq("if true\n  1\nend\n")
    stderr.to_s.should be_empty
  end

  it "formats stdin (formatted)" do
    stdin = IO::Memory.new "if true\n  1\nend\n"
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    format_command = Crystal::Command::FormatCommand.new(["-"], stdin: stdin, stdout: stdout, stderr: stderr)
    format_command.run
    format_command.status_code.should eq(0)
    stdout.to_s.should eq("if true\n  1\nend\n")
    stderr.to_s.should be_empty
  end

  it "formats stdin (syntax error)" do
    stdin = IO::Memory.new "if"
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    format_command = Crystal::Command::FormatCommand.new(["-"], stdin: stdin, stdout: stdout, stderr: stderr)
    format_command.run
    format_command.status_code.should eq(1)
    stdout.to_s.should be_empty
    stderr.to_s.should contain("syntax error in 'STDIN:1:3': unexpected token: EOF")
  end

  it "formats stdin (invalid byte sequence error)" do
    stdin = IO::Memory.new "\xfe\xff"
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    format_command = Crystal::Command::FormatCommand.new(["-"], stdin: stdin, stdout: stdout, stderr: stderr)
    format_command.run
    format_command.status_code.should eq(1)
    stdout.to_s.should be_empty
    stderr.to_s.should contain("file 'STDIN' is not a valid Crystal source file: Unexpected byte 0xff at position 1, malformed UTF-8")
  end

  it "formats stdin (bug)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    format_command = BuggyFormatCommand.new(["-"], stdin: stdin, stdout: stdout, stderr: stderr)
    format_command.run
    format_command.status_code.should eq(1)
    stdout.to_s.should be_empty
    stderr.to_s.should contain("there's a bug formatting 'STDIN', to show more information, please run:\n\n  $ crystal tool format --show-backtrace -")
  end

  it "formats stdin (bug + show-backtrace)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    format_command = BuggyFormatCommand.new(["-"], show_backtrace: true, stdin: stdin, stdout: stdout, stderr: stderr)
    format_command.run
    format_command.status_code.should eq(1)
    stdout.to_s.should be_empty
    stderr.to_s.should contain("format command test")
    stderr.to_s.should contain("couldn't format 'STDIN', please report a bug including the contents of it: https://github.com/crystal-lang/crystal/issues")
  end

  it "formats files" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("format_files") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "format.cr"), "if true\n1\nend"
        File.write File.join(path, "not_format.cr"), "if true\n  1\nend\n"

        format_command = Crystal::Command::FormatCommand.new([] of String, color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(0)
        stdout.to_s.should contain("Format #{Path[".", "format.cr"]}")
        stdout.to_s.should_not contain("Format #{Path[".", "not_format.cr"]}")
        stderr.to_s.should be_empty

        File.read(File.join(path, "format.cr")).should eq("if true\n  1\nend\n")
      end
    end
  end

  it "formats files (dir)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("format_files_dir") do |path|
      FileUtils.mkdir_p File.join(path, "dir")
      Dir.cd(path) do
        File.write File.join(path, "format.cr"), "if true\n1\nend"
        File.write File.join(path, "not_format.cr"), "if true\n  1\nend\n"
        File.write File.join(path, "dir", "format.cr"), "if true\n1\nend"
        File.write File.join(path, "dir", "not_format.cr"), "if true\n  1\nend\n"

        format_command = Crystal::Command::FormatCommand.new(["dir"], color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(0)
        stdout.to_s.should contain("Format #{Path[".", "dir", "format.cr"]}")
        stdout.to_s.should_not contain("Format #{Path[".", "dir", "not_format.cr"]}")
        stderr.to_s.should be_empty

        {stdout, stderr}.each &.clear

        format_command = Crystal::Command::FormatCommand.new([] of String, color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(0)
        stdout.to_s.should contain("Format #{Path[".", "format.cr"]}")
        stdout.to_s.should_not contain("Format #{Path[".", "not_format.cr"]}")
        stdout.to_s.should_not contain("Format #{Path[".", "dir", "format.cr"]}")
        stdout.to_s.should_not contain("Format #{Path[".", "dir", "not_format.cr"]}")
        stderr.to_s.should be_empty

        File.read(File.join(path, "format.cr")).should eq("if true\n  1\nend\n")
        File.read(File.join(path, "dir", "format.cr")).should eq("if true\n  1\nend\n")
      end
    end
  end

  it "formats files (error)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("format_files_error") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "format.cr"), "if true\n1\nend"
        File.write File.join(path, "syntax_error.cr"), "if"
        File.write File.join(path, "invalid_byte_sequence_error.cr"), "\xfe\xff"

        format_command = Crystal::Command::FormatCommand.new([] of String, color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(1)
        stdout.to_s.should contain("Format #{Path[".", "format.cr"]}")
        stderr.to_s.should contain("syntax error in '#{Path[".", "syntax_error.cr"]}:1:3': unexpected token: EOF")
        stderr.to_s.should contain("file '#{Path[".", "invalid_byte_sequence_error.cr"]}' is not a valid Crystal source file: Unexpected byte 0xff at position 1, malformed UTF-8")

        File.read(File.join(path, "format.cr")).should eq("if true\n  1\nend\n")
      end
    end
  end

  it "formats files (bug)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("format_files_bug") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "empty.cr"), ""

        format_command = BuggyFormatCommand.new([] of String, color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(1)
        stderr.to_s.should contain("there's a bug formatting '#{Path[".", "empty.cr"]}', to show more information, please run:\n\n  $ crystal tool format --show-backtrace '#{Path[".", "empty.cr"]}'")
      end
    end
  end

  it "formats files (bug + show-stacktrace)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("format_files_bug_show_stacktrace") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "empty.cr"), ""

        format_command = BuggyFormatCommand.new([] of String, show_backtrace: true, color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(1)
        stderr.to_s.should contain("format command test")
        stderr.to_s.should contain("couldn't format '#{Path[".", "empty.cr"]}', please report a bug including the contents of it: https://github.com/crystal-lang/crystal/issues")
      end
    end
  end

  it "checks files format" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("check_files_format") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "format.cr"), "if true\n1\nend"
        File.write File.join(path, "not_format.cr"), "if true\n  1\nend\n"
        File.write File.join(path, "syntax_error.cr"), "if"
        File.write File.join(path, "invalid_byte_sequence_error.cr"), "\xfe\xff"

        format_command = Crystal::Command::FormatCommand.new([] of String, check: true, color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(1)
        stdout.to_s.should be_empty
        stderr.to_s.should_not contain("not_format.cr")
        stderr.to_s.should contain("formatting '#{Path[".", "format.cr"]}' produced changes")
        stderr.to_s.should contain("syntax error in '#{Path[".", "syntax_error.cr"]}:1:3': unexpected token: EOF")
        stderr.to_s.should contain("file '#{Path[".", "invalid_byte_sequence_error.cr"]}' is not a valid Crystal source file: Unexpected byte 0xff at position 1, malformed UTF-8")
      end
    end
  end

  it "checks files format (ok)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("check_files_format_ok") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "format1.cr"), "if true\n  1\nend\n"
        File.write File.join(path, "format2.cr"), "if true\n  2\nend\n"

        format_command = Crystal::Command::FormatCommand.new([] of String, check: true, color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(0)
        stdout.to_s.should be_empty
        stderr.to_s.should be_empty
      end
    end
  end

  it "checks files format (excludes)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("check_files_format_excludes") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "format.cr"), "if true\n1\nend"
        File.write File.join(path, "not_format.cr"), "if true\n  1\nend\n"

        format_command = Crystal::Command::FormatCommand.new([] of String, check: true, excludes: ["format.cr"], color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(0)
        stdout.to_s.should be_empty
        stderr.to_s.should be_empty
      end
    end
  end

  it "checks files format (excludes + includes)" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("check_files_format_excludes_includes") do |path|
      FileUtils.mkdir_p path
      Dir.cd(path) do
        File.write File.join(path, "format.cr"), "if true\n1\nend"
        File.write File.join(path, "not_format.cr"), "if true\n  1\nend\n"

        format_command = Crystal::Command::FormatCommand.new([] of String, check: true, excludes: ["format.cr"], includes: ["format.cr"], color: false, stdin: stdin, stdout: stdout, stderr: stderr)
        format_command.run
        format_command.status_code.should eq(1)
        stdout.to_s.should be_empty
        stderr.to_s.should contain("formatting '#{Path[".", "format.cr"]}' produced changes")
      end
    end
  end
end
