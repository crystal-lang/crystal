#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "MacroExpander" do
  it "expands simple macro" do
    assert_macro "", "1 + 2", [] of ASTNode, "1 + 2"
  end

  it "expands macro with string sustitution" do
    assert_macro "x", "{{x}}", [StringLiteral.new("hello")] of ASTNode, "hello"
  end

  it "expands macro with symbol sustitution" do
    assert_macro "x", "{{x}}", [SymbolLiteral.new("hello")] of ASTNode, "hello"
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
    assert_macro "", %({{"hello"}}), [] of ASTNode, %(hello)
  end

  it "expands macro with symbol" do
    assert_macro "", %({{:foo}}), [] of ASTNode, %(foo)
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

  it "expands macro with var sustitution" do
    assert_macro "x", "{{x}}", [Var.new("hello")] of ASTNode, "hello"
  end

  it "expands macro with stringify call on string" do
    assert_macro "x", "{{x.stringify}}", [StringLiteral.new("hello")] of ASTNode, %("hello")
  end

  it "expands macro with stringify call on symbol" do
    assert_macro "x", "{{x.stringify}}", [SymbolLiteral.new("hello")] of ASTNode, %(":hello")
  end

  it "expands macro with for over array literal" do
    assert_macro "x", "{%for e in x}{{e}}{%end}", [ArrayLiteral.new([Var.new("hello"), Var.new("world")] of ASTNode)] of ASTNode, "helloworld"
  end

  it "expands macro with for over array literal with index" do
    assert_macro "x", "{%for e, i in x}{{e}}{{i}}{%end}", [ArrayLiteral.new([Var.new("hello"), Var.new("world")] of ASTNode)] of ASTNode, "hello0world1"
  end

  it "expands macro with for over embedded array literal" do
    assert_macro "", "{%for e in [1, 2]}{{e}}{%end}", [] of ASTNode, "12"
  end

  it "expands macro with for over hash literal" do
    assert_macro "x", "{%for k, v in x}{{k}}{{v}}{%end}", [HashLiteral.new([Var.new("a"), Var.new("b")] of ASTNode, [Var.new("c"), Var.new("d")] of ASTNode)] of ASTNode, "acbd"
  end

  it "expands macro with for over hash literal with index" do
    assert_macro "x", "{%for k, v, i in x}{{k}}{{v}}{{i}}{%end}", [HashLiteral.new([Var.new("a"), Var.new("b")] of ASTNode, [Var.new("c"), Var.new("d")] of ASTNode)] of ASTNode, "ac0bd1"
  end

  it "expands macro with for over tuple literal" do
    assert_macro "x", "{%for e, i in x}{{e}}{{i}}{%end}", [TupleLiteral.new([Var.new("a"), Var.new("b")] of ASTNode)] of ASTNode, "a0b1"
  end

  it "expands macro with if when truthy" do
    assert_macro "", "{%if true}hello{%end}", [] of ASTNode, "hello"
  end

  it "expands macro with if when falsey" do
    assert_macro "", "{%if false}hello{%end}", [] of ASTNode, ""
  end

  it "expands macro with if else when falsey" do
    assert_macro "", "{%if false}hello{%else}bye{%end}", [] of ASTNode, "bye"
  end

  it "executes == on numbers (true)" do
    assert_macro "", "{%if 1 == 1}hello{%else}bye{%end}", [] of ASTNode, "hello"
  end

  it "executes == on numbers (false)" do
    assert_macro "", "{%if 1 == 2}hello{%else}bye{%end}", [] of ASTNode, "bye"
  end

  it "executes != on numbers (true)" do
    assert_macro "", "{%if 1 != 2}hello{%else}bye{%end}", [] of ASTNode, "hello"
  end

  it "executes != on numbers (false)" do
    assert_macro "", "{%if 1 != 1}hello{%else}bye{%end}", [] of ASTNode, "bye"
  end

  it "executes > on numbers (true)" do
    assert_macro "", "{%if 2 > 1}hello{%else}bye{%end}", [] of ASTNode, "hello"
  end

  it "executes > on numbers (false)" do
    assert_macro "", "{%if 2 > 3}hello{%else}bye{%end}", [] of ASTNode, "bye"
  end

  it "executes >= on numbers (true)" do
    assert_macro "", "{%if 1 >= 1}hello{%else}bye{%end}", [] of ASTNode, "hello"
  end

  it "executes >= on numbers (false)" do
    assert_macro "", "{%if 2 >= 3}hello{%else}bye{%end}", [] of ASTNode, "bye"
  end

  it "executes < on numbers (true)" do
    assert_macro "", "{%if 1 < 2}hello{%else}bye{%end}", [] of ASTNode, "hello"
  end

  it "executes < on numbers (false)" do
    assert_macro "", "{%if 3 < 2}hello{%else}bye{%end}", [] of ASTNode, "bye"
  end

  it "executes <= on numbers (true)" do
    assert_macro "", "{%if 1 <= 1}hello{%else}bye{%end}", [] of ASTNode, "hello"
  end

  it "executes <= on numbers (false)" do
    assert_macro "", "{%if 3 <= 2}hello{%else}bye{%end}", [] of ASTNode, "bye"
  end

  it "executes string split without arguments" do
    assert_macro "", %({{"1 2 3".split}}), [] of ASTNode, %(["1", "2", "3"])
  end

  it "executes string split with string argument" do
    assert_macro "", %({{"1-2-3".split("-")}}), [] of ASTNode, %(["1", "2", "3"])
  end

  it "executes string split with char argument" do
    assert_macro "", %({{"1-2-3".split('-')}}), [] of ASTNode, %(["1", "2", "3"])
  end

  it "executes string strip" do
    assert_macro "", %({{"  hello   ".strip}}), [] of ASTNode, "hello"
  end

  it "executes string downcase" do
    assert_macro "", %({{"HELLO".downcase}}), [] of ASTNode, "hello"
  end

  it "executes string upcase" do
    assert_macro "", %({{"hello".upcase}}), [] of ASTNode, "HELLO"
  end

  it "executes string lines" do
    assert_macro "x", %({{x.lines}}), [StringLiteral.new("1\n2\n3")] of ASTNode, %(["1", "2", "3"])
  end

  it "executes string length" do
    assert_macro "", %({{"hello".length}}), [] of ASTNode, "5"
  end

  it "executes string empty" do
    assert_macro "", %({{"hello".empty?}}), [] of ASTNode, "false"
  end

  it "executes array index 0" do
    assert_macro "", %({{[1, 2, 3][0]}}), [] of ASTNode, "1"
  end

  it "executes array index 1" do
    assert_macro "", %({{[1, 2, 3][1]}}), [] of ASTNode, "2"
  end

  it "executes array length" do
    assert_macro "", %({{[1, 2, 3].length}}), [] of ASTNode, "3"
  end

  it "executes array empty?" do
    assert_macro "", %({{[1, 2, 3].empty?}}), [] of ASTNode, "false"
  end

  it "executes hash length" do
    assert_macro "", %({{{a: 1, b: 3}.length}}), [] of ASTNode, "2"
  end

  it "executes hash empty?" do
    assert_macro "", %({{{a: 1}.empty?}}), [] of ASTNode, "false"
  end

  it "executes hash index" do
    assert_macro "", %({{{a: 1}[:a]}}), [] of ASTNode, "1"
  end

  it "executes hash index not found" do
    assert_macro "", %({{{a: 1}[:b]}}), [] of ASTNode, "nil"
  end

  it "executes tuple length" do
    assert_macro "", %({{{1, 2, 3}.length}}), [] of ASTNode, "3"
  end

  it "executes tuple empty?" do
    assert_macro "", %({{{1, 2, 3}.empty?}}), [] of ASTNode, "false"
  end

  it "executes tuple index 1" do
    assert_macro "", %({{{1, 2, 3}[1]}}), [] of ASTNode, "2"
  end
end
