require "../../spec_helper"

describe "semantic: case" do
  it "doesn't check exhaustiveness when using 'when'" do
    assert_no_errors %(
        a = 1 || nil
        case a
        when Int32
        end
      )
  end

  it "checks exhaustiveness of single type" do
    assert_error %(
        case 1
        in Nil
        end
      ),
      "case is not exhaustive.\n\nMissing types:\n - Int32"
  end

  it "checks exhaustiveness of single type (T.class)" do
    assert_no_errors %(
        case Int32
        in Int32.class
        end
      )
  end

  it "checks exhaustiveness of single type (Foo(T).class)" do
    assert_no_errors %(
        class Foo(T)
        end

        case Foo(Int32)
        in Foo(Int32).class
        end
      )
  end

  it "checks exhaustiveness of single type (generic)" do
    assert_no_errors %(
        class Foo(T)
        end

        case Foo(Int32).new
        in Foo(Int32)
        end
      )
  end

  it "errors if casing against a constant" do
    assert_error %(
        #{bool_case_eq}

        FOO = false

        case true
        in FOO
        end
      ),
      "can't use constant values in exhaustive case, only constant types"
  end

  it "covers all types" do
    assert_no_errors %(
        a = 1 || nil
        case a
        in Int32
        in Nil
        end
      )
  end

  it "checks exhaustiveness of bool type (missing true)" do
    assert_error %(
        #{bool_case_eq}

        case false
        in false
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - true"
  end

  it "checks exhaustiveness of bool type (missing false)" do
    assert_error %(
        #{bool_case_eq}

        case false
        in true
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - false"
  end

  it "checks exhaustiveness of enum via question method" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        in .red?
        end
      ),
      "case is not exhaustive for enum Color.\n\nMissing members:\n - Green\n - Blue", inject_primitives: true
  end

  it "checks exhaustiveness of enum via const" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        in Color::Red
        end
      ),
      "case is not exhaustive for enum Color.\n\nMissing members:\n - Green\n - Blue"
  end

  it "checks exhaustiveness of enum (all cases covered)" do
    assert_no_errors %(
        require "prelude"

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        in .red?
        in .green?
        in .blue?
        end
      )
  end

  it "checks exhaustiveness of enum through method (all cases covered)" do
    assert_no_errors %(
        require "prelude"

        enum Color
          Red
          Green
          Blue
        end

        def foo
          Color::Red
        end

        case foo
        in .red?
        in .green?
        in .blue?
        end
      )
  end

  it "checks exhaustiveness of bool type with other types" do
    assert_no_errors %(
        #{bool_case_eq}

        case 1 || true
        in Int32
        in true
        in false
        end
      )
  end

  it "checks exhaustiveness of union type with virtual type" do
    assert_error %(
        class Foo
        end

        class Bar < Foo
        end

        a = 1 || Foo.new || Bar.new
        case a
        in Foo
        end
      ),
      "case is not exhaustive.\n\nMissing types:\n - Int32"
  end

  it "checks exhaustiveness, covers in base type covers" do
    assert_no_errors %(
        class Foo
        end

        class Bar < Foo
        end

        a = Bar.new
        case a
        in Foo
        end
      )
  end

  it "checks exhaustiveness, covers in base type covers (generic type)" do
    assert_no_errors %(
        class Foo(T)
        end

        a = Foo(Int32).new
        case a
        in Foo
        end
      )
  end

  it "checks exhaustiveness of nil type with nil literal" do
    assert_no_errors %(
        struct Nil
          def ===(other)
            true
          end
        end

        case nil
        in nil
        end
      )
  end

  it "checks exhaustiveness of nilable type with nil literal" do
    assert_no_errors %(
        struct Nil
          def ===(other)
            true
          end
        end

        a = 1 || nil
        case a
        in nil
        in Int32
        end
      )
  end

  it "can't prove case is exhaustive for @[Flags] enum" do
    assert_error %(
        #{enum_eq}

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
        in .red?
        end
      ),
      <<-ERROR
      case is not exhaustive.

      Missing cases:
       - Color

      Note that @[Flags] enum can't be proved to be exhaustive by matching against enum members.
      In particular, the enum Color can't be proved to be exhaustive like that.
      ERROR
  end

  it "can prove case is exhaustive for @[Flags] enum when matching type" do
    assert_no_errors %(
        require "prelude"

        @[Flags]
        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red
        case e
        in Color
        end
      )
  end

  it "can't prove case is exhaustive for @[Flags] enum, tuple case" do
    assert_error %(
        #{enum_eq}

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
        case {e}
        in {.red?}
        end
      ),
      <<-ERROR
      case is not exhaustive.

      Missing cases:
       - {Color}

      Note that @[Flags] enum can't be proved to be exhaustive by matching against enum members.
      In particular, the enum Color can't be proved to be exhaustive like that.
      ERROR
  end

  it "checks exhaustiveness of enum combined with another type" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        e = Color::Red || 1
        case e
        in Int32
        in .red?
        end
      ),
      "case is not exhaustive for enum Color.\n\nMissing members:\n - Green\n - Blue", inject_primitives: true
  end

  it "checks exhaustiveness of union with bool" do
    assert_error %(
        #{bool_case_eq}

        e = 1 || true
        case e
        in true
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - false\n - Int32"
  end

  it "checks exhaustiveness for tuple literal, and passes" do
    assert_no_errors %(
        a = 1 || 'a'
        b = 1 || 'a'

        case {a, b}
        in {Int32, Char}
        in {Int32, Int32}
        in {Char, Int32}
        in {Char, Char}
        end
      )
  end

  it "checks exhaustiveness for tuple literal of 2 elements, and warns" do
    assert_error %(
        a = 1 || 'a'

        case {a, a}
        in {Int32, Char}
        in {Int32, Int32}
        in {Char, Char}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, Int32}"
  end

  it "checks exhaustiveness for tuple literal of 3 elements, and warns" do
    assert_error %(
        a = 1 || 'a'

        case {a, a, a}
        in {Int32, Int32, Int32}
        in {Int32, Char, Int32}
        in {Int32, Char, Char}
        in {Char, Int32, Int32}
        in {Char, Char, Int32}
        in {Char, Char, Char}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, Int32, Char}\n - {Int32, Int32, Char}"
  end

  it "checks exhaustiveness for tuple literal of 2 elements, first is bool" do
    assert_error %(
        #{bool_case_eq}

        case {true, 'a'}
        in {true, Char}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {false, Char}"
  end

  it "checks exhaustiveness for tuple literal of 3 elements, all bool" do
    assert_error %(
        #{bool_case_eq}

        case {true, true, true}
        in {true, true, true}
        end
      ),
      <<-ERROR
      case is not exhaustive.

      Missing cases:
       - {true, true, false}
       - {true, false, Bool}
       - {false, Bool, Bool}
      ERROR
  end

  it "checks exhaustiveness for tuple literal of 2 elements, first is enum" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {Color::Red, 'a'}
        in {.red?, Char}
        in {.blue?, Char}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Color::Green, Char}", inject_primitives: true
  end

  it "checks exhaustiveness for tuple literal of 3 elements, all enums" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {Color::Red, Color::Red, Color::Red}
        in {.red?, .green?, .blue?}
        end
      ),
      <<-ERROR,
      case is not exhaustive.

      Missing cases:
       - {Color::Red, Color::Red, Color}
       - {Color::Red, Color::Green, Color::Red}
       - {Color::Red, Color::Green, Color::Green}
       - {Color::Red, Color::Blue, Color}
       - {Color::Green, Color, Color}
       - {Color::Blue, Color, Color}
      ERROR
      inject_primitives: true
  end

  it "checks exhaustiveness for tuple literal with types and underscore at first position" do
    assert_error %(
        a = 1 || 'a'

        case {a, a}
        in {_, Int32}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, Char}\n - {Int32, Char}"
  end

  it "checks exhaustiveness for tuple literal with types and underscore at second position" do
    assert_error %(
        a = 1 || 'a'

        case {a, a}
        in {Int32, _}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, Char}\n - {Char, Int32}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position" do
    assert_error %(
        #{bool_case_eq}

        case {true, 1 || 'a'}
        in {_, Int32}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Bool, Char}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position, with partial match" do
    assert_error %(
        #{bool_case_eq}

        case {true, 1 || 'a'}
        in {_, Int32}
        in {false, Char}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {true, Char}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position" do
    assert_error %(
        #{bool_case_eq}

        case {1 || 'a', true}
        in {Int32, _}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, Bool}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position, with partial match" do
    assert_error %(
        #{bool_case_eq}

        case {1 || 'a', true}
        in {Int32, _}
        in {Char, false}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, true}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {Color::Red, 1 || 'a'}
        in {_, Int32}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Color, Char}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at first position, partial match" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {Color::Red, 1 || 'a'}
        in {_, Int32}
        in {.blue?, Char}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Color::Red, Char}\n - {Color::Green, Char}", inject_primitives: true
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {1 || 'a', Color::Red}
        in {Int32, _}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, Color}"
  end

  it "checks exhaustiveness for tuple literal with bool and underscore at second position, partial match" do
    assert_error %(
        #{enum_eq}

        enum Color
          Red
          Green
          Blue
        end

        case {1 || 'a', Color::Red}
        in {Int32, _}
        in {Char, .blue?}
        end
      ),
      "case is not exhaustive.\n\nMissing cases:\n - {Char, Color::Red}\n - {Char, Color::Green}", inject_primitives: true
  end

  it "checks exhaustiveness for tuple literal, with call" do
    assert_no_errors %(
        struct Int
          def bar
            1 || 'a'
          end
        end

        foo = 1

        case {foo.bar, foo.bar}
        in {Int32, Char}
        in {Int32, Int32}
        in {Char, Int32}
        in {Char, Char}
        end
      )
  end
end

private def bool_case_eq
  <<-CRYSTAL
  struct Bool
    def ===(other)
      true
    end
  end
  CRYSTAL
end

private def enum_eq
  <<-CRYSTAL
  struct Enum
    def ==(other : self)
      value == other.value
    end

    def ===(other)
      true
    end
  end
  CRYSTAL
end
