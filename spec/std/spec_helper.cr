require "spec"
require "../support/tempfile"
require "../support/fibers"

def datapath(*components)
  File.join("spec", "std", "data", *components)
end

{% if flag?(:win32) %}
  def pending_win32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending("#{description} [win32]", file, line, end_line)
  end

  def pending_win32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    pending_win32(describe, file, line, end_line) { }
  end
{% else %}
  def pending_win32(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    it(description, file, line, end_line, &block)
  end

  def pending_win32(*, describe, file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
    describe(describe, file, line, end_line, &block)
  end
{% end %}

private class Witness
  @checked = false

  def check
    @checked = true
  end

  def checked?
    @checked
  end
end

def spawn_and_wait(before : Proc(_), file = __FILE__, line = __LINE__, &block)
  spawn_and_check(before, file, line) do |w|
    block.call
    w.check
  end
end

def spawn_and_check(before : Proc(_), file = __FILE__, line = __LINE__, &block : Witness -> _)
  done = Channel(Exception?).new
  w = Witness.new

  # State of the "before" filter:
  # 0 - not started
  # 1 - started
  # 2 - completed
  x = Atomic(Int32).new(0)

  before_fiber = spawn do
    x.set(1)

    # This is a workaround to ensure the "before" fiber
    # is unscheduled. Otherwise it might stay alive running the event loop
    spawn(same_thread: true) do
      while x.get != 2
        Fiber.yield
      end
    end

    before.call
    x.set(2)
  end

  spawn do
    begin
      # Wait until the "before" fiber starts
      while x.get == 0
        Fiber.yield
      end

      # Now wait until the "before" fiber is blocked
      wait_until_blocked before_fiber
      block.call w

      done.send nil
    rescue e
      done.send e
    end
  end

  ex = done.receive
  raise ex if ex
  unless w.checked?
    fail "Failed to stress expected path", file, line
  end
end
