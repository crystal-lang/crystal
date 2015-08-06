require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

def processed_context_visitor(code, cursor_location)
  compiler = Compiler.new
  compiler.no_build = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = ContextVisitor.new(cursor_location)
  process_result = visitor.process(result)

  {visitor, process_result}
end

def assert_context_includes(code, variable, var_types)
  cursor_location = nil

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      cursor_location = Location.new(line_number_0+1, column_number+1, ".")
    end
  end

  code = code.gsub('‸', "")

  if cursor_location
    visitor, result = processed_context_visitor(code, cursor_location)

    puts result.inspect
    # puts result.to_json(STDOUT)
    result.contexts.should_not be_nil
    result.contexts.not_nil!.map { |h| h[variable].to_s }.should eq(var_types)
    # t.should_not be_nil
    # t.not_nil!.to_s.should eq(var_type)
  else
    raise "no cursor found in spec"
  end
end

# References
#
#   ༓ marks the expected implementations to be found
#   ‸ marks the method call which implementations wants to be found
#
describe "context" do
  it "includes args" do
    assert_context_includes %(
      def foo(a)
        ‸
        1
      end

      foo(1i64)
    ), "a", ["Int64"]
  end

  it "consider different instances of def" do
    assert_context_includes %(
      def foo(a)
        ‸
        1
      end

      foo(1i64)
      foo("foo")
    ), "a", ["Int64", "String"]
  end

  it "includes assignments" do
    assert_context_includes %(
      def foo(a)
        b = a
        ‸
        1
      end

      foo(1i64)
      foo("foo")
    ), "b", ["Int64", "String"]
  end
end
