struct LLVM::PhiTable
  getter blocks : Array(LLVM::BasicBlock)
  getter values : Array(LLVM::Value)

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

  def size
    @blocks.size
  end
end
