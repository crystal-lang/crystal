require "../../../spec_helper"

private def processed_expand_visitor(code, cursor_location)
  compiler = Compiler.new
  compiler.no_codegen = true
  compiler.no_cleanup = true
  compiler.wants_doc = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = ExpandVisitor.new(cursor_location)
  process_result = visitor.process(result)

  {visitor, process_result}
end

private def run_expand_tool(code)
  cursor_location = nil

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      cursor_location = Location.new(".", line_number_0 + 1, column_number + 1)
    end
  end

  code = code.gsub('‸', "")

  if cursor_location
    visitor, result = processed_expand_visitor(code, cursor_location)

    yield result
  else
    raise "no cursor found in spec"
  end
end

private def expansion_to_a(expansion)
  [expansion.original_source].concat(expansion.expanded_sources)
end

private def assert_expand(code, expected_result)
  assert_expand(code, expected_result) { }
end

private def assert_expand(code, expected_result)
  run_expand_tool code do |result|
    result.status.should eq("ok")
    result.message.should eq("#{expected_result.size} expansion#{expected_result.size >= 2 ? "s" : ""} found")
    result.expansions.not_nil!.zip(expected_result) do |expansion, expected_result|
      expansion_to_a(expansion).zip(expected_result) do |result, expected|
        result.should eq(expected)
      end
    end

    yield result
  end
end

private def assert_expand_simple(code, expanded, original = code.gsub('‸', ""))
  assert_expand_simple(code, expanded, original) { }
end

private def assert_expand_simple(code, expanded, original = code.gsub('‸', ""))
  assert_expand(code, [[original, expanded]]) { |result| yield result.expansions.not_nil![0] }
end

private def assert_expand_fail(code, message = "no expansion found")
  run_expand_tool code do |result|
    result.status.should eq("failed")
    result.message.should eq(message)
  end
end

describe "expand" do
  it "expands macro expression {{ ... }}" do
    code = "‸{{ 1 + 2 }}"

    assert_expand_simple code, "3"
  end

  it "expands macro expression {{ ... }} with cursor inside it" do
    code = "{{ 1 ‸+ 2 }}"

    assert_expand_simple code, "3"
  end

  it "expands macro expression {{ ... }} with cursor end of it" do
    code = "{{ 1 + 2 }‸}"

    assert_expand_simple code, "3"
  end

  it "expands macro expression {% ... %}" do
    code = %(‸{% "test" %})

    assert_expand_simple code, ""
  end

  it "expands macro expression {% ... %} with cursor at end of it" do
    code = %({% "test" ‸%})

    assert_expand_simple code, ""
  end

  it "expands macro control {% if %}" do
    code = <<-CODE
    {%‸ if 1 == 1 %}
      true
    {% end %}
    CODE

    assert_expand_simple code, "true"
  end

  it "expands macro control {% if %} with cursor inside it" do
    code = <<-CODE
    {% if 1 == 1 %}
      tr‸ue
    {% end %}
    CODE

    assert_expand_simple code, "true"
  end

  it "expands macro control {% if %} with cursor at end of it" do
    code = <<-CODE
    {% if 1 == 1 %}
      true
    {% end ‸%}
    CODE

    assert_expand_simple code, "true"
  end

  it "expands macro control {% if %} with indent" do
    code = <<-CODE
    begin
      {% if 1 == 1 %}
        t‸rue
      {% end %}
    end
    CODE

    original = <<-CODE
    {% if 1 == 1 %}
      true
    {% end %}
    CODE

    assert_expand_simple code, original: original, expanded: "true"
  end

  it "expands macro control {% for %}" do
    code = <<-CODE
    {% f‸or x in 1..3 %}
      {{ x }}
    {% end %}
    CODE

    assert_expand_simple code, "1\n2\n3\n"
  end

  it "expands macro control {% for %} with cursor inside it" do
    code = <<-CODE
    {% for x in 1..3 %}
     ‸ {{ x }}
    {% end %}
    CODE

    assert_expand_simple code, "1\n2\n3\n"
  end

  it "expands macro control {% for %} with cursor at end of it" do
    code = <<-CODE
    {% for x in 1..3 %}
      {{ x }}
    ‸{% end %}
    CODE

    assert_expand_simple code, "1\n2\n3\n"
  end

  it "expands macro control {% for %} with indent" do
    code = <<-CODE
    begin
      {% f‸or x in 1..3 %}
        {{ x }}
      {% end %}
    end
    CODE

    original = <<-CODE
    {% for x in 1..3 %}
      {{ x }}
    {% end %}
    CODE

    assert_expand_simple code, original: original, expanded: "1\n2\n3\n"
  end

  it "expands simple macro" do
    code = <<-CODE
    macro foo
      1
    end

    ‸foo
    CODE

    assert_expand_simple code, original: "foo", expanded: "1" do |expansion|
      expansion.expanded_macros.size.should eq(1)
      macros = expansion.expanded_macros[0]
      macros.size.should eq(1)

      a_macro = macros[0]
      a_macro[:name].should eq("foo")
      a_macro[:implementation].filename.should eq(".")
      a_macro[:implementation].line.should eq(1)
      a_macro[:implementation].column.should eq(1)
    end
  end

  it "expands simple macro with cursor inside it" do
    code = <<-CODE
    macro foo
      1
    end

    f‸oo
    CODE

    assert_expand_simple code, original: "foo", expanded: "1"
  end

  it "expands simple macro with cursor at end of it" do
    code = <<-CODE
    macro foo
      1
    end

    fo‸o
    CODE

    assert_expand_simple code, original: "foo", expanded: "1"
  end

  it "expands complex macro" do
    code = <<-CODE
    macro foo
      {% if true %}
        "if true"
      {% end %}
      {% for x in %w(1 2 3) %}
        {{ x }}
      {% end %}
    end

    ‸foo
    CODE

    assert_expand_simple code, original: "foo", expanded: %("if true"\n"1"\n"2"\n"3"\n)
  end

  it "expands macros with 2 level" do
    code = <<-CODE
    macro foo
      :foo
    end

    macro bar
      foo
      :bar
    end

    b‸ar
    CODE

    assert_expand code, [["bar", "foo\n:bar\n", ":foo\n:bar\n"]] do |result|
      expansion = result.expansions.not_nil![0]

      macros = expansion.expanded_macros
      macros.size.should eq(2)
      macros[0].size.should eq(1)
      macros[1].size.should eq(1)

      macro1 = macros[0][0]
      macro1[:name].should eq("bar")
      macro1[:implementation].filename.should eq(".")
      macro1[:implementation].line.should eq(5)
      macro1[:implementation].column.should eq(1)

      macro2 = macros[1][0]
      macro2[:name].should eq("foo")
      macro2[:implementation].filename.should eq(".")
      macro2[:implementation].line.should eq(1)
      macro2[:implementation].column.should eq(1)
    end
  end

  it "expands macros with 3 level" do
    code = <<-CODE
    macro foo
      :foo
    end

    macro bar
      foo
      :bar
    end

    macro baz
      foo
      bar
      :baz
    end

    ba‸z
    CODE

    assert_expand code, [["baz", "foo\nbar\n:baz\n", ":foo\nfoo\n:bar\n:baz\n", ":foo\n:foo\n:bar\n:baz\n"]] do |result|
      expansion = result.expansions.not_nil![0]

      macros = expansion.expanded_macros
      macros.size.should eq(3)
      macros[0].size.should eq(1)
      macros[1].size.should eq(2)
      macros[2].size.should eq(1)

      macro1 = macros[0][0]
      macro1[:name].should eq("baz")
      macro1[:implementation].filename.should eq(".")
      macro1[:implementation].line.should eq(10)
      macro1[:implementation].column.should eq(1)

      macro2 = macros[1][0]
      macro2[:name].should eq("foo")
      macro2[:implementation].filename.should eq(".")
      macro2[:implementation].line.should eq(1)
      macro2[:implementation].column.should eq(1)

      macro3 = macros[1][1]
      macro3[:name].should eq("bar")
      macro3[:implementation].filename.should eq(".")
      macro3[:implementation].line.should eq(5)
      macro3[:implementation].column.should eq(1)

      macro4 = macros[2][0]
      macro4[:name].should eq("foo")
      macro4[:implementation].filename.should eq(".")
      macro4[:implementation].line.should eq(1)
      macro4[:implementation].column.should eq(1)
    end
  end

  it "expands macro of module" do
    code = <<-CODE
    module Foo
      macro foo
        :Foo
        :foo
      end
    end

    Foo.f‸oo
    CODE

    assert_expand_simple code, original: "Foo.foo", expanded: ":Foo\n:foo\n" do |expansion|
      expansion.expanded_macros.size.should eq(1)
      macros = expansion.expanded_macros[0]
      macros.size.should eq(1)

      a_macro = macros[0]
      a_macro[:name].should eq("Foo.foo")
      a_macro[:implementation].filename.should eq(".")
      a_macro[:implementation].line.should eq(2)
      a_macro[:implementation].column.should eq(3)
    end
  end

  it "expands macro of module with cursor at module name" do
    code = <<-CODE
    module Foo
      macro foo
        :Foo
        :foo
      end
    end

    F‸oo.foo
    CODE

    assert_expand_simple code, original: "Foo.foo", expanded: ":Foo\n:foo\n"
  end

  it "expands macro of module with cursor at dot" do
    code = <<-CODE
    module Foo
      macro foo
        :Foo
        :foo
      end
    end

    Foo‸.foo
    CODE

    assert_expand_simple code, original: "Foo.foo", expanded: ":Foo\n:foo\n"
  end

  it "expands macro of module inside module" do
    code = <<-CODE
    module Foo
      macro foo
        :Foo
        :foo
      end

      f‸oo
    end
    CODE

    assert_expand_simple code, original: "foo", expanded: ":Foo\n:foo\n"
  end

  %w(module class struct enum lib).each do |keyword|
    it "expands macro expression inside #{keyword}" do
      code = <<-CODE
      #{keyword} Foo
        ‸{{ "Foo = 1".id }}
      end
      CODE

      assert_expand_simple code, original: %({{ "Foo = 1".id }}), expanded: "Foo = 1"
    end

    it "expands macro expression inside private #{keyword}" do
      code = <<-CODE
      private #{keyword} Foo
        ‸{{ "Foo = 1".id }}
      end
      CODE

      assert_expand_simple code, original: %({{ "Foo = 1".id }}), expanded: "Foo = 1"
    end

    unless keyword == "lib"
      it "expands macro expression inside def of private #{keyword}" do
        code = <<-CODE
        private #{keyword} Foo
          Foo = 1
          def self.foo
            {{ :‸foo }}
          end
        end

        Foo.foo
        CODE

        assert_expand_simple code, original: "{{ :foo }}", expanded: ":foo"
      end
    end
  end

  %w(struct union).each do |keyword|
    it "expands macro expression inside C #{keyword}" do
      code = <<-CODE
      lib Foo
        #{keyword} Foo
          ‸{{ "Foo = 1".id }}
        end
      end
      CODE

      assert_expand_simple code, original: %({{ "Foo = 1".id }}), expanded: "Foo = 1"
    end

    it "expands macro expression inside C #{keyword} of private lib" do
      code = <<-CODE
      private lib Foo
        #{keyword} Foo
          ‸{{ "Foo = 1".id }}
        end
      end
      CODE

      assert_expand_simple code, original: %({{ "Foo = 1".id }}), expanded: "Foo = 1"
    end
  end

  ["", "private "].each do |prefix|
    it "expands macro expression inside #{prefix}def" do
      code = <<-CODE
      #{prefix}def foo(x : T) forall T
        ‸{{ T }}
      end

      foo 1
      foo "bar"
      CODE

      assert_expand code, [
        ["{{ T }}", "Int32"],
        ["{{ T }}", "String"],
      ]
    end

    it "expands macro expression inside def of #{prefix}module" do
      code = <<-CODE
      #{prefix}module Foo(T)
        def self.foo
          {{ ‸T }}
        end
      end

      Foo(Int32).foo
      Foo(String).foo
      Foo(1).foo
      CODE

      assert_expand code, [
        ["{{ T }}", "Int32"],
        ["{{ T }}", "String"],
        ["{{ T }}", "1"],
      ]
    end

    it "expands macro expression inside def of nested #{prefix}module" do
      code = <<-CODE
      #{prefix}module Foo
        #{prefix}module Bar(T)
          def self.foo
            {{ ‸T }}
          end
        end

        Bar(Int32).foo
        Bar(String).foo
        Bar(1).foo
      end
      CODE

      assert_expand code, [
        ["{{ T }}", "Int32"],
        ["{{ T }}", "String"],
        ["{{ T }}", "1"],
      ]
    end
  end

  it "expands macro expression inside fun" do
    code = <<-CODE
    fun foo
      {{ :foo‸ }}
    end
    CODE

    assert_expand_simple code, original: "{{ :foo }}", expanded: ":foo"
  end

  it "doesn't expand macro expression" do
    code = <<-CODE
    {{ 1 + 2 }}
    ‸
    CODE

    assert_expand_fail code
  end

  it "doesn't expand macro expression with cursor out of end" do
    code = <<-CODE
    {{ 1 + 2 }}‸
    CODE

    assert_expand_fail code
  end

  it "doesn't expand macro expression" do
    code = <<-CODE
    ‸  {{ 1 + 2 }}
    CODE

    assert_expand_fail code
  end

  it "doesn't expand normal call" do
    code = <<-CODE
    def foo
      1
    end

    ‸foo
    CODE

    assert_expand_fail code, "no expansion found: foo may not be a macro"
  end

  it "expands macro with doc" do
    code = <<-CODE
    macro foo(x)
      # string of {{ x }}
      def {{ x }}_str
        {{ x.stringify }}
      end
      # symbol of {{ x }}
      def {{ x }}_sym
        {{ x.symbolize }}
      end
    end

    ‸foo(hello)
    CODE

    expanded = <<-CODE
    # string of hello
    def hello_str
      "hello"
    end
    # symbol of hello
    def hello_sym
      :hello
    end
    CODE

    assert_expand_simple code, original: "foo(hello)", expanded: expanded + '\n'
  end
end
