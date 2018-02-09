require "../../spec_helper"

describe "Semantic: case" do
  it "check exhaustiveness for neither enum nor union types" do
    assert_type %(
      require "prelude"

      a = 42

      case a
      when Int32
        1
      end
    ) { int32 }
  end

  it "don't report exhaustiveness error for neither enum nor union types" do
    assert_type %(
      require "prelude"

      a = 42

      case a
      when 1
        1
      end
    ) { nilable(int32) }
  end

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

  it "checks exhaustiveness after loop" do
    assert_error %(
      require "prelude"

      a = 42

      while true
        case a
        when Int32
        end

        a = :foo
      end
    ), "found non-exhaustive pattern: Symbol"
  end
end
