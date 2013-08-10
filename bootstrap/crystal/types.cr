module Crystal
  abstract class Type
    def self.merge(type1, type2)
      type1
    end

    def llvm_type
      LLVM::Void
    end

    def to_s
      name
    end
  end

  class ContainedType < Type
    property :name
    property :container

    def initialize(name, container)
      @name = name
      @container = container
    end
  end

  class ModuleType < ContainedType
    property :types
    property :parents

    def initialize(name, container = nil, parents = [] of Type?)
      super(name, container)
      @parents = parents
      @types = {} of String => Type?
    end
  end

  class ClassType < ModuleType
    def initialize(name, parent_type, container = nil)
      super(name, container, parent_type ? [parent_type] of Type? : [] of Type?)
    end
  end

  class PrimitiveType < ClassType
    getter :llvm_type
    getter :llvm_size

    def initialize(name, parent_type, llvm_type, llvm_size, container = nil)
      super(name, parent_type, container)
      @llvm_type = llvm_type
      @llvm_size = llvm_size
    end

    def llvm_name
      name
    end
  end

  class ObjectType < ClassType
    def initialize(name, parent_type = nil, container = nil)
      super
    end

    def llvm_type
      LLVM::Void
    end
  end
end
