module Crystal
  class Type
    attr_reader :name
    attr_reader :llvm_type
    attr_reader :defs

    def initialize(name, llvm_type)
      @name = name
      @llvm_type = llvm_type
      @defs = {}
    end
  end
end