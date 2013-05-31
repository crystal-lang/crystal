module Crystal
  class Ident
    attr_accessor :target_const
  end

  class ArrayLiteral
    attr_accessor :expanded
  end

  class RangeLiteral
    attr_accessor :expanded
  end

  class RegexpLiteral
    attr_accessor :expanded
  end

  class HashLiteral
    attr_accessor :expanded
  end

  class Require
    attr_accessor :expanded
  end

  class Case
    attr_accessor :expanded
  end

  class BinaryOp
    attr_accessor :expanded
  end

  class Arg
    def self.new_with_type(name, type)
      arg = Arg.new(name)
      arg.type = type
      arg
    end

    def self.new_with_restriction(name, restriction)
      arg = Arg.new(name)
      arg.type_restriction = restriction
      arg
    end
  end

  class Block
    def break
      @break ||= Var.new("%break")
    end
  end

  class Def
    attr_accessor :owner
    attr_accessor :instances

    def add_instance(a_def, arg_types = a_def.args.map(&:type))
      @instances ||= {}
      @instances[arg_types] = a_def
    end

    def lookup_instance(arg_types)
      @instances && @instances[arg_types]
    end

    def has_default_arguments?
      args.length > 0 && args.last.default_value
    end

    def expand_default_arguments
      self_def = clone
      self_def.instance_vars = instance_vars
      self_def.args.each { |arg| arg.default_value = nil }

      expansions = [self_def]

      i = args.length - 1
      while i >= 0 && (arg = args[i]).default_value
        expansion = Def.new(name, self_def.args[0 ... i].map(&:clone), nil, receiver.clone, self_def.block_arg.clone, self_def.yields)
        expansion.instance_vars = instance_vars

        new_args = self_def.args[0 ... i].map { |arg| Var.new(arg.name) }
        new_args.push arg.default_value

        expansion.body = Call.new(nil, name, new_args)

        expansions << expansion
        i -= 1
      end

      expansions
    end
  end

  class Macro
    attr_accessor :instances

    def add_instance(fun, arg_types)
      @instances ||= {}
      @instances[arg_types] = fun
    end

    def lookup_instance(arg_types)
      @instances && @instances[arg_types]
    end
  end
end