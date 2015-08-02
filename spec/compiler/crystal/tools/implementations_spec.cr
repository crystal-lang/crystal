require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

module Crystal
  class Location
    def top_location
      f = filename
      if f.is_a?(VirtualFile)
        loc = f.expanded_location
        if loc
          loc.top_location
        else
          nil
        end
      else
        self
      end
    end
  end
end

def processed_implementation_visitor(code, cursor_location)
  compiler = Compiler.new
  compiler.no_build = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = ImplementationsVisitor.new(cursor_location)
  process_result = visitor.process(result)

  {visitor, process_result}
end

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
    visitor, _ = processed_implementation_visitor(code, cursor_location)

    visitor.locations.map(&.top_location.to_s).sort.should eq(expected_locations.map(&.to_s))
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

  it "find method calls inside while" do
    assert_implementations %(
      ༓def foo
        1
      end

      while false
        f‸oo
      end
    )
  end

  it "find method calls inside while cond" do
    assert_implementations %(
      ༓def foo
        1
      end

      while f‸oo
        puts 2
      end
    )
  end

  it "find method calls inside if" do
    assert_implementations %(
      ༓def foo
        1
      end

      if f‸oo
        puts 2
      end
    )
  end

  it "find method calls inside trailing if" do
    assert_implementations %(
      ༓def foo
        1
      end

      puts 2 if f‸oo
    )
  end

  it "find method calls inside rescue" do
    assert_implementations %(
      ༓def foo
        1
      end

      begin
        puts 2
      rescue
        f‸oo
      end
    )
  end

  it "find implementation from macro expansions" do
    assert_implementations %(
      macro foo
        def bar
        end
      end

      macro baz
        foo
      end

      ༓baz
      b‸ar
    )
  end

  it "find full trace for macro expansions" do
    visitor, result = processed_implementation_visitor(%(
      macro foo
        def bar
        end
      end

      macro baz
        foo
      end

      baz
      bar
    ), Location.new(12, 9, "."))

    result.implementations.should_not be_nil
    impls = result.implementations.not_nil!
    impls.size.should eq(1)

    impls[0].line.should eq(11) # location of baz
    impls[0].column.should eq(7)
    impls[0].filename.should eq(".")

    impls[0].expands.should_not be_nil
    exp = impls[0].expands.not_nil!
    exp.line.should eq(8) # location of foo call in macro baz
    exp.column.should eq(9)
    exp.macro.should eq("baz")
    exp.filename.should eq(".")

    exp.expands.should_not be_nil
    exp = exp.expands.not_nil!
    exp.line.should eq(3) # location of def bar in macro foo
    exp.column.should eq(9)
    exp.macro.should eq("foo")
    exp.filename.should eq(".")
  end
end
