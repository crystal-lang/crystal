#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "MacroExpander" do
  it "expands simple macro" do
    assert_macro "", "1 + 2", [] of ASTNode, "1 + 2"
  end

  it "expands macro with string sustitution" do
    assert_macro "x", "{{x}}", [StringLiteral.new("hello")] of ASTNode, %("hello")
  end

  it "expands macro with symbol sustitution" do
    assert_macro "x", "{{x}}", [SymbolLiteral.new("hello")] of ASTNode, ":hello"
  end

  it "expands macro with argument-less call sustitution" do
    assert_macro "x", "{{x}}", [Call.new(nil, "hello")] of ASTNode, "hello"
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
    assert_macro "", %({{{a: 1, b: 2}}}), [] of ASTNode, "{:a => 1, :b => 2}"
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
    assert_macro "x", "{{x}}", [Var.new("hello")] of ASTNode, "hello"
  end

  it "expands macro with or (1)" do
    assert_macro "x", "{{x || 1}}", [NilLiteral.new] of ASTNode, "1"
  end

  it "expands macro with or (2)" do
    assert_macro "x", "{{x || 1}}", [Var.new("hello")] of ASTNode, "hello"
  end

  it "expands macro with and (1)" do
    assert_macro "x", "{{x && 1}}", [NilLiteral.new] of ASTNode, "nil"
  end

  it "expands macro with and (2)" do
    assert_macro "x", "{{x && 1}}", [Var.new("hello")] of ASTNode, "1"
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
      assert_macro "x", "{%for e in x %}{{e}}{%end%}", [ArrayLiteral.new([Var.new("hello"), Var.new("world")] of ASTNode)] of ASTNode, "helloworld"
    end

    it "expands macro with for over array literal with index" do
      assert_macro "x", "{%for e, i in x%}{{e}}{{i}}{%end%}", [ArrayLiteral.new([Var.new("hello"), Var.new("world")] of ASTNode)] of ASTNode, "hello0world1"
    end

    it "expands macro with for over embedded array literal" do
      assert_macro "", "{%for e in [1, 2]%}{{e}}{%end%}", [] of ASTNode, "12"
    end

    it "expands macro with for over hash literal" do
      assert_macro "x", "{%for k, v in x%}{{k}}{{v}}{%end%}", [HashLiteral.new([Var.new("a"), Var.new("b")] of ASTNode, [Var.new("c"), Var.new("d")] of ASTNode)] of ASTNode, "acbd"
    end

    it "expands macro with for over hash literal with index" do
      assert_macro "x", "{%for k, v, i in x%}{{k}}{{v}}{{i}}{%end%}", [HashLiteral.new([Var.new("a"), Var.new("b")] of ASTNode, [Var.new("c"), Var.new("d")] of ASTNode)] of ASTNode, "ac0bd1"
    end

    it "expands macro with for over tuple literal" do
      assert_macro "x", "{%for e, i in x%}{{e}}{{i}}{%end%}", [TupleLiteral.new([Var.new("a"), Var.new("b")] of ASTNode)] of ASTNode, "a0b1"
    end

    it "expands macro with for over range literal" do
      assert_macro "", "{%for e in 1..3 %}{{e}}{%end%}", [] of ASTNode, "123"
    end

    it "expands macro with for over range literal, evaluating elements" do
      assert_macro "x, y", "{%for e in x..y %}{{e}}{%end%}", [NumberLiteral.new(3), NumberLiteral.new(6)] of ASTNode, "3456"
    end

    it "expands macro with for over range literal, evaluating elements (exclusive)" do
      assert_macro "x, y", "{%for e in x...y %}{{e}}{%end%}", [NumberLiteral.new(3), NumberLiteral.new(6)] of ASTNode, "345"
    end
  end

  describe "node methods" do
    describe "stringify" do
      it "expands macro with stringify call on string" do
        assert_macro "x", "{{x.stringify}}", [StringLiteral.new("hello")] of ASTNode, "\"\\\"hello\\\"\""
      end

      it "expands macro with stringify call on symbol" do
        assert_macro "x", "{{x.stringify}}", [SymbolLiteral.new("hello")] of ASTNode, %(":hello")
      end

      it "expands macro with stringify call on call" do
        assert_macro "x", "{{x.stringify}}", [Call.new(nil, "hello")] of ASTNode, %("hello")
      end

      it "expands macro with stringify call on number" do
        assert_macro "x", "{{x.stringify}}", [NumberLiteral.new(1)] of ASTNode, %("1")
      end
    end

    describe "id" do
      it "expands macro with id call on string" do
        assert_macro "x", "{{x.id}}", [StringLiteral.new("hello")] of ASTNode, "hello"
      end

      it "expands macro with id call on symbol" do
        assert_macro "x", "{{x.id}}", [SymbolLiteral.new("hello")] of ASTNode, "hello"
      end

      it "expands macro with id call on call" do
        assert_macro "x", "{{x.id}}", [Call.new(nil, "hello")] of ASTNode, "hello"
      end

      it "expands macro with id call on number" do
        assert_macro "x", "{{x.id}}", [NumberLiteral.new(1)] of ASTNode, %(1)
      end
    end

    it "executes == on numbers (true)" do
      assert_macro "", "{%if 1 == 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
    end

    it "executes == on numbers (false)" do
      assert_macro "", "{%if 1 == 2%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end

    it "executes != on numbers (true)" do
      assert_macro "", "{%if 1 != 2%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
    end

    it "executes != on numbers (false)" do
      assert_macro "", "{%if 1 != 1%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end
  end

  describe "number methods" do
    it "executes > (true)" do
      assert_macro "", "{%if 2 > 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
    end

    it "executes > (false)" do
      assert_macro "", "{%if 2 > 3%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end

    it "executes >= (true)" do
      assert_macro "", "{%if 1 >= 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
    end

    it "executes >= (false)" do
      assert_macro "", "{%if 2 >= 3%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end

    it "executes < (true)" do
      assert_macro "", "{%if 1 < 2%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
    end

    it "executes < (false)" do
      assert_macro "", "{%if 3 < 2%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end

    it "executes <= (true)" do
      assert_macro "", "{%if 1 <= 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
    end

    it "executes <= (false)" do
      assert_macro "", "{%if 3 <= 2%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
    end
  end

  describe "string methods" do
    it "executes split without arguments" do
      assert_macro "", %({{"1 2 3".split}}), [] of ASTNode, %(["1", "2", "3"])
    end

    it "executes split with argument" do
      assert_macro "", %({{"1-2-3".split("-")}}), [] of ASTNode, %(["1", "2", "3"])
    end

    it "executes split with char argument" do
      assert_macro "", %({{"1-2-3".split('-')}}), [] of ASTNode, %(["1", "2", "3"])
    end

    it "executes strip" do
      assert_macro "", %({{"  hello   ".strip}}), [] of ASTNode, %("hello")
    end

    it "executes downcase" do
      assert_macro "", %({{"HELLO".downcase}}), [] of ASTNode, %("hello")
    end

    it "executes upcase" do
      assert_macro "", %({{"hello".upcase}}), [] of ASTNode, %("HELLO")
    end

    it "executes capitalize" do
      assert_macro "", %({{"hello".capitalize}}), [] of ASTNode, %("Hello")
    end

    it "executes chars" do
      assert_macro "x", %({{x.chars}}), [StringLiteral.new("123")] of ASTNode, %(['1', '2', '3'])
    end

    it "executes lines" do
      assert_macro "x", %({{x.lines}}), [StringLiteral.new("1\n2\n3")] of ASTNode, %(["1", "2", "3"])
    end

    it "executes length" do
      assert_macro "", %({{"hello".length}}), [] of ASTNode, "5"
    end

    it "executes empty" do
      assert_macro "", %({{"hello".empty?}}), [] of ASTNode, "false"
    end

    it "executes string [Range] inclusive" do
      assert_macro "", %({{"hello"[1..-2]}}), [] of ASTNode, %("ell")
    end

    it "executes string [Range] exclusive" do
      assert_macro "", %({{"hello"[1...-2]}}), [] of ASTNode, %("el")
    end

    it "executes string chomp" do
      assert_macro "", %({{"hello\n".chomp}}), [] of ASTNode, %("hello")
    end

    it "executes string starts_with? char (true)" do
      assert_macro "", %({{"hello".starts_with?('h')}}), [] of ASTNode, %(true)
    end

    it "executes string starts_with? char (false)" do
      assert_macro "", %({{"hello".starts_with?('e')}}), [] of ASTNode, %(false)
    end

    it "executes string starts_with? string (true)" do
      assert_macro "", %({{"hello".starts_with?("hel")}}), [] of ASTNode, %(true)
    end

    it "executes string starts_with? string (false)" do
      assert_macro "", %({{"hello".starts_with?("hi")}}), [] of ASTNode, %(false)
    end

    it "executes string ends_with? char (true)" do
      assert_macro "", %({{"hello".ends_with?('o')}}), [] of ASTNode, %(true)
    end

    it "executes string ends_with? char (false)" do
      assert_macro "", %({{"hello".ends_with?('e')}}), [] of ASTNode, %(false)
    end

    it "executes string ends_with? string (true)" do
      assert_macro "", %({{"hello".ends_with?("llo")}}), [] of ASTNode, %(true)
    end

    it "executes string ends_with? string (false)" do
      assert_macro "", %({{"hello".ends_with?("tro")}}), [] of ASTNode, %(false)
    end

    it "executes string =~ (false)" do
      assert_macro "", %({{"hello" =~ /hei/}}), [] of ASTNode, %(false)
    end

    it "executes string =~ (true)" do
      assert_macro "", %({{"hello" =~ /ell/}}), [] of ASTNode, %(true)
    end
  end

  describe "macro id methods" do
    it "forwards methods to string" do
      assert_macro "x", %({{x.ends_with?("llo")}}), [MacroId.new("hello")] of ASTNode, %(true)
      assert_macro "x", %({{x.ends_with?("tro")}}), [MacroId.new("hello")] of ASTNode, %(false)
      assert_macro "x", %({{x.starts_with?("hel")}}), [MacroId.new("hello")] of ASTNode, %(true)
      assert_macro "x", %({{x.chomp}}), [MacroId.new("hello\n")] of ASTNode, %(hello)
      assert_macro "x", %({{x.upcase}}), [MacroId.new("hello")] of ASTNode, %(HELLO)
    end
  end

  describe "symbol methods" do
    it "forwards methods to string" do
      assert_macro "x", %({{x.ends_with?("llo")}}), [SymbolLiteral.new("hello")] of ASTNode, %(true)
      assert_macro "x", %({{x.ends_with?("tro")}}), [SymbolLiteral.new("hello")] of ASTNode, %(false)
      assert_macro "x", %({{x.starts_with?("hel")}}), [SymbolLiteral.new("hello")] of ASTNode, %(true)
      assert_macro "x", %({{x.chomp}}), [SymbolLiteral.new("hello\n")] of ASTNode, %(:hello)
      assert_macro "x", %({{x.upcase}}), [SymbolLiteral.new("hello")] of ASTNode, %(:HELLO)
    end
  end

  describe "array methods" do
    it "executes index 0" do
      assert_macro "", %({{[1, 2, 3][0]}}), [] of ASTNode, "1"
    end

    it "executes index 1" do
      assert_macro "", %({{[1, 2, 3][1]}}), [] of ASTNode, "2"
    end

    it "executes index out of bounds" do
      assert_macro "", %({{[1, 2, 3][3]}}), [] of ASTNode, "nil"
    end

    it "executes length" do
      assert_macro "", %({{[1, 2, 3].length}}), [] of ASTNode, "3"
    end

    it "executes empty?" do
      assert_macro "", %({{[1, 2, 3].empty?}}), [] of ASTNode, "false"
    end

    it "executes identify" do
      assert_macro "", %({{"A::B".identify}}), [] of ASTNode, "\"A__B\""
      assert_macro "", %({{"A".identify}}), [] of ASTNode, "\"A\""
    end

    it "executes join" do
      assert_macro "", %({{[1, 2, 3].join ", "}}), [] of ASTNode, %("1, 2, 3")
    end

    it "executes join with strings" do
      assert_macro "", %({{["a", "b"].join ", "}}), [] of ASTNode, %("a, b")
    end

    it "executes map" do
      assert_macro "", %({{[1, 2, 3].map { |e| e == 2 }}}), [] of ASTNode, "[false, true, false]"
    end

    it "executes map with arg" do
      assert_macro "x", %({{x.map { |e| e }}}), [ArrayLiteral.new([Call.new(nil, "hello")] of ASTNode)] of ASTNode, "[hello]"
    end

    it "executes select" do
      assert_macro "", %({{[1, 2, 3].select { |e| e == 1 }}}), [] of ASTNode, "[1]"
    end

    it "executes any? (true)" do
      assert_macro "", %({{[1, 2, 3].any? { |e| e == 1 }}}), [] of ASTNode, "true"
    end

    it "executes any? (false)" do
      assert_macro "", %({{[1, 2, 3].any? { |e| e == 4 }}}), [] of ASTNode, "false"
    end

    it "executes all? (true)" do
      assert_macro "", %({{[1, 1, 1].all? { |e| e == 1 }}}), [] of ASTNode, "true"
    end

    it "executes all? (false)" do
      assert_macro "", %({{[1, 2, 1].all? { |e| e == 1 }}}), [] of ASTNode, "false"
    end

    it "executes first" do
      assert_macro "", %({{[1, 2, 3].first}}), [] of ASTNode, "1"
    end

    it "executes last" do
      assert_macro "", %({{[1, 2, 3].last}}), [] of ASTNode, "3"
    end

    it "executes argify" do
      assert_macro "", %({{[1, 2, 3].argify}}), [] of ASTNode, "1, 2, 3"
    end

    it "executes argify with symbols and strings" do
      assert_macro "", %({{[:foo, "hello", 3].argify}}), [] of ASTNode, %(:foo, "hello", 3)
    end

    it "executes argify with splat" do
      assert_macro "", %({{*[1, 2, 3]}}), [] of ASTNode, "1, 2, 3"
    end

    it "executes is_a?" do
      assert_macro "", %({{[1, 2, 3].is_a?(ArrayLiteral)}}), [] of ASTNode, "true"
      assert_macro "", %({{[1, 2, 3].is_a?(NumberLiteral)}}), [] of ASTNode, "false"
    end
  end

  describe "hash methods" do
    it "executes length" do
      assert_macro "", %({{{a: 1, b: 3}.length}}), [] of ASTNode, "2"
    end

    it "executes empty?" do
      assert_macro "", %({{{a: 1}.empty?}}), [] of ASTNode, "false"
    end

    it "executes index" do
      assert_macro "", %({{{a: 1}[:a]}}), [] of ASTNode, "1"
    end

    it "executes index not found" do
      assert_macro "", %({{{a: 1}[:b]}}), [] of ASTNode, "nil"
    end

    it "executes keys" do
      assert_macro "", %({{{a: 1, b: 2}.keys}}), [] of ASTNode, "[:a, :b]"
    end

    it "executes values" do
      assert_macro "", %({{{a: 1, b: 2}.values}}), [] of ASTNode, "[1, 2]"
    end

    it "executes is_a?" do
      assert_macro "", %({{{a: 1}.is_a?(HashLiteral)}}), [] of ASTNode, "true"
      assert_macro "", %({{{a: 1}.is_a?(RangeLiteral)}}), [] of ASTNode, "false"
    end
  end

  describe "tuple methods" do
    it "executes length" do
      assert_macro "", %({{{1, 2, 3}.length}}), [] of ASTNode, "3"
    end

    it "executes empty?" do
      assert_macro "", %({{{1, 2, 3}.empty?}}), [] of ASTNode, "false"
    end

    it "executes index 1" do
      assert_macro "", %({{{1, 2, 3}[1]}}), [] of ASTNode, "2"
    end
  end

  describe "metavar methods" do
    it "executes nothing" do
      assert_macro "x", %({{x}}), [MetaVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
    end

    it "executes name" do
      assert_macro "x", %({{x.name}}), [MetaVar.new("foo", Program.new.int32)] of ASTNode, %("foo")
    end

    it "executes id" do
      assert_macro "x", %({{x.id}}), [MetaVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
    end
  end

  describe "block methods" do
    it "executes body" do
      assert_macro "x", %({{x.body}}), [Block.new(body: NumberLiteral.new(1))] of ASTNode, "1"
    end

    it "executes args" do
      assert_macro "x", %({{x.args}}), [Block.new([Var.new("x"), Var.new("y")])] of ASTNode, "[x, y]"
    end
  end

  it "executes assign" do
    assert_macro "", %({{a = 1}}{{a}}), [] of ASTNode, "1"
  end

  describe "type method" do
    it "executes name" do
      assert_macro("x", "{{x.name}}", %("String")) do |program|
        [MacroType.new(program.string)] of ASTNode
      end
    end

    it "executes instance_vars" do
      assert_macro("x", "{{x.instance_vars.map &.stringify}}", %(["bytesize", "length", "c"])) do |program|
        [MacroType.new(program.string)] of ASTNode
      end
    end

    it "executes superclass" do
      assert_macro("x", "{{x.superclass}}", %(Reference)) do |program|
        [MacroType.new(program.string)] of ASTNode
      end
    end
  end

  describe "env" do
    it "has key" do
      ENV["FOO"] = "foo"
      assert_macro "", %({{env("FOO")}}), [] of ASTNode, %("foo")
      ENV.delete "FOO"
    end

    it "doesn't have key" do
      ENV.delete "FOO"
      assert_macro "", %({{env("FOO")}}), [] of ASTNode, %(nil)
    end
  end
end
