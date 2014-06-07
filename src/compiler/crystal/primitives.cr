require "ast"
require "llvm"
require "types"
require "program"

module Crystal
  class Program
    def define_primitives
      define_object_primitives
      define_primitive_types_primitives
      define_struct_primitives
      define_reference_primitives
      define_pointer_primitives
      define_symbol_primitives
    end

    def define_object_primitives
      object.add_def Def.new("class", ([] of Arg), Primitive.new(:class))
      # object.metaclass.add_def Def.new("name", ([] of Arg), Primitive.new(:class_name))
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
          int.add_def Def.new(op, [Arg.new_with_type("other", another_int)], binary)
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
      symbol.add_def Def.new("to_i", ([] of Arg), cast)
    end

    def define_reference_primitives
      reference.add_def Def.new("object_id", ([] of Arg), Primitive.new(:object_id))
      reference.add_def Def.new("to_cstr", ([] of Arg), Primitive.new(:object_to_cstr))

      [object, value, bool, char, int32, int64, float32, float64, symbol, reference].each do |type|
        type.add_def Def.new("crystal_type_id", ([] of Arg), Primitive.new(:object_crystal_type_id))
      end
    end

    def define_struct_primitives
      self.struct.add_def Def.new("==", [Arg.new_with_restriction("other", Self.new)], Primitive.new(:struct_equals))
    end

    def define_pointer_primitives
      pointer.metaclass.add_def Def.new("malloc", [Arg.new_with_type("size", uint64)], Primitive.new(:pointer_malloc))
      pointer.metaclass.add_def Def.new("null", ([] of Arg), Primitive.new(:pointer_null))
      pointer.metaclass.add_def Def.new("new", [Arg.new_with_restriction("address", Path.new(["UInt64"], true))], Primitive.new(:pointer_new))
      pointer.add_def Def.new("value", ([] of Arg), Primitive.new(:pointer_get))
      pointer.add_def Def.new("value=", [Arg.new_with_restriction("value", Path.new(["T"]))], Primitive.new(:pointer_set))
      pointer.add_def Def.new("address", ([] of Arg), Primitive.new(:pointer_address))
      pointer.add_def Def.new("realloc", [Arg.new_with_type("size", uint64)], Primitive.new(:pointer_realloc))
      pointer.add_def Def.new("+", [Arg.new_with_type("offset", int64)], Primitive.new(:pointer_add))
      pointer.add_def Def.new("-", [Arg.new_with_restriction("other", Self.new)], Primitive.new(:pointer_diff))
    end

    def define_symbol_primitives
      symbol.add_def Def.new("hash", ([] of Arg), Primitive.new(:symbol_hash))
      symbol.add_def Def.new("to_s", ([] of Arg), Primitive.new(:symbol_to_s))
    end

    def sprintf(llvm_mod)
      llvm_mod.functions["sprintf"]? || llvm_mod.functions.add("sprintf", [LLVM::VoidPointer], LLVM::Int32, true)
    end

    def printf(llvm_mod)
      llvm_mod.functions["printf"]? || llvm_mod.functions.add("printf", [LLVM::VoidPointer], LLVM::Int32, true)
    end

    def realloc(llvm_mod)
      llvm_mod.functions["realloc"]? || llvm_mod.functions.add("realloc", ([LLVM::VoidPointer, LLVM::Int64]), LLVM::VoidPointer)
    end

    def memset(llvm_mod)
      llvm_mod.functions["llvm.memset.p0i8.i32"]? || llvm_mod.functions.add("llvm.memset.p0i8.i32", [LLVM::VoidPointer, LLVM::Int8, LLVM::Int32, LLVM::Int32, LLVM::Int1], LLVM::Void)
    end

    def trampoline_init(llvm_mod)
      llvm_mod.functions["llvm.init.trampoline"]? || llvm_mod.functions.add("llvm.init.trampoline", [
        LLVM::VoidPointer, LLVM::VoidPointer, LLVM::VoidPointer
      ], LLVM::Void)
    end

    def trampoline_adjust(llvm_mod)
      llvm_mod.functions["llvm.adjust.trampoline"]? || llvm_mod.functions.add("llvm.adjust.trampoline", [
        LLVM::VoidPointer
      ], LLVM::VoidPointer)
    end
  end

  class FunDef
    property! :external
  end
end
