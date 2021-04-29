require "../spec_helper"

describe Crystal::Repl::Interpreter do
  it "interprets nil" do
    interpret("nil").should eq(nil)
  end

  it "interprets a bool (false)" do
    interpret("false").should eq(false)
  end

  it "interprets a bool (true)" do
    interpret("true").should eq(true)
  end

  it "interprets a char" do
    interpret("'a'").should eq('a')
  end

  it "interprets an Int8" do
    value = interpret("123_i8")
    value.should be_a(Int8)
    value.should eq(123)
  end

  it "interprets an UInt8" do
    value = interpret("123_u8")
    value.should be_a(UInt8)
    value.should eq(123)
  end

  it "interprets an Int16" do
    value = interpret("123_i16")
    value.should be_a(Int16)
    value.should eq(123)
  end

  it "interprets an UInt16" do
    value = interpret("123_u16")
    value.should be_a(UInt16)
    value.should eq(123)
  end

  it "interprets an Int32" do
    value = interpret("123_i32")
    value.should be_a(Int32)
    value.should eq(123)
  end

  it "interprets an UInt32" do
    value = interpret("123_u32")
    value.should be_a(UInt32)
    value.should eq(123)
  end

  it "interprets an Int64" do
    value = interpret("123_i64")
    value.should be_a(Int64)
    value.should eq(123)
  end

  it "interprets an UInt64" do
    value = interpret("123_u64")
    value.should be_a(UInt64)
    value.should eq(123)
  end

  it "interprets a Float32" do
    value = interpret("1.5_f32")
    value.should be_a(Float32)
    value.should eq(1.5_f32)
  end

  it "interprets a Float64" do
    value = interpret("1.5")
    value.should be_a(Float64)
    value.should eq(1.5)
  end

  it "interprets a String literal" do
    value = interpret(%("Hello world!"))
    value.should be_a(String)
    value.should eq("Hello world!")
  end

  it "interprets Int32 + Int32" do
    interpret("1 + 2").should eq(3)
  end

  it "interprets simple call" do
    interpret(<<-CODE).should eq(3)
      def foo(x, y)
        x + y
      end

      foo(1, 2)
      CODE
  end

  it "interprets call with default values" do
    interpret(<<-CODE).should eq(3)
      def foo(x = 1, y = 2)
        x + y
      end

      foo
      CODE
  end

  it "interprets call with named arguments" do
    interpret(<<-CODE).should eq(15)
      def foo(x, y)
        x - y
      end

      foo(y: 10, x: 25)
      CODE
  end

  it "interprets variable set and get" do
    interpret(<<-CODE).should eq(1)
      a = 1
      a
      CODE
  end

  it "interprets pointer set and get (int)" do
    interpret(<<-CODE).should eq(10)
      ptr = Pointer(Int32).malloc(1_u64)
      ptr.value = 10
      ptr.value
    CODE
  end

  it "interprets pointer set and get (bool)" do
    interpret(<<-CODE).should eq(true)
      ptr = Pointer(Bool).malloc(1_u64)
      ptr.value = true
      ptr.value
    CODE
  end

  it "interprets pointerof, mutates pointer, read var" do
    interpret(<<-CODE).should eq(2)
      a = 1
      ptr = pointerof(a)
      ptr.value = 2
      a
    CODE
  end

  it "interprets pointerof, mutates var, read pointer" do
    interpret(<<-CODE).should eq(2)
      a = 1
      ptr = pointerof(a)
      a = 2
      ptr.value
    CODE
  end

  it "interprets pointerof and mutates memory (there are more variables)" do
    interpret(<<-CODE).should eq(2)
      x = 42
      a = 1
      ptr = pointerof(a)
      ptr.value = 2
      a
    CODE
  end
end

private def interpret(string, prelude = "primitives")
  program = Crystal::Program.new
  load_prelude(program, prelude)
  interpreter = Crystal::Repl::Interpreter.new(program)
  node = Crystal::Parser.parse(string)
  value = interpreter.interpret(node)
  value.value
end

private def load_prelude(program, prelude = "primitives")
  filenames = program.find_in_path(prelude)
  filenames.each do |filename|
    parser = Crystal::Parser.new File.read(filename), program.string_pool
    parser.filename = filename
    parsed_nodes = parser.parse
    parsed_nodes = program.normalize(parsed_nodes, inside_exp: false)
    program.top_level_semantic(parsed_nodes)
  end
end
