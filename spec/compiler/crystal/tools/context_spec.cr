require "../../../spec_helper"

private def processed_context_visitor(code, cursor_location)
  compiler = Compiler.new
  compiler.no_codegen = true
  compiler.prelude = "empty"
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = ContextVisitor.new(cursor_location)
  process_result = visitor.process(result)

  {visitor, process_result}
end

private def run_context_tool(code, &)
  cursor_location = nil

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      cursor_location = Location.new(".", line_number_0 + 1, column_number + 1)
    end
  end

  code = code.delete('‸')

  if cursor_location
    visitor, result = processed_context_visitor(code, cursor_location)

    yield result
  else
    raise "no cursor found in spec"
  end
end

private def assert_context_keys(code, *variables)
  run_context_tool(code) do |result|
    result.contexts.should_not be_nil
    result.contexts.not_nil!.each do |context|
      context.keys.should eq(variables.to_a)
    end
  end
end

private def assert_context_includes(code, variable, var_types)
  run_context_tool(code) do |result|
    result.contexts.should_not be_nil
    result.contexts.not_nil!.map(&.[variable].to_s).should eq(var_types)
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
        def lorem
          @lorem
        end

        def initialize(@lorem : Int64)
        end
      end

      def foo(f)
      end

      f = Foo.new(1i64)

      foo f.lo‸rem
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
      def match
        $~ = "match"
      end

      def foo
        s = "foo"
        match
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
    a = 1_i64.as(Int64 | String)
    ‸
    0
    ), "a", ["(Int64 | String)"]
  end

  it "can display text output" do
    run_context_tool(%(
    a = 1_i64.as(Int64 | String)
    ‸
    0
    )) do |result|
      String::Builder.build do |io|
        result.to_text(io)
      end.should eq %(1 possible context found

| Expr | Type           |
-------------------------
| a    | Int64 | String |
)
    end
  end

  it "can display json output" do
    run_context_tool(%(
    a = 1_i64.as(Int64 | String)
    ‸
    0
    )) do |result|
      String::Builder.build do |io|
        result.to_json(io)
      end.should eq %({"status":"ok","message":"1 possible context found","contexts":[{"a":"Int64 | String"}]})
    end
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

  it "can get context of yielded block" do
    assert_context_keys %(
    def foo(a)
      b = a + 1
      ‸
      yield b
    end

    foo 1 do |x|
    end
    ), "a", "b"
  end

  it "can get context of nested yielded block" do
    assert_context_keys %(
    def foo(a)
      b = a + 1
      ‸
      yield b
    end

    def bar
      foo 1 do |x|
        yield x
      end
    end

    bar do |y|
    end
    ), "a", "b"
  end

  it "can get context inside a module" do
    assert_context_includes %(
    module Foo
      class Bar
        def bar(o)
          ‸
        end
      end
    end

    Foo::Bar.new.bar("foo")
    ), "o", ["String"]
  end

  it "can get context inside class methods" do
    assert_context_includes %(
    class Bar
      def self.bar(o)
        ‸
      end
    end

    Bar.bar("foo")
    ), "o", ["String"]
  end

  it "can get context inside initialize" do
    assert_context_keys %(
    class Bar
      def initialize(@ivar : String)
        ‸
      end
    end

    Bar.new("s")
    ), "self", "@ivar", "ivar"
  end

  it "can get context in generic class" do
    assert_context_keys %(
    class Foo(T, S)
      def foo(a)
        ‸
      end
    end

    Foo(String, Char).new.foo(1)
    ), "T", "S", "self", "a"

    assert_context_includes %(
    class Foo(T, S)
      def foo(a)
        ‸
      end
    end

    Foo(String, Char).new.foo(1)
    ), "T", ["String"]
  end

  it "can get context in contained class' class method" do
    assert_context_keys %(
    module Baz
      class Bar(T)
        class Foo
          def self.bar_foo(a)
            ‸
          end
        end
      end
    end

    Baz::Bar::Foo.bar_foo(1)
    ), "self", "a"
  end

  it "use type filters from is_a?" do
    assert_context_includes %(
    def foo(c)
      if c.is_a?(String)
        ‸
      end
    end

    foo(1 < 0 ? nil : "s")
    ), "c", ["String"]
  end

  it "use type filters from if var" do
    assert_context_includes %(
    def foo(c)
      if c
        ‸
      end
    end

    foo(1 < 0 ? nil : "s")
    ), "c", ["String"]
  end

  it "can get context in file private method" do
    assert_context_keys %(
    private def foo(a)
      ‸
    end

    foo 100
    ), "a"
  end

  it "can get context in file private module" do
    assert_context_keys %(
    private module Foo
      def self.foo(a)
        ‸
      end
    end

    Foo.foo 100
    ), "self", "a"
  end

  it "can't get context from uncalled method" do
    run_context_tool %(
    def foo(value)
      ‸
    end
    ) do |result|
      result.status.should eq("failed")
      result.message.should match(/never called/)
    end
  end
end
