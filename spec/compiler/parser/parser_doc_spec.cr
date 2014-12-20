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
    {"call without obj", "foo"},
    {"fun def", "fun foo : Int32\nend"},
    {"enum def", "enum Foo\nend"},
    {"constant assign", "A = 1"},
    {"alias", "alias Foo = Bar"},
    {"attribute", "@[Some]"},
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
      node.doc.should eq("This is Foo.\nUse it well.")
    end
  end
end
