module Crystal
  class Module
    attr_accessor :types
    attr_accessor :defs

    def initialize
      @types = {}
      @types["Bool"] = Type.new "Bool", LLVM::Int1
      @types["Int"] = Type.new "Int", LLVM::Int
      @types["Float"] = Type.new "Float", LLVM::Float
      @types["Char"] = Type.new "Char", LLVM::Int8

      @defs = {}

      primitive(int, :+, ['other']) do |p|
        p.overload([int], int) do |b, args|
          b.ret b.add(args['self'], args['other'])
        end
      end

      primitive(int, :==, ['other']) do |p|
        p.overload([int], bool) do |b, args|
          b.ret b.icmp(:eq, args['self'], args['other'], "test")
        end
      end

      external('putchar', {'c' => char}, char)
    end

    def int
      @types["Int"]
    end

    def bool
      @types["Bool"]
    end

    def float
      @types["Float"]
    end

    def char
      @types["Char"]
    end

    def primitive(owner, name, arg_names)
      p = owner.defs[name] = FrozenDef.new(name, arg_names.map { |x| Var.new(x) })
      p.owner = owner
      yield p
    end

    def external(name, args, return_type)
      args = args.map do |name, type|
        var = Var.new(name)
        var.type = type
        var
      end

      instance = defs[name] = External.new(name, args)
      instance.body = Expressions.new
      instance.body.type = return_type
      instance.add_instance instance
    end
  end

  class Def
    def overload(arg_types, return_type, &block)
      instance = clone
      instance.owner = owner
      arg_types.each_with_index do |arg_type, i|
        instance.args[i].type = arg_type
      end
      instance.body = PrimitiveBody.new(return_type, block)
      add_instance(instance)
    end
  end

  class PrimitiveBody < ASTNode
    attr_accessor :block

    def initialize(type, block)
      @type = type
      @block = block
    end
  end

  class FrozenDef < Def
  end

  class External < FrozenDef
    def mangled_name
      name
    end
  end
end