require "ast"
require "llvm"
require "types"
require "program"

module Crystal
  class Program
    def define_primitives
      define_primitive_types_primitives
      define_reference_primitives
      define_pointer_primitives
      define_symbol_primitives
      define_type_sizes
      define_math_primitives
    end

    def define_primitive_types_primitives
      binary = Primitive.new(:binary)

      ints = [int8, int16, int32, int64, uint8, uint16, uint32, uint64]
      nums = ints + [float32, float64]

      num_ops = %w(+ - * /)
      int_ops = %w(% << >> | & ^)
      cmps = %w(== < <= > >= !=)

      args = {} of String => Type

      nums.each do |t1|
        nums.each do |t2|
          args["other"] = t2
          ret_type = t1.integer? && t2.float? ? t2 : t1
          num_ops.each { |op| singleton(t1, op, args, ret_type, binary) }
          cmps.each { |cmp| singleton(t1, cmp, args, bool, binary) }
        end
      end

      ints.each do |t1|
        ints.each do |t2|
          args["other"] = t2
          int_ops.each { |op| singleton(t1, op, args, t1, binary) }
        end
      end

      args["other"] = char
      cmps.each { |cmp| singleton(char, cmp, args, bool, binary) }

      args["other"] = symbol
      singleton(symbol, "==" args, bool, binary)
      singleton(symbol, "!=" args, bool, binary)

      args["other"] = bool
      singleton(bool, "==", args, bool, binary)
      singleton(bool, "!=", args, bool, binary)

      cast = Primitive.new(:cast)
      args.delete "other"

      nums.each do |t|
        singleton(t, "to_i", args, int32, cast)
        singleton(t, "to_i8", args, int8, cast)
        singleton(t, "to_i16", args, int16, cast)
        singleton(t, "to_i32", args, int32, cast)
        singleton(t, "to_i64", args, int64, cast)
        singleton(t, "to_u", args, uint32, cast)
        singleton(t, "to_u8", args, uint8, cast)
        singleton(t, "to_u16", args, uint16, cast)
        singleton(t, "to_u32", args, uint32, cast)
        singleton(t, "to_u64", args, uint64, cast)
        singleton(t, "to_f", args, float64, cast)
        singleton(t, "to_f32", args, float32, cast)
        singleton(t, "to_f64", args, float64, cast)
        singleton(t, "chr", args, char, cast)
      end

      singleton(char, "ord", args, int32, cast)

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
      pointer.metaclass.add_def Def.new("new", [Arg.new_with_restriction("address", Ident.new(["UInt64"], true))], Primitive.new(:pointer_new))
      pointer.add_def Def.new("value", ([] of Arg), Primitive.new(:pointer_get))
      pointer.add_def Def.new("value=", [Arg.new_with_restriction("value", Ident.new(["T"]))], Primitive.new(:pointer_set))
      pointer.add_def Def.new("address", ([] of Arg), Primitive.new(:pointer_address))
      pointer.add_def Def.new("realloc", [Arg.new_with_type("size", uint64)], Primitive.new(:pointer_realloc))
      pointer.add_def Def.new("+", [Arg.new_with_type("offset", int64)], Primitive.new(:pointer_add))
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

    def singleton(owner, name, args, return_type, body)
      a_def = Def.new(name, args.map { |arg_name, arg_type| Arg.new_with_type(arg_name, arg_type) })
      a_def.owner = owner
      owner.add_def a_def
      instance = a_def.overload(args.values, return_type, body)
      owner.add_def_instance(a_def.object_id, args.values, nil, instance)
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
  end

  class Def
    def overload(arg_types, return_type, body)
      instance = clone
      instance.owner = owner
      arg_types.each_with_index do |arg_type, i|
        instance.args[i].set_type(arg_type)
      end
      instance.body = body
      instance.set_type(return_type)
      instance
    end
  end

  class FunDef
    property! :external
  end
end
