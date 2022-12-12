require "../spec_helper"
require "../../support/finalize"

class IO::FileDescriptor
  include FinalizeCounter
end

describe IO::FileDescriptor do
  pending_win32 "reopen STDIN with the right mode" do
    code = %q(puts "#{STDIN.blocking} #{STDIN.info.type}")
    compile_source(code) do |binpath|
      `#{Process.quote(binpath)} < #{Process.quote(binpath)}`.chomp.should eq("true File")
      `echo "" | #{Process.quote(binpath)}`.chomp.should eq("false Pipe")
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
