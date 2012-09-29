module Crystal
  class Type
    attr_reader :name
    attr_reader :llvm_type
    attr_accessor :defs

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

    @@id = 0

    def initialize(name)
      @name = name
      @defs = {}
      @instance_vars = {}
      @@id += 1
      @id = @@id
    end

    def ==(other)
      other.class == self.class && name == other.name && instance_vars == other.instance_vars
    end

    def llvm_type
      @llvm_type ||= LLVM::Pointer(llvm_struct_type)
    end

    def llvm_struct_type
      unless @llvm_struct_type
        @llvm_struct_type = LLVM::Struct(to_s)
        @llvm_struct_type.element_types = @instance_vars.values.map(&:llvm_type)
      end
      @llvm_struct_type
    end

    def index_of_instance_var(name)
      @instance_vars.keys.index(name)
    end

    def clone
      obj = ObjectType.new name
      obj.defs = Hash[defs.map { |key, value| [key, value.clone] }]
      obj
    end

    def to_s
      "#{name}#{@id}"
    end
  end
end