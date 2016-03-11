require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

private def assert_agent(source, expected)
  ast = Parser.new(source).parse
  instrumented = Playground::AgentInstrumentorVisitor.new.process(ast)
  instrumented.to_s.should eq(expected)

  # whatever case should work beforeit should work with appended lines
  ast = Parser.new("#{source}\n1\n").parse
  instrumented = Playground::AgentInstrumentorVisitor.new.process(ast)
  instrumented.to_s.should contain(expected)
end

describe Playground::AgentInstrumentorVisitor do
  it "instrument literals" do
    assert_agent %(5), %($p.i(5, 1))
    assert_agent %(5.0), %($p.i(5.0, 1))
    assert_agent %("lorem"), %($p.i("lorem", 1))
    assert_agent %(true), %($p.i(true, 1))
    assert_agent %('c'), %($p.i('c', 1))
  end

  it "instrument single variables expressions" do
    assert_agent %(x), %($p.i(x, 1))
  end

  it "instrument assignments in the rhs" do
    assert_agent %(a = 4), %(a = $p.i(4, 1))
  end

  it "instrument single statement def" do
    assert_agent %(
    def foo
      4
    end), <<-CR
    def foo
      $p.i(4, 3)
    end
    CR
  end

  it "instrument single statement var def" do
    assert_agent %(
    def foo(x)
      x
    end), <<-CR
    def foo(x)
      $p.i(x, 3)
    end
    CR
  end

  it "instrument multi statement def" do
    assert_agent %(
    def foo
      2
      6
    end), <<-CR
    def foo
      $p.i(2, 3)
      $p.i(6, 4)
    end
    CR
  end

  it "instrument class defs" do
    assert_agent %(
    class Foo
      def initialize
        @x = 3
      end
      def bar(x)
        x = x + x
        x
      end
      def self.bar(x, y)
        x+y
      end
    end), <<-CR
    class Foo
      def initialize
        @x = $p.i(3, 4)
      end
      def bar(x)
        x = $p.i(x + x, 7)
        $p.i(x, 8)
      end
      def self.bar(x, y)
        $p.i(x + y, 11)
      end
    end
    CR
  end
end
