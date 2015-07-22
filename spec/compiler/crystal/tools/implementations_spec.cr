require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

def assert_implementations(code)
  cursor_location = nil
  expected_locations = [] of Location

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      cursor_location = Location.new(line_number_0+1, column_number+1, ".")
    end

    if column_number = line.index('༓')
      expected_locations << Location.new(line_number_0+1, column_number+1, ".")
    end
  end

  code = code.gsub('‸', "").gsub('༓', "")

  if cursor_location
    compiler = Compiler.new
    compiler.no_build = true
    result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

    visitor = ImplementationsVisitor.new(cursor_location)
    visitor.process(result)

    visitor.locations.map(&.to_s).sort.should eq(expected_locations.map(&.to_s))
  else
    raise "no cursor found in spec"
  end
end

# References
#
#   ༓ marks the expected implementations to be found
#   ‸ marks the method call which implementations wants to be found
#
describe "implementations" do
  it "find top level method calls" do
    assert_implementations %(
      ༓def foo
        1
      end

      puts f‸oo
    )
  end

  it "find implementors of different classes" do
    assert_implementations %(
      class A
        ༓def foo
        end
      end

      class B
        ༓def foo
        end
      end

      def bar(o)
        o.f‸oo
      end

      bar(A.new)
      bar(B.new)
    )
  end

  it "find implementors of classes that are only used" do
    assert_implementations %(
      class A
        ༓def foo
        end
      end

      class B
        def foo
        end
      end

      def bar(o)
        o.f‸oo
      end

      bar(A.new)
      B.new
    )
  end
end
