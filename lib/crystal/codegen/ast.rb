module Crystal
  class ASTNode
    def llvm_type
      type.llvm_type
    end

    def llvm_arg_type
      type.llvm_arg_type
    end

    def returns?
      false
    end

    def yields?
      false
    end

    def breaks?
      false
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

  class Arg
    def llvm_type
      llvm_type = type.llvm_type
      llvm_type = LLVM::Pointer(llvm_type) if out
      llvm_type
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

    def mangled_name(obj_type)
      real_name
    end
  end

  class CastedVar < ASTNode
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def to_s
      "#{name} as #{casted_type}"
    end
  end
end