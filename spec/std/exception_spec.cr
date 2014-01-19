#!/usr/bin/env bin/crystal --run
require "spec"

describe "Exception" do
  it "executes body if nothing raised" do
    y = 1
    x = begin
          1
        rescue
          y = 2
        end
    x.should eq(1)
    y.should eq(1)
  end

  it "executes rescue if something is raised conditionally" do
    y = 1
    x = 1
    x = begin
          y == 1 ? raise "Oh no!" : nil
          y = 2
        rescue
          y = 3
        end
    x.should eq(3)
    y.should eq(3)
  end

  it "executes rescue if something is raised unconditionally" do
    y = 1
    x = 1
    x = begin
          raise "Oh no!"
          y = 2
        rescue
          y = 3
        end
    x.should eq(3)
    y.should eq(3)
  end

  it "can result into union" do
    x = begin
      1
    rescue
      1.1
    end

    x.should eq(1)

    y = begin
      1 > 0 ? raise "Oh no!" : 0
    rescue
      1.1
    end

    y.should eq(1.1)
  end

  it "handles nested exceptions" do
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

    a.should eq(1)
    b.should eq(2)
  end

  it "executes ensure when no exception is raised" do
    a = 0
    b = begin
          a = 1
        rescue
          a = 3
        ensure
          a = 2
        end
    a.should eq(2)
    b.should eq(1)
  end

  it "executes ensure when exception is raised" do
    a = 0
    b = begin
          a = 1
          raise "Oh no!"
        rescue
          a = 3
        ensure
          a = 2
        end
    a.should eq(2)
    b.should eq(3)
  end

  class Ex1 < Exception
    def to_s
      "Ex1"
    end
  end

  class Ex2 < Exception
  end

  class Ex3 < Ex1
  end

  it "executes ensure when exception is unhandled" do
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
    a.should eq(3)
    b.should eq(4)
  end

  it "ensure without rescue" do
    a = 0
    begin
      begin
        raise "Oh no!"
      ensure
        a = 1
      end
    rescue
    end

    a.should eq(1)
  end

  def foo(x)
    begin
      return 0 if 1 == 1
    ensure
      x.value = 1
    end
  end

  it "execute ensure when the main block returns" do
    x = 0
    foo(pointerof(x)).should eq(0)
    x.should eq(1)
  end

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

  it "execute ensure when the main block yields and returns" do
    x = 0
    bar2(pointerof(x))
    x.should eq(1)
  end


  it "rescue with type" do
    a = begin
      raise Ex2.new
    rescue Ex1
      1
    rescue Ex2
      2
    end

    a.should eq(2)
  end

  it "rescue with types defaults to generic rescue" do
    a = begin
      raise "Oh no!"
    rescue Ex1
      1
    rescue Ex2
      2
    rescue
      3
    end

    a.should eq(3)
  end

  it "handle exception in outer block" do
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

    x.should eq(2)
    p.should eq(0)
  end

  it "handle subclass" do
    x = 0
    begin
      raise Ex3.new
    rescue Ex1
      x = 1
    end

    x.should eq(1)
  end

  it "handle multiple exception types" do
    x = 0
    begin
      raise Ex2.new
    rescue Ex1 | Ex2
      x = 1
    end

    x.should eq(1)

    x = 0
    begin
      raise Ex1.new
    rescue Ex1 | Ex2
      x = 1
    end

    x.should eq(1)
  end

  it "receives exception object" do
    x = ""
    begin
      raise Ex1.new
    rescue ex
      x = ex.to_s
    end

    x.should eq("Ex1")
  end

  it "executes else if no exception is raised" do
    x = 1
    y = begin
        rescue ex
          x = 2
        else
          x = 3
        end
    x.should eq(3)
    y.should eq(3)
  end

  it "doesn't execute else if exception is raised" do
    x = 1
    y = begin
          raise Ex1.new
        rescue ex
          x = 2
        else
          x = 3
        end
    x.should eq(2)
    y.should eq(2)
  end

  it "doesn't execute else if exception is raised conditionally" do
    x = 1
    y = begin
          raise Ex1.new if 1 == 1
        rescue ex
          x = 2
        else
          x = 3
        end
    x.should eq(2)
    y.should eq(2)
  end

  module ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName
    def self.foo
      raise "Foo"
    end
  end

  it "allocates enough space for backtrace frames" do
    begin
      ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName.foo
    rescue ex
      ex.backtrace.any? {|x| x.includes? "ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName" }.should be_true
    end
  end

  it "unescapes linux backtrace" do
    frame = "_2A_Crystal_3A__3A_Compiler_23_compile_3C_Crystal_3A__3A_Compiler_3E__3A_Nil"
    fixed = "\x2ACrystal\x3A\x3ACompiler\x23compile\x3CCrystal\x3A\x3ACompiler\x3E\x3ANil"
    Exception.unescape_linux_backtrace_frame(frame).should eq(fixed)
  end

  it "handle exception raised by fun literal" do
    x = 0
    f = -> { raise "Foo" if 1 == 1 }
    begin
      f.call
    rescue
      x = 1
    end
    x.should eq(1)
  end
end
