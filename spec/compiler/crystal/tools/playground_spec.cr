require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

private def instrument(source)
  ast = Parser.new(source).parse
  instrumented = Playground::AgentInstrumentorTransformer.transform ast
  instrumented.to_s
end

private def assert_agent(source, expected)
  # parse/to_s expected so block syntax and spaces do not bother
  expected = Parser.new(expected).parse.to_s

  instrument(source).should contain(expected)

  # whatever case should work beforeit should work with appended lines
  instrument("#{source}\n1\n").should contain(expected)
end

private def assert_agent_eq(source, expected)
  # parse/to_s expected so block syntax and spaces do not bother
  expected = Parser.new(expected).parse.to_s
  instrument(source).should eq(expected)
end

class Crystal::Playground::Agent
  @ws : HTTP::WebSocket | Crystal::Playground::TestAgent::FakeSocket
end

class Crystal::Playground::TestAgent < Playground::Agent
  class FakeSocket
    property message

    def send(@message : String)
    end
  end

  def initialize(url, @tag : Int32)
    @ws = @fake_socket = FakeSocket.new
  end

  def last_message
    @fake_socket.message
  end
end

fun a_sample_void : Void
end

describe Playground::Agent do
  it "should send json messages and return inspected value" do
    agent = Crystal::Playground::TestAgent.new(".", 32)
    agent.i(1) { 5 }.should eq(5)
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"5","value_type":"Int32"}))
    x, y = 3, 4
    agent.i(1, ["x", "y"]) { {x, y} }.should eq({3, 4})
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"{3, 4}","value_type":"{Int32, Int32}","data":{"x":"3","y":"4"}}))

    agent.i(1) { nil.as(Void?) }
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"nil","value_type":"Void?"}))
    agent.i(1) { a_sample_void.as(Void?) }
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"(void)","value_type":"Void?"}))
    agent.i(1) { a_sample_void }
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"(void)","value_type":"Void"}))
  end
end

describe Playground::AgentInstrumentorTransformer do
  it "instrument literals" do
    assert_agent %(nil), %($p.i(1) { nil })
    assert_agent %(5), %($p.i(1) { 5 })
    assert_agent %(5.0), %($p.i(1) { 5.0 })
    assert_agent %("lorem"), %($p.i(1) { "lorem" })
    assert_agent %(true), %($p.i(1) { true })
    assert_agent %('c'), %($p.i(1) { 'c' })
    assert_agent %(:foo), %($p.i(1) { :foo })
    assert_agent %([1, 2]), %($p.i(1) { [1, 2] })
    assert_agent %(/a/), %($p.i(1) { /a/ })
  end

  it "instrument literals with expression names" do
    assert_agent %({1, 2}), %($p.i(1, ["1", "2"]) { {1, 2} })
    assert_agent %({x, x + y}), %($p.i(1, ["x", "x + y"]) { {x, x + y} })
    assert_agent %(a = {x, x + y}), %(a = $p.i(1, ["x", "x + y"]) { {x, x + y} })
  end

  it "instrument single variables expressions" do
    assert_agent %(x), %($p.i(1) { x })
  end

  it "instrument single global variables expressions" do
    assert_agent %($x), %($p.i(1) { $x })
  end

  it "instrument string interpolations" do
    assert_agent %("lorem \#{a} \#{b}"), %($p.i(1) { "lorem \#{a} \#{b}" })
  end

  it "instrument assignments in the rhs" do
    assert_agent %(a = 4), %(a = $p.i(1) { 4 })
  end

  it "do not instrument constants assignments" do
    assert_agent %(A = 4), %(A = 4)
  end

  it "instrument not expressions" do
    assert_agent %(!true), %($p.i(1) { !true })
  end

  it "instrument binary expressions" do
    assert_agent %(a && b), %($p.i(1) { a && b })
    assert_agent %(a || b), %($p.i(1) { a || b })
  end

  it "instrument unary expressions" do
    assert_agent %(pointerof(x)), %($p.i(1) { pointerof(x) })
  end

  it "instrument is_a? expressions" do
    assert_agent %(x.is_a?(Foo)), %($p.i(1) { x.is_a?(Foo) })
  end

  it "instrument ivar with obj" do
    assert_agent %(x.@foo), %($p.i(1) { x.@foo })
  end

  it "instrument multi assignments in the rhs" do
    assert_agent %(a, b = t), %(a, b = $p.i(1) { t })
    assert_agent %(a, b = d, f), %(a, b = $p.i(1, ["d", "f"]) { {d, f} })
    assert_agent %(a, b = {d, f}), %(a, b = $p.i(1, ["d", "f"]) { {d, f} })
  end

  it "instrument puts with args" do
    assert_agent %(puts 3), %(puts($p.i(1) { 3 }))
    assert_agent %(puts a, 2, b), %(puts(*$p.i(1, ["a", "2", "b"]) { {a, 2, b} }))
    assert_agent_eq %(puts), %(puts)
  end

  it "instrument print with args" do
    assert_agent %(print 3), %(print($p.i(1) { 3 }))
    assert_agent %(print a, 2, b), %(print(*$p.i(1, ["a", "2", "b"]) { {a, 2, b} }))
    assert_agent_eq %(print), %(print)
  end

  it "instrument single statement def" do
    assert_agent %(
    def foo
      4
    end), <<-CR
    def foo
      $p.i(3) { 4 }
    end
    CR
  end

  it "instrument single statement var def" do
    assert_agent %(
    def foo(x)
      x
    end), <<-CR
    def foo(x)
      $p.i(3) { x }
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
      $p.i(3) { 2 }
      $p.i(4) { 6 }
    end
    CR
  end

  it "instrument returns inside def" do
    assert_agent %(
    def foo
      return 4
    end), <<-CR
    def foo
      return $p.i(3) { 4 }
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
        @x = $p.i(4) { 3 }
      end
      def bar(x)
        x = $p.i(7) { x + x }
        $p.i(8) { x }
      end
      def self.bar(x, y)
        $p.i(11) { x + y }
      end
    end
    CR
  end

  it "instrument instance variable and class variables reads and writes" do
    assert_agent %(
    class Foo
      def initialize
        @x = 3
        @@x = 4
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
        @x = $p.i(4) { 3 }
        @@x = $p.i(5) { 4 }
      end
      def bar
        $p.i(8) { @x }
      end
      def self.bar
        $p.i(11) { @@x }
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
        @z = $p.i(4) { @x + @y }
      end
    end
    CR
  end

  it "allow visibility modifiers" do
    assert_agent %(
    class Foo
      private def bar
        1
      end
      protected def self.bar
        2
      end
    end), <<-CR
    class Foo
      private def bar
        $p.i(4) { 1 }
      end
      protected def self.bar
        $p.i(7) { 2 }
      end
    end
    CR
  end

  it "do not instrument macro calls in class" do
    assert_agent %(
    class Foo
      property foo
    end), <<-CR
    class Foo
      property foo
    end
    CR
  end

  it "instrument nested class defs" do
    assert_agent %(
    class Bar
      class Foo
        def initialize
          @x = 3
        end
      end
    end), <<-CR
    class Bar
      class Foo
        def initialize
          @x = $p.i(5) { 3 }
        end
      end
    end
    CR
  end

  it "do not instrument records class" do
    assert_agent %(
    record Foo, x, y
    ), <<-CR
    record Foo, x, y
    CR
  end

  it "do not instrument top level macro calls" do
    assert_agent(<<-CR
    macro bar
      def foo
        4
      end
    end
    bar
    foo
    CR
    , <<-CR
    macro bar
      def foo
        4
      end
    end
    bar
    $p.i(7) { foo }
    CR
    )
  end

  it "do not instrument class/module declared macro" do
    assert_agent(<<-CR
    module Bar
      macro bar
        4
      end
    end

    class Foo
      include Bar
      def foo
        bar
        8
      end
    end
    CR
    , <<-CR
    module Bar
      macro bar
        4
      end
    end

    class Foo
      include Bar
      def foo
        bar
        $p.i(11) { 8 }
      end
    end
    CR
    )
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
            @x = $p.i(6) { 3 }
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
      $p.i(3) { b }
    else
      $p.i(5) { c }
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
      $p.i(3) { b }
    else
      $p.i(5) { c }
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
      $p.i(3) { b }
      $p.i(4) { c }
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
      $p.i(4) { b }
    when 1
      $p.i(6) { c }
    else
      $p.i(8) { d }
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
      yield $p.i(3) { x }
    end
    $p.i(5) do
      foo do |a|
        $p.i(6) { a }
      end
    end
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
    $p.i(5) do
      foo do |a, i|
        $p.i(6) { a }
      end
    end
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
    a = $p.i(2) do
      foo do
        $p.i(3) { 'a' }
        $p.i(4) do
          bar do
            $p.i(5) { 'b' }
          end
        end
        $p.i(7) do
          baz do
            'c'
          end
        end
      end
    end
    CR
  end

  it "instrument typeof" do
    assert_agent %(typeof(5)), %($p.i(1) { typeof(5) })
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
      raise($p.i(3) { "The exception" })
    rescue ex : String
      $p.i(5) { 1 }
    rescue
      $p.i(7) { 0 }
    else
      $p.i(9) { 2 }
    ensure
      $p.i(11) { 3 }
    end
    def foo(x)
      begin
        raise($p.i(14) { "Other" })
      rescue
        $p.i(16) { 0 }
      end
    end
    CR
  end
end
