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

    def metaclass?
      false
    end

    def instance_type
      self
    end

    def lookup_def_instance(def_object_id, arg_types, block_type)
      raise "BUG: #{self} doesn't implement lookup_def_instance"
    end

    def add_def_instance(def_object_id, arg_types, block_type, typed_def)
      raise "BUG: #{self} doesn't implement add_def_instance"
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      raise "BUG: #{self} doesn't implement lookup_type"
    end

    def types
      raise "BUG: #{self} doesn't implement types"
    end

    def add_def(a_def)
      raise "BUG: #{self} doesn't implement add_def"
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      raise "BUG: #{self} doesn't implement lookup_matches"
    end

    def lookup_defs(name)
      raise "BUG: #{self} doesn't implement lookup_defs"
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
        if def_key.yields == yields
          matched = true
          def_key.restrictions.each_with_index do |restriction, i|
            arg_type = arg_types[i]
            case restriction
            when nil
              # Nothing
            when Type
              matched = false unless restriction == arg_type
            when Ident
              type = lookup_type restriction.names
              if type
                matched = false unless type == arg_type
              end
              # TODO
            end
          end

          if matched
            return Matches.new([Match.new(self, a_def, arg_types)], nil, owner)
          end
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
      restrictions = a_def.args.map { |arg| arg.type || arg.type_restriction }
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

    def initialize(program, container, name, @superclass, add_subclass = true)
      super(program, container, name)
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
    include DefInstanceContainer
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

  class IntegerType < PrimitiveType
    getter :rank

    def initialize(program, container, name, superclass, llvm_type, llvm_size, @rank)
      super(program, container, name, superclass, llvm_type, llvm_size)
    end
  end

  class FloatType < PrimitiveType
    getter :rank

    def initialize(program, container, name, superclass, llvm_type, llvm_size, @rank)
      super(program, container, name, superclass, llvm_type, llvm_size)
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

    getter :program
    getter :instance_type

    def initialize(@program, @instance_type)
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

  class UnionType < Type
    getter :program
    getter :union_types

    def initialize(@program, @union_types)
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
