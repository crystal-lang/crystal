require "../../../spec_helper"
include Crystal

def processed_unreachable_visitor(code)
  compiler = Compiler.new
  compiler.no_codegen = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = UnreachableVisitor.new(".")
  process_result = visitor.process(result)

  {visitor, process_result}
end

private def assert_unreachable(code)
  expected_locations = [] of Location

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('༓')
      expected_locations << Location.new(".", line_number_0 + 1, column_number + 1)
    end
  end

  code = code.gsub('༓', "")

  visitor, result = processed_unreachable_visitor(code)

  result_location = result.locations.try(&.map(&.to_s).sort!)

  result_location.should eq(expected_locations.map(&.to_s))
end

# References
#
#   ༓ marks the expected unreachable code to be found
#
describe "unreachable" do
  it "find top level methods" do
    assert_unreachable %(
      ༓def foo
        1
      end

      def bar
        2
      end

      bar
    )
  end

  it "find instance methods" do
    assert_unreachable %(
      class Foo
        ༓def foo
          1
        end

        def bar
          2
        end
      end

      Foo.new.bar
    )
  end

  it "find class methods" do
    assert_unreachable %(
      class Foo
        ༓def self.foo
          1
        end

        def self.bar
          2
        end
      end

      Foo.bar
    )
  end

  it "find instance methods in nested types" do
    assert_unreachable %(
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
    )
  end

  # TODO macro expanded methods
  # TODO generic types
  # TODO methods with blocks does not have typed_def, we need to search for calls
end
