module Crystal
  class ASTNode
    def returns?
      false
    end

    def yields?
      false
    end

    def breaks?
      false
    end

    def no_returns?
      type && type.no_return?
    end

    def needs_const_block?
      true
    end
  end

  [NilLiteral, BoolLiteral, NumberLiteral, CharLiteral, StringLiteral, SymbolLiteral].each do |klass|
    class_eval %Q(
      class #{klass}
        def needs_const_block?
          false
        end
      end
    )
  end

  class Assign
    def returns?
      value.returns?
    end

    def yields?
      value.yields?
    end

    def breaks?
      value.breaks?
    end
  end

  class Return
    def returns?
      true
    end
  end

  class Yield
    def yields?
      true
    end
  end

  class Break
    def breaks?
      true
    end
  end

  class Expressions
    def returns?
      any? &:returns?
    end

    def yields?
      any? &:yields?
    end

    def breaks?
      any? &:breaks?
    end
  end

  class Block
    def returns?
      body && body.returns?
    end

    def breaks?
      body && body.breaks?
    end

    def yields?
      body && body.yields?
    end
  end

  class If
    def returns?
      self.then && self.then.returns? &&
      self.else && self.else.returns?
    end

    def yields?
      self.then && self.then.yields? &&
      self.else && self.else.yields?
    end

    def breaks?
      self.then && self.then.breaks? &&
      self.else && self.else.breaks?
    end
  end

  class Case
    def returns?
      expanded.returns?
    end

    def yields?
      expanded.yields?
    end

    def breaks?
      expanded.breaks?
    end
  end

  class Call
    def returns?
      block && block.returns? && target_defs.all? { |t| t.body && t.body.yields? }
    end

    def yields?
      return true if args.any?(&:yields?)
      if block && block.yields?
        target_defs.any? { |t| t.body.yields? }
      end
    end
  end

  class Def
    def mangled_name(self_type)
      Def.mangled_name(self_type, owner, name, type, args.map(&:type))
    end

    def self.mangled_name(self_type, owner, name, return_type, arg_types)
      str = '*'
      if owner
        if owner.metaclass?
          str << owner.instance_type.llvm_name
          str << '::'
        elsif !owner.is_a?(Crystal::Program)
          str << owner.llvm_name
          str << '#'
        end
      end
      str << name.to_s.gsub('@', '.')
      str << '<'
      if self_type
        str << self_type.llvm_name
      end
      if arg_types.length > 0
        str << ', ' if self_type
        str << arg_types.map(&:llvm_name).join(', ')
      end
      str << '>'
      if return_type
        str << ':'
        str << return_type.llvm_name
      end
      str
    end
  end

  class External < Def
    attr_accessor :real_name
    attr_accessor :varargs
    attr_accessor :fun_def
    attr_accessor :dead

    def mangled_name(obj_type)
      real_name
    end

    def compatible_with?(other)
      return false if args.length != other.args.length
      return false if varargs != other.varargs

      args.each_with_index do |arg, i|
        return false if !arg.type.equal?(other.args[i].type)
      end

      type.equal?(other.type)
    end

    def to_s
      fun_def.to_s
    end
  end

  class CastedVar < ASTNode
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end
end
