require "../../spec_helper"

describe "Semantic: case" do
  it "checks exhaustiveness of union type" do
    assert_warning %(
        a = 1 || nil
        case a
        when Int32
        end
      ),
      "warning in line 4\nWarning: case is not exhaustive.\n\nMissing types: Nil"
  end

  it "checks exhaustiveness of single type" do
    assert_warning %(
        case 1
        when Nil
        end
      ),
      "warning in line 3\nWarning: case is not exhaustive.\n\nMissing types: Int32"
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
        struct Bool
          def ===(other)
            true
          end
        end

        case false
        when false
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases: true"
  end

  it "checks exhaustiveness of bool type (missing false)" do
    assert_warning %(
        struct Bool
          def ===(other)
            true
          end
        end

        case false
        when true
        end
      ),
      "warning in line 9\nWarning: case is not exhaustive.\n\nMissing cases: false"
  end

  it "checks exhaustiveness of enum via question method" do
    assert_warning %(
        struct Enum
          def ==(other : self)
            value == other.value
          end
        end

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
      "warning in line 16\nWarning: case is not exhaustive for enum Color.\n\nMissing members: Green, Blue"
  end

  it "checks exhaustiveness of enum via const" do
    assert_warning %(
        struct Enum
          def ==(other : self)
            value == other.value
          end

          def ===(other)
            true
          end
        end

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
      "warning in line 20\nWarning: case is not exhaustive for enum Color.\n\nMissing members: Green, Blue"
  end

  it "checks exhaustiveness of enum (all cases covered)" do
    assert_no_warnings %(
        struct Enum
          def ==(other : self)
            value == other.value
          end
        end

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
        struct Bool
          def ===(other)
            true
          end
        end

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
      "warning in line 10\nWarning: case is not exhaustive.\n\nMissing types: Int32"
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

  it "always warns on condless case without else" do
    assert_warning %(
        case
        when 1 == 2
        when 3 == 4
        end
      ),
      "warning in line 3\nWarning: case without condition must have an `else` clause."
  end

  it "always requires an else for Flags enum" do
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

  it "checks exhaustiveness of enum combined with another type" do
    assert_warning %(
        struct Enum
          def ==(other : self)
            value == other.value
          end
        end

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
      "warning in line 16\nWarning: case is not exhaustive for enum Color.\n\nMissing members: Green, Blue"
  end

  it "checks exhaustiveness of union with bool" do
    assert_warning %(
        struct Bool
          def ===(other)
            true
          end
        end

        e = 1 || true
        case e
        when true
        end
      ),
      "warning in line 10\nWarning: case is not exhaustive.\n\nMissing cases: false, Int32"
  end
end
