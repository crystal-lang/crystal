require "llvm"
require "types"
require "program"

module Crystal
  class Program
    def define_primitives
      owner = int32
      type = int32
      return_type = int32

      a_def = Def.new("+", [Arg.new_with_type("other", type)])
      a_def.owner = owner
      a_def.body = NilLiteral.new
      owner.add_def a_def

      instance = a_def.clone
      instance.owner = owner
      instance.args[0].set_type type
      instance.body = PrimitiveBody.new(type, ->(b : LLVM::Builder, f : LLVM::Function, llvm_mod : LLVM::Module, self_type : Type | Program) {
        value = b.add f.get_param(0), f.get_param(1)
        value.address
        value
      })
      instance.set_type(return_type)

      owner.add_def_instance(a_def.object_id, [type], nil, instance)
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
