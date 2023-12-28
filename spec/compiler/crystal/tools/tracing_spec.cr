require "spec"
require "compiler/crystal/tools/tracing"
require "../../../support/tempfile"

describe Crystal::Tracing::StatsCommand do
  it "parses stdin" do
    stdin = IO::Memory.new <<-TRACE
    gc malloc d=0.000023724 thread=7f0ea62bd740 size=16
    gc malloc d=0.000009074 thread=7f0ea62bd740 size=4 atomic=1
    gc malloc d=0.000000128 thread=7f0ea62bd740 size=144
    sched spawn t=102125.792579486 thread=7f0ea62bd740 fiber=7f0ea6299f00
    sched enqueue d=0.000101572 thread=7f0ea62bd740 fiber=7f0ea6299e60 [main] fiber=7f0ea6299f00
    gc malloc d=0.000000222 thread=7f0ea62bd740 size=24
    gc collect d=0.000079489 thread=7f0ea62bd740
    gc heap_resize t=102125.791993928 thread=7f0ea62bd740 size=131072
    TRACE
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Crystal::Tracing::StatsCommand.new("-", stdin: stdin, stdout: stdout, stderr: stderr).run
    output = stdout.to_s
    output.should contain("gc:malloc events=4 durations=")
    output.should contain("gc:collect events=1 durations=")
    output.should contain("gc:heap_resize events=1")
    output.should contain("sched:spawn events=1")
    output.should contain("sched:enqueue events=1 durations=")
    stderr.to_s.should be_empty
  end

  it "--fast" do
    stdin = IO::Memory.new <<-TRACE
    gc malloc d=0.000023724 thread=7f0ea62bd740 size=16
    gc malloc d=0.000009074 thread=7f0ea62bd740 size=4 atomic=1
    gc malloc d=0.000000128 thread=7f0ea62bd740 size=144
    sched spawn t=102125.792579486 thread=7f0ea62bd740 fiber=7f0ea6299f00
    sched enqueue d=0.000101572 thread=7f0ea62bd740 fiber=7f0ea6299e60 [main] fiber=7f0ea6299f00
    gc malloc d=0.000000222 thread=7f0ea62bd740 size=24
    gc collect d=0.000079489 thread=7f0ea62bd740
    gc heap_resize t=102125.791993928 thread=7f0ea62bd740 size=131072
    TRACE
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Crystal::Tracing::StatsCommand.new("-", fast: true, stdin: stdin, stdout: stdout, stderr: stderr).run
    output = stdout.to_s
    output.should contain("gc:malloc events=4 duration=")
    output.should contain("gc:collect events=1 duration=")
    output.should contain("gc:heap_resize events=1")
    output.should contain("sched:spawn events=1")
    output.should contain("sched:enqueue events=1 duration=")
    stderr.to_s.should be_empty
  end

  it "parses file" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("trace.log") do |path|
      File.write path, <<-TRACE
      gc malloc d=0.000023724 thread=7f0ea62bd740 size=16
      gc malloc d=0.000009074 thread=7f0ea62bd740 size=4 atomic=1
      gc malloc d=0.000000222 thread=7f0ea62bd740 size=24
      gc collect d=0.000079489 thread=7f0ea62bd740
      TRACE

      Crystal::Tracing::StatsCommand.new(path, stdin: stdin, stdout: stdout, stderr: stderr).run
      output = stdout.to_s
      output.should contain("gc:malloc events=3 durations=")
      output.should contain("gc:collect events=1 durations=")
      stderr.to_s.should be_empty
    end
  end

  it "warns about invalid traces" do
    stdin = IO::Memory.new ""
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    with_tempfile("trace.log") do |path|
      File.write path, <<-TRACE
      Using compiled compiler at .build/crystal
      gc malloc d=0.000023724 thread=7f0ea62bd740 size=16
      TRACE

      Crystal::Tracing::StatsCommand.new(path, stdin: stdin, stdout: stdout, stderr: stderr).run
      stdout.to_s.should contain("gc:malloc events=1 durations=")
      stderr.to_s.should contain("WARN: invalid trace 'Using compiled compiler at .build/crystal'")
    end
  end

  it "skips invalid traces when parsing stdin" do
    stdin = IO::Memory.new <<-TRACE
      Using compiled compiler at .build/crystal
      gc malloc d=0.000023724 thread=7f0ea62bd740 size=16
      TRACE
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    Crystal::Tracing::StatsCommand.new("-", stdin: stdin, stdout: stdout, stderr: stderr).run
    stdout.to_s.should contain("gc:malloc events=1 durations=")
    stderr.to_s.should be_empty
  end
end
