require "../../../spec_helper"
include Crystal

def processed_unreachable_visitor(code)
  compiler = Compiler.new
  compiler.prelude = "empty"
  compiler.no_codegen = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = UnreachableVisitor.new
  visitor.excludes << Path[Dir.current].to_posix.to_s
  visitor.includes << "."

  visitor.process(result)
end

private def assert_unreachable(code, file = __FILE__, line = __LINE__)
  expected = Hash(String, Int32).new

  code.lines.each_with_index do |line, line_number_0|
    if match = line.match(/༓(?:\[(\d+)\])?/)
      location = Location.new(".", line_number_0 + 1, match.begin + 1)
      expected[location.to_s] = (match[1]? || 0).to_i
    end
  end

  code = code.gsub(/༓(?:\[(\d+)\])?/, "")

  tallies = processed_unreachable_visitor(code)

  processed_results = [] of {Location, Int32}
  tallies.each do |k, v|
    location = k.location.not_nil!
    next unless v.zero? || expected.has_key?(location.to_s)
    processed_results << {location, v}
  end

  processed_results = processed_results.sort_by! do |loc, v|
    {loc.filename.as(String), loc.line_number, loc.column_number}
  end.map { |k, v| {k.to_s, v} }

  processed_results.should eq(expected.to_a), file: file, line: line
end

# References
#
#   ༓ marks the expected unreachable code to be found
#   ༓[n] marks the expected code to be called n times
#
describe "unreachable" do
  it "finds top level methods" do
    assert_unreachable <<-CRYSTAL
      ༓def foo
        1
      end

      def bar
        2
      end

      bar
      CRYSTAL
  end

  it "finds instance methods" do
    assert_unreachable <<-CRYSTAL
      class Foo
        ༓def foo
          1
        end

        def bar
          2
        end
      end

      Foo.new.bar
      CRYSTAL
  end

  it "finds class methods" do
    assert_unreachable <<-CRYSTAL
      class Foo
        ༓def self.foo
          1
        end

        def self.bar
          2
        end
      end

      Foo.bar
      CRYSTAL
  end

  it "finds instance methods in nested types" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds initializer" do
    assert_unreachable <<-CRYSTAL
      class Foo
        ༓def initialize
        end
      end

      class Bar
        def initialize
        end
      end

      Bar.new
      CRYSTAL
  end

  it "finds method with free variable" do
    assert_unreachable <<-CRYSTAL
      ༓def foo(u : U) forall U
      end

      def bar(u : U) forall U
      end

      bar(1)
      CRYSTAL
  end

  it "finds yielding methods" do
    assert_unreachable <<-CRYSTAL
      ༓def foo
        yield
      end

      def bar
        yield
      end

      bar {}
      CRYSTAL
  end

  it "finds method called from block" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds method called from proc" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds methods with proc parameter" do
    assert_unreachable <<-CRYSTAL
      ༓def foo(&proc : ->)
        proc.call
      end

      def bar(&proc : ->)
        proc.call
      end

      bar {}
      CRYSTAL
  end

  it "finds shadowed method" do
    assert_unreachable <<-CRYSTAL
      ༓def foo
      end

      ༓def foo
      end

      ༓def bar
      end

      def bar
      end

      bar
      CRYSTAL
  end

  it "finds method with `previous_def`" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds methods called from reachable code" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds method with `super`" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds methods in generic type" do
    assert_unreachable <<-CRYSTAL
      class Foo(T)
        ༓def foo
          1
        end

        def bar
          2
        end
      end

      Foo(Int32).new.bar
      CRYSTAL
  end

  it "finds method in abstract type" do
    assert_unreachable <<-CRYSTAL
      abstract class Foo
        ༓def foo
        end

        def bar
        end
      end

      class Baz < Foo
      end

      Baz.new.bar
      CRYSTAL
  end

  # TODO: Should abstract Foo#bar be reported as well?
  it "finds abstract method" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds virtual method" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "ignores autogenerated enum predicates" do
    assert_unreachable <<-CRYSTAL
      enum Foo
        BAR
        BAZ

        ༓def foo
        end
      end
      CRYSTAL
  end

  it "finds method called from instance variable initializer" do
    assert_unreachable <<-CRYSTAL
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
    CRYSTAL
  end

  it "finds method called from expanded macro" do
    assert_unreachable <<-CRYSTAL
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
      CRYSTAL
  end

  it "finds method called from expanded macro expression" do
    assert_unreachable <<-CRYSTAL
      ༓def foo
      end

      def bar
      end

      {% begin %}
        bar
      {% end %}
      CRYSTAL
  end

  it "tallies calls" do
    assert_unreachable <<-CRYSTAL
      ༓def foo
        1
      end

      ༓[2]def bar
        2
      end

      ༓[1]def baz
        bar
      end

      bar
      baz
      CRYSTAL
  end
end
