require "./attribute_kind/*"

enum LLVM::AttributeKind : UInt32
  def self.id_from_name(name : String) : UInt32
    LibLLVM.get_enum_attribute_kind_for_name(name, name.bytesize)
  end
end
