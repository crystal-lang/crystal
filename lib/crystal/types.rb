module Crystal
  class Type
    include Enumerable

    attr_reader :name
    attr_reader :llvm_type
    attr_accessor :defs

    def initialize(name, llvm_type)
      @name = name
      @llvm_type = llvm_type
      @defs = {}
    end

    def add_observer(observer, func = nil)
    end

    def each
      yield self
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
        types = [t1, t2].map { |type| type.is_a?(UnionType) ? type.types.to_a : type }.flatten.uniq
        if types.length == 1
          types.first
        else
          union = UnionType.new(*types)
          return t1 if t1 == union
          return t2 if t2 == union
          union
        end
      end
    end

    def to_s
      name
    end
  end

  class ObjectType < Type
    attr_accessor :instance_vars
    attr_accessor :observers

    @@id = 0

    def initialize(name)
      @name = name
      @defs = {}
      @instance_vars = {}
      @@id += 1
      @id = @@id
    end

    def add_observer(observer, func = :update_from_object_type)
      return if @observers && @observers.has_key?(observer)
      @observers ||= {}
      @observers[observer] = func
      observer.send func, self
    end

    def update_from_instance_var(type)
      notify_observers
    end

    def notify_observers
      return unless @observers
      @observers.each do |observer, func|
        observer.send func, @type
      end
    end

    def lookup_instance_var(name)
      var = @instance_vars[name]
      unless var
        var = Var.new name
        @instance_vars[name] = var
        var.add_observer self, :update_from_instance_var
      end
      var
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
      obj.instance_vars = Hash[instance_vars.map { |name, var| [name, Var.new(name, var.type)] }]
      obj.defs = Hash[defs.map { |key, value| [key, value.clone] }]
      obj
    end

    def to_s
      unless @to_s
        @to_s = "..."
        instance_vars_to_s = instance_vars.map {|name, var| "#{name}: #{var.type}"}.join ', '
        @to_s = "#{name}<#{instance_vars_to_s}>"
      end
      @to_s
    end
  end

  class UnionType < Type
    attr_reader :types

    def initialize(*types)
      @types = Set.new types
    end

    def llvm_type
      unless @llvm_type
        @llvm_type = LLVM::Struct(to_s)
        @llvm_type.element_types = [LLVM::Int, LLVM::Type.array(LLVM::Int8, 100)]
      end
      @llvm_type
    end

    def index_of_type(type)
      @types.to_a.index type
    end

    def each(&block)
      types.each(&block)
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

    def to_s
      "Union[#{types.to_a.join ', '}]"
    end
  end
end