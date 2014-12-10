struct LLVM::PhiTable
  getter blocks
  getter values

  def initialize
    @blocks = [] of LLVM::BasicBlock
    @values = [] of LLVM::Value
  end

  def add(block, value)
    @blocks << block
    @values << value.to_value
  end

  def empty?
    @blocks.empty?
  end

  def length
    @blocks.length
  end
end
