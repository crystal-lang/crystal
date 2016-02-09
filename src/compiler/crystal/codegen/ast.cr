require "../syntax/ast"

module Crystal
  class ASTNode
    def no_returns?
      type?.try &.no_return?
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

  class While
    property :ensure_exception_handler
  end

  class Block
    property :ensure_exception_handler
  end

  class Call
    property :ensure_exception_handler
  end

  class Def
    property :ensure_exception_handler

    def mangled_name(self_type)
      name = String.build do |str|
        str << "*"

        if owner = @owner
          if owner.metaclass?
            owner.instance_type.llvm_name(str)
            if original_owner != self_type
              str << "@"
              original_owner.instance_type.llvm_name(str)
            end
            str << "::"
          elsif !owner.is_a?(Crystal::Program)
            owner.llvm_name(str)
            if original_owner != self_type
              str << "@"
              original_owner.llvm_name(str)
            end
            str << "#"
          end
        end

        str << name.gsub('@', '.')

        next_def = self.next
        while next_def
          str << "'"
          next_def = next_def.next
        end

        needs_self_type = self_type.try &.passed_as_self?

        if args.size > 0 || needs_self_type || uses_block_arg
          str << "<"
          if needs_self_type
            self_type.not_nil!.llvm_name(str)
          end
          if args.size > 0
            str << ", " if needs_self_type
            args.each_with_index do |arg, i|
              str << ", " if i > 0
              arg.type.llvm_name(str)
            end
          end
          if uses_block_arg
            str << ", " if needs_self_type || args.size > 0
            str << "&"
            block_arg.not_nil!.type.llvm_name(str)
          end
          str << ">"
        end
        if return_type = @type
          str << ":"
          return_type.llvm_name(str)
        end
      end

      Crystal.safe_mangling(name)
    end

    def varargs
      false
    end
  end

  class External
    property abi_info
  end
end
