require "../../spec_helper"

describe "Parser doc" do
  [
    {"class", "class Foo\nend"},
    {"abstract class", "abstract class Foo\nend"},
    {"struct", "struct Foo\nend"},
    {"module", "module Foo\nend"},
    {"def", "def foo\nend"},
    {"abstract def", "abstract def foo"},
    {"macro", "macro foo\nend"},
    {"macro def", "macro def foo : Int32\nend"},
    {"call without obj", "foo"},
    {"fun def", "fun foo : Int32\nend"},
    {"enum def", "enum Foo\nend"},
    {"constant assign", "A = 1"},
    {"alias", "alias Foo = Bar"},
    {"attribute", "@[Some]"},
    {"private def", "private def foo\nend"},
    ].each do |tuple|
    desc, code = tuple

    it "includes doc for #{desc}" do
      parser = Parser.new(%(
        # This is Foo.
        # Use it well.
        #{code}
        ))
      parser.wants_doc = true
      node = parser.parse
      expect(node.doc).to eq("This is Foo.\nUse it well.")
    end
  end

  it "disables doc parsing inside defs" do
    parser = Parser.new(%(
      # doc 1
      def foo
        # doc 2
        bar
      end

      # doc 3
      def baz
      end
      ))
    parser.wants_doc = true
    nodes = parser.parse as Expressions

    foo = nodes[0] as Def
    expect(foo.doc).to eq("doc 1")

    bar = foo.body as Call
    expect(bar.doc).to be_nil

    baz = nodes[1] as Def
    expect(baz.doc).to eq("doc 3")
  end
end
