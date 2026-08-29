require "../../spec_helper"

describe "Call errors" do
  it "says wrong number of arguments (to few arguments)" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'foo' (given 0, expected 1)"
      def foo(x)
      end

      foo
      CRYSTAL
  end

  it "says wrong number of arguments even if other overloads don't match by block" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'foo' (given 0, expected 1)"
      def foo(x)
      end

      def foo(x, y)
        yield
      end

      foo
      CRYSTAL
  end

  it "says not expected to be invoked with a block" do
    assert_error <<-CRYSTAL, "'foo' is not expected to be invoked with a block, but a block was given"
      def foo
      end

      foo {}
      CRYSTAL
  end

  it "says expected to be invoked with a block" do
    assert_error <<-CRYSTAL, "'foo' is expected to be invoked with a block, but no block was given"
      def foo
        yield
      end

      foo
      CRYSTAL
  end

  it "says missing named argument" do
    assert_error <<-CRYSTAL, "missing argument: x"
      def foo(*, x)
      end

      foo
      CRYSTAL
  end

  it "says missing named arguments" do
    assert_error <<-CRYSTAL, "missing arguments: x, y"
      def foo(*, x, y)
      end

      foo
      CRYSTAL
  end

  it "says no parameter named" do
    assert_error <<-CRYSTAL, "no parameter named 'x'"
      def foo
      end

      foo(x: 1)
      CRYSTAL
  end

  it "says no parameters named" do
    assert_error <<-CRYSTAL, "no parameters named 'x', 'y'"
      def foo
      end

      foo(x: 1, y: 2)
      CRYSTAL
  end

  it "says argument already specified" do
    assert_error <<-CRYSTAL, "argument for parameter 'x' already specified"
      def foo(x)
      end

      foo(1, x: 2)
      CRYSTAL
  end

  it "says type mismatch for positional argument" do
    assert_error <<-CRYSTAL, "expected argument #2 to 'foo' to be Int32, not Char"
      def foo(x : Int32, y : Int32)
      end

      foo(1, 'a')
      CRYSTAL
  end

  it "says type mismatch for positional argument with two options" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'foo' to be Int32 or String, not Char"
      def foo(x : Int32)
      end

      def foo(x : String)
      end

      foo('a')
      CRYSTAL
  end

  it "says type mismatch for positional argument with three options" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'foo' to be Bool, Int32 or String, not Char"
      def foo(x : Int32)
      end

      def foo(x : String)
      end

      def foo(x : Bool)
      end

      foo('a')
      CRYSTAL
  end

  it "says type mismatch for named argument " do
    assert_error <<-CRYSTAL, "expected argument 'x' to 'foo' to be Int32, not Char"
      def foo(x : Int32, y : Int32)
      end

      foo(y: 1, x: 'a')
      CRYSTAL
  end

  it "replaces free variables in positional argument" do
    assert_error <<-CRYSTAL, "expected argument #2 to 'foo' to be Int32, not Char"
      def foo(x : T, y : T) forall T
      end

      foo(1, 'a')
      CRYSTAL
  end

  it "replaces free variables in named argument" do
    assert_error <<-CRYSTAL, "expected argument 'y' to 'foo' to be Int32, not Char"
      def foo(x : T, y : T) forall T
      end

      foo(x: 1, y: 'a')
      CRYSTAL
  end

  it "replaces generic type var in positional argument" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'Foo(Int32).foo' to be Int32, not Char"
      class Foo(T)
        def self.foo(x : T)
        end
      end

      Foo(Int32).foo('a')
      CRYSTAL
  end

  it "replaces generic type var in named argument" do
    assert_error <<-CRYSTAL, "expected argument 'y' to 'Foo(Int32).foo' to be Int32, not Char"
      class Foo(T)
        def self.foo(x : T, y : T)
        end
      end

      Foo(Int32).foo(x: 1, y: 'a')
      CRYSTAL
  end

  it "says type mismatch for positional argument even if there are overloads that don't match" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'foo' to be Char or Int32, not String"
      def foo(x : Int32)
      end

      def foo(x : Char)
      end

      def foo(x : Char, y : Int32)
      end

      foo("hello")
      CRYSTAL
  end

  it "says type mismatch for symbol against enum (did you mean)" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'foo' to match a member of enum Color.\n\nDid you mean :red?"
      enum Color
        Red
        Green
        Blue
      end

      def foo(x : Color)
      end

      foo(:rred)
      CRYSTAL
  end

  it "says type mismatch for symbol against enum (list all possibilities when 10 or less)" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'foo' to match a member of enum Color.\n\nOptions are: :red, :green, :blue, :violet and :purple"
      enum Color
        Red
        Green
        Blue
        Violet
        Purple
      end

      def foo(x : Color)
      end

      foo(:hello_world)
      CRYSTAL
  end

  it "says type mismatch for symbol against enum, named argument case" do
    assert_error <<-CRYSTAL, "expected argument 'x' to 'foo' to match a member of enum Color.\n\nDid you mean :red?"
      enum Color
        Red
        Green
        Blue
      end

      def foo(x : Color)
      end

      foo(x: :rred)
      CRYSTAL
  end

  it "errors on argument if more types are given than expected" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'foo' to be Int32, not (Int32 | Nil)"
      def foo(x : Int32)
      end

      def foo(x : Char)
      end

      foo(1 || nil)
      CRYSTAL
  end

  it "errors on argument if more types are given than expected, shows all expected types" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'foo' to be Char or Int32, not (Char | Int32 | Nil)"
      def foo(x : Int32)
      end

      def foo(x : Char)
      end

      foo(1 ? nil : (1 || 'a'))
      CRYSTAL
  end

  it "errors on argument if argument matches in all overloads but with different types in other arguments" do
    assert_error <<-CRYSTAL, "expected argument #2 to 'foo' to be Int32, not (Int32 | Nil)"
      def foo(x : String, y : Int32, w : Int32)
      end

      def foo(x : String, y : Nil, w : Char)
      end

      foo("a", 1 || nil, 1)
      CRYSTAL
  end

  describe "method signatures in error traces" do
    it "includes named argument" do
      assert_error <<-CRYSTAL, "instantiating 'bar(y: Int32)'"
        def foo(x)
        end

        def bar(**opts)
          foo
        end

        bar(y: 1)
        CRYSTAL
    end

    it "includes named arguments" do
      assert_error <<-CRYSTAL, "instantiating 'bar(y: Int32, z: String)'"
        def foo(x)
        end

        def bar(**opts)
          foo
        end

        bar(y: 1, z: "")
        CRYSTAL
    end

    it "includes positional and named argument" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32, y: String)'"
        def foo(x)
        end

        def bar(*args, **opts)
          foo
        end

        bar(1, y: "")
        CRYSTAL
    end

    it "expands single splat argument" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32)'"
        def foo(x)
        end

        def bar(*args)
          foo
        end

        bar(*{1})
        CRYSTAL
    end

    it "expands single splat argument, more elements" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32, String)'"
        def foo(x)
        end

        def bar(*args)
          foo
        end

        bar(*{1, ""})
        CRYSTAL
    end

    it "expands single splat argument, empty tuple" do
      assert_error <<-CRYSTAL, "instantiating 'bar()'"
        #{tuple_new}

        def foo(x)
        end

        def bar(*args)
          foo
        end

        bar(*Tuple.new)
        CRYSTAL
    end

    it "expands positional and single splat argument" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32, String)'"
        def foo(x)
        end

        def bar(*args)
          foo
        end

        bar(1, *{""})
        CRYSTAL
    end

    it "expands positional and single splat argument, more elements" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32, String, Bool)'"
        def foo(x)
        end

        def bar(*args)
          foo
        end

        bar(1, *{"", true})
        CRYSTAL
    end

    it "expands positional and single splat argument, empty tuple" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32)'"
        #{tuple_new}

        def foo(x)
        end

        def bar(*args)
          foo
        end

        bar(1, *Tuple.new)
        CRYSTAL
    end

    it "expands double splat argument" do
      assert_error <<-CRYSTAL, "instantiating 'bar(y: Int32)'"
        def foo(x)
        end

        def bar(**opts)
          foo
        end

        bar(**{y: 1})
        CRYSTAL
    end

    it "expands double splat argument, more elements" do
      assert_error <<-CRYSTAL, "instantiating 'bar(y: Int32, z: String)'"
        def foo(x)
        end

        def bar(**opts)
          foo
        end

        bar(**{y: 1, z: ""})
        CRYSTAL
    end

    it "expands double splat argument, empty named tuple" do
      assert_error <<-CRYSTAL, "instantiating 'bar()'"
        #{named_tuple_new}

        def foo(x)
        end

        def bar(**opts)
          foo
        end

        bar(**NamedTuple.new)
        CRYSTAL
    end

    it "expands positional and double splat argument" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32, y: String)'"
        def foo(x)
        end

        def bar(*args, **opts)
          foo
        end

        bar(1, **{y: ""})
        CRYSTAL
    end

    it "expands positional and double splat argument, more elements" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32, y: String, z: Bool)'"
        def foo(x)
        end

        def bar(*args, **opts)
          foo
        end

        bar(1, **{y: "", z: true})
        CRYSTAL
    end

    it "expands positional and double splat argument, empty named tuple" do
      assert_error <<-CRYSTAL, "instantiating 'bar(Int32)'"
        #{named_tuple_new}

        def foo(x)
        end

        def bar(*args, **opts)
          foo
        end

        bar(1, **NamedTuple.new)
        CRYSTAL
    end

    it "uses `T.method` instead of `T.class#method`" do
      assert_error <<-CRYSTAL, "instantiating 'Bar.bar()'"
        def foo(x)
        end

        class Bar
          def self.bar
            foo
          end
        end

        Bar.bar
        CRYSTAL
    end

    it "uses `T.method` instead of `T:module#method`" do
      assert_error <<-CRYSTAL, "instantiating 'Bar.bar()'"
        def foo(x)
        end

        module Bar
          def self.bar
            foo
          end
        end

        Bar.bar
        CRYSTAL
    end
  end
end

private def tuple_new
  <<-CRYSTAL
    struct Tuple
      def self.new(*args)
        args
      end
    end
    CRYSTAL
end

private def named_tuple_new
  <<-CRYSTAL
    struct NamedTuple
      def self.new(**opts)
        opts
      end
    end
    CRYSTAL
end
