module Crystal
  class Type
    def llvm_name
      to_s
    end
  end

  class PrimitiveType
    def llvm_name
      name
    end
  end

  class AliasType
    def llvm_name
      "alias.#{to_s}"
    end
  end

  class CStructType
    def llvm_name
      "struct.#{to_s}"
    end
  end

  class CUnionType
    def llvm_name
      "union.#{to_s}"
    end
  end

  class TypeDefType
    def llvm_name
      typedef.llvm_name
    end
  end
end
