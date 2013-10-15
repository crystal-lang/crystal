require "type_inference/restrictions"

module Crystal
  abstract class Type
    def self.merge(types)
      types = types.compact
      return nil if types.empty?
      first = types.first
      raise "Bug found!" unless first
      first.program.type_merge(types)
    end

    def metaclass
      @metaclass ||= Metaclass.new(program, self)
    end

    def type_id
      @type_id ||= program.next_type_id
    end

    def passed_as_self?
      true
    end

    def integer?
      false
    end

    def float?
      false
    end

    def class?
      false
    end

    def metaclass?
      false
    end

    def union?
      false
    end

    def hierarchy_type
      self
    end

    def instance_type
      self
    end

    def lookup_def_instance(def_object_id, arg_types, block_type)
      raise "Bug: #{self} doesn't implement lookup_def_instance"
    end

    def add_def_instance(def_object_id, arg_types, block_type, typed_def)
      raise "Bug: #{self} doesn't implement add_def_instance"
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      raise "Bug: #{self} doesn't implement lookup_type"
    end

    def types
      raise "Bug: #{self} doesn't implement types"
    end

    def defs
      raise "Bug: #{self} doesn't implement defs"
    end

    def add_def(a_def)
      raise "Bug: #{self} doesn't implement add_def"
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      raise "Bug: #{self} doesn't implement lookup_matches"
    end

    def lookup_defs(name)
      raise "Bug: #{self} doesn't implement lookup_defs"
    end

    def llvm_name
      to_s
    end
  end

  abstract class ContainedType < Type
    getter :program
    getter :container
    getter :types

    def initialize(@program, @container)
      @types = {} of String => Type
    end
  end

  module MatchesLookup
    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      yields = !!yields

      name_defs = defs[name]
      name_defs.each do |def_key, a_def|
        if def_key.restrictions.length == arg_types.length && def_key.yields == yields
          matched = true
          def_key.restrictions.each_with_index do |restriction, i|
            restricted_type = arg_types[i].not_nil!.restrict restriction, self
            matched = false unless restricted_type
          end

          if matched
            return Matches.new([Match.new(self, a_def, arg_types)], nil, owner)
          end
        end
      end

      parents.each do |parent|
        matches = parent.lookup_matches(name, arg_types, yields, owner, type_lookup, matches_array)
        unless matches.empty?
          return matches
        end
      end

      Matches.new([] of Match, nil, owner, false)
    end

    def lookup_first_def(name, yields)
      yields = !!yields
      self.defs[name].values.find { |a_def| !!a_def.yields == yields }
    end

    def lookup_defs(name)
      defs = self.defs[name]
      return defs.values unless defs.empty?

      # parents.each do |parent|
      #   defs = parent.lookup_defs(name)
      #   return defs unless defs.empty?
      # end

      [] of Def
    end
  end

  module DefContainer
    include MatchesLookup

    make_tuple DefKey, restrictions, yields

    def defs
      @defs ||= Hash(String, Hash(DefKey, Def)).new { |h, k| h[k] = {} of DefKey => Def }
    end

    def add_def(a_def)
      restrictions = Array(Type | ASTNode | Nil).new(a_def.args.length)
      a_def.args.each { |arg| restrictions.push(arg.type || arg.type_restriction) }
      # restrictions = a_def.args.map { |arg| arg.type || arg.type_restriction }
      defs[a_def.name][DefKey.new(restrictions, !!a_def.yields)] = a_def
    end
  end

  module DefInstanceContainer
    make_tuple DefInstanceKey, def_object_id, arg_types, block_type

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

    def initialize(program, container, @name)
      super(program, container)
      @parents = [] of Type
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)

      if lookup_in_container
        already_looked_up.add(type_id)
      end

      type = self
      names.each do |name|
        type = type.try! &.types[name]?
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
    include DefInstanceContainer
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
    getter :owned_instance_vars
    property :instance_vars_in_initialize

    def initialize(program, container, name, @superclass, add_subclass = true)
      super(program, container, name)
      if superclass
        @depth = superclass.depth + 1
      else
        @depth = 0
      end
      @subclasses = [] of Type
      @parents.push superclass if superclass
      @owned_instance_vars = Set(String).new
      force_add_subclass if add_subclass
    end

    def force_add_subclass
      @superclass.add_subclass(self) if @superclass
    end

    def add_def(a_def)
      super

      transfer_instance_vars a_def

      a_def
    end

    def transfer_instance_vars(a_def)
      if a_def_instance_vars = a_def.instance_vars
        a_def_instance_vars.each do |ivar|
          if my_superclass = superclass
            unless my_superclass.owns_instance_var?(ivar)
              unless owned_instance_vars.includes?(ivar)
                owned_instance_vars.add(ivar)
                # each_subclass(self) do |subclass|
                #   subclass.remove_instance_var(ivar)
                # end
              end
            end
          end
        end

        if a_def.name == "initialize"
          if @instance_vars_in_initialize
            @instance_vars_in_initialize = @instance_vars_in_initialize & a_def_instance_vars
          else
            @instance_vars_in_initialize = a_def_instance_vars
          end

          # unless a_def.calls_super
          #   sup = superclass
          #   while sup
          #     sup.instance_vars_in_initialize &= a_def_instance_vars
          #     sup = sup.superclass
          #   end
          # end
        end
      end
    end
  end

  module InstanceVarContainer
    # def immutable
    #   @immutable.nil? ? true : @immutable
    # end

    # def immutable=(immutable)
    #   @immutable = immutable
    # end

    def instance_vars
      @instance_vars ||= {} of String => Var
    end

    def owns_instance_var?(name)
      owned_instance_vars.includes?(name) || ((my_superclass = superclass) && my_superclass.owns_instance_var?(name))
    end

    def remove_instance_var(name)
      owned_instance_vars.delete(name)
      instance_vars.delete(name)
    end

    def lookup_instance_var(name, create = true)
      lookup_instance_var_internal(name, create).not_nil!
    end

    def lookup_instance_var_internal(name, create)
      if my_superclass = superclass
        if var = my_superclass.lookup_instance_var_internal(name, false)
          return var
        end
      end

      if create || owned_instance_vars.includes?(name)
        instance_vars.fetch_or_assign(name) { Var.new name }
      else
        instance_vars[name]?
      end
    end

    def index_of_instance_var(name)
      if sup = superclass
        index = sup.index_of_instance_var(name)
        if index
          index
        else
          index = instance_vars.keys.index(name)
          if index
            sup.all_instance_vars_count + index
          else
            nil
          end
        end
      else
        instance_vars.keys.index(name)
      end
    end

    def each_instance_var(&block)
      if superclass
        superclass.each_instance_var(&block)
      end

      instance_vars.each(&block)
    end

    def all_instance_vars
      if sup = superclass
        sup.all_instance_vars.merge(instance_vars)
      else
        instance_vars
      end
    end

    def all_instance_vars_count
      if sup = superclass
        sup.all_instance_vars_count + instance_vars.length
      else
        instance_vars.length
      end
    end

    def has_instance_var_in_initialize?(name)
      (ivars = instance_vars_in_initialize) && ivars.includes?(name) || ((sup = superclass) && sup.has_instance_var_in_initialize?(name))
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end
  end

  class NonGenericClassType < ClassType
    include InstanceVarContainer
    include DefInstanceContainer

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(program, self)
        metaclass.add_def Def.new("allocate", ([] of Arg), Primitive.new(:allocate))
        metaclass
      end
    end

    def class?
      true
    end
  end

  class PrimitiveType < ClassType
    include DefInstanceContainer

    getter :llvm_type
    getter :llvm_size

    def initialize(program, container, name, superclass, @llvm_type, @llvm_size)
      super(program, container, name, superclass)
    end

    def llvm_name
      name
    end
  end

  class BoolType < PrimitiveType
  end

  class CharType < PrimitiveType
  end

  class IntegerType < PrimitiveType
    getter :rank

    def initialize(program, container, name, superclass, llvm_type, llvm_size, @rank)
      super(program, container, name, superclass, llvm_type, llvm_size)
    end

    def integer?
      true
    end

    def signed?
      @rank % 2 == 1
    end

    def unsigned?
      @rank % 2 == 0
    end

    def bits
      8 * (2 ** normal_rank)
    end

    def normal_rank
      (@rank - 1) / 2
    end
  end

  class FloatType < PrimitiveType
    getter :rank

    def initialize(program, container, name, superclass, llvm_type, llvm_size, @rank)
      super(program, container, name, superclass, llvm_type, llvm_size)
    end

    def float?
      true
    end
  end

  class NilType < PrimitiveType
    def type_id
      0
    end
  end

  class ValueType < NonGenericClassType
    def value?
      true
    end
  end

  module GenericType
    def type_vars
      @type_vars
    end

    def generic_types
      @generic_types ||= {} of Array(Int32) => Type
    end

    def instantiate(type_vars)
      key = type_vars.map(&.type_id)
      if (instance = generic_types[key]?)
        return instance
      end

      instance_type_vars = {} of String => Var
      self.type_vars.zip(type_vars) do |name, type|
        var = Var.new(name, type)
        var.bind_to var
        instance_type_vars[name] = var
      end

      instance = instance_class.new program, self, instance_type_vars
      generic_types[key] = instance

      instance.after_initialize
      instance
    end

    def generic?
      true
    end
  end

  class GenericClassType < ClassType
    include GenericType

    def initialize(program, container, name, superclass, @type_vars, add_subclass = true)
      super(program, container, name, superclass, add_subclass)
    end

    def instance_class
      GenericClassInstanceType
    end

    def class?
      true
    end

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(program, self)
        metaclass.add_def Def.new("allocate", ([] of Arg), Primitive.new(:allocate))
        metaclass
      end
    end

    def to_s
      "#{super}(#{type_vars.join ", "})"
    end
  end

  class GenericClassInstanceType < Type
    include InheritableClass
    include InstanceVarContainer
    # include ClassVarContainer
    include DefInstanceContainer
    include MatchesLookup

    getter program
    getter generic_class
    getter type_vars
    getter subclasses

    def initialize(@program, @generic_class, @type_vars)
      @subclasses = [] of Type
    end

    def after_initialize
      @generic_class.superclass.not_nil!.add_subclass(self)
    end

    def defs
      @generic_class.defs
    end

    def superclass
      @generic_class.superclass
    end

    def owned_instance_vars
      @generic_class.owned_instance_vars
    end

    def instance_vars_in_initialize
      @generic_class.instance_vars_in_initialize
    end

    def class?
      true
    end

    def generic?
      true
    end

    def metaclass
      @metaclass ||= GenericClassInstanceMetaclass.new(program, self)
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)
      already_looked_up.add(type_id)

      if names.length == 1
        if type_var = type_vars[names[0]]?
          return type_var.type
        end
      end

      type = generic_class
      names.each do |name|
        type = type.not_nil!.types[name]?
        break unless type
      end

      return type if type

      parents.each do |parent|
        match = parent.lookup_type(names, already_looked_up, false)
        return match if match
      end

      if lookup_in_container
        if sup_container = generic_class.container
          return sup_container.lookup_type(names, already_looked_up)
        end
      end

      nil
    end


    def parents
      generic_class.parents.map do |t|
        # if t.is_a?(IncludedGenericModule)
        #   IncludedGenericModule.new(t.module, self, t.mapping)
        # else
          t
        # end
      end
    end

    def to_s
      "#{generic_class.full_name}(#{type_vars.values.map(&.type).join ", "})"
    end
  end

  class PointerType < GenericClassType
    def instance_class
      PointerInstanceType
    end

    def pointer?
      true
    end
  end

  class PointerInstanceType < GenericClassInstanceType
    def var
      type_vars["T"]
    end

    def pointer?
      true
    end

    def allocated
      true
    end

    def primitive_like?
      var.type.primitive_like?
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end
  end

  class LibType < ModuleType
    property :libname

    def initialize(program, container, name, @libname = nil)
      super(program, container, name)
    end

    def metaclass
      self
    end

    # def add_def(a_def)
    #   existing = defs[a_def.name]
    #   if existing.length > 0
    #     existing = existing.first[1]
    #     if existing.compatible_with?(a_def)
    #       return
    #     else
    #       raise "fun redefinition with different signature (was #{existing.to_s})"
    #     end
    #   end

    #   super
    # end

    # def add_var(name, type)
    #   arg = Arg.new_with_restriction('value', type)
    #   arg.set_type(type)

    #   setter = External.new("#{name}=", [arg], LibSet.new(name, type))
    #   setter.real_name = "*#{to_s}.#{name}="
    #   setter.owner = self
    #   setter.set_type(type)

    #   getter = External.new(name, [], LibGet.new(name, type))
    #   getter.real_name = "*#{to_s}.#{name}"
    #   getter.owner = self
    #   getter.set_type(type)

    #   add_def setter
    #   add_def getter
    # end

    def passed_as_self?
      false
    end

    def type_desc
      "lib"
    end

    # def to_s
    #   name
    # end
  end

  class Metaclass < Type
    include DefContainer
    include DefInstanceContainer

    getter program
    getter instance_type

    def initialize(@program, @instance_type)
    end

    def parents
      instance_type.parents.map &.metaclass
    end

    def metaclass?
      true
    end

    def types
      raise "Metaclass doesn't have types"
    end

    def to_s
      "#{instance_type}:Class"
    end
  end

  class GenericClassInstanceMetaclass < Type
    include MatchesLookup
    include DefInstanceContainer

    getter program
    getter instance_type

    def initialize(@program, @instance_type)
    end

    def add_def(a_def)
      instance_type.generic_class.metaclass.add_def a_def
    end

    def defs
      instance_type.generic_class.metaclass.defs
    end

    def type_vars
      instance_type.type_vars
    end

    def abstract
      instance_type.abstract
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      instance_type.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def metaclass?
      true
    end

    def parents
      instance_type.parents.map &.metaclass
    end

    def llvm_size
      4
    end

    def to_s
      "#{instance_type}:Class"
    end
  end

  class UnionType < Type
    getter :program
    getter :union_types

    def initialize(@program, @union_types)
    end

    def parents
      [] of Type
    end

    def union?
      true
    end

    def to_s
      # if nilable?
      #   "#{nilable_type}?"
      # else
        @union_types.join " | "
      # end
    end
  end
end
