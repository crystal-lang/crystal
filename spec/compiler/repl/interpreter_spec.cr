require "../spec_helper"

describe Crystal::Repl::Interpreter do
  it "interprets nil" do
    interpret("nil", Nil).should be_nil
  end

  it "interprets a bool (false)" do
    interpret("false", Bool).should be_false
  end

  it "interprets a bool (true)" do
    interpret("true", Bool).should be_true
  end

  it "interprets an Int8" do
    interpret("123_i8", Int8).should eq(123_i8)
  end

  it "interprets an UInt8" do
    interpret("145_u8", UInt8).should eq(145_u8)
  end

  it "interprets an Int16" do
    interpret("12345_i16", Int16).should eq(12345_i16)
  end

  it "interprets an UInt16" do
    interpret("12389_u16", UInt16).should eq(12389_u16)
  end

  # it "interprets an Int32" do
  #   value = interpret("123_i32")
  #   value.should be_a(Int32)
  #   value.should eq(123)
  # end

  # it "interprets an UInt32" do
  #   value = interpret("123_u32")
  #   value.should be_a(UInt32)
  #   value.should eq(123)
  # end

  # it "interprets an Int64" do
  #   value = interpret("123_i64")
  #   value.should be_a(Int64)
  #   value.should eq(123)
  # end

  # it "interprets an UInt64" do
  #   value = interpret("123_u64")
  #   value.should be_a(UInt64)
  #   value.should eq(123)
  # end

  # it "interprets a Float32" do
  #   value = interpret("1.5_f32")
  #   value.should be_a(Float32)
  #   value.should eq(1.5_f32)
  # end

  # it "interprets a Float64" do
  #   value = interpret("1.5")
  #   value.should be_a(Float64)
  #   value.should eq(1.5)
  # end

  # it "interprets a char" do
  #   interpret("'a'").should eq('a')
  # end

  # it "interprets a String literal" do
  #   value = interpret(%("Hello world!"))
  #   value.should be_a(String)
  #   value.should eq("Hello world!")
  # end

  # it "interprets variable set" do
  #   interpret(<<-CODE).should eq(1)
  #     a = 1
  #     CODE
  # end

  # it "interprets variable set and get" do
  #   interpret(<<-CODE).should eq(1)
  #     a = 1
  #     a
  #     CODE
  # end

  # it "interprets variable set and get, second local var" do
  #   interpret(<<-CODE).should eq(1)
  #     x = 10
  #     a = 1
  #     a
  #     CODE
  # end

  # it "interprets Int32 + Int32" do
  #   interpret("1 + 2").should eq(3)
  # end

  # it "interprets Int32 + Float64" do
  #   interpret("1 + 2.5").should eq(3.5)
  # end

  # it "interprets Float64 + Int32" do
  #   interpret("2.5 + 1").should eq(3.5)
  # end

  # it "interprets Float64 + Float64" do
  #   interpret("2.5 + 2.3").should eq(4.8)
  # end

  # it "interprets Int32 - Int32" do
  #   interpret("1 - 2").should eq(-1)
  # end

  # it "interprets Int32 * Int32" do
  #   interpret("2 * 3").should eq(6)
  # end

  # it "interprets Int32 < Int32" do
  #   interpret("1 < 2").should be_true
  # end

  # it "interprets Int32 < Float64" do
  #   interpret("1 < 2.5").should be_true
  # end

  # it "interprets Float64 < Int32" do
  #   interpret("1.2 < 2").should be_true
  # end

  # it "interprets Float64 < Float64" do
  #   interpret("1.2 < 2.3").should be_true
  # end

  # it "interprets Int32 == Int32 (true)" do
  #   interpret("1 == 1").should be_true
  # end

  # it "interprets Int32 == Int32 (false)" do
  #   interpret("1 == 2").should be_false
  # end

  # it "interprets Int32 != Int32 (true)" do
  #   interpret("1 != 2").should be_true
  # end

  # it "interprets Int32 != Int32 (false)" do
  #   interpret("1 != 1").should be_false
  # end

  # it "interprets if (true)" do
  #   interpret("1 == 1 ? 2 : 3").should eq(2)
  # end

  # it "interprets if (false)" do
  #   interpret("1 == 2 ? 2 : 3").should eq(3)
  # end

  # it "interprets if that declares variable in unexecuted branch" do
  #   interpret("if true; false; else; a = 1; end; a").should eq(nil)
  # end

  # it "interprets while" do
  #   interpret(<<-CODE).should eq(10)
  #     a = 0
  #     while a < 10
  #       a = a + 1
  #     end
  #     a
  #     CODE
  # end

  # it "interprets while, returns nil" do
  #   interpret(<<-CODE).should eq(nil)
  #     a = 0
  #     while a < 10
  #       a = a + 1
  #     end
  #     CODE
  # end

  # it "interprets pointer set and get (int)" do
  #   interpret(<<-CODE).should eq(10)
  #     ptr = Pointer(Int32).malloc(1_u64)
  #     ptr.value = 10
  #     ptr.value
  #   CODE
  # end

  # it "interprets pointer set and get (bool)" do
  #   interpret(<<-CODE).should be_true
  #     ptr = Pointer(Bool).malloc(1_u64)
  #     ptr.value = true
  #     ptr.value
  #   CODE
  # end

  # it "interprets pointerof, mutates pointer, read var" do
  #   interpret(<<-CODE).should eq(2)
  #     a = 1
  #     ptr = pointerof(a)
  #     ptr.value = 2
  #     a
  #   CODE
  # end

  # it "interprets pointerof, mutates var, read pointer" do
  #   interpret(<<-CODE).should eq(2)
  #     a = 1
  #     ptr = pointerof(a)
  #     a = 2
  #     ptr.value
  #   CODE
  # end

  # it "interprets pointerof and mutates memory (there are more variables)" do
  #   interpret(<<-CODE).should eq(2)
  #     x = 42
  #     a = 1
  #     ptr = pointerof(a)
  #     ptr.value = 2
  #     a
  #   CODE
  # end

  # it "interprets pointer set and get (union type)" do
  #   interpret(<<-CODE).should eq(true)
  #     ptr = Pointer(Int32 | Bool).malloc(1_u64)
  #     ptr.value = 10
  #     ptr.value = true
  #     ptr.value
  #   CODE
  # end

  # it "interprets pointer new and pointer address" do
  #   interpret(<<-CODE).should eq(123_u64)
  #     ptr = Pointer(Int32 | Bool).new(123_u64)
  #     ptr.address
  #   CODE
  # end

  # it "interprets pointer diff" do
  #   interpret(<<-CODE).should eq(2_i64)
  #     ptr1 = Pointer(Int32).new(132_u64)
  #     ptr2 = Pointer(Int32).new(100_u64)
  #     ptr1 - ptr2
  #   CODE
  # end

  # it "interprets typeof instance type" do
  #   program, repl_value = interpret_full("typeof(1)")
  #   repl_value.value.should eq(program.int32.metaclass)
  # end

  # it "interprets typeof metaclass type" do
  #   program, repl_value = interpret_full("typeof(Int32)")
  #   repl_value.value.should eq(program.class_type)
  # end

  # it "interprets simple call" do
  #   interpret(<<-CODE).should eq(3)
  #     def foo(x, y)
  #       x + y
  #     end

  #     foo(1, 2)
  #     CODE
  # end

  # it "interprets call with default values" do
  #   interpret(<<-CODE).should eq(3)
  #     def foo(x = 1, y = 2)
  #       x + y
  #     end

  #     foo
  #     CODE
  # end

  # it "interprets call with named arguments" do
  #   interpret(<<-CODE).should eq(15)
  #     def foo(x, y)
  #       x - y
  #     end

  #     foo(y: 10, x: 25)
  #     CODE
  # end
end

private def interpret(string, t : T.class, prelude = "primitives") forall T
  program, return_value = interpret_full(string, prelude)
  return_value.as(T*).value
end

private def interpret_full(string, prelude = "primitives")
  program = Crystal::Program.new
  load_prelude(program, prelude)
  interpreter = Crystal::Repl::Interpreter.new(program)
  node = Crystal::Parser.parse(string)
  {program, interpreter.interpret(node)}
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
