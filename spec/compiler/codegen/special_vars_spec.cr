require "../../spec_helper"

describe "Codegen: special vars" do
  ["$~", "$?"].each do |name|
    it "codegens #{name}" do
      run(<<-CRYSTAL).to_string.should eq("hey")
        class Object; def not_nil!; self; end; end

        def foo(z)
          #{name} = "hey"
        end

        foo(2)
        #{name}
        CRYSTAL
    end

    it "codegens #{name} with nilable (1)" do
      run(<<-CRYSTAL).to_string.should eq("ouch")
        require "prelude"

        def foo
          if 1 == 2
            #{name} = "foo"
          end
        end

        foo

        begin
          #{name}
        rescue ex
          "ouch"
        end
        CRYSTAL
    end

    it "codegens #{name} with nilable (2)" do
      run(<<-CRYSTAL).to_string.should eq("foo")
        require "prelude"

        def foo
          if 1 == 1
            #{name} = "foo"
          end
        end

        foo

        begin
          #{name}
        rescue ex
          "ouch"
        end
        CRYSTAL
    end
  end

  it "codegens $~ two levels" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      class Object; def not_nil!; self; end; end

      def foo
        $? = "hey"
      end

      def bar
        $? = foo
        $?
      end

      bar
      $?
      CRYSTAL
  end

  it "works lazily" do
    run(<<-CRYSTAL).to_string.should eq("bar")
      require "prelude"

      class Foo
        getter string

        def initialize(@string : String)
        end
      end

      def bar(&block : Foo -> _)
        block
      end

      block = bar do |foo|
        case foo.string
        when /foo-(.+)/
          $1
        else
          "baz"
        end
      end
      block.call(Foo.new("foo-bar"))
      CRYSTAL
  end

  it "codegens in block" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      require "prelude"

      class Object; def not_nil!; self; end; end

      def foo
        $~ = "hey"
        yield
      end

      a = nil
      foo do
        a = $~
      end
      a.not_nil!
      CRYSTAL
  end

  it "codegens in block when def has typed block annotation (#16391)" do
    # `Nil#not_nil!` returns a sentinel (0) instead of raising so that if
    # this regression is reintroduced the test fails cleanly on the value
    # comparison rather than aborting the spec run with a NilAssertionError.
    run(<<-CRYSTAL).to_i.should eq(42)
      class Object; def not_nil!; self; end; end
      struct Nil; def not_nil!; 0; end; end

      def foo(& : Int32 -> _)
        $~ = 42
        yield 0
      end

      a = 0
      foo do
        a = $~
      end
      a
      CRYSTAL
  end

  it "codegens in block when def has typed block annotation with concrete output (#16391)" do
    run(<<-CRYSTAL).to_i.should eq(42)
      class Object; def not_nil!; self; end; end
      struct Nil; def not_nil!; 0; end; end

      def foo(& : Int32 -> Int32)
        $~ = 42
        yield 0
      end

      a = 0
      foo do |s|
        a = $~
        s
      end
      a
      CRYSTAL
  end

  it "codegens when def assigns special vars and block return type uses a free variable (#16391)" do
    # Free variable in the block output requires eager block typing — the
    # block's actual return type fixes `U`. The previous deferral-only fix
    # for `assigns_special_var?` couldn't compile this combination at all
    # ("can't infer block return type"). The block here doesn't reference
    # `$~` itself, so eager typing produces correct types.
    run(<<-CRYSTAL).to_i.should eq(20)
      def foo(& : Int32 -> U) forall U
        $~ = "hey"
        yield 1
      end

      foo do |i|
        i &* 20
      end
      CRYSTAL
  end

  it "codegens in block with nested block" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      require "prelude"

      class Object; def not_nil!; self; end; end

      def bar
        yield
      end

      def foo
        bar do
          $~ = "hey"
          yield
        end
      end

      a = nil
      foo do
        a = $~
      end
      a.not_nil!
      CRYSTAL
  end

  it "codegens after block" do
    run(<<-CRYSTAL).to_string.should eq("hey")
      require "prelude"

      class Object; def not_nil!; self; end; end

      def foo
        $~ = "hey"
        yield
      end

      a = nil
      foo {}
      $~
      CRYSTAL
  end

  it "codegens after block 2" do
    run(<<-CRYSTAL).to_string.should eq("bye")
      class Object; def not_nil!; self; end; end

      def baz
        $~ = "bye"
      end

      def foo
        baz
        yield
        $~
      end

      foo do
      end
      CRYSTAL
  end

  it "codegens with default argument" do
    run(<<-CRYSTAL).to_string.should eq("bye")
      class Object; def not_nil!; self; end; end

      def baz(x = 1)
        $~ = "bye"
      end

      baz
      $~
      CRYSTAL
  end

  it "preserves special vars in macro expansion with call with default arguments (#824)" do
    run(<<-CRYSTAL).to_string.should eq("yes")
      class Object; def not_nil!; self; end; end

      def bar(x = 0)
        $~ = "yes"
      end

      macro foo
        bar
        $~
      end

      foo
      CRYSTAL
  end

  it "allows with primitive" do
    run(<<-CRYSTAL).to_i.should eq(123)
      class Object; def not_nil!; self; end; end

      def foo
        $~ = 123
      end

      foo

      v = $~
      v || 456
      CRYSTAL
  end

  it "allows with struct" do
    run(<<-CRYSTAL).to_i.should eq(123)
      class Object; def not_nil!; self; end; end

      struct Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      def foo
        $~ = Foo.new(123)
      end

      foo

      v = $~
      if v
        v.x
      else
        456
      end
      CRYSTAL
  end

  it "preserves special vars if initialized inside block (#2194)" do
    run(<<-CRYSTAL).to_string.should eq("foo")
      class Object; def not_nil!; self; end; end

      def foo
        $~ = "foo"
      end

      def bar
        yield
      end

      bar do
        foo
      end

      v = $~
      if v
        v
      else
        "bar"
      end
      CRYSTAL
  end
end
