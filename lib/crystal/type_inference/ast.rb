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

  class If
    attr_accessor :binary
  end
end