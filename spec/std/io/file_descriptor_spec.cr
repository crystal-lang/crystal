require "../spec_helper"
require "../../support/finalize"

class IO::FileDescriptor
  include FinalizeCounter
end

private def shell_command(command)
  {% if flag?(:win32) %}
    "cmd.exe /c #{Process.quote(command)}"
  {% else %}
    "/bin/sh -c #{Process.quote(command)}"
  {% end %}
end

describe IO::FileDescriptor do
  it "reopen STDIN with the right mode" do
    code = %q(puts "#{STDIN.blocking} #{STDIN.info.type}")
    compile_source(code) do |binpath|
      `#{shell_command %(#{Process.quote(binpath)} < #{Process.quote(binpath)})}`.chomp.should eq("true File")
      `#{shell_command %(echo "" | #{Process.quote(binpath)})}`.chomp.should eq("#{ {{ flag?(:win32) }} } Pipe")
    end
  end

  it "closes on finalize" do
    pipes = [] of IO::FileDescriptor
    assert_finalizes("fd") do
      a, b = IO.pipe
      pipes << b
      a
    end

    expect_raises(IO::Error) do
      pipes.each do |p|
        p.puts "123"
      end
    end
  end

  it "does not close if close_on_finalize is false" do
    pipes = [] of IO::FileDescriptor
    assert_finalizes("fd") do
      a, b = IO.pipe
      a.close_on_finalize = false
      pipes << b
      a
    end

    pipes.each do |p|
      p.puts "123"
    end
  end
end
