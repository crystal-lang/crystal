require "ast"
require "llvm"
require "types"
require "program"

module Crystal
  class Program
    def define_primitives
      define_primitive_types_primitives
      define_pointer_primitives
      define_type_sizes
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
    end

    def define_pointer_primitives
      pointer.metaclass.add_def Def.new("malloc", [Arg.new_with_type("size", uint64)], Primitive.new(:pointer_malloc))
      pointer.metaclass.add_def Def.new("new", [Arg.new_with_restriction("address", Ident.new(["UInt64"], true))], Primitive.new(:pointer_new))
      pointer.add_def Def.new("value", ([] of Arg), Primitive.new(:pointer_get))
      pointer.add_def Def.new("value=", [Arg.new_with_restriction("value", Ident.new(["T"]))], Primitive.new(:pointer_set))
      pointer.add_def Def.new("address", ([] of Arg), Primitive.new(:pointer_address))
    end

    def define_type_sizes
      byte_size = Primitive.new(:byte_size)
      [void, self.nil, bool, char, int8, int16, int32, int64, uint8, uint16, uint32, uint64, float32, float64, symbol, reference, pointer].each do |t|
        t.metaclass.add_def Def.new("byte_size", ([] of Arg), byte_size)
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
