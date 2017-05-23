require "../../spec_helper"

describe "Code gen: exception" do
  it "codegens rescue specific leaf exception" do
    run(%(
      require "prelude"

      class Foo < Exception
      end

      def foo
        raise Foo.new
      end

      def bar(x)
        1
      end

      begin
        foo
        2
      rescue ex : Foo
        bar(ex)
      end
      )).to_i.should eq(1)
  end

  it "codegens exception handler with return" do
    run(%(
      require "prelude"

      def foo
        begin
          return 1
        ensure
          1 + 2
        end
      end

      foo
      )).to_i.should eq(1)
  end

  it "does ensure after rescue which returns (#171)" do
    run(%(
      require "prelude"

      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo
        raise "foo"
      rescue
        Global.x += 1
        return
      ensure
        Global.x += 1
      end

      foo

      Global.x
      )).to_i.should eq(2)
  end

  it "executes body if nothing raised (1)" do
    run(%(
      require "prelude"

      y = 1
      x = begin
            2
          rescue
            y = 10
          end
      x + y
      )).to_i.should eq(3)
  end

  it "executes rescue if something is raised conditionally" do
    run(%(
      require "prelude"

      y = 1
      x = 1

      x = begin
            y == 1 ? raise("Oh no!") : nil
            y = 10
          rescue
            y = 4
          end
      x + y
      )).to_i.should eq(8)
  end

  it "executes rescue if something is raised unconditionally" do
    run(%(
      require "prelude"

      y = 1
      x = 1
      x = begin
            raise "Oh no!"
            y = 10
          rescue
            y = 3
          end
      x + y
      )).to_i.should eq(6)
  end

  it "can result into union (1)" do
    run(%(
      require "prelude"

      x = begin
            1
          rescue
            2.1
          end
      x.to_i
      )).to_i.should eq(1)
  end

  it "can result into union (2)" do
    run(%(
      require "prelude"

      y = begin
            1 > 0 ? raise("Oh no!") : 0
          rescue
            2.1
          end
      y.to_i
    )).to_i.should eq(2)
  end

  it "handles nested exceptions" do
    run(%(
      require "prelude"

      a = 0
      b = begin
            begin
              raise "Oh no!"
            rescue
              a = 1
              raise "Boom!"
            end
          rescue
            2
          end

      a + b
      )).to_i.should eq(3)
  end

  it "executes ensure when no exception is raised (1)" do
    run(%(
      require "prelude"

      a = 0
      b = begin
            a = 1
          rescue
            a = 3
          ensure
            a = 10
          end
      a
      )).to_i.should eq(10)
  end

  it "executes ensure when no exception is raised (2)" do
    run(%(
      require "prelude"

      a = 0
      b = begin
            a = 1
          rescue
            a = 3
          ensure
            a = 10
          end
      b
      )).to_i.should eq(1)
  end

  it "executes ensure when exception is raised (1)" do
    run(%(
      require "prelude"

      a = 0
      b = begin
            a = 1
            raise "Oh no!"
          rescue
            a = 3
          ensure
            a = 2
          end
      a
      )).to_i.should eq(2)
  end

  it "executes ensure when exception is raised (2)" do
    run(%(
      require "prelude"

      a = 0
      b = begin
            a = 1
            raise "Oh no!"
          rescue
            a = 3
          ensure
            a = 2
          end
      b
      )).to_i.should eq(3)
  end

  it "executes ensure when exception is unhandled (1)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end

      a = 0
      b = begin
            begin
              a = 1
              raise "Oh no!"
            rescue Ex1
              a = 2
            ensure
              a = 3
            end
          rescue
            4
          end
      a
      )).to_i.should eq(3)
  end

  it "executes ensure when exception is unhandled (2)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end

      a = 0
      b = begin
            begin
              a = 1
              raise "Oh no!"
            rescue Ex1
              a = 2
            ensure
              a = 3
            end
          rescue
            4
          end
      b
      )).to_i.should eq(4)
  end

  it "ensure without rescue" do
    run(%(
      require "prelude"

      a = 0
      begin
        begin
          raise "Oh no!"
        ensure
          a = 1
        end
      rescue
      end

      a
      )).to_i.should eq(1)
  end

  it "executes ensure when the main block returns" do
    run(%(
      require "prelude"

      struct Nil; def to_i; 0; end; end

      def foo(x)
        begin
          return 0 if 1 == 1
        ensure
          x.value = 1
        end
      end

      x = 0
      foo(pointerof(x)).to_i
      )).to_i.should eq(0)
  end

  it "executes ensure when the main block returns" do
    run(%(
      require "prelude"

      def foo(x)
        begin
          return 0 if 1 == 1
        ensure
          x.value = 1
        end
      end

      x = 0
      foo(pointerof(x))
      x
      )).to_i.should eq(1)
  end

  it "executes ensure when the main block yields and returns" do
    run(%(
      require "prelude"

      def foo2(x)
        begin
          yield
        ensure
          x.value = 1
        end
      end

      def bar2(y)
        foo2(y) do
          return if 1 == 1
        end
      end

      x = 0
      bar2(pointerof(x))
      x
      )).to_i.should eq(1)
  end

  it "rescues with type" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end
      class Ex2 < Exception; end

      a = begin
            raise Ex2.new
          rescue Ex1
            1
          rescue Ex2
            2
          end

      a
      )).to_i.should eq(2)
  end

  it "rescues with types defaults to generic rescue" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end
      class Ex2 < Exception; end

      a = begin
            raise "Oh no!"
          rescue Ex1
            1
          rescue Ex2
            2
          rescue
            3
          end

      a
      )).to_i.should eq(3)
  end

  it "handles exception in outer block (1)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end
      class Ex2 < Exception; end

      p = 0
      x = begin
            begin
              raise Ex1.new
            rescue Ex2
              p = 1
              1
            end
          rescue
            2
          end

      x
      )).to_i.should eq(2)
  end

  it "handles exception in outer block (2)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end
      class Ex2 < Exception; end

      p = 0
      x = begin
            begin
              raise Ex1.new
            rescue Ex2
              p = 1
              1
            end
          rescue
            2
          end

      p
      )).to_i.should eq(0)
  end

  it "handles subclass" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end
      class Ex2 < Exception; end
      class Ex3 < Ex1; end

      x = 0
      begin
        raise Ex3.new
      rescue Ex1
        x = 1
      end
      x
      )).to_i.should eq(1)
  end

  it "handle multiple exception types (1)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end
      class Ex2 < Exception; end

      x = 0
      begin
        raise Ex2.new
      rescue Ex1 | Ex2
        x = 1
      end
      x
      )).to_i.should eq(1)
  end

  it "handle multiple exception types (2)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end
      class Ex2 < Exception; end

      x = 0
      begin
        raise Ex1.new
      rescue Ex1 | Ex2
        x = 1
      end
      x
      )).to_i.should eq(1)
  end

  it "receives exception object" do
    run(%(
      require "prelude"

      class Ex1 < Exception
        def to_s(io)
          io << "Ex1"
        end
      end

      x = ""
      begin
        raise Ex1.new
      rescue ex
        x = ex.to_s
      end

      x
      )).to_string.should eq("Ex1")
  end

  it "executes else if no exception is raised (1)" do
    run(%(
      require "prelude"

      x = 1
      y = begin
          rescue ex
            x = 2
          else
            x = 3
          end
      x
      )).to_i.should eq(3)
  end

  it "executes else if no exception is raised (2)" do
    run(%(
      require "prelude"

      x = 1
      y = begin
          rescue ex
            x = 2
          else
            x = 3
          end
      y
      )).to_i.should eq(3)
  end

  it "doesn't execute else if exception is raised (1)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end

      x = 1
      y = begin
            raise Ex1.new
          rescue ex
            x = 2
          else
            x = 3
          end
      x
      )).to_i.should eq(2)
  end

  it "doesn't execute else if exception is raised (2)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end

      x = 1
      y = begin
            raise Ex1.new
          rescue ex
            x = 2
          else
            x = 3
          end
      y
      )).to_i.should eq(2)
  end

  it "doesn't execute else if exception is raised conditionally (1)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end

      x = 1
      y = begin
            raise Ex1.new if 1 == 1
          rescue ex
            x = 2
          else
            x = 3
          end
      x
      )).to_i.should eq(2)
  end

  it "doesn't execute else if exception is raised conditionally (2)" do
    run(%(
      require "prelude"

      class Ex1 < Exception; end

      x = 1
      y = begin
            raise Ex1.new if 1 == 1
          rescue ex
            x = 2
          else
            x = 3
          end
      y
      )).to_i.should eq(2)
  end

  it "handle exception raised by proc literal" do
    run(%(
      require "prelude"

      x = 0
      f = -> { raise "Foo" if 1 == 1 }
      begin
        f.call
      rescue
        x = 1
      end
      x
      )).to_i.should eq(1)
  end

  it "codegens issue #118 (1)" do
    codegen(%(
      require "prelude"

      begin
        raise "hey"
        n = 3
      ensure
        p n
      end
      ))
  end

  it "codegens issue #118 (2)" do
    codegen(%(
      require "prelude"

      n = nil
      begin
        raise "hey"
        n = 3
      ensure
        p n
      end
      ))
  end

  it "captures exception thrown from proc" do
    run(%(
      require "prelude"

      def foo
        ->{ raise "OH NO" }.call
      end

      a = 1
      begin
        foo
      rescue
        a = 2
      end
      a
      )).to_i.should eq(2)
  end

  it "uses exception after rescue" do
    run(%(
      require "prelude"

      begin
        raise "OH NO"
      rescue ex
      end
      ex.not_nil!.message
      )).to_string.should eq("OH NO")
  end

  it "doesn't codegen duplicated ensure if unreachable (#709)" do
    codegen(%(
      require "prelude"

      class Foo
        def initialize
          exit if 1 == 2
        end
      end

      begin
        begin
          while true
          end
        ensure
          Foo.new.object_id
        end
      ensure
      end
      ))
  end

  it "executes ensure when raising inside rescue" do
    run(%(
      require "prelude"

      a = 1

      begin
        begin
          raise "OH NO"
        rescue
          raise "LALA"
        ensure
          a = 2
        end
      rescue
      end

      a
      )).to_i.should eq(2)
  end

  it "executes ensure of break inside while inside body" do
    run(%(
      require "prelude"

      a = 0
      while true
        begin
          break
        ensure
          a = 123
        end
      end
      a
      )).to_i.should eq(123)
  end

  it "executes ensure of break inside while inside body with nested handlers" do
    run(%(
      require "prelude"

      a = 0
      b = 0
      begin
        while true
          begin
            break
          ensure
            a += 1
          end
        end
        b = a
      ensure
        a += 1
      end
      b
      )).to_i.should eq(1)
  end

  it "executes ensure of break inside while inside body with block" do
    run(%(
      require "prelude"

      class Global
        @@a = 0
        @@b = 0

        def self.a=(@@a)
        end

        def self.a
          @@a
        end

        def self.b=(@@b)
        end

        def self.b
          @@b
        end
      end

      def bar
        begin
          yield
        ensure
          Global.a = 1
        end
      end

      bar do
        while true
          break
        end
        Global.b = Global.a
      end

      Global.b
      )).to_i.should eq(0)
  end

  it "executes ensure of break inside while inside rescue" do
    run(%(
      require "prelude"

      a = 0
      while true
        begin
          raise "OH NO"
        rescue
          break
        ensure
          a = 123
        end
      end
      a
      )).to_i.should eq(123)
  end

  it "executes ensure of break inside while inside else" do
    run(%(
      require "prelude"

      a = 0
      while true
        begin
        rescue
        else
          break
        ensure
          a = 123
        end
      end
      a
      )).to_i.should eq(123)
  end

  it "executes ensure of next inside while inside body" do
    run(%(
      require "prelude"

      a = 0
      continue = true
      while continue
        continue = false
        begin
          next
        ensure
          a = 123
        end
      end
      a
      )).to_i.should eq(123)
  end

  it "executes return inside rescue, executing ensure" do
    run(%(
      require "prelude"

      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo
        begin
          begin
            raise "foo"
          rescue
            Global.x += 1
            return
          end
        ensure
          Global.x += 1
        end
      end

      foo

      Global.x
      )).to_i.should eq(2)
  end

  it "executes ensure from return until target" do
    run(%(
      require "prelude"

      def foo
        yield
        return
      end

      a = 0

      begin
        foo {}
      ensure
        a += 1
      end

      a
      )).to_i.should eq(1)
  end

  it "executes ensure from return until target" do
    run(%(
      require "prelude"

      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo
        begin
          yield
        ensure
          Global.x += 1
        end
      end

      def bar
        begin
          foo do
            return
          end
        ensure
          Global.x += 1
        end
      end

      bar

      Global.x
      )).to_i.should eq(2)
  end

  it "executes ensure of next inside block" do
    run(%(
      require "prelude"

      def foo
        yield
      end

      a = 0
      b = 0

      begin
        foo do
          begin
            next
          ensure
            a += 1
          end
        end
        b = a
      ensure
        a += 1
      end

      b
      )).to_i.should eq(1)
  end

  it "executes ensure of next inside block" do
    run(%(
      require "prelude"

      class Global
        @@a = 0
        @@b = 0

        def self.a=(@@a)
        end

        def self.a
          @@a
        end

        def self.b=(@@b)
        end

        def self.b
          @@b
        end
      end

      def foo
        begin
          yield
          Global.b = Global.a
        ensure
          Global.a += 1
        end
      end

      begin
        foo do
          begin
            next
          ensure
            Global.a += 1
          end
        end
      ensure
        Global.a += 1
      end

      Global.b
      )).to_i.should eq(1)
  end

  it "executes ensure of break inside block" do
    run(%(
      require "prelude"

      def foo
        yield
      end

      a = 0
      b = 0

      begin
        foo do
          begin
            break
          ensure
            a += 1
          end
        end
        b = a
      ensure
        a += 1
      end

      b
      )).to_i.should eq(1)
  end

  it "executes ensure of calling method when doing break inside block (#1233)" do
    run(%(
      require "prelude"

      class Global
        @@x = 0

        def self.x=(@@x)
        end

        def self.x
          @@x
        end
      end

      def foo
        yield
      ensure
        Global.x = 123
      end

      foo do
        break
      end

      Global.x
      )).to_i.should eq(123)
  end

  it "propagates raise status (#2074)" do
    run(%(
      require "prelude"

      class Foo
        @var : Var?

        def method1
          method2
        end

        def method2
          if var = @var
            var.method3
          end
        end

        def var=(@var)
        end
      end

      class Var
        def method3
          raise "OH NO"
        end
      end

      # method1 isn't marked as raise because @var's type isn't known yet
      Foo.new.method1

      foo = Foo.new
      # This causes method2 to recompute, but method1 doesn't get notified
      # that it might now raise
      foo.var = Var.new
      a = 1
      begin
        foo.method1
      rescue ex
        a = 2
      end
      a
      )).to_i.should eq(2)
  end

  it "doesn't crash on #1988" do
    run(%(
      require "prelude"

      begin
        x = 42
      rescue
      end

      if x.is_a?(Int32)
        x
      else
        21
      end
      )).to_i.should eq(42)
  end

  it "runs #2441" do
    run(%(
      require "prelude"

      while true
        begin
          raise "foo"
        rescue ex
          break
        end
      end

      ex.not_nil!.message.to_s
      )).to_string.should eq("foo")
  end

  it "can rescue TypeCastError (#2607)" do
    run(%(
      require "prelude"

      begin
        (1 || "foo").as(String)
        2
      rescue e : TypeCastError
        42
      rescue e : Exception
        0
      end
      )).to_i.should eq(42)
  end

  it "can use argument in rescue (#2844)" do
    run(%(
      require "prelude"

      def foo(exe)
        begin
          raise exe
        rescue exe
          exe
        end
      end

      ex = Exception.new("foo")
      ex = foo(ex)
      ex.message.not_nil!
      )).to_string.should eq("foo")
  end

  it "can use argument in rescue, with a different type (1) (#2844)" do
    run(%(
      require "prelude"

      def foo(exe)
        begin
          raise Exception.new("foo") if 1 == 1
          exe
        rescue exe
          exe
        end
      end

      ex = foo(1).as(Exception)
      ex.message.not_nil!
      )).to_string.should eq("foo")
  end

  it "can use argument in rescue, with a different type (2) (#2844)" do
    run(%(
      require "prelude"

      def foo(exe)
        begin
          raise Exception.new("foo") if 1 == 2
          exe
        rescue exe
          exe
        end
      end

      foo(10).as(Int32)
      )).to_i.should eq(10)
  end

  it "runs NoReturn ensure (#3082)" do
    run(%(
      require "prelude"

      begin
        print 1
        raise "OH NO"
        print 0
      rescue
        print 2
      ensure
        print 3
        exit
        print 4
      end
      print 5
      )).to_i.should eq(123)
  end

  it "catches exception thrown by as inside method (#4030)" do
    run(%(
      require "prelude"

      def foo
        a = 1 || ""
        a.as(String)
      end

      begin
        foo
        "bad"
      rescue ex : TypeCastError
        "good"
      end
      )).to_string.should eq("good")
  end
end
