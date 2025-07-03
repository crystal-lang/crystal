{% skip_file if flag?(:without_playground) %}

require "../../../spec_helper"

private def instrument(source)
  ast = Parser.new(source).parse
  instrumented = Playground::AgentInstrumentorTransformer.transform ast
  instrumented.to_s
end

private def assert_agent(source, expected, *, file : String = __FILE__, line : Int32 = __LINE__)
  # parse/to_s expected so block syntax and spaces do not bother
  expected = Parser.new(expected).parse.to_s

  instrument(source).should contain(expected), file: file, line: line

  # whatever case should work before it should work with appended lines
  instrument("#{source}\n1\n").should contain(expected)
end

private def assert_agent_eq(source, expected)
  # parse/to_s expected so block syntax and spaces do not bother
  expected = Parser.new(expected).parse.to_s
  instrument(source).should eq(expected)
end

class Playground::Agent
  @ws : HTTP::WebSocket | TestAgent::FakeSocket
end

private class TestAgent < Playground::Agent
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

describe Playground::Agent do
  it "should send json messages and return inspected value" do
    agent = TestAgent.new(".", 32)
    agent.i(1) { 5 }.should eq(5)
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"5","html_value":"5","value_type":"Int32"}))
    x, y = 3, 4
    agent.i(1, ["x", "y"]) { {x, y} }.should eq({3, 4})
    agent.last_message.should eq(%({"tag":32,"type":"value","line":1,"value":"{3, 4}","html_value":"{3, 4}","value_type":"Tuple(Int32, Int32)","data":{"x":"3","y":"4"}}))
  end
end

describe Playground::AgentInstrumentorTransformer do
  it "instrument literals" do
    assert_agent %(nil), %(_p.i(1) { nil })
    assert_agent %(5), %(_p.i(1) { 5 })
    assert_agent %(5.0), %(_p.i(1) { 5.0 })
    assert_agent %("lorem"), %(_p.i(1) { "lorem" })
    assert_agent %(true), %(_p.i(1) { true })
    assert_agent %('c'), %(_p.i(1) { 'c' })
    assert_agent %(:foo), %(_p.i(1) { :foo })
    assert_agent %([1, 2]), %(_p.i(1) { [1, 2] })
    assert_agent %({} of Int32 => Int32), %(_p.i(1) { {} of Int32 => Int32 })
    assert_agent %(/a/), %(_p.i(1) { /a/ })
  end

  it "instrument literals with expression names" do
    assert_agent %({1, 2}), %(_p.i(1, ["1", "2"]) { {1, 2} })
    assert_agent %({x, x + y}), %(_p.i(1, ["x", "x + y"]) { {x, x + y} })
    assert_agent %(a = {x, x + y}), %(a = _p.i(1, ["x", "x + y"]) { {x, x + y} })
  end

  it "instrument single variables expressions" do
    assert_agent %(x), %(_p.i(1) { x })
  end

  it "instrument string interpolations" do
    assert_agent %("lorem \#{a} \#{b}"), %(_p.i(1) { "lorem \#{a} \#{b}" })
  end

  it "instrument assignments in the rhs" do
    assert_agent %(a = 4), %(a = _p.i(1) { 4 })
  end

  it "do not instrument constants assignments" do
    assert_agent %(A = 4), %(A = 4)
  end

  it "instrument not expressions" do
    assert_agent %(!true), %(_p.i(1) { !true })
  end

  it "instrument binary expressions" do
    assert_agent %(a && b), %(_p.i(1) { a && b })
    assert_agent %(a || b), %(_p.i(1) { a || b })
  end

  it "instrument chained comparisons (#4663)" do
    assert_agent %(1 <= 2 <= 3), %(_p.i(1) { 1 <= 2 <= 3 })
  end

  it "instrument unary expressions" do
    assert_agent %(pointerof(x)), %(_p.i(1) { pointerof(x) })
  end

  it "instrument is_a? expressions" do
    assert_agent %(x.is_a?(Foo)), %(_p.i(1) { x.is_a?(Foo) })
  end

  it "instrument ivar with obj" do
    assert_agent %(x.@foo), %(_p.i(1) { x.@foo })
  end

  it "instrument multi assignments in the rhs" do
    assert_agent %(a, b = t), %(a, b = _p.i(1) { t })
    assert_agent %(a, b = d, f), %(a, b = _p.i(1, ["d", "f"]) { {d, f} })
    assert_agent %(a, b = {d, f}), %(a, b = _p.i(1, ["d", "f"]) { {d, f} })
  end

  it "instrument puts with args" do
    assert_agent %(puts 3), %(puts(_p.i(1) { 3 }))
    assert_agent %(puts a, 2, b), %(puts(*_p.i(1, ["a", "2", "b"]) { {a, 2, b} }))
    assert_agent %(puts *{3}), %(puts(*_p.i(1, ["3"]) { {3} }))
    assert_agent %(puts *{3,a}), %(puts(*_p.i(1, ["3", "a"]) { {3,a} }))
    assert_agent_eq %(puts), %(puts)
  end

  it "instrument print with args" do
    assert_agent %(print 3), %(print(_p.i(1) { 3 }))
    assert_agent %(print a, 2, b), %(print(*_p.i(1, ["a", "2", "b"]) { {a, 2, b} }))
    assert_agent_eq %(print), %(print)
  end

  it "instrument single statement def" do
    assert_agent %(
    def foo
      4
    end), <<-CRYSTAL
    def foo
      _p.i(3) { 4 }
    end
    CRYSTAL
  end

  it "instrument single statement var def" do
    assert_agent %(
    def foo(x)
      x
    end), <<-CRYSTAL
    def foo(x)
      _p.i(3) { x }
    end
    CRYSTAL
  end

  it "instrument multi statement def" do
    assert_agent %(
    def foo
      2
      6
    end), <<-CRYSTAL
    def foo
      _p.i(3) { 2 }
      _p.i(4) { 6 }
    end
    CRYSTAL
  end

  it "instrument returns inside def" do
    assert_agent %(
    def foo
      return 4
    end), <<-CRYSTAL
    def foo
      return _p.i(3) { 4 }
    end
    CRYSTAL
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
    end), <<-CRYSTAL
    class Foo
      def initialize
        @x = _p.i(4) { 3 }.as(typeof(3))
      end
      def bar(x)
        x = _p.i(7) { x + x }
        _p.i(8) { x }
      end
      def self.bar(x, y)
        _p.i(11) { x + y }
      end
    end
    CRYSTAL
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
    end), <<-CRYSTAL
    class Foo
      def initialize
        @x = _p.i(4) { 3 }.as(typeof(3))
        @@x = _p.i(5) { 4 }.as(typeof(4))
      end
      def bar
        _p.i(8) { @x }
      end
      def self.bar
        _p.i(11) { @@x }
      end
    end
    CRYSTAL
  end

  it "do not instrument class initializing arguments" do
    assert_agent %(
    class Foo
      def initialize(@x, @y)
        @z = @x + @y
      end
    end
    ), <<-CRYSTAL
    class Foo
      def initialize(x, y)
        @x = x
        @y = y
        @z = _p.i(4) { @x + @y }.as(typeof(@x + @y))
      end
    end
    CRYSTAL
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
    end), <<-CRYSTAL
    class Foo
      private def bar
        _p.i(4) { 1 }
      end
      protected def self.bar
        _p.i(7) { 2 }
      end
    end
    CRYSTAL
  end

  it "do not instrument macro calls in class" do
    assert_agent %(
    class Foo
      property foo
    end), <<-CRYSTAL
    class Foo
      property foo
    end
    CRYSTAL
  end

  it "instrument nested class defs" do
    assert_agent %(
    class Bar
      class Foo
        def initialize
          @x = 3
        end
      end
    end), <<-CRYSTAL
    class Bar
      class Foo
        def initialize
          @x = _p.i(5) { 3 }.as(typeof(3))
        end
      end
    end
    CRYSTAL
  end

  it "do not instrument records class" do
    assert_agent %(
    record Foo, x, y
    ), <<-CRYSTAL
    record Foo, x, y
    CRYSTAL
  end

  it "do not instrument top level macro calls" do
    assert_agent(<<-CRYSTAL, <<-CRYSTAL)
    macro bar
      def foo
        4
      end
    end
    bar
    foo
    CRYSTAL
    macro bar
      def foo
        4
      end
    end
    bar
    _p.i(7) { foo }
    CRYSTAL
  end

  it "do not instrument class/module declared macro" do
    assert_agent(<<-CRYSTAL, <<-CRYSTAL)
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
    CRYSTAL
    module Bar
      macro bar
        4
      end
    end

    class Foo
      include Bar
      def foo
        bar
        _p.i(11) { 8 }
      end
    end
    CRYSTAL
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
    end), <<-CRYSTAL
    module Bar
      class Baz
        class Foo
          def initialize
            @x = _p.i(6) { 3 }.as(typeof(3))
          end
        end
      end
    end
    CRYSTAL
  end

  it "instrument if statement" do
    assert_agent %(
    if a
      b
    else
      c
    end
    ), <<-CRYSTAL
    if a
      _p.i(3) { b }
    else
      _p.i(5) { c }
    end
    CRYSTAL
  end

  it "instrument unless statement" do
    assert_agent %(
    unless a
      b
    else
      c
    end
    ), <<-CRYSTAL
    unless a
      _p.i(3) { b }
    else
      _p.i(5) { c }
    end
    CRYSTAL
  end

  it "instrument while statement" do
    assert_agent %(
    while a
      b
      c
    end
    ), <<-CRYSTAL
    while a
      _p.i(3) { b }
      _p.i(4) { c }
    end
    CRYSTAL
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
    ), <<-CRYSTAL
    case a
    when 0
      _p.i(4) { b }
    when 1
      _p.i(6) { c }
    else
      _p.i(8) { d }
    end
    CRYSTAL
  end

  it "instrument blocks and single yields" do
    assert_agent %(
    def foo(x)
      yield x
    end
    foo do |a|
      a
    end
    ), <<-CRYSTAL
    def foo(x)
      yield _p.i(3) { x }
    end
    _p.i(5) do
      foo do |a|
        _p.i(6) { a }
      end
    end
    CRYSTAL
  end

  it "instrument blocks and but non multi yields" do
    assert_agent %(
    def foo(x)
      yield x, 1
    end
    foo do |a, i|
      a
    end
    ), <<-CRYSTAL
    def foo(x)
      yield x, 1
    end
    _p.i(5) do
      foo do |a, i|
        _p.i(6) { a }
      end
    end
    CRYSTAL
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
    ), <<-CRYSTAL
    a = _p.i(2) do
      foo do
        _p.i(3) { 'a' }
        _p.i(4) do
          bar do
            _p.i(5) { 'b' }
          end
        end
        _p.i(7) do baz do 'c' end end
      end
    end
    CRYSTAL
  end

  it "instrument typeof" do
    assert_agent %(typeof(5)), %(_p.i(1) { typeof(5) })
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
    ), <<-CRYSTAL
    begin
      raise(_p.i(3) { "The exception" })
    rescue ex : String
      _p.i(5) { 1 }
    rescue
      _p.i(7) { 0 }
    else
      _p.i(9) { 2 }
    ensure
      _p.i(11) { 3 }
    end
    def foo(x)
      begin
        raise(_p.i(14) { "Other" })
      rescue
        _p.i(16) { 0 }
      end
    end
    CRYSTAL
  end
end

private def assert_compile(source)
  sources = Playground::Session.instrument_and_prelude("", "", 0, source)
  compiler = Compiler.new
  compiler.no_codegen = true
  compiler.compile sources, "fake-no-build"
end

describe Playground::Session do
  it { assert_compile %(puts "1") }
end
