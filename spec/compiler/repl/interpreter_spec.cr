require "../spec_helper"

describe Crystal::Repl::Interpreter do
  context "literals" do
    it "interprets nil" do
      interpret("nil").should be_nil
    end

    it "interprets a bool (false)" do
      interpret("false").should be_false
    end

    it "interprets a bool (true)" do
      interpret("true").should be_true
    end

    it "interprets an Int8" do
      interpret("123_i8").should eq(123_i8)
    end

    it "interprets an UInt8" do
      interpret("145_u8").should eq(145_u8)
    end

    it "interprets an Int16" do
      interpret("12345_i16").should eq(12345_i16)
    end

    it "interprets an UInt16" do
      interpret("12389_u16").should eq(12389_u16)
    end

    it "interprets an Int32" do
      interpret("123456789_i32").should eq(123456789)
    end

    it "interprets an UInt32" do
      interpret("323456789_u32").should eq(323456789_u32)
    end

    it "interprets an Int64" do
      interpret("123_i64").should eq(123_i64)
    end

    it "interprets an UInt64" do
      interpret("123_u64").should eq(123_u64)
    end

    it "interprets a Float32" do
      interpret("1.5_f32").should eq(1.5_f32)
    end

    it "interprets a Float64" do
      interpret("1.5").should eq(1.5)
    end

    it "interprets a char" do
      interpret("'a'").should eq('a')
    end

    # it "interprets a String literal" do
    #   value = interpret(%("Hello world!"))
    #   value.should be_a(String)
    #   value.should eq("Hello world!")
    # end
  end

  context "local variables" do
    it "interprets variable set" do
      interpret(<<-CODE).should eq(1)
      a = 1
      CODE
    end

    it "interprets variable set and get" do
      interpret(<<-CODE).should eq(1)
      a = 1
      a
      CODE
    end

    it "interprets variable set and get, second local var" do
      interpret(<<-CODE).should eq(1)
      x = 10
      a = 1
      a
      CODE
    end
  end

  context "conversion" do
    {% for target_type in %w(u8 i8 u16 i16 u32 i32 u i u64 i64 f32 f64).map(&.id) %}
      it "interprets Int8::MAX#to_{{target_type}}!" do
        interpret("#{Int8::MAX}_i8.to_{{target_type}}!").should eq(Int8::MAX.to_{{target_type}}!)
      end

      it "interprets Int8::MIN#to_{{target_type}}!" do
        interpret("#{Int8::MIN}_i8.to_{{target_type}}!").should eq(Int8::MIN.to_{{target_type}}!)
      end

      it "interprets UInt8::MAX#to_{{target_type}}!" do
        interpret("#{UInt8::MAX}_u8.to_{{target_type}}!").should eq(UInt8::MAX.to_{{target_type}}!)
      end

      it "interprets Int16::MAX#to_{{target_type}}!" do
        interpret("#{Int16::MAX}_i16.to_{{target_type}}!").should eq(Int16::MAX.to_{{target_type}}!)
      end

      it "interprets Int16::MIN#to_{{target_type}}!" do
        interpret("#{Int16::MIN}_i16.to_{{target_type}}!").should eq(Int16::MIN.to_{{target_type}}!)
      end

      it "interprets UInt16::MAX#to_{{target_type}}!" do
        interpret("#{UInt16::MAX}_u16.to_{{target_type}}!").should eq(UInt16::MAX.to_{{target_type}}!)
      end

      it "interprets Int32::MAX#to_{{target_type}}!" do
        interpret("#{Int32::MAX}.to_{{target_type}}!").should eq(Int32::MAX.to_{{target_type}}!)
      end

      it "interprets Int32::MIN#to_{{target_type}}!" do
        interpret("#{Int32::MIN}.to_{{target_type}}!").should eq(Int32::MIN.to_{{target_type}}!)
      end

      it "interprets UInt32::MAX#to_{{target_type}}!" do
        interpret("#{UInt32::MAX}_u32.to_{{target_type}}!").should eq(UInt32::MAX.to_{{target_type}}!)
      end

      it "interprets Int64::MAX#to_{{target_type}}!" do
        interpret("#{Int64::MAX}_i64.to_{{target_type}}!").should eq(Int64::MAX.to_{{target_type}}!)
      end

      it "interprets Int64::MIN#to_{{target_type}}!" do
        interpret("#{Int64::MIN}_i64.to_{{target_type}}!").should eq(Int64::MIN.to_{{target_type}}!)
      end

      it "interprets UInt64::MAX#to_{{target_type}}!" do
        interpret("#{UInt64::MAX}_u64.to_{{target_type}}!").should eq(UInt64::MAX.to_{{target_type}}!)
      end

      it "interprets Float32#to_{{target_type}}! (positive)" do
        f = 23.8_f32
        interpret("23.8_f32.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end

      it "interprets Float32#to_{{target_type}}! (negative)" do
        f = -23.8_f32
        interpret("-23.8_f32.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end

      it "interprets Float64#to_{{target_type}}! (positive)" do
        f = 23.8_f64
        interpret("23.8_f64.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end

      it "interprets Float64#to_{{target_type}}! (negative)" do
        f = -23.8_f64
        interpret("-23.8_f64.to_{{target_type}}!").should eq(f.to_{{target_type}}!)
      end
    {% end %}
  end

  context "math" do
    it "interprets Int32 + Int32" do
      interpret("1 + 2").should eq(3)
    end

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
  end

  context "comparisons" do
    it "interprets Int32 < Int32" do
      interpret("1 < 2").should be_true
    end

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
  end

  context "not" do
    it "interprets not for nil" do
      interpret("!nil").should eq(true)
    end

    it "interprets not for bool true" do
      interpret("!true").should eq(false)
    end

    it "interprets not for bool false" do
      interpret("!false").should eq(true)
    end
  end

  context "if and unless" do
    it "interprets if (true)" do
      interpret("1 == 1 ? 2 : 3").should eq(2)
    end

    it "interprets if (false)" do
      interpret("1 == 2 ? 2 : 3").should eq(3)
    end

    it "interprets unless" do
      interpret("unless 1 == 1; 2; else; 3; end").should eq(3)
    end
  end

  context "while and until" do
    it "interprets while" do
      interpret(<<-CODE).should eq(10)
        a = 0
        while a < 10
          a = a + 1
        end
        a
        CODE
    end

    it "interprets while, returns nil" do
      interpret(<<-CODE).should eq(nil)
        a = 0
        while a < 10
          a = a + 1
        end
        CODE
    end

    it "interprets until" do
      interpret(<<-CODE).should eq(10)
        a = 0
        until a == 10
          a = a + 1
        end
        a
      CODE
    end
  end

  context "pointers" do
    it "interprets pointer set and get (int)" do
      interpret(<<-CODE).should eq(10)
        ptr = Pointer(Int32).malloc(1_u64)
        ptr.value = 10
        ptr.value
      CODE
    end

    it "interprets pointer set and get (bool)" do
      interpret(<<-CODE).should be_true
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

    # it "interprets pointer set and get (union type)" do
    #   interpret(<<-CODE).should eq(true)
    #     ptr = Pointer(Int32 | Bool).malloc(1_u64)
    #     ptr.value = 10
    #     ptr.value = true
    #     ptr.value
    #   CODE
    # end

    it "interprets pointer new and pointer address" do
      interpret(<<-CODE).should eq(123_u64)
        ptr = Pointer(Int32 | Bool).new(123_u64)
        ptr.address
      CODE
    end

    it "interprets pointer diff" do
      interpret(<<-CODE).should eq(8_i64)
        ptr1 = Pointer(Int32).new(133_u64)
        ptr2 = Pointer(Int32).new(100_u64)
        ptr1 - ptr2
      CODE
    end
  end

  context "types" do
    it "interprets path to type" do
      program, repl_value = interpret_full("String")
      repl_value.value.should eq(program.string.metaclass)
    end

    it "interprets typeof instance type" do
      program, repl_value = interpret_full("typeof(1)")
      repl_value.value.should eq(program.int32.metaclass)
    end

    it "interprets typeof metaclass type" do
      program, repl_value = interpret_full("typeof(Int32)")
      repl_value.value.should eq(program.class_type)
    end

    it "interprets class for non-union type" do
      program, repl_value = interpret_full("1.class")
      repl_value.value.should eq(program.int32)
    end

    it "interprets crystal_type_id for nil" do
      interpret("nil.crystal_type_id").should eq(0)
    end

    it "interprets crystal_type_id for non-nil" do
      program, repl_value = interpret_full("1.crystal_type_id")
      repl_value.value.should eq(program.llvm_id.type_id(program.int32))
    end
  end

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

private def interpret(string, prelude = "primitives")
  program, return_value = interpret_full(string, prelude)
  return_value.value
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
