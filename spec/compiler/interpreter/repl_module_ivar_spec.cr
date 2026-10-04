{% skip_file if flag?(:without_interpreter) %}

require "./spec_helper"
require "./repl_pty_spec_helper"

# These specs guard instance variable initializers declared in modules
# across REPL expressions. With the interpreter's incremental (per
# expression) semantic, a module's `@x = ...` initializers are processed
# as soon as the module is defined — possibly before a class includes
# the module in a later expression. The including class must still get
# the initializers (types AND runtime values), like a one-shot compiled
# program does (there, the initializer pass runs after all includes and
# propagates to every including type).

describe "REPL module instance var initializers" do
  it "class including a module defined in an earlier expression" do
    session = ReplPtySession.new(ReplPty.compiler_bin)
    begin
      session.read_until("initial prompt", "icr:1>", 30.seconds)

      session.submit(%(module M123; @x = false; def x; @x; end; end))
      session.read_until("module result", "=> nil", 30.seconds)

      session.submit(%(class A123; include M123; def initialize; end; end))
      session.read_until("class result", "=> nil", 30.seconds)

      session.submit(%(A123.new.x))
      session.read_until("ivar value", "=> false", 30.seconds)
      session.output.should_not contain("can't infer")
    ensure
      session.close
    end
  end

  it "class including a prelude module (IO::Buffered) in a later expression" do
    session = ReplPtySession.new(ReplPty.compiler_bin)
    begin
      session.read_until("initial prompt", "icr:1>", 30.seconds)

      session.submit(%(class B123; include IO::Buffered; def initialize; end) \
                     %(; def unbuffered_read(slice : Bytes); 0; end) \
                     %(; def unbuffered_write(slice : Bytes); end) \
                     %(; def unbuffered_flush; end; def unbuffered_rewind; end; def unbuffered_close; end; end))
      session.read_until("class result", "=> nil", 30.seconds)

      session.submit(%(B123.new.sync?))
      session.read_until("sync? value", "=> false", 30.seconds)
      session.output.should_not contain("can't infer")
      session.output.should_not contain("must return Bool")
    ensure
      session.close
    end
  end
end
