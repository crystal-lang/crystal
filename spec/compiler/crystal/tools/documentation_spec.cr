require "../../../spec_helper"

private def processed_documentation_visitor(code, cursor_location)
  compiler = Compiler.new
  compiler.no_codegen = true
  compiler.wants_doc = true
  result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

  visitor = DocumentationVisitor.new(cursor_location)
  process_result = visitor.process(result)

  {visitor, process_result}
end

private def assert_documentation(code, check_lines = true)
  cursor_location = nil
  expected_documentation = [] of String
  expected_lines = [] of Int32

  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      cursor_location = Location.new(".", line_number_0 + 1, column_number + 1)
    end

    if column_number = line.index('༓')
      expected_documentation << line[column_number + 1...line.size]
      expected_lines << line_number_0 + 2 if check_lines
    end
  end

  code = code.delete &.in?('‸', '༓')

  if cursor_location
    visitor, result = processed_documentation_visitor(code, cursor_location)

    if documentations = result.documentations
      result_documentation = documentations.map(&.[0]).sort!
      result_lines = visitor.documentations.map(&.[1].line_number).sort!

      result_documentation.should eq(expected_documentation.sort!)
      result_lines.should eq(expected_lines.sort!) if check_lines
    else
      raise "no documentation found"
    end
  else
    raise "no cursor found in spec"
  end
end

describe "documentation" do
  it "finds top level method calls" do
    assert_documentation %(
      # ༓Hello world
      def foo
        1
      end

      puts f‸oo
    )
  end

  it "find documentation from different classes" do
    assert_documentation %(
      class Foo
        # ༓Foo docs
        def foo
        end
      end

      class Bar
        # ༓Bar docs
        def foo
        end
      end

      def bar(o)
        o.f‸oo
      end

      bar(Foo.new)
      bar(Bar.new)
    )
  end

  it "find documentation from classes that are only used" do
    assert_documentation %(
      class Foo
        # ༓Foo.foo
        def foo
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
    assert_documentation %(
      # ༓Hello world
      def foo
        1
      end

      while false
        f‸oo
      end
    )
  end

  it "find method calls inside while cond" do
    assert_documentation %(
      # ༓Hello world
      def foo
        1
      end

      while f‸oo
        puts 2
      end
    )
  end

  it "find method calls inside if" do
    assert_documentation %(
      # ༓Hello world
      def foo
        1
      end

      if f‸oo
        puts 2
      end
    )
  end

  it "find method calls inside trailing if" do
    assert_documentation %(
      # ༓Hello world
      def foo
        1
      end

      puts 2 if f‸oo
    )
  end

  it "find method calls inside rescue" do
    assert_documentation %(
      # ༓Hello world
      def foo
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
    assert_documentation %(
      macro foo
        # ༓bar docs
        def bar
        end
      end

      macro baz
        foo
      end

      baz
      b‸ar
    ), check_lines: false
  end

  it "can display text output" do
    visitor, result = processed_documentation_visitor(%(
      # foo docs
      macro foo
        # bar docs
        def bar
        end
      end

      # baz docs
      macro baz
        foo
      end

      baz
      bar
    ), Location.new(".", 15, 9))

    String::Builder.build do |io|
      result.to_text(io)
    end.should eq <<-DOC
    1 doc comment found
    .:5:9
    bar docs

    DOC
  end

  it "can display json output" do
    _, result = processed_documentation_visitor(%(
      # foo docs
      macro foo
        # bar docs
        def bar
        end
      end

      # baz docs
      macro baz
        foo
      end

      baz
      bar
    ), Location.new(".", 15, 9))

    String::Builder.build do |io|
      result.to_json(io)
    end.should eq %({"status":"ok","message":"1 doc comment found","documentations":[["bar docs",".:5:9"]]})
  end

  it "find implementation in class methods" do
    assert_documentation %(
    # ༓Hello world
    def foo
      1
    end

    class Bar
      def self.bar
        f‸oo
      end
    end

    Bar.bar)
  end

  it "find implementation in generic class" do
    assert_documentation %(
    class Foo
      # ༓Foo stuff
      def self.foo
      end
    end

    class Baz
      # ༓Baz stuff
      def self.foo
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
    assert_documentation %(
    # ༓Hello world
    def foo
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
    assert_documentation %(
    # ༓Hello world
    def foo
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
    assert_documentation %(
    # ༓Hello world
    def foo

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
    assert_documentation %(
    # ༓Hello world
    private def foo
    end

    private def bar
      f‸oo
    end

    bar
    )
  end

  it "find implementation inside contained file private class' class method" do
    assert_documentation %(
    # ༓Hello world
    private def foo
    end

    private class Bar
      def self.bar
        f‸oo
      end
    end

    Bar.bar
    )
  end

  it "find class implementation" do
    assert_documentation %(
    # ༓Foo docs
    class Foo
    end

    F‸oo
    )
  end

  # TODO: currently new docs overwrite old docs.
  # Returns ["More foo docs", "More foo docs"]
  pending "from open classes" do
    assert_documentation %(
    # ༓Foo docs
    class Foo
      def foo
      end
    end

    # ༓More foo docs
    class Foo
      def bar
      end
    end

    F‸oo
    )
  end

  it "find struct implementation" do
    assert_documentation %(
    # ༓Foo docs
    struct Foo
    end

    F‸oo
    )
  end

  it "find module implementation" do
    assert_documentation %(
    # ༓Foo docs
    module Foo
    end

    F‸oo
    )
  end

  it "find enum implementation" do
    assert_documentation %(
    # ༓Foo docs
    enum Foo
      Foo
    end

    F‸oo
    )
  end

  it "find enum value implementation" do
    assert_documentation %(
    enum Foo
      # ༓Foo docs
      Foo
    end

    Foo::F‸oo
    )
  end

  it "find alias implementation" do
    assert_documentation %(
    class Foo
    end

    # ༓Bar docs
    alias Bar = Foo

    B‸ar
    )
  end

  it "find class defined by macro" do
    assert_documentation %(
    macro foo
      # ༓foo docs
      class Foo
      end
    end

    foo

    F‸oo
    ), check_lines: false
  end

  it "find class inside method" do
    assert_documentation %(
    # ༓Foo docs
    class Foo
    end

    def foo
      F‸oo
    end

    foo
    )
  end

  it "find const implementation" do
    assert_documentation %(
    # ༓Foo docs
    Foo = 42

    F‸oo
    )
  end
end
