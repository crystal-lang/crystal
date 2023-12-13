require "../../spec_helper"

describe "Call errors" do
  it "says wrong number of arguments (to few arguments)" do
    assert_error %(
      def foo(x)
      end

      foo
      ),
      "wrong number of arguments for 'foo' (given 0, expected 1)"
  end

  it "says wrong number of arguments even if other overloads don't match by block" do
    assert_error %(
      def foo(x)
      end

      def foo(x, y)
        yield
      end

      foo
      ),
      "wrong number of arguments for 'foo' (given 0, expected 1)"
  end

  it "says not expected to be invoked with a block" do
    assert_error %(
      def foo
      end

      foo {}
      ),
      "'foo' is not expected to be invoked with a block, but a block was given"
  end

  it "says expected to be invoked with a block" do
    assert_error %(
      def foo
        yield
      end

      foo
      ),
      "'foo' is expected to be invoked with a block, but no block was given"
  end

  it "says missing named argument" do
    assert_error %(
      def foo(*, x)
      end

      foo
      ),
      "missing argument: x"
  end

  it "says missing named arguments" do
    assert_error %(
      def foo(*, x, y)
      end

      foo
      ),
      "missing arguments: x, y"
  end

  it "says no parameter named" do
    assert_error %(
      def foo
      end

      foo(x: 1)
      ),
      "no parameter named 'x'"
  end

  it "says no parameters named" do
    assert_error %(
      def foo
      end

      foo(x: 1, y: 2)
      ),
      "no parameters named 'x', 'y'"
  end

  it "says argument already specified" do
    assert_error %(
      def foo(x)
      end

      foo(1, x: 2)
      ),
      "argument for parameter 'x' already specified"
  end

  it "says type mismatch for positional argument" do
    assert_error %(
      def foo(x : Int32, y : Int32)
      end

      foo(1, 'a')
      ),
      "expected argument #2 to 'foo' to be Int32, not Char"
  end

  it "says type mismatch for positional argument with two options" do
    assert_error %(
      def foo(x : Int32)
      end

      def foo(x : String)
      end

      foo('a')
      ),
      "expected argument #1 to 'foo' to be Int32 or String, not Char"
  end

  it "says type mismatch for positional argument with three options" do
    assert_error %(
      def foo(x : Int32)
      end

      def foo(x : String)
      end

      def foo(x : Bool)
      end

      foo('a')
      ),
      "expected argument #1 to 'foo' to be Bool, Int32 or String, not Char"
  end

  it "says type mismatch for named argument " do
    assert_error %(
      def foo(x : Int32, y : Int32)
      end

      foo(y: 1, x: 'a')
      ),
      "expected argument 'x' to 'foo' to be Int32, not Char"
  end

  it "replaces free variables in positional argument" do
    assert_error %(
      def foo(x : T, y : T) forall T
      end

      foo(1, 'a')
      ),
      "expected argument #2 to 'foo' to be Int32, not Char"
  end

  it "replaces free variables in named argument" do
    assert_error %(
      def foo(x : T, y : T) forall T
      end

      foo(x: 1, y: 'a')
      ),
      "expected argument 'y' to 'foo' to be Int32, not Char"
  end

  it "replaces generic type var in positional argument" do
    assert_error %(
      class Foo(T)
        def self.foo(x : T)
        end
      end

      Foo(Int32).foo('a')
      ),
      "expected argument #1 to 'Foo(Int32).foo' to be Int32, not Char"
  end

  it "replaces generic type var in named argument" do
    assert_error %(
      class Foo(T)
        def self.foo(x : T, y : T)
        end
      end

      Foo(Int32).foo(x: 1, y: 'a')
      ),
      "expected argument 'y' to 'Foo(Int32).foo' to be Int32, not Char"
  end

  it "says type mismatch for positional argument even if there are overloads that don't match" do
    assert_error %(
      def foo(x : Int32)
      end

      def foo(x : Char)
      end

      def foo(x : Char, y : Int32)
      end

      foo("hello")
      ),
      "expected argument #1 to 'foo' to be Char or Int32, not String"
  end

  it "says type mismatch for symbol against enum (did you mean)" do
    assert_error %(
      enum Color
        Red
        Green
        Blue
      end

      def foo(x : Color)
      end

      foo(:rred)
      ),
      "expected argument #1 to 'foo' to match a member of enum Color.\n\nDid you mean :red?"
  end

  it "says type mismatch for symbol against enum (list all possibilities when 10 or less)" do
    assert_error %(
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
      ),
      "expected argument #1 to 'foo' to match a member of enum Color.\n\nOptions are: :red, :green, :blue, :violet and :purple"
  end

  it "says type mismatch for symbol against enum, named argument case" do
    assert_error %(
      enum Color
        Red
        Green
        Blue
      end

      def foo(x : Color)
      end

      foo(x: :rred)
      ),
      "expected argument 'x' to 'foo' to match a member of enum Color.\n\nDid you mean :red?"
  end

  it "errors on argument if more types are given than expected" do
    assert_error %(
      def foo(x : Int32)
      end

      def foo(x : Char)
      end

      foo(1 || nil)
      ),
      "expected argument #1 to 'foo' to be Int32, not (Int32 | Nil)"
  end

  it "errors on argument if more types are given than expected, shows all expected types" do
    assert_error %(
      def foo(x : Int32)
      end

      def foo(x : Char)
      end

      foo(1 ? nil : (1 || 'a'))
      ),
      "expected argument #1 to 'foo' to be Char or Int32, not (Char | Int32 | Nil)"
  end

  it "errors on argument if argument matches in all overloads but with different types in other arguments" do
    assert_error %(
      def foo(x : String, y : Int32, w : Int32)
      end

      def foo(x : String, y : Nil, w : Char)
      end

      foo("a", 1 || nil, 1)
      ),
      "expected argument #2 to 'foo' to be Int32, not (Int32 | Nil)"
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
