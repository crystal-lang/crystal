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

    def ==(other)
      equal?(other) || (other.is_a?(UnionType) && other == self)
    end

    def eql?(other)
      self == other
    end

    def self.merge(t1, t2)
      if t1 == t2
        t1
      else
        UnionType.new(t1, t2)
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
      equal?(other) ||
        (other.class == self.class && name == other.name && instance_vars == other.instance_vars) ||
        (other.is_a?(UnionType) && other == self)
    end

    def eql?(other)
      self == other
    end

    def hash
      name.hash
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

  class UnionType < Type
    attr_reader :types

    def initialize(*types)
      types = types.map { |type| type.is_a?(UnionType) ? type.types.to_a : type }.flatten.uniq
      @name = "Union[#{types.join ', '}]"
      @types = Set.new types
    end

    def add(other)
      @types.add other
    end

    def defs
      @types.first.defs
    end

    def instance_vars
      @types.first.instance_vars
    end

    def llvm_type
      @types.first.llvm_type
    end

    def ==(other)
      return true if equal?(other)

      if @types.length == 1
        @types.first == other
      elsif other.is_a?(UnionType)
        @types == other.types
      else
        false
      end
    end
  end
end