require "../ast"

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

    def nexts?
      false
    end

    def no_returns?
      type?.try &.no_return?
    end

    def needs_const_block?
      true
    end

    def zero?
      false
    end

    def false?
      false
    end
  end

  class BoolLiteral
    def false?
      !value
    end
  end

  class NumberLiteral
    def zero?
      case :kind
      when :f32, :f64
        value == "0.0"
      else
        value == "0"
      end
    end
  end

  macro self.doesnt_need_const_block(klass)"
    class #{klass}
      def needs_const_block?
        false
      end
    end
  "end

  doesnt_need_const_block NilLiteral
  doesnt_need_const_block BoolLiteral
  doesnt_need_const_block NumberLiteral
  doesnt_need_const_block CharLiteral
  doesnt_need_const_block StringLiteral
  doesnt_need_const_block SymbolLiteral

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

    def nexts?
      value.breaks?
    end
  end

  class Primitive
    def needs_const_block?
      case name
      when :float32_infinity, :flaot64_infinity
        false
      else
        true
      end
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

  class Next
    def nexts?
      true
    end
  end

  class Expressions
    def returns?
      expressions.any? &.returns?
    end

    def yields?
      expressions.any? &.yields?
    end

    def breaks?
      expressions.any? &.breaks?
    end

    def nexts?
      expressions.any? &.breaks?
    end
  end

  class Block
    def returns?
      body.returns?
    end

    def breaks?
      body.breaks?
    end

    def yields?
      body.yields?
    end

    def nexts?
      body.nexts?
    end
  end

  class If
    def returns?
      self.then.returns? && self.else.returns?
    end

    def yields?
      self.then.yields? && self.else.yields?
    end

    def breaks?
      self.then.breaks? && self.else.breaks?
    end

    def nexts?
      self.then.nexts? && self.else.nexts?
    end
  end

  class Call
    def returns?
      block = @block
      block && block.returns? && target_defs.try &.all? &.body.yields?
    end

    def yields?
      return true if args.any?(&.yields?)

      if block.try &.yields?
        target_defs.try &.any? &.body.yields?
      end
    end
  end

  class Def
    def mangled_name(self_type)
      name = String.build do |str|
        str << "*"

        if owner = @owner
          if owner.metaclass?
            owner.instance_type.append_llvm_name(str)
            str << "::"
          elsif !owner.is_a?(Crystal::Program)
            owner.append_llvm_name(str)
            str << "#"
          end
        end

        str << name.replace('@', '.')

        if args.length > 0 || self_type
          str << "<"
          if self_type
            self_type.append_llvm_name(str)
          end
          if args.length > 0
            str << ", " if self_type
            args.each_with_index do |arg, i|
              str << ", " if i > 0
              arg.type.append_llvm_name(str)
            end
          end
          str << ">"
        end
        if return_type = @type
          str << ":"
          return_type.append_llvm_name(str)
        end
      end

      # Windows only allows alphanumeric, dot, dollar and underscore
      # for mangled names.
      ifdef windows
        name = name.replace do |char|
          case char
          when '<', '>', '(', ')', '*', ':', ',', '#', ' '
            "."
          when '+'
            ".."
          else
            nil
          end
        end
      end

      name
    end

    def varargs
      false
    end
  end
end
