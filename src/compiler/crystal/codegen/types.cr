module Crystal
  class Type
    def llvm_name
      String.build do |io|
        llvm_name io
      end
    end

    def llvm_name(io)
      to_s io
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
      to_s io
    end
  end

  class CStructType
    def llvm_name(io)
      io << "struct."
      to_s io
    end
  end

  class CUnionType
    def llvm_name(io)
      io << "union."
      to_s io
    end
  end

  class TypeDefType
    def llvm_name(io)
      typedef.llvm_name(io)
    end
  end

  class Const
    property initializer
  end
end
