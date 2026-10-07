{% skip_file if flag?(:without_interpreter) || flag?(:windows) %}

require "./spec_helper"
require "./repl_pty_spec_helper"

# These specs guard type-level instance var initializers in REPL mode.
# Initializers like `@x = 1` in a class or module body are NOT executed
# when the type is defined: they run when an instance is created. In a
# one-shot compilation the codegen knows this; the interpreter must not
# compile those statements as part of the type body either. In a generic
# type the initializer value can't even be typed before an instantiation
# (`[] of T`), so executing it runs a cleanup `raise` placeholder.

describe "REPL type-level instance var initializers" do
  it "generic class initializer is not executed when the class is defined" do
    bin = ReplPty.compiler_bin
    ReplPty.check_repl_bin!(bin)
    session = ReplPtySession.new(bin)
    begin
      session.read_until("initial prompt", "icr:1>", 30.seconds)

      session.submit(%(class GPoolSpec(T); @total = [] of T; def total; @total; end; end))
      session.read_until("class result", "=> nil", 30.seconds)
      session.output.should_not contain("can't execute")

      session.submit(%(GPoolSpec(Int32).new.total))
      session.read_until("total value", "=> []", 30.seconds)
    ensure
      session.close
    end
  end

  it "non-generic class initializer is not executed when the class is defined" do
    bin = ReplPty.compiler_bin
    ReplPty.check_repl_bin!(bin)
    session = ReplPtySession.new(bin)
    begin
      session.read_until("initial prompt", "icr:1>", 30.seconds)

      session.submit(%(class CSpec; @side_effect = (puts "b" + "oom"; 1); def x; @side_effect; end; end))
      session.read_until("class result", "=> nil", 30.seconds)
      session.output.should_not contain("boom")

      session.submit(%(CSpec.new.x))
      session.read_until("side effect happens on instantiation", "boom", 30.seconds)
    ensure
      session.close
    end
  end
end
