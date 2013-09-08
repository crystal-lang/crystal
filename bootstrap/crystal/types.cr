module Crystal
  abstract class Type
    def self.merge(types)
      types = types.compact
      return nil if types.empty?
      first = types.first
      raise "Bug found!" unless first
      first.program.type_merge(types)
    end

    def type_id
      object_id
    end
  end

  abstract class ContainedType < Type
    getter :container
    getter :types

    def initialize(@container)
      @types = {} of String => Type
    end

    def program
      container.program
    end
  end

  module DefContainer
    def defs
      @defs ||= {} of String => Def
    end

    def add_def(a_def)
      defs[a_def.name] = a_def
    end
  end

  module MatchesLookup
    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      a_def = defs[name]?
      if a_def
        Matches.new([Match.new(self, a_def, arg_types)], nil)
      else
        nil
      end
    end
  end

  module DefInstanceContainer
    class DefInstanceKey
      getter :def_object_id
      getter :arg_types
      getter :block_type

      def initialize(@def_object_id, @arg_types, @block_type)
      end

      def ==(other : DefInstanceKey)
        other.def_object_id == @def_object_id && other.arg_types == @arg_types && other.block_type == @block_type
      end

      def hash
        hash = 0
        hash = 31 * hash + @def_object_id
        hash = 31 * hash + @arg_types.hash
        hash = 31 * hash + @block_type.hash
        hash
      end
    end

    def def_instances
      @def_instances ||= {} of DefInstanceKey => Def
    end

    def add_def_instance(def_object_id, arg_types, block_type, typed_def)
      def_instances[def_instance_key(def_object_id, arg_types, block_type)] = typed_def
    end

    def lookup_def_instance(def_object_id, arg_types, block_type)
      def_instances.fetch(def_instance_key(def_object_id, arg_types, block_type), nil)
    end

    def def_instance_key(def_object_id, arg_types, block_type)
      DefInstanceKey.new(def_object_id, arg_types, block_type)
    end
  end

  abstract class ModuleType < ContainedType
    include DefContainer

    getter :name
    getter :parents

    def initialize(container, @name)
      super(container)
      @parents = [] of Type
    end

    def lookup_type(names, already_looked_up = Set(UInt64).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)

      if lookup_in_container
        already_looked_up.add(type_id)
      end

      type = self
      names.each do |name|
        type = type.types[name]
        break unless type
      end

      return type if type

      parents.each do |parent|
        match = parent.lookup_type(names, already_looked_up, false)
        return match if match
      end

      lookup_in_container && container ? container.lookup_type(names, already_looked_up) : nil
    end

    def full_name
      @container && !@container.is_a?(Program) ? "#{@container}::#{@name}" : @name
    end

    def to_s
      full_name
    end
  end

  class NonGenericModuleType < ModuleType
  end

  module InheritableClass
    def add_subclass(subclass)
      subclasses << subclass
      notify_subclass_added
      @superclass.notify_subclass_added if @superclass
    end

    def notify_subclass_added
      # if @subclass_observers
      #   @subclass_observers.each do |observer|
      #     observer.on_new_subclass
      #   end
      # end
    end
  end

  abstract class ClassType < ModuleType
    include InheritableClass

    getter :superclass
    getter :subclasses
    getter :depth
    property :abstract

    def initialize(container, name, @superclass, add_subclass = true)
      super(container, name)
      if superclass
        @depth = superclass.depth + 1
      else
        @depth = 0
      end
      @subclasses = [] of Type
      @parents.push superclass if superclass
      force_add_subclass if add_subclass
    end

    def force_add_subclass
      @superclass.add_subclass(self) if @superclass
    end
  end

  class NonGenericClassType < ClassType
  end

  class PrimitiveType < ClassType
    getter :llvm_type
    getter :llvm_size

    def initialize(container, name, superclass, @llvm_type, @llvm_size)
      super(container, name, superclass)
    end

    def llvm_name
      name
    end
  end

  class IntegerType < PrimitiveType
    getter :rank

    def initialize(container, name, superclass, llvm_type, llvm_size, @rank)
      super(container, name, superclass, llvm_type, llvm_size)
    end
  end

  class FloatType < PrimitiveType
    getter :rank

    def initialize(container, name, superclass, llvm_type, llvm_size, @rank)
      super(container, name, superclass, llvm_type, llvm_size)
    end
  end

  class NilType < PrimitiveType
  end

  class ValueType < NonGenericClassType
    def value?
      true
    end
  end
end
