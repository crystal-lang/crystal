require "../../spec_helper"

describe "Semantic: case" do
  it "check exhaustiveness for union types (Path)" do
    assert_error %(
      foo = true ? 42 : "foo"

      case foo
      when String
      end
      ), "found non-exhaustive pattern: Int32"
  end

  it "check exhaustiveness for union types (IsA)" do
    assert_error %(
      foo = true ? 42 : "foo"

      case foo
      when .is_a?(String)
      end
      ), "found non-exhaustive pattern: Int32"
  end

  it "checks exhaustiveness for enum types (Path)" do
    assert_error %(
      enum FooBar
        Foo
        Bar
      end

      foo = FooBar::Foo

      case foo
      when FooBar::Foo
      end
      ), "found non-exhaustive pattern: Bar"
  end

  it "checks exhaustiveness for enum types (Call)" do
    assert_error %(
      enum FooBar
        Foo
        Bar
      end

      foo = FooBar::Foo

      case foo
      when .foo?
      end
      ), "found non-exhaustive pattern: Bar"
  end

  it "checks exhaustiveness for bool type (BoolLiteral)" do
    assert_error %(
      foo = true

      case foo
      when true
      end
      ), "found non-exhaustive pattern: false"
  end

  it "checks exhaustiveness for nilable types (NilLiteral)" do
    assert_error %(
      foo = true ? "foo" : nil

      case foo
      when nil
      end
      ), "found non-exhaustive pattern: String"
  end

  it "checks exhaustiveness for complex type" do
    assert_error %(
      enum FooBar
        Foo
        Bar
      end

      foo = nil.as(Nil | Bool | FooBar)

      case foo
      when .foo?
      when true
      end
      ), "found non-exhaustive patterns: nil, false, FooBar::Bar"
  end

  it "passes exhaustivness check if 'case' has 'else' block" do
    assert_type %(
      foo = true ? 42 : "foo"

      case foo
      when String
      else
      end
      ) { nil_type }
  end

  it "passes exhaustivness check if 'case' has 'when _' block" do
    assert_type %(
      require "prelude"

      foo = true ? 42 : "foo"

      case foo
      when String
      when _
      end
      ) { nil_type }
  end

  it "passes exhaustiveness check if all values are exhausted" do
    assert_type %(
      require "prelude"

      foo = true ? 42 : "foo"

      case foo
      when String
        :string
      when Int32
        :int32
      end
      ) { symbol }
  end

  it "checks tuple exhaustiveness" do
    assert_error %(
      require "prelude"

      foo = true ? 42 : "foo"
      bar = true ? 3.14 : :bar

      case {foo, bar}
      when {String, _}
      when {_, Float64}
      end
      ), "found non-exhaustive pattern: {Int32, Symbol}"
  end

  it "checks tuple exhaustiveness (multiple non-exhaustive patterns)" do
    assert_error %(
      require "prelude"

      foo = true ? 42 : "foo"
      bar = true ? 3.14 : :bar

      case {foo, bar}
      when {String, _}
      end
      ), "found non-exhaustive patterns: {Int32, Float64}, {Int32, Symbol}"
  end

  it "passes tuple exhaustiveness check if all values are exhausted" do
    assert_type %(
      require "prelude"

      foo = true ? 42 : "foo"
      bar = true ? 3.14 : :bar

      case {foo, bar}
      when {String, _}
        :left_string
      when {_, Float64}
        :right_float64
      when {Int32, Symbol}
        :int32_string
      end
      ) { symbol }
  end

  it "passes tuple exhaustivness check if 'case' has 'when _' block" do
    assert_type %(
      require "prelude"

      foo = true ? 42 : "foo"
      bar = true ? 3.14 : :bar

      case foo
      when {String, Float64}
      when _
      end
      ) { nil_type }
  end
end
