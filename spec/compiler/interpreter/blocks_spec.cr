{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "blocks" do
    it "interprets simplest block" do
      interpret(<<-CRYSTAL).should eq(1)
        def foo
          yield
        end

        a = 0
        foo do
          a += 1
        end
        a
      CRYSTAL
    end

    it "interprets block with multiple yields" do
      interpret(<<-CRYSTAL).should eq(2)
        def foo
          yield
          yield
        end

        a = 0
        foo do
          a += 1
        end
        a
      CRYSTAL
    end

    it "interprets yield return value" do
      interpret(<<-CRYSTAL).should eq(1)
        def foo
          yield
        end

        z = foo do
          1
        end
        z
      CRYSTAL
    end

    it "interprets yield inside another block" do
      interpret(<<-CRYSTAL).should eq(1)
        def foo
          bar do
            yield
          end
        end

        def bar
          yield
        end

        a = 0
        foo do
          a += 1
        end
        a
      CRYSTAL
    end

    it "interprets yield inside def with arguments" do
      interpret(<<-CRYSTAL).should eq(18)
        def foo(x)
          a = yield
          a + x
        end

        a = foo(10) do
          8
        end
        a
      CRYSTAL
    end

    it "interprets yield expression" do
      interpret(<<-CRYSTAL).should eq(2)
        def foo
          yield 1
        end

        a = 1
        foo do |x|
          a += x
        end
        a
      CRYSTAL
    end

    it "interprets yield expressions" do
      interpret(<<-CRYSTAL).should eq(2 + 2*3 + 4*5)
        def foo
          yield 3, 4, 5
        end

        a = 2
        foo do |x, y, z|
          a += a * x + y * z
        end
        a
      CRYSTAL
    end

    it "discards yield expression" do
      interpret(<<-CRYSTAL).should eq(3)
        def foo
          yield 1
        end

        a = 2
        foo do
          a = 3
        end
        a
      CRYSTAL
    end

    it "yields different values to form a union" do
      interpret(<<-CRYSTAL).should eq(5)
        def foo
          yield 1
          yield 'a'
        end

        a = 2
        foo do |x|
          a +=
            case x
            in Int32
              1
            in Char
              2
            end
        end
        a
      CRYSTAL
    end

    it "returns from block" do
      interpret(<<-CRYSTAL).should eq(42)
        def foo
          baz do
            yield
          end
        end

        def baz
          yield
        end

        def bar
          foo do
            foo do
              return 42
            end
          end

          1
        end

        bar
      CRYSTAL
    end

    it "interprets next inside block" do
      interpret(<<-CRYSTAL).should eq(10)
        def foo
          yield
        end

        a = 0
        foo do
          if a == 0
            next 10
          end
          20
        end
      CRYSTAL
    end

    it "interprets next inside block (union, through next)" do
      interpret(<<-CRYSTAL).should eq(10)
        def foo
          yield
        end

        a = 0
        x = foo do
          if a == 0
            next 10
          end
          'a'
        end

        if x.is_a?(Int32)
          x
        else
          20
        end
      CRYSTAL
    end

    it "interprets next inside block (union, through normal exit)" do
      interpret(<<-CRYSTAL).should eq('a')
        def foo
          yield
        end

        a = 0
        x = foo do
          if a == 1
            next 10
          end
          'a'
        end

        if x.is_a?(Char)
          x
        else
          'b'
        end
      CRYSTAL
    end

    it "interprets break inside block" do
      interpret(<<-CRYSTAL).should eq(20)
        def baz
          yield
        end

        def foo
          baz do
            w = yield
            w + 100
          end
        end

        a = 0
        foo do
          if a == 0
            break 20
          end
          20
        end
      CRYSTAL
    end

    it "interprets break inside block (union, through break)" do
      interpret(<<-CRYSTAL).should eq(20)
        def foo
          yield
          'a'
        end

        a = 0
        w = foo do
          if a == 0
            break 20
          end
          20
        end
        if w.is_a?(Int32)
          w
        else
          30
        end
      CRYSTAL
    end

    it "interprets break inside block (union, through normal flow)" do
      interpret(<<-CRYSTAL).should eq('a')
        def foo
          yield
          'a'
        end

        a = 0
        w = foo do
          if a == 1
            break 20
          end
          20
        end
        if w.is_a?(Char)
          w
        else
          'b'
        end
      CRYSTAL
    end

    it "interprets break inside block (union, through return)" do
      interpret(<<-CRYSTAL).should eq('a')
        def foo
          yield
          return 'a'
        end

        a = 0
        w = foo do
          if a == 1
            break 20
          end
          20
        end
        if w.is_a?(Char)
          w
        else
          'b'
        end
      CRYSTAL
    end

    it "interprets block with args that conflict with a local var" do
      interpret(<<-CRYSTAL).should eq(201)
        def foo
          yield 1
        end

        a = 200
        x = 0

        foo do |a|
          x += a
        end

        x + a
      CRYSTAL
    end

    it "interprets block with args that conflict with a local var" do
      interpret(<<-CRYSTAL).should eq(216)
        def foo
          yield 1
        end

        def bar
          yield 2
        end

        def baz
          yield 3, 4, 5
        end

        # a: 0, 8
        a = 200

        # x: 8, 16
        x = 0

        # a: 16, 24
        foo do |a|
          x += a

          # a: 24, 32
          bar do |a|
            x += a
          end

          # a: 24, 32
          # b: 32, 40
          # c: 40, 48
          baz do |a, b, c|
            x += a
            x += b
            x += c
          end

          x += a
        end
        x + a
      CRYSTAL
    end

    it "clears block local variables when calling block" do
      interpret(<<-CRYSTAL).should eq(20)
        def foo
          yield 1
        end

        def bar
          a = 1

          foo do |b|
            x = 1
          end

          foo do |b|
            if a == 0 || b == 0
              x = 10
            end

            return x
          end
        end

        z = bar
        if z.is_a?(Nil)
          20
        else
          z
        end
        CRYSTAL
    end

    it "clears block local variables when calling block (2)" do
      interpret(<<-CRYSTAL).should eq(20)
        def foo
          yield
        end

        a = 0

        foo do
          x = 1
        end

        foo do
          if 1 == 2
            x = 1
          end
          a = x
        end

        if a
          a
        else
          20
        end
        CRYSTAL
    end

    it "captures non-closure block" do
      interpret(<<-CRYSTAL).should eq(42)
        def capture(&block : Int32 -> Int32)
          block
        end

        # This variable is needed in the test because it's also
        # part of the block, even though it's not closured (it's in node.def.vars)
        a = 100
        b = capture { |x| x + 1 }
        b.call(41)
      CRYSTAL
    end

    it "casts yield expression to block var type (not block arg type)" do
      interpret(<<-CRYSTAL).should eq(42)
        def foo
          yield 42
        end

        def bar
          foo do |x|
            yield x
            x = nil
          end
        end

        a = 0
        bar { |z| a = z }
        a
      CRYSTAL
    end

    it "interprets with ... yield" do
      interpret(<<-CRYSTAL).should eq(31)
        struct Int32
          def plus(x : Int32)
            self + x
          end
        end

        def foo
          with 10 yield 20
        end

        foo do |x|
          1 + (plus x)
        end
      CRYSTAL
    end

    it "interprets with ... yield with struct" do
      interpret(<<-CRYSTAL).should eq(2)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        def foo
          with Foo.new yield
        end

        foo do
          inc
          x
        end
      CRYSTAL
    end

    it "interprets with ... yield with extra arguments (#12296)" do
      interpret(<<-CRYSTAL).should eq(1)
        class Object
          def itself
            self
          end
        end

        def build
          with 1 yield 2
        end

        build do |t|
          itself
        end
      CRYSTAL
    end

    it "counts with ... yield scope in block args bytesize (#12316)" do
      interpret(<<-CRYSTAL).should eq(42)
        class Object
          def itself
            self
          end
        end

        def foo
          bar(21, with 10 yield 8)
        end

        def bar(x, y)
          x &* y
        end

        foo do |x|
          itself &- x
        end
      CRYSTAL
    end

    it "interprets yield with splat (1)" do
      interpret(<<-CRYSTAL).should eq((2 - 3) * 4)
        def foo
          t = {2, 3, 4}
          yield *t
        end

        a = 0
        foo do |x1, x2, x3|
          a = (x1 - x2) * x3
        end
        a
      CRYSTAL
    end

    it "interprets yield with splat (2)" do
      interpret(<<-CRYSTAL).should eq((((1 - 2) * 3) - 4) * 5)
        def foo
          t = {2, 3, 4}
          yield 1, *t, 5
        end

        a = 0
        foo do |x1, x2, x3, x4, x5|
          a = (((x1 - x2) * x3) - x4) * x5
        end
        a
      CRYSTAL
    end

    it "interprets yield with splat, less block arguments" do
      interpret(<<-CRYSTAL).should eq(2 - 3)
        def foo
          t = {2, 3, 4}
          yield *t
        end

        a = 0
        foo do |x1, x2|
          a = x1 - x2
        end
        a
      CRYSTAL
    end

    it "interprets block with splat" do
      interpret(<<-CRYSTAL).should eq((((1 - 2) * 3) - 4) * 5)
        def foo
          yield 1, 2, 3, 4, 5
        end

        a = 0
        foo do |x1, *x, x5|
          a = (((x1 - x[0]) * x[1]) - x[2]) * x5
        end
        a
      CRYSTAL
    end

    it "interprets yield with splat, block with splat" do
      interpret(<<-CRYSTAL).should eq((((1 - 2) * 3) - 4) * 5)
        def foo
          t = {1, 2, 3}
          yield *t, 4, 5
        end

        a = 0
        foo do |x1, *x, x5|
          a = (((x1 - x[0]) * x[1]) - x[2]) * x5
        end
        a
      CRYSTAL
    end

    it "interprets yield with splat, block with splat (#12227)" do
      interpret(<<-CRYSTAL).should eq(1)
        def foo
          yield *{ {3, 2} }
        end

        foo do |x, y|
          x &- y
        end
      CRYSTAL
    end

    it "considers block arg without type as having NoReturn type (#12270)" do
      interpret(<<-CRYSTAL).should eq(42)
        def bar
          if ptr = nil
            yield ptr
          else
            42
          end
        end

        def foo
          bar do |obj|
            obj
          end
        end

        foo
      CRYSTAL
    end

    it "considers block arg without type as having NoReturn type (2) (#12270)" do
      interpret(<<-CRYSTAL).should eq(42)
        def bar
          if ptr = nil
            yield ptr
          else
            42
          end
        end

        def foo
          bar do |obj|
            return obj
          end
        end

        foo
      CRYSTAL
    end

    it "caches method with captured block (#12276)" do
      interpret(<<-CRYSTAL).should eq(42)
        def execute(x, &block : -> Int32)
          if x
            execute(false) do
              block.call
            end
          else
            yield
          end
        end

        execute(true) do
          42
        end
      CRYSTAL
    end
  end
end
