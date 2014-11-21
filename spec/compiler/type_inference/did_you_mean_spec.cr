require "../../spec_helper"

describe "Type inference: did you mean" do
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
        def !
        end
      end

      Foo.new.a
      )
    begin
      infer_type nodes
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
end
