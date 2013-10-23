require "type_inference/restrictions"

module Crystal
  abstract class Type
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

    def value?
      false
    end

    def module?
      false
    end

    def metaclass?
      false
    end

    def union?
      false
    end

    def generic?
      false
    end

    def c_struct?
      false
    end

    def c_union?
      false
    end

    def c_enum?
      false
    end

    def primitive_like?
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

    def parents
      raise "Bug: #{self} doesn't implement parents"
    end

    def defs
      raise "Bug: #{self} doesn't implement defs"
    end

    def sorted_defs
      raise "Bug: #{self} doesn't implement sorted_defs"
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

    def include(mod)
      raise "Bug: #{self} doesn't implement include"
    end

    def llvm_name
      to_s
    end

    def type_desc
      to_s
    end
  end

  class NoReturnType < Type
    getter :program

    def initialize(@program)
    end

    def no_return?
      true
    end

    def primitive_like?
      true
    end

    def parents
      nil
    end

    def to_s
      "NoReturn"
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
    def match_def_args(args, a_def, owner, type_lookup)
      match = Match.new(owner, a_def, [] of Type)
      args.each_with_index do |arg, i|
        def_arg = a_def.args[i]
        match_arg_type = match_arg(arg, def_arg, owner, type_lookup, match.free_vars)
        if match_arg_type
          match.arg_types.push match_arg_type
        else
          return nil
        end
      end

      match
    end

    def match_arg(arg_type, arg, owner, type_lookup, free_vars)
      restriction = arg.type? || arg.type_restriction
      arg_type.not_nil!.restrict restriction, type_lookup
    end

    def lookup_matches_without_parents(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      if defs = self.sorted_defs[DefContainer::SortedDefKey.new(name, arg_types.length, yields)]
        matches_array ||= [] of Match
        defs.each do |a_def|
          match = match_def_args(arg_types, a_def, owner, type_lookup)
          if match
            matches_array.push match
            if match.arg_types == arg_types
              return Matches.new(matches_array, true, owner)
            end
          end
        end
      end

      Matches.new(matches_array,
        nil, #Cover.new(arg_types, matches_array),
        owner)
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      the_type_lookup = type_lookup

      matches_array ||= [] of Match

      matches = lookup_matches_without_parents(name, arg_types, yields, owner, the_type_lookup, matches_array)
      return matches if matches.cover_all?

      if (my_parents = parents) && !(name == "new" && owner.metaclass?)
        my_parents.each do |parent|
          the_type_lookup = parent
          if value?
            parent_owner = owner
          elsif parent.class?
            parent_owner = owner
          elsif parent.is_a?(IncludedGenericModule)
            the_type_lookup = parent
            parent_owner = owner
          elsif parent.module?
            parent_owner = owner
          else
            parent_owner = parent
          end
          parent_matches = parent.lookup_matches(name, arg_types, yields, parent_owner, the_type_lookup, matches.matches)
          return parent_matches if parent_matches.cover_all?

          matches = parent_matches unless !parent_matches.matches || parent_matches.matches.empty?
        end
      end

      Matches.new(matches.matches, matches.cover, owner, false)

    end

    def lookup_first_def(name, yields)
      yields = !!yields
      self.defs[name].values.find { |a_def| !!a_def.yields == yields }
    end

    def lookup_defs(name)
      defs = self.defs[name]
      return defs.values unless defs.empty?

      parents.try &.each do |parent|
        parent_defs = parent.lookup_defs(name)
        return parent_defs unless parent_defs.empty?
      end

      [] of Def
    end
  end

  module DefContainer
    include MatchesLookup

    make_tuple DefKey, restrictions, yields
    make_tuple SortedDefKey, name, length, yields

    def defs
      @defs ||= Hash(String, Hash(DefKey, Def)).new { |h, k| h[k] = {} of DefKey => Def }
    end

    def sorted_defs
      @sorted_defs ||= Hash(SortedDefKey, Array(Def)).new { |h, k| h[k] = [] of Def }
    end

    def add_def(a_def)
      restrictions = Array(Type | ASTNode | Nil).new(a_def.args.length)
      a_def.args.each { |arg| restrictions.push(arg.type? || arg.type_restriction) }
      # restrictions = a_def.args.map { |arg| arg.type || arg.type_restriction }
      key = DefKey.new(restrictions, !!a_def.yields)
      old_def = defs[a_def.name][key]?
      defs[a_def.name][key] = a_def
      add_sorted_def(a_def)
      old_def
    end

    def add_sorted_def(a_def)
      sorted_defs = self.sorted_defs[SortedDefKey.new(a_def.name, a_def.args.length, !!a_def.yields)]
      # sorted_defs.each_with_index do |ex_def, i|
      #   if a_def.is_restriction_of?(ex_def, self)
      #     sorted_defs.insert(i, a_def)
      #     return
      #   end
      # end
      sorted_defs << a_def
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

    def include(mod)
      @parents.insert 0, mod unless parents.any? &.==(mod)
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)

      if lookup_in_container
        already_looked_up.add(type_id)
      end

      type = self
      names.each do |name|
        type = type.not_nil!.types[name]?
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

    def type_desc
      "module"
    end
  end

  class NonGenericModuleType < ModuleType
    include DefInstanceContainer

    def module?
      true
    end
  end

  module ClassVarContainer
    def class_vars
      @class_vars ||= {} of String => Var
    end

    def has_class_var?(name)
      class_vars.has_key?(name)
    end

    def lookup_class_var(name)
      class_vars[name] ||= Var.new name
    end

    def class_var_owner
      self
    end
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
          if superclass = @superclass
            unless superclass.owns_instance_var?(ivar)
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

    def type_desc
      "class"
    end
  end

  module InstanceVarContainer
    def immutable
      @immutable.nil? ? true : @immutable
    end

    def immutable=(immutable)
      @immutable = immutable
    end

    def instance_vars
      @instance_vars ||= {} of String => Var
    end

    def owns_instance_var?(name)
      owned_instance_vars.includes?(name) || ((superclass = @superclass) && superclass.owns_instance_var?(name))
    end

    def remove_instance_var(name)
      owned_instance_vars.delete(name)
      instance_vars.delete(name)
    end

    def lookup_instance_var(name, create = true)
      lookup_instance_var?(name, create).not_nil!
    end

    def lookup_instance_var?(name, create)
      if superclass = @superclass
        if var = superclass.lookup_instance_var?(name, false)
          return var
        end
      end

      if create || owned_instance_vars.includes?(name)
        instance_vars[name] ||= Var.new(name)
      else
        instance_vars[name]?
      end
    end

    def index_of_instance_var(name)
      index_of_instance_var?(name).not_nil!
    end

    def index_of_instance_var?(name)
      if sup = superclass
        index = sup.index_of_instance_var?(name)
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
    include ClassVarContainer
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

    def value?
      true
    end

    def primitive_like?
      true
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
    getter type_vars

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

  class GenericModuleType < ModuleType
    include GenericType

    def initialize(program, container, name, @type_vars)
      super(program, container, name)
    end

    def module?
      true
    end

    def type_desc
      "generic module"
    end

    def to_s
      "#{super}(#{type_vars.join ", "})"
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

    def type_desc
      "generic class"
    end

    def to_s
      "#{super}(#{type_vars.join ", "})"
    end
  end

  class GenericClassInstanceType < Type
    include InheritableClass
    include InstanceVarContainer
    include ClassVarContainer
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

    delegate defs, @generic_class
    delegate sorted_defs, @generic_class
    delegate superclass, @generic_class
    delegate owned_instance_vars, @generic_class
    delegate instance_vars_in_initialize, @generic_class

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
        if t.is_a?(IncludedGenericModule)
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        else
          t
        end
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

  class IncludedGenericModule < Type
    getter program
    getter :module
    getter including_class
    getter mapping

    # delegate [:implements?, :lookup_matches_without_parents, :lookup_similar_defs, :lookup_macro, :defs] => :@module

    def initialize(@program, @module, @including_class, @mapping)
    end

    delegate container, @module
    delegate name, @module
    delegate parents, @module
    delegate defs, @module

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      @module.lookup_matches(name, arg_types, yields, owner, type_lookup, matches_array)
    end

    def lookup_defs(name)
      @module.lookup_defs(name)
    end

    def match_arg(arg_type, arg, owner, type_lookup, free_vars)
      @module.match_arg(arg_type, arg, owner, type_lookup, free_vars)
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      if names.length == 1
        if m = @mapping[names[0]]?
          case m
          when Type
            return m
          when String
            including_class = @including_class

            if including_class.is_a?(GenericClassInstanceType)
              type_var = including_class.type_vars[m]?
              return type_var ? type_var.type : nil
            end
          end
        end
      end

      @module.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def to_s
      "#{@module}(#{@including_class})"
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

    def add_def(a_def : External)
      existing_defs = defs[a_def.name]
      existing = existing_defs.first_value?
      if existing
        assert_type existing, External
        if existing.compatible_with?(a_def)
          return
        else
          raise "fun redefinition with different signature (was #{existing.to_s})"
        end
      end

      super
    end

    def add_def(a_def : Def)
      raise "Bug: shouldn't be adding a Def in a LibType"
    end

    def add_var(name, type)
      setter = External.new("#{name}=", [Arg.new_with_type("value", type)], Primitive.new(:external_var_set, type))
      setter.set_type(type)

      getter = External.new("#{name}", ([] of Arg), Primitive.new(:external_var_get, type))
      getter.set_type(type)

      add_def setter
      add_def getter
    end

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

  class TypeDefType < ContainedType
    getter :name
    getter :typedef

    # delegate [:lookup_first_def] => :typedef

    def initialize(program, container, @name, @typedef)
      super(program, container)
    end

    delegate llvm_name, typedef
    delegate pointer?, typedef
    delegate parents, typedef

    def lookup_matches(name, arg_types, yields)
      typedef.lookup_matches(name, arg_types, yields)
    end

    def primitive_like?
      true
    end

    def type_def_type?
      true
    end

    def type_desc
      "type def"
    end

    def to_s
      name
    end
  end

  class CStructType < ContainedType
    include DefContainer
    include DefInstanceContainer

    getter name
    getter vars

    def initialize(program, container, @name, vars)
      super(program, container)
      @name = name
      @vars = {} of String => Var
      vars.each do |var|
        @vars[var.name] = var
        add_def Def.new("#{var.name}=", [Arg.new_with_type("value", var.type)], Primitive.new(:struct_set))
        add_def Def.new(var.name, ([] of Arg), Primitive.new(:struct_get))
      end
    end

    def c_struct?
      true
    end

    def primitive_like?
      true
    end

    def parents
      nil
    end

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(program, self)
        metaclass.add_def Def.new("new", ([] of Arg), Primitive.new(:struct_new))
        metaclass
      end
    end

    def llvm_name
      "struct.#{to_s}"
    end

    def index_of_var(name)
      @vars.keys.index(name).not_nil!
    end

    def type_desc
      "struct"
    end

    def to_s
      "#{container}::#{name}"
    end
  end

  class CUnionType < ContainedType
    include DefContainer
    include DefInstanceContainer

    getter name
    getter vars

    def initialize(program, container, @name, vars)
      super(program, container)
      @name = name
      @vars = {} of String => Var
      vars.each do |var|
        @vars[var.name] = var
        add_def Def.new("#{var.name}=", [Arg.new_with_type("value", var.type)], Primitive.new(:union_set))
        add_def Def.new(var.name, ([] of Arg), Primitive.new(:union_get))
      end
    end

    def c_union?
      true
    end

    def primitive_like?
      true
    end

    def parents
      nil
    end

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(program, self)
        metaclass.add_def Def.new("new", ([] of Arg), Primitive.new(:union_new))
        metaclass
      end
    end

    def llvm_name
      "union.#{to_s}"
    end

    def type_desc
      "union"
    end

    def to_s
      "#{container}::#{name}"
    end
  end

  class CEnumType < ContainedType
    property name
    property base_type

    def initialize(program, container, @name, constants)
      super(program, container)

      constants.each do |constant|
        @types[constant.name] = Const.new(program, self, constant.name, constant.default_value.not_nil!)
      end
    end

    def c_enum?
      true
    end

    def primitive_like?
      true
    end

    def parents
      nil
    end

    def type_desc
      "enum"
    end

    def to_s
      "#{container}::#{name}"
    end
  end

  class Metaclass < Type
    include DefContainer
    include DefInstanceContainer
    include ClassVarContainer

    getter program
    getter instance_type

    def initialize(@program, @instance_type)
    end

    def lookup_type(names, already_looked_up = Set(Int32).new, lookup_in_container = true)
      instance_type.lookup_type(names, already_looked_up, lookup_in_container)
    end

    delegate :abstract, instance_type

    def class_var_owner
      instance_type
    end

    def parents
      instance_type.parents.try &.map &.metaclass
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

    delegate defs, :"instance_type.generic_class.metaclass"
    delegate sorted_defs, :"instance_type.generic_class.metaclass"
    delegate type_vars, instance_type
    delegate :abstract, instance_type

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
      nil
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

    def type_desc
      "union"
    end
  end

  class Const < ContainedType
    getter name
    getter value
    getter scope_types
    getter scope

    def initialize(program, container, @name, @value, @scope_types = [] of Type, @scope = nil)
      super(program, container)
    end

    def full_name
      container && !container.is_a?(Program) ? "#{container}::#{name}" : name
    end

    def type_desc
      "constant"
    end

    def to_s
      full_name
    end
  end
end
