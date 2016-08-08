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

  class Def
    def mangled_name(program, self_type)
      name = String.build do |str|
        str << "*"

        if owner = @owner
          if owner.metaclass?
            self_type.instance_type.llvm_name(str)
            if original_owner != self_type
              str << "@"
              original_owner.instance_type.llvm_name(str)
            end
            str << "::"
          elsif !owner.is_a?(Crystal::Program)
            self_type.llvm_name(str)
            if original_owner != self_type
              str << "@"
              original_owner.llvm_name(str)
            end
            str << "#"
          end
        end

        str << self.name.gsub('@', '.')

        next_def = self.next
        while next_def
          str << "'"
          next_def = next_def.next
        end

        if args.size > 0 || uses_block_arg?
          str << "<"
          if args.size > 0
            args.each_with_index do |arg, i|
              str << ", " if i > 0
              arg.type.llvm_name(str)
            end
          end
          if uses_block_arg?
            str << ", " if args.size > 0
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

      Crystal.safe_mangling(program, name)
    end

    def varargs?
      false
    end

    # Returns `self` as an `External` if this Def must be considered
    # an external in the codegen, meaning we need to respect the C ABI.
    # The only case where this is not true if for LLVM instrinsics.
    # For example overflow intrincis return a tuple, like {i32, i1}:
    # in C ABI that is represented as i64, but we need to keep the original
    # type here, respecting LLVM types, not the C ABI.
    def considered_external?
      if self.is_a?(External) && !self.real_name.starts_with?("llvm.")
        self
      else
        nil
      end
    end
  end

  class External
    property abi_info : LLVM::ABI::FunctionType?
  end
end
