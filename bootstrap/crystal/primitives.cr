require "llvm"
require "types"
require "program"

module Crystal
  class Program
    macro define_binary(op, owner, name, arg_type, return_type)"
      singleton(int32, \"#{name}\", {\"other\" => #{arg_type}}, #{return_type}, ->(b : LLVM::Builder, f : LLVM::Function, llvm_mod : LLVM::Module, self_type : Type | Program) {
        b.#{op} f.get_param(0), f.get_param(1)
      })
    "end

    def define_primitives
      define_binary add, int32, "+", int32, int32
      define_binary sub, int32, "-", int32, int32
      define_binary mul, int32, "*", int32, int32
      define_binary sdiv, int32, "/", int32, int32
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

  class External < Def
    property :real_name
    property :varargs

    def mangled_name(obj_type)
      real_name
    end
  end
end
