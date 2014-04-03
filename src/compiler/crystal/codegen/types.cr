module Crystal
  class Type
    def llvm_name
      String.build do |str|
        append_llvm_name(str)
      end
    end

    def append_llvm_name(str)
      append_to_s(str)
    end
  end

  class PrimitiveType
    def append_llvm_name(str)
      str << name
    end
  end

  class AliasType
    def append_llvm_name(str)
      str << "alias."
      append_to_s(str)
    end
  end

  class CStructType
    def append_llvm_name(str)
      str << "struct."
      append_to_s(str)
    end
  end

  class CUnionType
    def append_llvm_name(str)
      str << "union."
      append_to_s(str)
    end
  end

  class TypeDefType
    def append_llvm_name(str)
      typedef.append_llvm_name(str)
    end
  end
end
