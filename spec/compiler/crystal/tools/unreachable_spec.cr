require "../../../spec_helper"
include Crystal

def processed_unreachable_visitor(code)
  compiler = Compiler.new
  compiler.prelude = "empty"
  compiler.no_codegen = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = UnreachableVisitor.new
  visitor.excludes << Dir.current
  visitor.includes << "."

  process_result = visitor.process(result)

  {visitor, process_result}
end

private def assert_unreachable(code, file = __FILE__, line = __LINE__)
  expected_locations = [] of Location

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('༓')
      expected_locations << Location.new(".", line_number_0 + 1, column_number + 1)
    end
  end

  code = code.gsub('༓', "")

  visitor, result = processed_unreachable_visitor(code)

  result_location = result.defs.try &.compact_map(&.location).sort_by! do |loc|
    {loc.filename.as(String), loc.line_number, loc.column_number}
  end.map(&.to_s)

  result_location.should eq(expected_locations.map(&.to_s)), file: file, line: line
end

# References
#
#   ༓ marks the expected unreachable code to be found
#
describe "unreachable" do
  it "finds top level methods" do
    assert_unreachable <<-CR
      ༓def foo
        1
      end

      def bar
        2
      end

      bar
      CR
  end

  it "finds instance methods" do
    assert_unreachable <<-CR
      class Foo
        ༓def foo
          1
        end

        def bar
          2
        end
      end

      Foo.new.bar
      CR
  end

  it "finds class methods" do
    assert_unreachable <<-CR
      class Foo
        ༓def self.foo
          1
        end

        def self.bar
          2
        end
      end

      Foo.bar
      CR
  end

  it "finds instance methods in nested types" do
    assert_unreachable <<-CR
      module Mod
        class Foo
          ༓def foo
            1
          end

          def bar
            2
          end
        end
      end

      Mod::Foo.new.bar
      CR
  end

  it "finds method with free variable" do
    assert_unreachable <<-CR
      ༓def foo(u : U) forall U
      end

      def bar(u : U) forall U
      end

      bar(1)
      CR
  end

  it "finds yielding methods" do
    assert_unreachable <<-CR
      ༓def foo
        yield
      end

      def bar
        yield
      end

      bar {}
      CR
  end

  it "finds method called from block" do
    assert_unreachable <<-CR
      ༓def foo
      end

      def bar
      end

      def baz
        yield
      end

      baz do
        bar
      end
      CR
  end

  it "finds method called from proc" do
    assert_unreachable <<-CR
      ༓def foo
      end

      def bar
      end

      def baz(&proc : ->)
        proc.call
      end

      baz do
        bar
      end
      CR
  end

  it "finds methods with proc parameter" do
    assert_unreachable <<-CR
      ༓def foo(&proc : ->)
        proc.call
      end

      def bar(&proc : ->)
        proc.call
      end

      bar {}
      CR
  end

  it "finds shadowed method (1)" do
    assert_unreachable <<-CR
      ༓def foo
      end

      ༓def foo
      end

      ༓def bar
      end

      def bar
      end

      bar
      CR
  end

  it "finds method with `previous_def`" do
    assert_unreachable <<-CR
      ༓def foo
      end

      ༓def foo
        previous_def
      end

      def bar
      end

      def bar
        previous_def
      end

      bar
      CR
  end

  it "finds methods called from reachable code" do
    assert_unreachable <<-CR
      ༓def qux_foo
      end

      ༓def foo
        qux_foo
      end

      def qux_bar
      end

      def bar
        qux_bar
      end

      bar
      CR
  end

  it "does not finds method with `super`" do
    assert_unreachable <<-CR
      class Foo
        ༓def foo
        end

        def bar
        end
      end

      class Qux < Foo
        ༓def foo
          super
        end

        def bar
          super
        end
      end

      Qux.new.bar
      CR
  end

  it "finds methods in generic type" do
    assert_unreachable <<-CR
      class Foo(T)
        ༓def foo
          1
        end

        def bar
          2
        end
      end

      Foo(Int32).new.bar
      CR
  end

  it "finds method in abstract type" do
    assert_unreachable <<-CR
      abstract class Foo
        ༓def foo
        end

        def bar
        end
      end

      class Baz < Foo
      end

      Baz.new.bar
      CR
  end

  # TODO: Should abstract Foo#bar be reported as well?
  it "finds abstract method" do
    assert_unreachable <<-CR
      abstract class Foo
        abstract def foo

        abstract def bar
      end

      class Baz < Foo
        ༓def foo
        end

        def bar
        end
      end

      Baz.new.bar
      CR
  end

  it "finds virtual method" do
    assert_unreachable <<-CR
      abstract class Foo
        ༓def foo
        end

        def bar
        end
      end

      class Baz < Foo
      end

      class Qux < Foo
        ༓def foo
        end

        def bar
        end
      end

      Baz.new.as(Baz | Qux).bar
      CR
  end

  it "ignores autogenerated enum predicates" do
    assert_unreachable <<-CR
      enum Foo
        BAR
        BAZ

        ༓def foo
        end
      end
      CR
  end

  it "finds method called from instance variable initializer" do
    assert_unreachable <<-CR
      ༓def foo
      end

      def bar
        1
      end

      class Foo
        @status = Bar.new
        @other : Int32 = bar
      end

      class Bar
        def initialize
        end
      end

      Foo.new
    CR
  end

  it "finds mathod called from expanded macro" do
    assert_unreachable <<-CR
      ༓def foo
      end

      def bar
      end

      macro bar_macro
        bar
      end

      def go(&block)
        block.call
      end

      go { bar_macro }
      CR
  end
end
