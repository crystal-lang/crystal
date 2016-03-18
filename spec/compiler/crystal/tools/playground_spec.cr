require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

private def assert_agent(source, expected)
  ast = Parser.new(source).parse
  instrumented = ast.transform Playground::AgentInstrumentorTransformer.new
  instrumented.to_s.should contain(expected)

  # whatever case should work beforeit should work with appended lines
  ast = Parser.new("#{source}\n1\n").parse
  instrumented = ast.transform Playground::AgentInstrumentorTransformer.new
  instrumented.to_s.should contain(expected)
end

class Crystal::Playground::TestAgent < Playground::Agent
  class FakeSocket
    property message

    def send(@message)
    end
  end

  def initialize(url, @tag)
    @ws = FakeSocket.new
  end

  def last_message
    @ws.message
  end
end

fun a_sample_void : Void
end

describe Playground::Agent do
  it "should send json messages and return inspected value" do
    agent = Crystal::Playground::TestAgent.new(".", 32)
    agent.i(5, 1).should eq(5)
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"5","value_type":"Int32"}))
    x, y = 3, 4
    agent.i({x, y}, 1, ["x", "y"]).should eq({3, 4})
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"{3, 4}","value_type":"{Int32, Int32}","data":{"x":"3","y":"4"}}))

    agent.i(nil as Void?, 1)
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"nil","value_type":"Void?"}))
    agent.i(a_sample_void as Void?, 1)
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"(void)","value_type":"Void?"}))
    agent.i(a_sample_void, 1)
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"(void)","value_type":"Void"}))
  end
end

describe Playground::AgentInstrumentorTransformer do
  it "instrument literals" do
    assert_agent %(nil), %($p.i(nil, 1))
    assert_agent %(5), %($p.i(5, 1))
    assert_agent %(5.0), %($p.i(5.0, 1))
    assert_agent %("lorem"), %($p.i("lorem", 1))
    assert_agent %(true), %($p.i(true, 1))
    assert_agent %('c'), %($p.i('c', 1))
    assert_agent %(:foo), %($p.i(:foo, 1))
    assert_agent %([1, 2]), %($p.i([1, 2], 1))
    assert_agent %(/a/), %($p.i(/a/, 1))
  end

  it "instrument literals with expression names" do
    assert_agent %({1, 2}), %($p.i({1, 2}, 1, ["1", "2"]))
    assert_agent %({x, x + y}), %($p.i({x, x + y}, 1, ["x", "x + y"]))
    assert_agent %(a = {x, x + y}), %(a = $p.i({x, x + y}, 1, ["x", "x + y"]))
  end

  it "instrument single variables expressions" do
    assert_agent %(x), %($p.i(x, 1))
  end

  it "instrument single global variables expressions" do
    assert_agent %($x), %($p.i($x, 1))
  end

  it "instrument string interpolations" do
    assert_agent %("lorem \#{a} \#{b}"), %($p.i("lorem \#{a} \#{b}", 1))
  end

  it "instrument assignments in the rhs" do
    assert_agent %(a = 4), %(a = $p.i(4, 1))
  end

  it "instrument multi assignments in the rhs" do
    assert_agent %(a, b = t), %(a, b = $p.i(t, 1))
    assert_agent %(a, b = d, f), %(a, b = $p.i({d, f}, 1, ["d", "f"]))
    assert_agent %(a, b = {d, f}), %(a, b = $p.i({d, f}, 1, ["d", "f"]))
  end

  it "instrument puts" do
    assert_agent %(puts 3), %(puts($p.i(3, 1)))
    assert_agent %(puts a, 2, b), %(puts(*$p.i({a, 2, b}, 1, ["a", "2", "b"])))
  end

  it "instrument print" do
    assert_agent %(print 3), %(print($p.i(3, 1)))
    assert_agent %(print a, 2, b), %(print(*$p.i({a, 2, b}, 1, ["a", "2", "b"])))
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

  it "instrument returns inside def" do
    assert_agent %(
    def foo
      return 4
    end), <<-CR
    def foo
      return $p.i(4, 3)
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

  it "instrument instance variable and class variables reads" do
    assert_agent %(
    class Foo
      def initialize
        @x = 3
      end
      def bar
        @x
      end
      def self.bar
        @@x
      end
    end), <<-CR
    class Foo
      def initialize
        @x = $p.i(3, 4)
      end
      def bar
        $p.i(@x, 7)
      end
      def self.bar
        $p.i(@@x, 10)
      end
    end
    CR
  end

  it "do not instrument class initializing arguments" do
    assert_agent %(
    class Foo
      def initialize(@x, @y)
        @z = @x + @y
      end
    end
    ), <<-CR
    class Foo
      def initialize(x, y)
        @x = x
        @y = y
        @z = $p.i(@x + @y, 4)
      end
    end
    CR
  end

  it "instrument inside modules" do
    assert_agent %(
    module Bar
      class Baz
        class Foo
          def initialize
            @x = 3
          end
        end
      end
    end), <<-CR
    module Bar
      class Baz
        class Foo
          def initialize
            @x = $p.i(3, 6)
          end
        end
      end
    end
    CR
  end

  it "instrument if statement" do
    assert_agent %(
    if a
      b
    else
      c
    end
    ), <<-CR
    if a
      $p.i(b, 3)
    else
      $p.i(c, 5)
    end
    CR
  end

  it "instrument unless statement" do
    assert_agent %(
    unless a
      b
    else
      c
    end
    ), <<-CR
    unless a
      $p.i(b, 3)
    else
      $p.i(c, 5)
    end
    CR
  end

  it "instrument while statement" do
    assert_agent %(
    while a
      b
      c
    end
    ), <<-CR
    while a
      $p.i(b, 3)
      $p.i(c, 4)
    end
    CR
  end

  it "instrument case statement" do
    # mind multi cond cases and non-cond cases before instrumenting single-cond cases
    assert_agent %(
    case a
    when 0
      b
    when 1
      c
    else
      d
    end
    ), <<-CR
    case a
    when 0
      $p.i(b, 4)
    when 1
      $p.i(c, 6)
    else
      $p.i(d, 8)
    end
    CR
  end

  it "instrument blocks and single yields" do
    assert_agent %(
    def foo(x)
      yield x
    end
    foo do |a|
      a
    end
    ), <<-CR
    def foo(x)
      yield $p.i(x, 3)
    end
    $p.i(foo do |a|
      $p.i(a, 6)
    end, 5)
    CR
  end

  it "instrument blocks and but non multi yields" do
    assert_agent %(
    def foo(x)
      yield x, 1
    end
    foo do |a, i|
      a
    end
    ), <<-CR
    def foo(x)
      yield x, 1
    end
    $p.i(foo do |a, i|
      $p.i(a, 6)
    end, 5)
    CR
  end

  it "instrument nested blocks unless in same line" do
    assert_agent %(
    a = foo do
      'a'
      bar do
        'b'
      end
      baz { 'c' }
    end
    ), <<-CR
    a = $p.i(foo do
      $p.i('a', 3)
      $p.i(bar do
        $p.i('b', 5)
      end, 4)
      $p.i(baz do
        'c'
      end, 7)
    end, 2)
    CR
  end

  it "instrument typeof" do
    assert_agent %(typeof(5)), %($p.i(typeof(5), 1))
  end

  it "instrument exceptions" do
    assert_agent %(
    begin
      raise "The exception"
    rescue ex : String
      1
    rescue
      0
    else
      2
    ensure
      3
    end
    def foo(x)
      raise "Other"
    rescue
      0
    end
    ), <<-CR
    begin
      raise($p.i("The exception", 3))
    rescue ex : String
      $p.i(1, 5)
    rescue
      $p.i(0, 7)
    else
      $p.i(2, 9)
    ensure
      $p.i(3, 11)
    end
    def foo(x)
      begin
        raise($p.i("Other", 14))
      rescue
        $p.i(0, 16)
      end
    end
    CR
  end
end
