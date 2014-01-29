class LLVM::PhiTable
  getter blocks
  getter values

  def initialize
    @blocks = [] of LibLLVM::BasicBlockRef
    @values = [] of LibLLVM::ValueRef
  end

  def add(block, value)
    @blocks << block
    @values << value
  end

  def empty?
    @blocks.empty?
  end
end
