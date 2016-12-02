require "../../spec_helper"

describe "Semantic: did you mean" do
  it "says did you mean for one mistake in short word in instance method" do
    assert_error "
      class Foo
        def bar
        end
      end

      Foo.new.baz
      ",
      "did you mean 'bar'"
  end

  it "says did you mean for two mistakes in long word in instance method" do
    assert_error "
      class Foo
        def barbara
        end
      end

      Foo.new.bazbaza
      ",
      "did you mean 'barbara'"
  end

  it "says did you mean for global method with parenthesis" do
    assert_error "
      def bar
      end

      baz()
      ",
      "did you mean 'bar'"
  end

  it "says did you mean for global method without parenthesis" do
    assert_error "
      def bar
      end

      baz
      ",
      "did you mean 'bar'"
  end

  it "says did you mean for variable" do
    assert_error "
      bar = 1
      baz
      ",
      "did you mean 'bar'"
  end

  it "says did you mean for class" do
    assert_error "
      class Foo
      end

      Fog.new
      ",
      "did you mean 'Foo'"
  end

  it "says did you mean for nested class" do
    assert_error "
      class Foo
        class Bar
        end
      end

      Foo::Baz.new
      ",
      "did you mean 'Foo::Bar'"
  end

  it "says did you mean finds most similar in def" do
    assert_error "
      def barbaza
      end

      def barbara
      end

      barbarb
      ",
      "did you mean 'barbara'"
  end

  it "says did you mean finds most similar in type" do
    assert_error "
      class Barbaza
      end

      class Barbara
      end

      Barbarb
      ",
      "did you mean 'Barbara'"
  end

  it "doesn't suggest for operator" do
    nodes = parse %(
      class Foo
        def +
        end
      end

      Foo.new.a
      )
    begin
      semantic nodes
      fail "TypeException wasn't raised"
    rescue ex : Crystal::TypeException
      ex.to_s.includes?("did you mean").should be_false
    end
  end

  it "says did you mean for named argument" do
    assert_error "
      def foo(barbara = 1)
      end

      foo bazbaza: 1
      ",
      "did you mean 'barbara'"
  end

  it "says did you mean for instance var" do
    assert_error %(
      class Foo
        def initialize
          @barbara = 1
        end

        def foo
          @bazbaza.abs
        end
      end

      Foo.new.foo
      ),
      "did you mean @barbara"
  end

  it "says did you mean for instance var in subclass" do
    assert_error %(
      class Foo
        def initialize
          @barbara = 1
        end
      end

      class Bar < Foo
        def foo
          @bazbaza.abs
        end
      end

      Bar.new.foo
      ),
      "did you mean @barbara"
  end

  it "doesn't suggest when declaring var with suffix if and using it (#946)" do
    assert_error %(
      a if a = 1
      ),
      "If you declared 'a' in a suffix if, declare it in a regular if for this to work"
  end

  it "doesn't suggest when declaring var inside macro (#466)" do
    assert_error %(
      macro foo
        a = 1
      end

      foo
      a
      ),
      "If the variable was declared in a macro it's not visible outside it"
  end

  it "suggest that there might be a type for an initialize method" do
    assert_error %(
      class Foo
        def intialize(x)
        end
      end

      Foo.new(1)
      ),
      "do you maybe have a typo in this 'intialize' method?"
  end

  it "suggest that there might be a type for an initialize method in inherited class" do
    assert_error %(
      class Foo
        def initialize
        end
      end

      class Bar < Foo
        def intialize(x)
        end
      end

      Bar.new(1)
      ),
      "do you maybe have a typo in this 'intialize' method?"
  end

  it "suggest that there might be a type for an initialize method with overload" do
    assert_error %(
      class Foo
        def initialize(x : Int32)
        end

        def intialize(y : Float64)
        end
      end

      Foo.new(1.0)
      ),
      "do you maybe have a typo in this 'intialize' method?"
  end

  it "suggests for class variable" do
    assert_error %(
      class Foo
        @@foobar = 1
        @@fooobar
      end
      ), "did you mean @@foobar"
  end

  it "suggests a better alternative to logical operators (#2715)" do
    message = "undefined method 'and'"
    message = " (did you mean '&&'?)".colorize.yellow.bold.to_s
    assert_error %(
      def rand(x : Int32)
      end

      class String
        def bytes
          self
        end
      end

      if "a".bytes and 1
        1
      end
      ), message
  end

  it "says did you mean in instance var declaration" do
    assert_error %(
      class FooBar
      end

      class Foo
        @x : FooBaz
      end
      ),
      "did you mean 'FooBar'"
  end
end
