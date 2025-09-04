require "../../spec_helper"

describe "Code gen: alias" do
  it "invokes methods on empty array of recursive alias (1)" do
    run(<<-CRYSTAL).to_string.should eq("")
      require "prelude"

      alias Alias = Array(Alias)

      a = [] of Alias
      b = a.map(&.to_s).join
      CRYSTAL
  end

  it "invokes methods on empty array of recursive alias (2)" do
    run(<<-CRYSTAL).to_string.should eq("")
      require "prelude"

      alias Alias = Nil | Array(Alias)

      a = [] of Alias
      b = a.map(&.to_s).join
      CRYSTAL
  end

  it "invokes methods on empty array of recursive alias (3)" do
    run(<<-CRYSTAL).to_string.should eq("")
      require "prelude"

      alias Alias = Nil | Array(Alias)

      a = [] of Alias
      b = a.map(&.to_s).join
      CRYSTAL
  end

  it "casts to recursive alias" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      class Bar(T)
      end

      alias Foo = Int32 | Bar(Foo)

      a = 1.as(Foo)
      b = a.as(Int32)
      b
      CRYSTAL
  end

  it "casts to recursive alias" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Bar(T)
        def self.new(&block : -> T)
        end

        def to_i!
          0
        end
      end

      alias Foo = Int32 | Bar(Foo)

      def foo(n)
        if n == 0
          1
        else
          foo(n &- 1).as(Foo)
        end
      end

      foo(2).to_i!
      CRYSTAL
  end

  it "doesn't break with alias for link attributes" do
    result = semantic(%(
      alias Foo = Int32

      module Moo
        alias Bar = Foo
        alias Foo = Moo
      end
      ))
    result.program.link_annotations
  end

  it "doesn't crash on cast to as recursive alias (#639)" do
    codegen(<<-CRYSTAL)
      class Foo(T)
      end

      alias Type = Int32 | Foo(Type)

      Foo(Type).new

      ptr = Pointer(Type).malloc(1_u64)
      ptr.value = 1.as(Type)
      ptr.value = 1
      CRYSTAL
  end

  it "lazily solves aliases (#1346)" do
    run(<<-CRYSTAL)
      struct Proc
        def self.new(&block : self)
          block
        end
      end

      class Session; end

      alias CmdHandler = Proc(Session, Int32)

      class Session
        def foo
          1
        end
      end

      class SmtpSession < Session
        def foo
          2
        end
      end

      cmd = CmdHandler.new { |s| s.foo }
      cmd.call(SmtpSession.new)
      CRYSTAL
  end

  it "codegens cast to alias that includes bool" do
    run(<<-CRYSTAL).to_i.should eq(2)
      alias Foo = Bool | Array(Foo)

      a = false.as(Foo)
      if a
        1
      else
        2
      end
      CRYSTAL
  end

  it "overloads alias against generic (1) (#3261)" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(2)
      class Foo(T)
      end

      alias FooString = Foo(String)

      def take(foo : Foo(String))
        1
      end

      def take(foo : FooString)
        2
      end

      take(Foo(String).new)
      CRYSTAL
  end

  it "overloads alias against generic (2) (#3261)" do
    run(<<-CRYSTAL, inject_primitives: false).to_i.should eq(1)
      class Foo(T)
      end

      alias FooString = Foo(String)

      def take(foo : FooString)
        2
      end

      def take(foo : Foo(String))
        1
      end

      take(Foo(String).new)
      CRYSTAL
  end
end
