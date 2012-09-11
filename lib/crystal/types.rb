module Crystal
  class Type
    attr_reader :name
    attr_reader :llvm_type

    def initialize(name, llvm_type)
      @name = name
      @llvm_type = llvm_type
    end

    Bool = Type.new "Bool", LLVM::Int1
    Int = Type.new "Int", LLVM::Int
    Float = Type.new "Float", LLVM::Float
  end
end