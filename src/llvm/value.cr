require "./value_methods"

struct LLVM::Value
  include ValueMethods

  def self.null
    LLVM::Value.new(Pointer(::Void).null.as(LibLLVM::ValueRef))
  end

  def to_value
    self
  end
end
