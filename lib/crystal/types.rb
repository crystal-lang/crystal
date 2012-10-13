module Crystal
  class Type
    include Enumerable

    attr_accessor :observers

    def metaclass
      @metaclass ||= Metaclass.new(self)
    end

    def add_observer(observer, func = nil)
    end

    def eql?(other)
      self == other
    end

    def each
      yield self
    end

    def self.merge(t1, t2)
      if t1.equal? t2
        t1
      else
        types = [t1, t2].map { |type| type.is_a?(UnionType) ? type.types.to_a : type }.flatten.uniq(&:object_id)
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
  end

  class ClassType < Type
    attr_reader :parent_type
    attr_reader :name
    attr_accessor :defs

    def initialize(name, parent_type)
      @name = name
      @parent_type = parent_type
      @defs = parent_type ? HashWithParent.new(parent_type.defs) : {}
    end
  end

  class PrimitiveType < ClassType
    attr_reader :name
    attr_reader :llvm_type
    attr_reader :llvm_size

    def initialize(name, parent_type, llvm_type, llvm_size)
      super(name, parent_type)
      @llvm_type = llvm_type
      @llvm_size = llvm_size
    end

    def ==(other)
      equal?(other) || (other.is_a?(UnionType) && other == self)
    end

    def llvm_name
      name
    end

    def to_s
      name
    end
  end

  class ObjectType < ClassType
    attr_accessor :instance_vars
    @@id = 0

    def initialize(name, parent_type = nil)
      super
      @instance_vars = {}
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

    def llvm_size
      Crystal::Module::POINTER_SIZE
    end

    def llvm_struct_type
      unless @llvm_struct_type
        @llvm_struct_type = LLVM::Struct(llvm_name)
        @llvm_struct_type.element_types = @instance_vars.values.map(&:llvm_type)
      end
      @llvm_struct_type
    end

    def llvm_name
      @id ||= (@@id += 1)
      "#{name}#{@id}"
    end

    def index_of_instance_var(name)
      @instance_vars.keys.index(name)
    end

    def clone
      obj = ObjectType.new name, @parent_type
      obj.instance_vars = Hash[instance_vars.map { |name, var| [name, Var.new(name, var.type)] }]
      obj.defs = @parent_type ? HashWithParent.new(@parent_type.defs) : {}
      defs.each do |key, value|
        obj.defs[key] = value.clone
      end
      obj
    end

    def to_s
      return @to_s if @to_s
      @to_s = "..."
      instance_vars_to_s = instance_vars.map {|name, var| "#{name}: #{var.type}"}.join ', '
      @to_s = nil
      "#{name}<#{instance_vars_to_s}>"
    end
  end

  class ArrayType < ClassType
    attr_accessor :element_type_var

    def initialize(parent_type = nil)
      super("Array", parent_type)
      @element_type_var = Var.new('element')
    end

    def element_type
      @element_type_var.type
    end

    def ==(other)
      self.class == other.class && element_type == other.element_type
    end

    def clone
      array = ArrayType.new @parent_type
      array.element_type_var = @element_type_var.clone
      array.defs = @parent_type ? HashWithParent.new(@parent_type.defs) : {}
      defs.each do |key, value|
        array.defs[key] = value.clone
      end
      array
    end

    def llvm_type
      @llvm_type ||= LLVM::Pointer(llvm_struct_type)
    end

    def llvm_struct_type
      unless @llvm_struct_type
        @llvm_struct_type = LLVM::Struct(llvm_name)
        @llvm_struct_type.element_types = [LLVM::Int, LLVM::Int, LLVM::Pointer(element_type.llvm_type)]
      end
      @llvm_struct_type
    end

    def llvm_size
      4 + 4 + Crystal::Module::POINTER_SIZE
    end

    def llvm_name
      "Array<#{element_type.llvm_name}>"
    end

    def to_s
      "Array<#{element_type || 'Void'}>"
    end
  end

  class UnionType < Type
    attr_reader :types

    def initialize(*types)
      @types = types
    end

    def llvm_type
      unless @llvm_type
        @llvm_type = LLVM::Struct(llvm_name)
        @llvm_type.element_types = [LLVM::Int, LLVM::Type.array(LLVM::Int8, llvm_value_size)]
      end
      @llvm_type
    end

    def llvm_name
      "[#{types.map(&:llvm_name).join ', '}]"
    end

    def llvm_size
      @llvm_size ||= llvm_value_size + 4
    end

    def llvm_value_size
      @llvm_value_size ||= @types.map(&:llvm_size).max
    end

    def index_of_type(type)
      @types.index type
    end

    def each(&block)
      types.each(&block)
    end

    def ==(other)
      return true if equal?(other)

      if @types.length == 1
        @types.first == other
      elsif other.is_a?(UnionType)
        Set.new(@types) == Set.new(other.types)
      else
        false
      end
    end

    def to_s
      "Union[#{types.join ', '}]"
    end
  end

  class Metaclass < Type
    attr_accessor :type
    attr_accessor :defs

    def initialize(type)
      @name = "#{type.name}:Metaclass"
      @type = type
      @defs = {}
      @defs['alloc'] = Def.new('alloc', [], Alloc.new(@type))
    end

    def name
      @name
    end

    def llvm_name
      @name
    end
  end

  class Alloc < ASTNode
    def initialize(type)
      @type = type
    end

    def clone
      Alloc.new(@type.clone)
    end
  end
end