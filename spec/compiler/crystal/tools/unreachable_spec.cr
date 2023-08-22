require "../../../spec_helper"
include Crystal

def processed_unreachable_visitor(code)
  compiler = Compiler.new
  compiler.prelude = "empty"
  compiler.no_codegen = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = UnreachableVisitor.new(".")
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

  result_location = result.defs.try(&.map(&.location.to_s).sort!)

  result_location.should eq(expected_locations.map(&.to_s)), file: file, line: line
end

# References
#
#   ༓ marks the expected unreachable code to be found
#
describe "unreachable" do
  it "find top level methods" do
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

  it "find instance methods" do
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

  it "find class methods" do
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

  it "find instance methods in nested types" do
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

  # TODO: This should be supported
  it "does not find yielding methods" do
    assert_unreachable <<-CR
      def foo
        yield
      end

      def bar
        yield
      end

      bar {}
      CR
  end

  # TODO: This should be supported
  it "does not find methods with proc parameter" do
    assert_unreachable <<-CR
      def foo(&proc : ->)
        proc.call
      end

      def bar(&proc : ->)
        proc.call
      end

      bar {}
      CR
  end

  # TODO: This should be supported
  it "does not find shadowed method (1)" do
    assert_unreachable <<-CR
      def foo
      end

      ༓def foo
      end
      CR
  end

  # TODO: This should be supported
  it "does not find shadowed method (2)" do
    assert_unreachable <<-CR
      def bar
      end

      def bar
      end

      bar
      CR
  end

  # TODO: This should be supported
  it "does not find methods in generic type" do
    assert_unreachable <<-CR
      class Foo(T)
        def foo
          1
        end

        def bar
          2
        end
      end

      Foo(Int32).new.bar
      CR
  end

  # TODO macro expanded methods
  # TODO generic types
  # TODO methods with blocks does not have typed_def, we need to search for calls
end
