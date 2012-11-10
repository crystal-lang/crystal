class NilClass
  def llvm_name
    "Void"
  end

  def llvm_type
    LLVM.Void
  end

  def llvm_size
    0
  end

  def clone(*)
    nil
  end
end