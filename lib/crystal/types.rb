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

    def self.merge(t1, t2)
      if t1 == t2
        t1
      else
        [t1, t2].flatten.uniq
      end
    end

    def self.unmerge(t1, t2)
      t1.delete t2
      if t1.length == 1
        t1.first
      else
        t1
      end
    end

    def to_s
      name
    end
  end

  class ObjectType < Type
    attr_accessor :instance_vars

    def initialize(name)
      @name = name
      @defs = {}
      @instance_vars = {}
    end

    def ==(other)
      other.class == self.class && name == other.name && instance_vars == other.instance_vars
    end

    def llvm_type
      LLVM::Int
    end

    def to_s
      "#{name}<#{@instance_vars.map{ |name, type| "#{name}: #{type}" }.join ', '}>"
    end
  end
end