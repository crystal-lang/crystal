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

      $x = 0

      def foo
        raise "foo"
      rescue
        $x += 1
        return
      ensure
        $x += 1
      end

      foo

      $x
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
            y == 1 ? raise "Oh no!" : nil
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
            1 > 0 ? raise "Oh no!" : 0
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

  it "handle exception raised by fun literal" do
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
    build(%(
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
    build(%(
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
end
