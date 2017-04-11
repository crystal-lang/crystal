require "../../../spec_helper"

private def processed_implementation_visitor(code, cursor_location)
  compiler = Compiler.new
  compiler.no_codegen = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = ImplementationsVisitor.new(cursor_location)
  process_result = visitor.process(result)

  {visitor, process_result}
end

private def assert_implementations(code)
  cursor_location = nil
  expected_locations = [] of Location

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      cursor_location = Location.new(".", line_number_0 + 1, column_number + 1)
    end

    if column_number = line.index('༓')
      expected_locations << Location.new(".", line_number_0 + 1, column_number + 1)
    end
  end

  code = code.gsub('‸', "").gsub('༓', "")

  if cursor_location
    visitor, result = processed_implementation_visitor(code, cursor_location)

    result_location = result.implementations.not_nil!.map { |e| Location.new(e.filename.not_nil!, e.line.not_nil!, e.column.not_nil!).to_s }.sort

    result_location.should eq(expected_locations.map(&.to_s))
  else
    raise "no cursor found in spec"
  end
end

# References
#
#   ༓ marks the expected implementations to be found
#   ‸ marks the method call which implementations wants to be found
#
describe "implementations" do
  it "find top level method calls" do
    assert_implementations %(
      ༓def foo
        1
      end

      puts f‸oo
    )
  end

  it "find implementors of different classes" do
    assert_implementations %(
      class Foo
        ༓def foo
        end
      end

      class Bar
        ༓def foo
        end
      end

      def bar(o)
        o.f‸oo
      end

      bar(Foo.new)
      bar(Bar.new)
    )
  end

  it "find implementors of classes that are only used" do
    assert_implementations %(
      class Foo
        ༓def foo
        end
      end

      class Bar
        def foo
        end
      end

      def bar(o)
        o.f‸oo
      end

      bar(Foo.new)
      Bar.new
    )
  end

  it "find method calls inside while" do
    assert_implementations %(
      ༓def foo
        1
      end

      while false
        f‸oo
      end
    )
  end

  it "find method calls inside while cond" do
    assert_implementations %(
      ༓def foo
        1
      end

      while f‸oo
        puts 2
      end
    )
  end

  it "find method calls inside if" do
    assert_implementations %(
      ༓def foo
        1
      end

      if f‸oo
        puts 2
      end
    )
  end

  it "find method calls inside trailing if" do
    assert_implementations %(
      ༓def foo
        1
      end

      puts 2 if f‸oo
    )
  end

  it "find method calls inside rescue" do
    assert_implementations %(
      ༓def foo
        1
      end

      begin
        puts 2
      rescue
        f‸oo
      end
    )
  end

  it "find implementation from macro expansions" do
    assert_implementations %(
      macro foo
        def bar
        end
      end

      macro baz
        foo
      end

      ༓baz
      b‸ar
    )
  end

  it "find full trace for macro expansions" do
    visitor, result = processed_implementation_visitor(%(
      macro foo
        def bar
        end
      end

      macro baz
        foo
      end

      baz
      bar
    ), Location.new(".", 12, 9))

    result.implementations.should_not be_nil
    impls = result.implementations.not_nil!
    impls.size.should eq(1)

    impls[0].line.should eq(11) # location of baz
    impls[0].column.should eq(7)
    impls[0].filename.should eq(".")

    impls[0].expands.should_not be_nil
    exp = impls[0].expands.not_nil!
    exp.line.should eq(8) # location of foo call in macro baz
    exp.column.should eq(9)
    exp.macro.should eq("baz")
    exp.filename.should eq(".")

    exp.expands.should_not be_nil
    exp = exp.expands.not_nil!
    exp.line.should eq(3) # location of def bar in macro foo
    exp.column.should eq(9)
    exp.macro.should eq("foo")
    exp.filename.should eq(".")
  end

  it "can display text output" do
    visitor, result = processed_implementation_visitor(%(
      macro foo
        def bar
        end
      end

      macro baz
        foo
      end

      baz
      bar
    ), Location.new(".", 12, 9))

    String::Builder.build do |io|
      result.to_text(io)
    end.should eq %(1 implementation found
.:11:7
 ~> macro baz: .:8:9
 ~> macro foo: .:3:9
)
  end

  it "can display json output" do
    _, result = processed_implementation_visitor(%(
      macro foo
        def bar
        end
      end

      macro baz
        foo
      end

      baz
      bar
    ), Location.new(".", 12, 9))

    String::Builder.build do |io|
      result.to_json(io)
    end.should eq %({"status":"ok","message":"1 implementation found","implementations":[{"line":11,"column":7,"filename":".","expands":{"line":8,"column":9,"filename":".","macro":"baz","expands":{"line":3,"column":9,"filename":".","macro":"foo"}}}]})
  end

  it "find implementation in class methods" do
    assert_implementations %(
    ༓def foo
    end

    class Bar
      def self.bar
        f‸oo
      end
    end

    Bar.bar)
  end

  it "find implementation in generic class" do
    assert_implementations %(
    class Foo
      ༓def self.foo
      end
    end

    class Baz
      ༓def self.foo
      end
    end

    class Bar(T)
      def bar
        T.f‸oo
      end
    end

    Bar(Foo).new.bar
    Bar(Baz).new.bar
    )
  end

  it "find implementation in generic class methods" do
    assert_implementations %(
    ༓def foo
    end

    class Bar(T)
      def self.bar
        f‸oo
      end
    end

    Bar(Nil).bar
    )
  end

  it "find implementation inside a module class" do
    assert_implementations %(
    ༓def foo
    end

    module Baz
      class Bar(T)
        def self.bar
          f‸oo
        end
      end
    end

    Baz::Bar(Nil).bar
    )
  end

  it "find implementation inside contained class' class method" do
    assert_implementations %(
    ༓def foo

    end

    class Bar(T)
      class Foo
        def self.bar_foo
          f‸oo
        end
      end
    end

    Bar::Foo.bar_foo
    )
  end

  it "find implementation inside contained file private method" do
    assert_implementations %(
    private ༓def foo
    end

    private def bar
      f‸oo
    end

    bar
    )
  end

  it "find implementation inside contained file private class' class method" do
    assert_implementations %(
    private ༓def foo
    end

    private class Bar
      def self.bar
        f‸oo
      end
    end

    Bar.bar
    )
  end
end
