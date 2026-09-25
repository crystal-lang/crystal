require "../../spec_helper"

describe "Semantic: method_missing" do
  it "does error in method_missing macro with virtual type" do
    assert_error <<-CRYSTAL, "undefined method 'lala' for Baz"
      abstract class Foo
      end

      class Bar < Foo
        macro method_missing(call)
          2
        end
      end

      class Baz < Foo
      end

      foo = Baz.new || Bar.new
      foo.lala
      CRYSTAL
  end

  it "does error in method_missing if wrong number of params" do
    assert_error <<-CRYSTAL, "wrong number of parameters for macro 'method_missing' (given 2, expected 1)"
      class Foo
        macro method_missing(call, foo)
        end
      end
      CRYSTAL
  end

  it "does method missing for generic type" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        macro method_missing(call)
          1
        end
      end

      Foo(Int32).new.foo
      CRYSTAL
  end

  it "exposes the original call location in method_missing (#7104)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        macro method_missing(call)
          {% raise "missing call location" unless call.filename && call.line_number == 8 && call.column_number == 1 %}
          1
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "points a method_missing call.raise at the original call (#7104)" do
    ex = assert_error(<<-CRYSTAL, "missing bar")
      class Foo
        macro method_missing(call)
          {% call.raise "missing bar" %}
        end
      end

      Foo.new.bar
      CRYSTAL

    ex.to_s.should contain "error in line 7"
    ex.column_number.should eq 9
    ex.size.should eq 3
  end

  it "errors if method_missing expands to an incorrect method" do
    assert_error <<-CRYSTAL, "wrong method_missing expansion"
      class Foo
        macro method_missing(call)
          def baz
            1
          end
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "errors if method_missing expands to multiple methods" do
    assert_error <<-CRYSTAL, "wrong method_missing expansion"
      class Foo
        macro method_missing(call)
          def bar
            1
          end

          def qux
          end
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "finds method_missing with 'with ... yield'" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        macro method_missing(call)
          1
        end
      end

      def bar
        foo = Foo.new
        with foo yield
      end

      bar do
        baz
      end
      CRYSTAL
  end

  it "doesn't look up method_missing in with_yield_scope if call has a receiver (#12097)" do
    assert_error(<<-CRYSTAL, "undefined method 'bar' for Int32")
      class Foo
        macro method_missing(method)
          def {{method}}
            1
          end
        end
      end

      def run
        with Foo.new yield
      end

      run do
        foo.bar
      end
      CRYSTAL
  end
end
