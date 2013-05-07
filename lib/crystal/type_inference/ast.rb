module Crystal
  class Ident
    attr_accessor :target_const

    def is_restriction_of?(other, owner)
      return true if self == other

      if other.is_a?(IdentUnion)
        return other.idents.any? { |o| self.is_restriction_of?(o, owner) }
      end

      return false unless other.is_a?(Ident)

      if self_type = owner.lookup_type(names)
        other_type = owner.lookup_type(other.names)

        return other_type == nil || self_type.is_restriction_of?(other_type, owner)
      end

      false
    end
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

  class NewGenericClass
    def is_restriction_of?(other, owner)
      return true if self == other
      return false unless other.is_a?(NewGenericClass)
      return false unless name == other.name && type_vars.length == other.type_vars.length

      0.upto(type_vars.length - 1) do |i|
        return false unless type_vars[i].is_restriction_of?(other.type_vars[i], owner)
      end

      true
    end
  end
end