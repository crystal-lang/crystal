require "../../spec_helper"

describe "Code gen: debug" do
  it "runs" do
    debug %(
      (gdb) break foo
      (gdb) run
      (gdb) frame
      #0  foo () at spec:2
      (gdb) next
      (gdb) frame
      #0  foo () at spec:3
      (gdb) print x
      $1 = 1
      (gdb) next
      (gdb) print x
      $2 = 3
    ), %(
      def foo
        x = 1
        x = 3
      end
      foo
    )
  end

  it "emits local variables in methods" do
    debug %(
      (gdb) break foo
      (gdb) run
      (gdb) frame
      #0  foo () at spec:2
      (gdb) info locals
      x = 0
      y = 0
      (gdb) next
      (gdb) next
      (gdb) info locals
      x = 33
      y = 42
      (gdb) print x
      $1 = 33
      (gdb) print y
      $2 = 42
    ), %(
      def foo
        x = 33
        y = 42
        x + y
      end
      foo
    )
  end

  it "emits parameters to methods" do
    debug %(
      (gdb) break foo
      (gdb) run
      (gdb) frame
      #0  foo (x=33, y=42) at spec:1
      (gdb) info locals
      No locals.
      (gdb) info arg
      x = 33
      y = 42
      (gdb) print x
      $1 = 33
      (gdb) print y
      $2 = 42
    ), %(
      def foo(x, y)
        x + y
      end
      foo(33, 42)
    )
  end

  it "emits toplevel variables" do
    debug %(
      (gdb) run
      /SIGTRAP/
      /.* in __crystal_main \\\(\\\) at spec:3/
      (gdb) info locals
      a = 1
      b = 2
      (gdb) print a
      $1 = 1
      (gdb) print b
      $2 = 2
    ), %(
      a = 1
      b = 2
      Intrinsics.debugtrap
    )
  end
end
