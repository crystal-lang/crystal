require "../../spec_helper"

private STABLE_ABI_TYPES = [
  Nil, Void, Int32, Float32, Bool, Char, Symbol, Pointer(Void),           # primitive scalars
  StaticArray(Int32, 1), Tuple(Int32), NamedTuple(x: Int32), Proc(Int32), # primitive aggregates
  Reference, String,
  Union(Int32, Char), Union(Int32, String), Union(Nil, String), Union(Nil, String, Regex), Union(Nil, Proc(Int32)), # unions
]

private UNSTABLE_ABI_TYPES = [
  Value, Struct, Int, Float,
  Slice, Slice(Int32), Enumerable, Enumerable(Int32), Flags,
  StaticArray(Slice(Int32), 1), Tuple(Slice(Int32)), NamedTuple(x: Slice(Int32)),
  Union(Slice(Int32), Nil),
]

describe "MacroExpander" do
  it "expands simple macro" do
    assert_macro "1 + 2", "1 + 2"
  end

  it "expands macro with string substitution" do
    assert_macro "{{x}}", %("hello"), {x: "hello".string}
  end

  it "expands macro with symbol substitution" do
    assert_macro "{{x}}", ":hello", {x: "hello".symbol}
  end

  it "expands macro with argument-less call substitution" do
    assert_macro "{{x}}", "hello", {x: "hello".call}
  end

  it "expands macro with boolean" do
    assert_macro "{{true}}", "true"
  end

  it "expands macro with integer" do
    assert_macro "{{1}}", "1"
  end

  it "expands macro with char" do
    assert_macro "{{'a'}}", "'a'"
  end

  it "expands macro with string" do
    assert_macro %({{"hello"}}), %("hello")
  end

  it "expands macro with symbol" do
    assert_macro %({{:foo}}), %(:foo)
  end

  it "expands macro with nil" do
    assert_macro %({{nil}}), %(nil)
  end

  it "expands macro with array" do
    assert_macro %({{[1, 2, 3]}}), %([1, 2, 3])
  end

  it "expands macro with hash" do
    assert_macro %({{{:a => 1, :b => 2}}}), "{:a => 1, :b => 2}"
  end

  it "expands macro with tuple" do
    assert_macro %({{{1, 2, 3}}}), %({1, 2, 3})
  end

  it "expands macro with range" do
    assert_macro %({{1..3}}), %(1..3)
  end

  it "expands macro with string interpolation" do
    assert_macro "{{ \"hello\#{1 == 1}world\" }}", %("hellotrueworld")
  end

  it "expands macro with var substitution" do
    assert_macro "{{x}}", "hello", {x: "hello".var}
  end

  it "expands macro with or (1)" do
    assert_macro "{{x || 1}}", "1", {x: NilLiteral.new}
  end

  it "expands macro with or (2)" do
    assert_macro "{{x || 1}}", "hello", {x: "hello".var}
  end

  it "expands macro with and (1)" do
    assert_macro "{{x && 1}}", "nil", {x: NilLiteral.new}
  end

  it "expands macro with and (2)" do
    assert_macro "{{x && 1}}", "1", {x: "hello".var}
  end

  describe "if" do
    it "expands macro with if when truthy" do
      assert_macro "{%if true%}hello{%end%}", "hello"
    end

    it "expands macro with if when falsey" do
      assert_macro "{%if false%}hello{%end%}", ""
    end

    it "expands macro with if else when falsey" do
      assert_macro "{%if false%}hello{%else%}bye{%end%}", "bye"
    end

    it "expands macro with if with nop" do
      assert_macro "{%if x%}hello{%else%}bye{%end%}", "bye", {x: Nop.new}
    end

    it "expands macro with if with not" do
      assert_macro "{%if !true%}hello{%else%}bye{%end%}", "bye"
    end
  end

  describe "for" do
    it "expands macro with for over array literal" do
      assert_macro "{%for e in x %}{{e}}{%end%}", "helloworld", {x: ArrayLiteral.new(["hello".var, "world".var] of ASTNode)}
    end

    it "expands macro with for over array literal with index" do
      assert_macro "{%for e, i in x%}{{e}}{{i}}{%end%}", "hello0world1", {x: ArrayLiteral.new(["hello".var, "world".var] of ASTNode)}
    end

    it "expands macro with for over embedded array literal" do
      assert_macro "{%for e in [1, 2]%}{{e}}{%end%}", "12"
    end

    it "expands macro with for over hash literal" do
      assert_macro "{%for k, v in x%}{{k}}{{v}}{%end%}", "acbd", {x: HashLiteral.new([HashLiteral::Entry.new("a".var, "c".var), HashLiteral::Entry.new("b".var, "d".var)])}
    end

    it "expands macro with for over hash literal with index" do
      assert_macro "{%for k, v, i in x%}{{k}}{{v}}{{i}}{%end%}", "ac0bd1", {x: HashLiteral.new([HashLiteral::Entry.new("a".var, "c".var), HashLiteral::Entry.new("b".var, "d".var)])}
    end

    it "expands macro with for over tuple literal" do
      assert_macro "{%for e, i in x%}{{e}}{{i}}{%end%}", "a0b1", {x: TupleLiteral.new(["a".var, "b".var] of ASTNode)}
    end

    it "expands macro with for over range literal" do
      assert_macro "{%for e in 1..3 %}{{e}}{%end%}", "123"
    end

    it "expands macro with for over range literal, evaluating elements" do
      assert_macro "{%for e in x..y %}{{e}}{%end%}", "3456", {x: 3.int32, y: 6.int32}
    end

    it "expands macro with for over range literal, evaluating elements (exclusive)" do
      assert_macro "{%for e in x...y %}{{e}}{%end%}", "345", {x: 3.int32, y: 6.int32}
    end
  end

  it "does regular if" do
    assert_macro %({{1 == 2 ? 3 : 4}}), "4"
  end

  it "does regular unless" do
    assert_macro %({{unless 1 == 2; 3; else; 4; end}}), "3"
  end

  it "does not expand when macro expression is {% ... %}" do
    assert_macro %({% 1 %}), ""
  end

  it "can't use `yield` outside a macro" do
    assert_error %({{yield}}), "can't use `{{yield}}` outside a macro"
  end

  it "outputs invisible location pragmas" do
    node = 42.int32
    node.location = Location.new "foo.cr", 10, 20
    assert_macro %({{node}}), "42", {node: node}, expected_pragmas: {
      0 => [
        Lexer::LocPushPragma.new,
        Lexer::LocSetPragma.new("foo.cr", 10, 20),
      ] of Lexer::LocPragma,
      2 => [
        Lexer::LocPopPragma.new,
      ] of Lexer::LocPragma,
    }
  end

  {% for op in ["sizeof".id, "alignof".id] %}
    describe "{{ op }}" do
      {% for type in STABLE_ABI_TYPES %}
        it "gets {{ op }} {{ type.id }}" do
          # we are not interested in the actual sizes or alignments here, these
          # values are up to the codegen spec suite
          assert_macro %(\{{ {{ op }}({{ type.id }}).is_a?(NumberLiteral) }}), "true"
        end
      {% end %}

      it "gets {{ op }} enum" do
        assert_macro("\{{ {{ op }}(Foo) == {{ op }}(Int16) }}", "true") do |program|
          program.types["Foo"] = EnumType.new(program, program, "Foo", program.int16)
          nil
        end
      end

      it "gets {{ op }} alias" do
        assert_macro("\{{ {{ op }}(Foo) == {{ op }}(Int16) }}", "true") do |program|
          program.types["Foo"] = AliasType.new(program, program, "Foo", Crystal::Path.global("Int16"))
          nil
        end
      end

      it "gets {{ op }} typedef" do
        assert_macro("\{{ {{ op }}(Foo) == {{ op }}(Int16) }}", "true") do |program|
          program.types["Foo"] = TypeDefType.new(program, program, "Foo", program.int16)
          nil
        end
      end

      it "errors with typeof" do
        assert_error %(\{{ {{ op }}(typeof(1)) }})
      end

      {% for type in UNSTABLE_ABI_TYPES %}
        it "errors with {{ type.id }}" do
          assert_error %(\{{ {{ op }}({{ type.id }}) }}), "argument to `{{ op }}` inside macros must be a type with a stable {{ op == "sizeof" ? "size".id : "alignment".id }}"
        end
      {% end %}

      it "errors with alias of unstable type" do
        assert_error <<-CRYSTAL, "argument to `{{ op }}` inside macros must be a type with a stable {{ op == "sizeof" ? "size".id : "alignment".id }}"
          struct Foo
          end

          alias Bar = Foo

          \{{ {{ op }}(Bar) }}
          CRYSTAL
      end

      it "errors with typedef of unstable type" do
        assert_error <<-CRYSTAL, "argument to `{{ op }}` inside macros must be a type with a stable {{ op == "sizeof" ? "size".id : "alignment".id }}"
          lib Lib
            struct Foo
              x : Int32
            end

            type Bar = Foo
          end

          \{{ {{ op }}(Lib::Bar) }}
          CRYSTAL
      end
    end
  {% end %}
end
