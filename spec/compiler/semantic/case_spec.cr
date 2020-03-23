require "../../spec_helper"

describe "Semantic: case" do
  it "checks exhaustiveness of union type" do
    assert_warning %(
        a = 1 || nil
        case a
        when Int32
        end
      ),
      "warning in line 4\nWarning: case is not exhaustive.\n\nMissing types:\n - Nil"
  end

  it "checks exhaustiveness of single type" do
    assert_warning %(
        case 1
        when Nil
        end
      ),
      "warning in line 3\nWarning: case is not exhaustive.\n\nMissing types:\n - Int32"
  end

  it "covers all types" do
    assert_no_warnings %(
        a = 1 || nil
        case a
        when Int32
        when Nil
        end
      )
  end

  it "can't prove exhaustiveness" do
    assert_warning %(
        struct Int32
          def ===(other)
            true
          end
        end

        case 1
        when 2
        end
      ),
      "warning in line 9\nWarning: can't prove case is exhaustive.\n\nPlease add an `else` clause."
  end

  it "checks exhaustiveness of bool type (missing true)" do
    assert_warning %(
        #{bool_case_eq}

        case false
        when false
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases:\n - true"
  end

  it "checks exhaustiveness of bool type (missing false)" do
    assert_warning %(
        #{bool_case_eq}

        case false
        when true
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases:\n - false"
  end

  it "checks exhaustiveness of enum via question method" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        when .red?
        end
      ),
      "warning in line 20\nWarning: case is not exhaustive for enum Color.\n\nMissing members:\n - Green\n - Blue"
  end

  it "checks exhaustiveness of enum via const" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        when Color::Red
        end
      ),
      "warning in line 20\nWarning: case is not exhaustive for enum Color.\n\nMissing members:\n - Green\n - Blue"
  end

  it "checks exhaustiveness of enum (all cases covered)" do
    assert_no_warnings %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        when .red?
        when .green?
        when .blue?
        end
      )
  end

  it "checks exhaustiveness of bool type with other types" do
    assert_no_warnings %(
        #{bool_case_eq}

        case 1 || true
        when Int32
        when true
        when false
        end
      )
  end

  it "checks exhaustiveness of union type with virtual type" do
    assert_warning %(
        class Foo
        end

        class Bar < Foo
        end

        a = 1 || Foo.new || Bar.new
        case a
        when Foo
        end
      ),
      "warning in line 10\nWarning: case is not exhaustive.\n\nMissing types:\n - Int32"
  end

  it "checks exhaustiveness, covers when base type covers" do
    assert_no_warnings %(
        class Foo
        end

        class Bar < Foo
        end

        a = Bar.new
        case a
        when Foo
        end
      )
  end

  it "checks exhaustiveness, covers when base type covers (generic type)" do
    assert_no_warnings %(
        class Foo(T)
        end

        a = Foo(Int32).new
        case a
        when Foo
        end
      )
  end

  it "checks exhaustiveness of nil type with nil literal" do
    assert_no_warnings %(
        struct Nil
          def ===(other)
            true
          end
        end

        case nil
        when nil
        end
      )
  end

  it "checks exhaustiveness of nilable type with nil literal" do
    assert_no_warnings %(
        struct Nil
          def ===(other)
            true
          end
        end

        a = 1 || nil
        case a
        when nil
        when Int32
        end
      )
  end

  it "never warns on condless case without else" do
    assert_no_warnings %(
        case
        when 1 == 2
        end
      )
  end

  it "always requires an else for Flags enum (no coverage)" do
    assert_warning %(
        struct Enum
          def includes?(other : self)
            false
          end
        end

        @[Flags]
        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        when .red?
        end
      ),
      "warning in line 17\nWarning: can't prove case is exhaustive.\n\nPlease add an `else` clause."
  end

  it "always requires an else for Flags enum (all members covered but doesn't count)" do
    assert_warning %(
        struct Enum
          def includes?(other : self)
            false
          end
        end

        @[Flags]
        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        when .red?
        when .green?
        when .blue?
        end
      ),
      "warning in line 17\nWarning: can't prove case is exhaustive.\n\nPlease add an `else` clause."
  end

  it "checks exhaustiveness of enum combined with another type" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red || 1
        case e
        when Int32
        when .red?
        end
      ),
      "warning in line 20\nWarning: case is not exhaustive for enum Color.\n\nMissing members:\n - Green\n - Blue"
  end

  it "checks exhaustiveness of union with bool" do
    assert_warning %(
        #{bool_case_eq}

        e = 1 || true
        case e
        when true
        end
      ),
      "warning in line 10\nWarning: case is not exhaustive.\n\nMissing cases:\n - false\n - Int32"
  end

  it "checks exhaustiveness for tuple literal, and passes" do
    assert_no_warnings %(
        a = 1 || 'a'
        b = 1 || 'a'

        case {a, b}
        when {Int32, Char}
        when {Int32, Int32}
        when {Char, Int32}
        when {Char, Char}
        end
      )
  end

  it "checks exhaustiveness for tuple literal of 2 elements, and warns" do
    assert_warning %(
        a = 1 || 'a'

        case {a, a}
        when {Int32, Char}
        when {Int32, Int32}
        when {Char, Char}
        end
      ),
      "warning in line 5\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, Int32}"
  end

  it "checks exhaustiveness for tuple literal of 3 elements, and warns" do
    assert_warning %(
        a = 1 || 'a'

        case {a, a, a}
        when {Int32, Int32, Int32}
        when {Int32, Char, Int32}
        when {Int32, Char, Char}
        when {Char, Int32, Int32}
        when {Char, Char, Int32}
        when {Char, Char, Char}
        end
      ),
      "warning in line 5\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, Int32, Char}\n - {Int32, Int32, Char}"
  end

  it "checks exhaustiveness for tuple literal of 2 elements, first is bool" do
    assert_warning %(
        #{bool_case_eq}

        case {true, 'a'}
        when {true, Char}
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases:\n - {false, Char}"
  end

  it "checks exhaustiveness for tuple literal of 2 elements, first is enum" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {Color::Red, 'a'}
        when {.red?, Char}
        when {.blue?, Char}
        end
      ),
      "warning in line 19\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Color::Green, Char}"
  end

  it "checks exhaustiveness for tuple literal with types and underscore at first position" do
    assert_warning %(
        a = 1 || 'a'

        case {a, a}
        when {_, Int32}
        end
      ),
      "warning in line 5\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, Char}\n - {Int32, Char}"
  end

  it "checks exhaustiveness for tuple literal with types and underscore at second position" do
    assert_warning %(
        a = 1 || 'a'

        case {a, a}
        when {Int32, _}
        end
      ),
      "warning in line 5\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, Char}\n - {Char, Int32}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position" do
    assert_warning %(
        #{bool_case_eq}

        case {true, 1 || 'a'}
        when {_, Int32}
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Bool, Char}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position, with partial match" do
    assert_warning %(
        #{bool_case_eq}

        case {true, 1 || 'a'}
        when {_, Int32}
        when {false, Char}
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases:\n - {true, Char}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position" do
    assert_warning %(
        #{bool_case_eq}

        case {1 || 'a', true}
        when {Int32, _}
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, Bool}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position, with partial match" do
    assert_warning %(
        #{bool_case_eq}

        case {1 || 'a', true}
        when {Int32, _}
        when {Char, false}
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, true}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {Color::Red, 1 || 'a'}
        when {_, Int32}
        end
      ),
      "warning in line 19\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Color, Char}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position, partial match" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {Color::Red, 1 || 'a'}
        when {_, Int32}
        when {.blue?, Char}
        end
      ),
      "warning in line 19\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Color::Red, Char}\n - {Color::Green, Char}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {1 || 'a', Color::Red}
        when {Int32, _}
        end
      ),
      "warning in line 19\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, Color}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position, partial match" do
    assert_warning %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {1 || 'a', Color::Red}
        when {Int32, _}
        when {Char, .blue?}
        end
      ),
      "warning in line 19\nWarning: case is not exhaustive.\n\nMissing cases:\n - {Char, Color::Red}\n - {Char, Color::Green}"
  end

  it "checks exhaustiveness for tuple literal, with call" do
    assert_no_warnings %(
        struct Int
          def bar
            1 || 'a'
          end
        end

        foo = 1

        case {foo.bar, foo.bar}
        when {Int32, Char}
        when {Int32, Int32}
        when {Char, Int32}
        when {Char, Char}
        end
      )
  end
end

private def bool_case_eq
  <<-CODE
  struct Bool
    def ===(other)
      true
    end
  end
  CODE
end

private def enum_eq
  <<-CODE
  struct Enum
    def ==(other : self)
      value == other.value
    end

    def ===(other)
      true
    end
  end
  CODE
end
