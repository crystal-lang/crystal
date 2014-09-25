require "value_methods"

struct LLVM::Value
  include ValueMethods

  def to_value
    self
  end
end
