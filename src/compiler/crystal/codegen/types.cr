module Crystal
  class Type
    def llvm_name
      String.build do |io|
        llvm_name io
      end
    end

    def llvm_name(io)
      to_s_with_options io, codegen: true
    end
  end

  class PrimitiveType
    def llvm_name(io)
      io << name
    end
  end

  class AliasType
    def llvm_name(io)
      io << "alias."
      to_s_with_options io, codegen: true
    end
  end

  class CStructType
    def llvm_name(io)
      io << "struct."
      to_s_with_options io, codegen: true
    end
  end

  class CUnionType
    def llvm_name(io)
      io << "union."
      to_s_with_options io, codegen: true
    end
  end

  class TypeDefType
    def llvm_name(io)
      typedef.llvm_name(io)
    end
  end

  class Const
    property initializer : LLVM::Value?

    def initialized_llvm_name
      "#{llvm_name}:init"
    end

    def simple?
      value.simple_literal?
    end
  end
end
