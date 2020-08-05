require "../../spec_helper"

describe "MacroExpander" do
  it "expands simple macro" do
    assert_macro "", "1 + 2", [] of ASTNode, "1 + 2"
  end

  it "expands macro with string sustitution" do
    assert_macro "x", "{{x}}", ["hello".string] of ASTNode, %("hello")
  end

  it "expands macro with symbol sustitution" do
    assert_macro "x", "{{x}}", ["hello".symbol] of ASTNode, ":hello"
  end

  it "expands macro with argument-less call sustitution" do
    assert_macro "x", "{{x}}", ["hello".call] of ASTNode, "hello"
  end

  it "expands macro with boolean" do
    assert_macro "", "{{true}}", [] of ASTNode, "true"
  end

  it "expands macro with integer" do
    assert_macro "", "{{1}}", [] of ASTNode, "1"
  end

  it "expands macro with char" do
    assert_macro "", "{{'a'}}", [] of ASTNode, "'a'"
  end

  it "expands macro with string" do
    assert_macro "", %({{"hello"}}), [] of ASTNode, %("hello")
  end

  it "expands macro with symbol" do
    assert_macro "", %({{:foo}}), [] of ASTNode, %(:foo)
  end

  it "expands macro with nil" do
    assert_macro "", %({{nil}}), [] of ASTNode, %(nil)
  end

  it "expands macro with array" do
    assert_macro "", %({{[1, 2, 3]}}), [] of ASTNode, %([1, 2, 3])
  end

  it "expands macro with hash" do
    assert_macro "", %({{{:a => 1, :b => 2}}}), [] of ASTNode, "{:a => 1, :b => 2}"
  end

  it "expands macro with tuple" do
    assert_macro "", %({{{1, 2, 3}}}), [] of ASTNode, %({1, 2, 3})
  end

  it "expands macro with range" do
    assert_macro "", %({{1..3}}), [] of ASTNode, %(1..3)
  end

  it "expands macro with string interpolation" do
    assert_macro "", "{{ \"hello\#{1 == 1}world\" }}", [] of ASTNode, %("hellotrueworld")
  end

  it "expands macro with var sustitution" do
    assert_macro "x", "{{x}}", ["hello".var] of ASTNode, "hello"
  end

  it "expands macro with or (1)" do
    assert_macro "x", "{{x || 1}}", [NilLiteral.new] of ASTNode, "1"
  end

  it "expands macro with or (2)" do
    assert_macro "x", "{{x || 1}}", ["hello".var] of ASTNode, "hello"
  end

  it "expands macro with and (1)" do
    assert_macro "x", "{{x && 1}}", [NilLiteral.new] of ASTNode, "nil"
  end

  it "expands macro with and (2)" do
    assert_macro "x", "{{x && 1}}", ["hello".var] of ASTNode, "1"
  end

  describe "if" do
    it "expands macro with if when truthy" do
      assert_macro "", "{%if true%}hello{%end%}", [] of ASTNode, "hello"
    end

    it "expands macro with if when falsey" do
      assert_macro "", "{%if false%}hello{%end%}", [] of ASTNode, ""
    end

    it "expands macro with if else when falsey" do
      assert_macro "", "{%if false%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end

    it "expands macro with if with nop" do
      assert_macro "x", "{%if x%}hello{%else%}bye{%end%}", [Nop.new] of ASTNode, "bye"
    end

    it "expands macro with if with not" do
      assert_macro "", "{%if !true%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end
  end

  describe "for" do
    it "expands macro with for over array literal" do
      assert_macro "x", "{%for e in x %}{{e}}{%end%}", [ArrayLiteral.new(["hello".var, "world".var] of ASTNode)] of ASTNode, "helloworld"
    end

    it "expands macro with for over array literal with index" do
      assert_macro "x", "{%for e, i in x%}{{e}}{{i}}{%end%}", [ArrayLiteral.new(["hello".var, "world".var] of ASTNode)] of ASTNode, "hello0world1"
    end

    it "expands macro with for over embedded array literal" do
      assert_macro "", "{%for e in [1, 2]%}{{e}}{%end%}", [] of ASTNode, "12"
    end

    it "expands macro with for over hash literal" do
      assert_macro "x", "{%for k, v in x%}{{k}}{{v}}{%end%}", [HashLiteral.new([HashLiteral::Entry.new("a".var, "c".var), HashLiteral::Entry.new("b".var, "d".var)])] of ASTNode, "acbd"
    end

    it "expands macro with for over hash literal with index" do
      assert_macro "x", "{%for k, v, i in x%}{{k}}{{v}}{{i}}{%end%}", [HashLiteral.new([HashLiteral::Entry.new("a".var, "c".var), HashLiteral::Entry.new("b".var, "d".var)])] of ASTNode, "ac0bd1"
    end

    it "expands macro with for over tuple literal" do
      assert_macro "x", "{%for e, i in x%}{{e}}{{i}}{%end%}", [TupleLiteral.new(["a".var, "b".var] of ASTNode)] of ASTNode, "a0b1"
    end

    it "expands macro with for over range literal" do
      assert_macro "", "{%for e in 1..3 %}{{e}}{%end%}", [] of ASTNode, "123"
    end

    it "expands macro with for over range literal, evaluating elements" do
      assert_macro "x, y", "{%for e in x..y %}{{e}}{%end%}", [3.int32, 6.int32] of ASTNode, "3456"
    end

    it "expands macro with for over range literal, evaluating elements (exclusive)" do
      assert_macro "x, y", "{%for e in x...y %}{{e}}{%end%}", [3.int32, 6.int32] of ASTNode, "345"
    end
  end

  it "does regular if" do
    assert_macro "", %({{1 == 2 ? 3 : 4}}), [] of ASTNode, "4"
  end

  it "does regular unless" do
    assert_macro "", %({{unless 1 == 2; 3; else; 4; end}}), [] of ASTNode, "3"
  end

  it "does not expand when macro expression is {% ... %}" do
    assert_macro "", %({% 1 %}), [] of ASTNode, ""
  end

  it "can't use `yield` outside a macro" do
    assert_error %({{yield}}), "can't use `{{yield}}` outside a macro"
  end

  it "outputs invisible location pragmas" do
    node = 42.int32
    node.location = Location.new "foo.cr", 10, 20
    assert_macro "node", %({{node}}), [node] of ASTNode, "42", {
      0 => [
        Lexer::LocPushPragma.new,
        Lexer::LocSetPragma.new("foo.cr", 10, 20),
      ] of Lexer::LocPragma,
      2 => [
        Lexer::LocPopPragma.new,
      ] of Lexer::LocPragma,
    }
  end
end
