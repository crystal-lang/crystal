require "ast"
require "llvm"
require "types"
require "program"

module Crystal
  class Program
    def define_primitives
      define_object_primitives
      define_primitive_types_primitives
      define_reference_primitives
      define_pointer_primitives
      define_symbol_primitives
      define_type_sizes
      define_math_primitives
    end

    def define_object_primitives
      object.add_def Def.new("class", ([] of Arg), Primitive.new(:class))
    end

    def define_primitive_types_primitives
      binary = Primitive.new(:binary)
      cast = Primitive.new(:cast)

      ints = [int8, int16, int32, int64, uint8, uint16, uint32, uint64] of Type
      floats = [float32, float64] of Type
      nums = ints + floats

      %w(+ - * /).each do |op|
        nums.each do |another_number|
          number.add_def Def.new(op, [Arg.new_with_type("other", another_number)], binary)
        end
      end

      %w(== < <= > >= !=).each do |op|
        nums.each do |another_number|
          number.add_def Def.new(op, [Arg.new_with_type("other", another_number)], binary)
        end
        char.add_def Def.new(op, [Arg.new_with_type("other", char)], binary)
      end

      %w(% << >> | & ^).each do |op|
        ints.each do |another_int|
          int.add_def Def.new(op, [Arg.new_with_type("other", int)], binary)
        end
      end

      [bool, symbol].each do |type|
        %w(== !=).each do |op|
          type.add_def Def.new(op, [Arg.new_with_type("other", type)], binary)
        end
      end

      %w(to_i to_i8 to_i32 to_i16 to_i32 to_i64 to_u to_u8 to_u16 to_u32 to_u64 to_f to_f32 to_f64).each do |op|
        number.add_def Def.new(op, ([] of Arg), cast)
      end

      int.add_def Def.new("chr", ([] of Arg), cast)
      char.add_def Def.new("ord", ([] of Arg), cast)

      float32.add_def Def.new("**", [Arg.new_with_type("other", float32)], Primitive.new(:float32_pow))
      float64.add_def Def.new("**", [Arg.new_with_type("other", float64)], Primitive.new(:float64_pow))
    end

    def define_reference_primitives
      reference.add_def Def.new("object_id", ([] of Arg), Primitive.new(:object_id))
      reference.add_def Def.new("to_cstr", ([] of Arg), Primitive.new(:object_to_cstr))

      [object, value, bool, char, int32, int64, float32, float64, symbol, reference].each do |type|
        type.add_def Def.new("crystal_type_id", ([] of Arg), Primitive.new(:object_crystal_type_id))
      end
    end

    def define_pointer_primitives
      pointer.metaclass.add_def Def.new("malloc", [Arg.new_with_type("size", uint64)], Primitive.new(:pointer_malloc))
      pointer.metaclass.add_def Def.new("null", ([] of Arg), Primitive.new(:pointer_null))
      pointer.metaclass.add_def Def.new("new", [Arg.new_with_restriction("address", Ident.new(["UInt64"], true))], Primitive.new(:pointer_new))
      pointer.add_def Def.new("value", ([] of Arg), Primitive.new(:pointer_get))
      pointer.add_def Def.new("value=", [Arg.new_with_restriction("value", Ident.new(["T"]))], Primitive.new(:pointer_set))
      pointer.add_def Def.new("address", ([] of Arg), Primitive.new(:pointer_address))
      pointer.add_def Def.new("realloc", [Arg.new_with_type("size", uint64)], Primitive.new(:pointer_realloc))
      pointer.add_def Def.new("+", [Arg.new_with_type("offset", int64)], Primitive.new(:pointer_add))
      pointer.add_def Def.new("-", [Arg.new_with_restriction("other", SelfType.new)], Primitive.new(:pointer_diff))
      pointer.add_def Def.new("as", [Arg.new("type")], Primitive.new(:pointer_cast))
    end

    def define_symbol_primitives
      symbol.add_def Def.new("hash", ([] of Arg), Primitive.new(:symbol_hash))
      symbol.add_def Def.new("to_s", ([] of Arg), Primitive.new(:symbol_to_s))
    end

    def define_type_sizes
      byte_size = Primitive.new(:byte_size)
      [void, self.nil, bool, char, int8, int16, int32, int64, uint8, uint16, uint32, uint64, float32, float64, symbol, reference, pointer].each do |t|
        t.metaclass.add_def Def.new("byte_size", ([] of Arg), byte_size)
      end
    end

    def define_math_primitives
      math = types["Math"].metaclass
      math.add_def Def.new("sqrt", [Arg.new_with_type("value", float32)], Primitive.new(:math_sqrt_float32))
      math.add_def Def.new("sqrt", [Arg.new_with_type("value", float64)], Primitive.new(:math_sqrt_float64))
    end

    def sprintf(llvm_mod)
      llvm_mod.functions["sprintf"]? || llvm_mod.functions.add("sprintf", [LLVM.pointer_type(LLVM::Int8)], LLVM::Int32, true)
    end

    def realloc(llvm_mod)
      llvm_mod.functions["realloc"]? || llvm_mod.functions.add("realloc", ([LLVM.pointer_type(LLVM::Int8), LLVM::Int64]), LLVM.pointer_type(LLVM::Int8))
    end

    def memset(llvm_mod)
      llvm_mod.functions["llvm.memset.p0i8.i32"]? || llvm_mod.functions.add("llvm.memset.p0i8.i32", [LLVM.pointer_type(LLVM::Int8), LLVM::Int8, LLVM::Int32, LLVM::Int32, LLVM::Int1], LLVM::Void)
    end

    def sqrt_float64(llvm_mod)
      llvm_mod.functions["llvm.sqrt.f64"]? || llvm_mod.functions.add("llvm.sqrt.f64", [LLVM::Double], LLVM::Double)
    end

    def sqrt_float32(llvm_mod)
      llvm_mod.functions["llvm.sqrt.f32"]? || llvm_mod.functions.add("llvm.sqrt.f32", [LLVM::Float], LLVM::Float)
    end

    def pow_float64(llvm_mod)
      llvm_mod.functions["llvm.pow.f64"]? || llvm_mod.functions.add("llvm.pow.f64", [LLVM::Double, LLVM::Double], LLVM::Double)
    end

    def pow_float32(llvm_mod)
      llvm_mod.functions["llvm.pow.f32"]? || llvm_mod.functions.add("llvm.pow.f32", [LLVM::Float, LLVM::Float], LLVM::Float)
    end

    def trampoline_init(llvm_mod)
      llvm_mod.functions["llvm.init.trampoline"]? || llvm_mod.functions.add("llvm.init.trampoline", [
        LLVM.pointer_type(LLVM::Int8), LLVM.pointer_type(LLVM::Int8), LLVM.pointer_type(LLVM::Int8)
      ], LLVM::Void)
    end

    def trampoline_adjust(llvm_mod)
      llvm_mod.functions["llvm.adjust.trampoline"]? || llvm_mod.functions.add("llvm.adjust.trampoline", [
        LLVM.pointer_type(LLVM::Int8)
      ], LLVM.pointer_type(LLVM::Int8))
    end
  end

  class FunDef
    property! :external
  end
end
