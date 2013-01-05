module Crystal
  class CrystalLLVMBuilder
    def initialize(builder)
      @builder = builder
    end

    def ret(*args)
      return if @end
      @builder.ret *args
      @end = true
    end

    def br(*args)
      return if @end
      @builder.br *args
      @end = true
    end

    def unreachable
      return if @end
      @builder.unreachable
      @end = true
    end

    def position_at_end(block)
      @builder.position_at_end block
      @end = false
    end

    def insert_block(*args)
      @builder.insert_block *args
    end

    def method_missing(name, *args)
      return if @end
      @builder.send name, *args
    end
  end
end