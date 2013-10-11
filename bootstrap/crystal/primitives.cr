require "llvm"
require "types"
require "program"

module Crystal
  class Program
    macro primitive_body(body)"
      ->(b : LLVM::Builder, f : LLVM::Function, llvm_mod : LLVM::Module, self_type : Type | Program) {
        #{body}
      }
    "end

    macro binary_body(body)"
      ->(b : LLVM::Builder, f : LLVM::Function, llvm_mod : LLVM::Module, self_type : Type | Program) {
        p0 = f.get_param(0)
        p1 = f.get_param(1)
        #{body}
      }
    "end

    def define_primitives
      define_number_primitives
    end

    def define_number_primitives
      add_ints = binary_body "b.add p0, p1"
      sub_ints = binary_body "b.sub p0, p1"
      mul_ints = binary_body "b.mul p0, p1"
      div_ints = binary_body "b.sdiv p0, p1"
      div_uints = binary_body "b.udiv p0, p1"

      add_floats = binary_body "b.fadd p0, p1"
      sub_floats = binary_body "b.fsub p0, p1"
      mul_floats = binary_body "b.fmul p0, p1"
      div_floats = binary_body "b.fdiv p0, p1"

      add_ints_less = binary_body "b.trunc(b.add(b.sext(p0, LLVM.type_of(p1)), p1), LLVM.type_of(p0))"
      add_ints_greater = binary_body "b.add(p0, b.sext(p1, LLVM.type_of(p0)))"
      sub_ints_less = binary_body "b.trunc(b.sub(b.sext(p0, LLVM.type_of(p1)), p1), LLVM.type_of(p0))"
      sub_ints_greater = binary_body "b.sub(p0, b.sext(p1, LLVM.type_of(p0)))"
      mul_ints_less = binary_body "b.trunc(b.mul(b.sext(p0, LLVM.type_of(p1)), p1), LLVM.type_of(p0))"
      mul_ints_greater = binary_body "b.mul(p0, b.sext(p1, LLVM.type_of(p0)))"
      div_ints_less = binary_body "b.trunc(b.sdiv(b.sext(p0, LLVM.type_of(p1)), p1), LLVM.type_of(p0))"
      div_ints_greater = binary_body "b.sdiv(p0, b.sext(p1, LLVM.type_of(p0)))"

      add_int_and_float = binary_body "b.fadd b.si2fp(p0, LLVM.type_of(p1)), p1"
      add_float_and_int = binary_body "b.fadd p0, b.si2fp(p1, LLVM.type_of(p0))"
      add_uint_and_float = binary_body "b.fadd b.ui2fp(p0, LLVM.type_of(p1)), p1"
      add_float_and_uint = binary_body "b.fadd p0, b.ui2fp(p1, LLVM.type_of(p0))"
      sub_int_and_float = binary_body "b.fsub b.si2fp(p0, LLVM.type_of(p1)), p1"
      sub_float_and_int = binary_body "b.fsub p0, b.si2fp(p1, LLVM.type_of(p0))"
      sub_uint_and_float = binary_body "b.fsub b.ui2fp(p0, LLVM.type_of(p1)), p1"
      sub_float_and_uint = binary_body "b.fsub p0, b.ui2fp(p1, LLVM.type_of(p0))"
      mul_int_and_float = binary_body "b.fmul b.si2fp(p0, LLVM.type_of(p1)), p1"
      mul_float_and_int = binary_body "b.fmul p0, b.si2fp(p1, LLVM.type_of(p0))"
      mul_uint_and_float = binary_body "b.fmul b.ui2fp(p0, LLVM.type_of(p1)), p1"
      mul_float_and_uint = binary_body "b.fmul p0, b.ui2fp(p1, LLVM.type_of(p0))"
      div_int_and_float = binary_body "b.fdiv b.si2fp(p0, LLVM.type_of(p1)), p1"
      div_float_and_int = binary_body "b.fdiv p0, b.si2fp(p1, LLVM.type_of(p0))"
      div_uint_and_float = binary_body "b.fdiv b.ui2fp(p0, LLVM.type_of(p1)), p1"
      div_float_and_uint = binary_body "b.fdiv p0, b.ui2fp(p1, LLVM.type_of(p0))"

      eq_ints = binary_body "b.icmp LibLLVM::IntPredicate::EQ, p0, p1"
      eq_floats = binary_body "b.fcmp LibLLVM::RealPredicate::OEQ, p0, p1"

      less_ints = binary_body "b.icmp LibLLVM::IntPredicate::SLT, p0, p1"

      ints = [int8, int16, int32, int64, uint8, uint16, uint32, uint64]
      floats = [float32, float64]

      ints.each do |int|
        if int.signed?
          floats.each do |float|
            singleton(int, "+", {"other" => float}, float, add_int_and_float)
            singleton(float, "+", {"other" => int}, float, add_float_and_int)
            singleton(int, "-", {"other" => float}, float, sub_int_and_float)
            singleton(float, "-", {"other" => int}, float, sub_float_and_int)
            singleton(int, "*", {"other" => float}, float, mul_int_and_float)
            singleton(float, "*", {"other" => int}, float, mul_float_and_int)
            singleton(int, "/", {"other" => float}, float, div_int_and_float)
            singleton(float, "/", {"other" => int}, float, div_float_and_int)
          end
        else
          floats.each do |float|
            singleton(int, "+", {"other" => float}, float, add_uint_and_float)
            singleton(float, "+", {"other" => int}, float, add_float_and_uint)
            singleton(int, "-", {"other" => float}, float, sub_uint_and_float)
            singleton(float, "-", {"other" => int}, float, sub_float_and_uint)
            singleton(int, "*", {"other" => float}, float, mul_uint_and_float)
            singleton(float, "*", {"other" => int}, float, mul_float_and_uint)
            singleton(int, "/", {"other" => float}, float, div_uint_and_float)
            singleton(float, "/", {"other" => int}, float, div_float_and_uint)
          end
        end

        ints.each do |int2|
          if int == int2
            singleton(int, "+", {"other" => int}, int, add_ints)
            singleton(int, "-", {"other" => int}, int, sub_ints)
            singleton(int, "*", {"other" => int}, int, mul_ints)
            singleton(int, "/", {"other" => int}, int, (int.signed? ? div_ints : div_uints))
            singleton(int, "==", {"other" => int}, bool, eq_ints)
            singleton(int, "<", {"other" => int}, bool, less_ints)
          elsif int.signed? && int2.signed?
            if int.rank < int2.rank
              singleton(int, "+", {"other" => int2}, int, add_ints_less)
              singleton(int, "-", {"other" => int2}, int, sub_ints_less)
              singleton(int, "*", {"other" => int2}, int, mul_ints_less)
              singleton(int, "/", {"other" => int2}, int, div_ints_less)
            else
              singleton(int, "+", {"other" => int2}, int, add_ints_greater)
              singleton(int, "-", {"other" => int2}, int, sub_ints_greater)
              singleton(int, "*", {"other" => int2}, int, mul_ints_greater)
              singleton(int, "/", {"other" => int2}, int, div_ints_greater)
            end
          end
        end
      end

      floats.each do |float|
        singleton(float, "+", {"other" => float}, float, add_floats)
        singleton(float, "-", {"other" => float}, float, sub_floats)
        singleton(float, "*", {"other" => float}, float, mul_floats)
        singleton(float, "/", {"other" => float}, float, div_floats)
        singleton(float, "==", {"other" => float}, bool, eq_floats)
      end
    end

    def singleton(owner, name, args, return_type, block)
      a_def = Def.new(name, args.map { |arg_name, arg_type| Arg.new_with_type(arg_name, arg_type) })
      a_def.owner = owner
      owner.add_def a_def
      instance = a_def.overload(args.values, return_type, block)
      owner.add_def_instance(a_def.object_id, args.values, nil, instance)
    end
  end

  class Def
    def overload(arg_types, return_type, block)
      instance = clone
      instance.owner = owner
      arg_types.each_with_index do |arg_type, i|
        instance.args[i].set_type(arg_type)
      end
      instance.body = PrimitiveBody.new(return_type, block)
      instance.set_type(return_type)
      instance
    end
  end

  class FunDef
    property :external
  end

  class External < Def
    property :real_name
    property :varargs
    property :fun_def
    property :dead

    def initialize(name, args : Array(Arg), body = nil, receiver = nil, block_arg = nil, yields = -1, @real_name)
      super(name, args, body, receiver, block_arg, yields)
    end

    def mangled_name(obj_type)
      real_name
    end

    def self.for_fun(name, real_name, args, return_type, varargs, body, fun_def)
      external = External.new(name, args, body, nil, nil, nil, real_name)
      external.varargs = varargs
      # external.owner = self
      external.set_type(return_type)
      external.fun_def = fun_def
      fun_def.external = external
      external
    end
  end
end
