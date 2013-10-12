require "ast"
require "llvm"
require "types"
require "program"

module Crystal
  class Program
    def define_primitives
      define_number_primitives
    end

    def define_number_primitives
      binary = PrimitiveBinary.new

      nums = [int8, int16, int32, int64, uint8, uint16, uint32, uint64, float32, float64]
      ops = %w(+ - * /)
      cmps = %w(== < <= > >= !=)

      args = {} of String => Type

      nums.each do |t1|
        nums.each do |t2|
          args["other"] = t2
          ret_type = t1.integer? && t2.float? ? t2 : t1
          ops.each { |op| singleton(t1, op, args, ret_type, binary) }
          cmps.each { |cmp| singleton(t1, cmp, args, bool, binary) }
        end
      end

      cast = PrimitiveCast.new
      cast_names = {
        "to_i" => int32,
        "to_i8" => int8,
        "to_i16" => int16,
        "to_i32" => int32,
        "to_i64" => int64,
        "to_u" => uint32,
        "to_u8" => uint8,
        "to_u16" => uint16,
        "to_u32" => uint32,
        "to_u64" => uint64,
        "to_f" => float64,
        "to_f32" => float32,
        "to_f64" => float64,
      } of String => Type

      args.delete "other"

      nums.each do |t|
        cast_names.each do |name, ret_type|
          singleton(t, name, args, ret_type, cast)
        end
      end
    end

    def singleton(owner, name, args, return_type, body)
      a_def = Def.new(name, args.map { |arg_name, arg_type| Arg.new_with_type(arg_name, arg_type) })
      a_def.owner = owner
      owner.add_def a_def
      instance = a_def.overload(args.values, return_type, body)
      owner.add_def_instance(a_def.object_id, args.values, nil, instance)
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
      external.set_type(return_type)
      external.fun_def = fun_def
      fun_def.external = external
      external
    end
  end
end
