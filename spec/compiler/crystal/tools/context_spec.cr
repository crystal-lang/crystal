require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

def processed_context_visitor(code, cursor_location)
  compiler = Compiler.new
  compiler.no_codegen = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = ContextVisitor.new(cursor_location)
  process_result = visitor.process(result)

  {visitor, process_result}
end

def run_context_tool(code)
  cursor_location = nil

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      cursor_location = Location.new(line_number_0+1, column_number+1, ".")
    end
  end

  code = code.gsub('‸', "")

  if cursor_location
    visitor, result = processed_context_visitor(code, cursor_location)

    yield result
  else
    raise "no cursor found in spec"
  end
end

def assert_context_keys(code, *variables)
  run_context_tool(code) do |result|
    result.contexts.should_not be_nil
    result.contexts.not_nil!.each do |context|
      context.keys.should eq(variables.to_a)
    end
  end
end

def assert_context_includes(code, variable, var_types)
  run_context_tool(code) do |result|
    result.contexts.should_not be_nil
    result.contexts.not_nil!.map { |h| h[variable].to_s }.should eq(var_types)
  end
end

# References
#
#   ‸ marks location of the cursor to use
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

  it "includes block args" do
    assert_context_includes %(
      def bar(x)
        yield x
      end

      def foo(a)
        bar a do |b|
          ‸
          1
        end
        1
      end

      foo(1i64)
      foo("foo")
    ), "b", ["Int64", "String"]
  end

  it "includes top level vars" do
    assert_context_includes %(
      a = 0i64
      ‸
      1
    ), "a", ["Int64"]
  end

  it "includes last call" do
    assert_context_includes %(
      class Foo
        property lorem

        def initialize(@lorem : Int64)
        end
      end

      f = Foo.new(1i64)

      puts f.lo‸rem
      1
    ), "f.lorem", ["Int64"]
  end

  it "does not includes temp variables" do
    assert_context_keys %(
      a = 0i64
      ‸
      1
    ), "a"
  end

  it "does includes regex special variables" do
    assert_context_keys %(
      def foo
        s = "string"
        s =~ /s/
        ‸
        0
      end

      foo
    ), "s", "$~"
  end

  it "does includes self on classes" do
    assert_context_includes %(
      class Foo
        def foo
          ‸
          0
        end
      end

      f = Foo.new
      f.foo
      0
    ), "self", ["Foo"]
  end

  it "does includes args, instance vars, local variables and expressions on instance methods" do
    assert_context_keys %(
      class Foo
        def foo(the_arg)
          @ivar = 2
          the_arg.fo‸o(self)
          0
        end
      end

      f = Foo.new
      f.foo(Foo.new)
      0
    ), "self", "@ivar", "the_arg", "the_arg.foo(self)"
  end

  it "can handle union types" do
    assert_context_includes %(
    a = if rand() > 0
      1i64
    else
      "foo"
    end
    ‸
    0
    ), "a", ["(String | Int64)"]
  end

  it "can get context of empty def" do
    assert_context_includes %(
    def foo(a)
      ‸
    end

    foo(0i64)
    ), "a", ["Int64"]
  end

  it "can get context of empty yielded block" do
    assert_context_includes %(
    def it_like
      yield
    end

    it_like do
      a = 1i64‸
    end
    ), "a", ["Int64"]
  end
end
