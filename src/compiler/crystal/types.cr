module Crystal
  abstract class Type
    include Enumerable(self)

    def self.merge(nodes : Array(ASTNode))
      nodes.find(&.type?).try &.type.program.type_merge(nodes)
    end

    def self.merge(types : Array(Type))
      if types.length == 0
        nil
      else
        types.first.program.type_merge(types)
      end
    end

    def each
      yield self
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

    def passed_by_val?
      false
    end

    def rank
      raise "Bug: #{self} doesn't implement rank"
    end

    def abstract
      raise "Bug: #{self} doesn't implement abstract"
    end

    def subclasses
      raise "Bug: #{self} doesn't implement subclasses"
    end

    def integer?
      false
    end

    def float?
      false
    end

    def number?
      integer? || float?
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

    def pointer?
      false
    end

    def nilable?
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

    def nil_type?
      false
    end

    def bool_type?
      false
    end

    def no_return?
      false
    end

    def hierarchy?
      false
    end

    def hierarchy_metaclass?
      false
    end

    def fun_type?
      false
    end

    def void?
      false
    end

    def hierarchy_type
      self
    end

    def instance_type
      self
    end

    def includes_type?(type)
      self == type
    end

    def allocated
      true
    end

    def allocated=(value)
      raise "Bug: #{self} doesn't implement allocated="
    end

    def implements?(other_type)
      self == other_type
    end

    def is_subclass_of?(type)
      self == type
    end

    def filter_by(other_type)
      implements?(other_type) ? self : nil
    end

    def filter_by_responds_to(name)
      nil
    end

    def cover
      self
    end

    def cover_length
      1
    end

    def common_ancestor(other)
      nil
    end

    def lookup_def_instance(def_object_id, arg_types, block_type)
      raise "Bug: #{self} doesn't implement lookup_def_instance"
    end

    def add_def_instance(def_object_id, arg_types, block_type, typed_def)
      raise "Bug: #{self} doesn't implement add_def_instance"
    end

    def lookup_type(node : Ident)
      (node.global ? program : self).lookup_type(node.names)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
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

    def lookup_matches_with_modules(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      raise "Bug: #{self} doesn't implement lookup_matches_with_modules"
    end

    def lookup_defs(name)
      raise "Bug: #{self} doesn't implement lookup_defs"
    end

    def lookup_first_def(name, yields)
      raise "Bug: #{self} doesn't implement lookup_first_def"
    end

    def macros
      raise "Bug: #{self} doesn't implement macros"
    end

    def add_macro(a_def)
      raise "Bug: #{self} doesn't implement add_macro"
    end

    def lookup_macro(name, args_length)
      raise "Bug: #{self} doesn't implement lookup_macro"
    end

    def include(mod)
      raise "Bug: #{self} doesn't implement include"
    end

    def add_subclass_observer(observer)
      raise "Bug: #{self} doesn't implement add_subclass_observer"
    end

    def remove_subclass_observer(observer)
      raise "Bug: #{self} doesn't implement remove_subclass_observer"
    end

    def all_instance_vars
      raise "Bug: #{self} doesn't implement all_instance_vars"
    end

    def owned_instance_vars
      raise "Bug: #{self} doesn't implement owned_instance_vars"
    end

    def index_of_instance_var(name)
      raise "Bug: #{self} doesn't implement index_of_instance_var"
    end

    def lookup_instance_var(name, create = true)
      raise "Bug: #{self} doesn't implement lookup_instance_var"
    end

    def has_instance_var_in_initialize?(name)
      raise "Bug: #{self} doesn't implement has_instance_var_in_initialize?"
    end

    def has_def?(name)
      raise "Bug: #{self} doesn't implement has_def?"
    end

    def remove_instance_var(name)
      raise "Bug: #{self} doesn't implement remove_instance_var"
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

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      Matches.new([] of Match, nil, self, false)
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
      match = Match.new(owner, a_def, type_lookup, [] of Type)
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

    def match_arg(arg_type, arg : Arg, owner, type_lookup, free_vars)
      restriction = arg.type? || arg.type_restriction
      arg_type.not_nil!.restrict restriction, owner, type_lookup, free_vars
    end

    def match_arg(arg_type, restriction : ASTNode, owner, type_lookup, free_vars)
      arg_type.not_nil!.restrict restriction, owner, type_lookup, free_vars
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

      Matches.new(matches_array, Cover.new(arg_types, matches_array), owner)
    end

    def lookup_matches_with_modules(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      matches_array ||= [] of Match

      matches = lookup_matches_without_parents(name, arg_types, yields, owner, type_lookup, matches_array)
      return matches unless matches.empty?

      if (my_parents = parents) && !(name == "new" && owner.metaclass?)
        my_parents.each do |parent|
          type_lookup = parent
          parent_owner = owner
          if parent.is_a?(IncludedGenericModule)
            type_lookup = parent
          elsif parent.module?
            # Nothing
          else
            break
          end

          parent_matches = parent.lookup_matches_with_modules(name, arg_types, yields, parent_owner, type_lookup, matches.matches)
          return parent_matches unless parent_matches.empty?

          matches = parent_matches unless !parent_matches.matches || parent_matches.matches.empty?
        end
      end

      Matches.new(matches.matches, matches.cover, owner, false)
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      matches_array ||= [] of Match

      matches = lookup_matches_without_parents(name, arg_types, yields, owner, type_lookup, matches_array)
      return matches if matches.cover_all?

      if (my_parents = parents) && !(name == "new" && owner.metaclass?)
        my_parents.each do |parent|
          type_lookup = parent
          if value?
            parent_owner = owner
          elsif parent.class?
            parent_owner = owner
          elsif parent.is_a?(IncludedGenericModule)
            type_lookup = parent
            parent_owner = owner
          elsif parent.module?
            parent_owner = owner
          else
            parent_owner = parent
          end
          parent_matches = parent.lookup_matches(name, arg_types, yields, parent_owner, type_lookup, matches.matches)
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

    def lookup_macro(name, args_length)
      if a_macro = self.macros[name][args_length]?
        return a_macro
      end

      parents.try &.each do |parent|
        parent_macro = parent.lookup_macro(name, args_length)
        return parent_macro if parent_macro
      end

      nil
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
      a_def.owner = self
      restrictions = Array(Type | ASTNode | Nil).new(a_def.args.length)
      a_def.args.each { |arg| restrictions.push(arg.type? || arg.type_restriction) }
      key = DefKey.new(restrictions, !!a_def.yields)
      old_def = defs[a_def.name][key]?
      defs[a_def.name][key] = a_def
      add_sorted_def(a_def)
      old_def
    end

    def add_sorted_def(a_def)
      sorted_defs = self.sorted_defs[SortedDefKey.new(a_def.name, a_def.args.length, !!a_def.yields)]
      sorted_defs.each_with_index do |ex_def, i|
        if a_def.is_restriction_of?(ex_def, self)
          sorted_defs.insert(i, a_def)
          return
        end
      end
      sorted_defs << a_def
    end

    def macros
      @macros ||= Hash(String, Hash(Int32, Macro)).new { |h, k| h[k] = {} of Int32 => Macro }
    end

    def add_macro(a_def)
      self.macros[a_def.name][a_def.args.length] = a_def
    end

    def filter_by_responds_to(name)
      has_def?(name) ? self : nil
    end

    def has_def?(name)
      return true if defs.has_key?(name)

      parents.try &.each do |parent|
        return true if parent.has_def?(name)
      end

      false
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
      def_instances[def_instance_key(def_object_id, arg_types, block_type)]?
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

    def implements?(other_type)
      super || parents.any? &.implements?(other_type)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
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

    def add_subclass_observer(observer)
      @subclass_observers ||= [] of Call
      @subclass_observers << observer
    end

    def remove_subclass_observer(observer)
      @subclass_observers.try &.delete(observer)
    end

    def notify_subclass_added
      @subclass_observers.try &.each &.on_new_subclass
    end
  end

  module NonGenericOrGenericClassInstanceType
  end

  abstract class ClassType < ModuleType
    include InheritableClass

    getter :superclass
    getter :subclasses
    getter :depth
    property :abstract
    getter :owned_instance_vars
    property :instance_vars_in_initialize
    getter :allocated

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

    def all_subclasses
      subclasses = [] of Type
      append_subclasses(self, subclasses)
      subclasses
    end

    def append_subclasses(type, subclasses)
      type.subclasses.each do |subclass|
        subclasses << subclass
        append_subclasses subclass, subclasses
      end
    end

    def is_subclass_of?(type)
      super || ((superclass = @superclass) && superclass.is_subclass_of?(type))
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
                all_subclasses.each do |subclass|
                  subclass.remove_instance_var(ivar)
                end
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

          unless a_def.calls_super
            sup = superclass
            while sup
              sup_ivars = sup.instance_vars_in_initialize
              if sup_ivars
                sup.instance_vars_in_initialize = sup_ivars & a_def_instance_vars
              end
              sup = sup.superclass
            end
          end
        end
      end
    end

    def transfer_instance_vars_of_mod(mod)
      mod.defs.each do |def_name, hash|
        hash.each do |restrictions, a_def|
          transfer_instance_vars a_def
        end
      end

      mod.parents.try &.each do |parent|
        transfer_instance_vars_of_mod parent
      end
    end

    def include(mod)
      super mod
      transfer_instance_vars_of_mod mod
    end

    def allocated=(allocated)
      @allocated = allocated
      if superclass = @superclass
        superclass.allocated = allocated
      end
    end

    def common_ancestor(other : ClassType)
      if depth <= 1
        return nil
      end

      if self == other
        return self
      end

      if depth == other.depth
        my_superclass = @superclass
        other_superclass = other.superclass

        if my_superclass && other_superclass
          return my_superclass.common_ancestor(other_superclass)
        end
      elsif depth > other.depth
        my_superclass = @superclass
        if my_superclass
          return my_superclass.common_ancestor(other)
        end
      elsif depth < other.depth
        other_superclass = other.superclass
        if other_superclass
          return common_ancestor(other_superclass)
        end
      end

      nil
    end

    def common_ancestor(other : HierarchyType)
      common_ancestor(other.base_type)
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
      if (superclass = @superclass) && (var = superclass.lookup_instance_var?(name, false))
        return var
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
    include NonGenericOrGenericClassInstanceType

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(program, self)
        metaclass.add_def Def.new("allocate", ([] of Arg), Primitive.new(:allocate))
        metaclass
      end
    end

    def hierarchy_type
      @hierarchy_type ||= HierarchyType.new(program, self)
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

    def common_ancestor(other)
      nil
    end

    def allocated
      true
    end
  end

  class BoolType < PrimitiveType
    def bool_type?
      true
    end
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

  class SymbolType < PrimitiveType
  end

  class NilType < PrimitiveType
    def type_id
      0
    end

    def nil_type?
      true
    end
  end

  class VoidType < PrimitiveType
    def void?
      true
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
    include NonGenericOrGenericClassInstanceType

    getter program
    getter generic_class
    getter type_vars
    getter subclasses
    property allocated

    def initialize(@program, @generic_class, @type_vars)
      @subclasses = [] of Type
    end

    def after_initialize
      @generic_class.superclass.not_nil!.add_subclass(self)
    end

    def hierarchy_type
      @hierarchy_type ||= HierarchyType.new(program, self)
    end

    delegate depth, @generic_class
    delegate defs, @generic_class
    delegate sorted_defs, @generic_class
    delegate superclass, @generic_class
    delegate owned_instance_vars, @generic_class
    delegate instance_vars_in_initialize, @generic_class
    delegate macros, @generic_class
    delegate :abstract, @generic_class

    def class?
      true
    end

    def generic?
      true
    end

    def metaclass
      @metaclass ||= GenericClassInstanceMetaclass.new(program, self)
    end

    def is_subclass_of?(type)
      super || generic_class.is_subclass_of?(type)
    end

    def implements?(other_type)
      super || generic_class.implements?(other_type)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)
      already_looked_up.add(type_id)

      if (names.length == 1) && (type_var = type_vars[names[0]]?)
        return type_var.type
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

      if lookup_in_container && (sup_container = generic_class.container)
        return sup_container.lookup_type(names, already_looked_up)
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
    include MatchesLookup

    getter program
    getter :module
    getter including_class
    getter mapping

    # delegate [:lookup_similar_defs, :lookup_macro] => :@module

    def initialize(@program, @module, @including_class, @mapping)
    end

    delegate container, @module
    delegate name, @module
    delegate parents, @module
    delegate defs, @module
    delegate macros, @module

    def implements?(other_type)
      @module.implements?(other_type)
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      @module.lookup_matches(name, arg_types, yields, owner, type_lookup, matches_array)
    end

    def lookup_matches_without_parents(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      @module.lookup_matches_without_parents(name, arg_types, yields, owner, type_lookup, matches_array)
    end

    def lookup_defs(name)
      @module.lookup_defs(name)
    end

    def match_arg(arg_type, arg, owner, type_lookup, free_vars)
      @module.match_arg(arg_type, arg, owner, type_lookup, free_vars)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      if (names.length == 1) && (m = @mapping[names[0]]?)
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
    include DefInstanceContainer

    getter :name
    getter :typedef

    def initialize(program, container, @name, @typedef)
      super(program, container)
    end

    delegate llvm_name, typedef
    delegate pointer?, typedef
    delegate parents, typedef

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self)
      typedef.lookup_matches(name, arg_types, yields, owner, type_lookup)
    end

    def lookup_defs(name)
      typedef.lookup_defs(name)
    end

    def lookup_first_def(name, yields)
      typedef.lookup_first_def(name, yields)
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

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
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
    delegate macros, :"instance_type.generic_class.metaclass"
    delegate type_vars, instance_type
    delegate :abstract, instance_type

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
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

  module MultiType
    def concrete_types
      types = [] of Type
      each_concrete_type { |type| types << type }
      types
    end
  end

  class UnionType < Type
    include MultiType

    getter :program
    getter :union_types

    def initialize(@program, @union_types)
    end

    def each
      @union_types.each do |union_type|
        yield union_type
      end
    end

    def metaclass
      self
    end

    def parents
      nil
    end

    def union?
      true
    end

    def passed_by_val?
      true
    end

    def includes_type?(other_type)
      union_types.any? &.includes_type?(other_type)
    end

    def cover
      cover = [] of Type
      union_types.each do |union_type|
        union_type_cover = union_type.cover
        if union_type_cover.is_a?(Array)
          union_type_cover.each do |cover_type|
            cover << cover_type
          end
        else
          cover << union_type_cover
        end
      end
      cover
    end

    def cover_length
      sum = 0
      union_types.each { |t| sum += t.cover_length }
      sum
    end

    def filter_by(other_type)
      apply_filter &.filter_by(other_type)
    end

    def filter_by_responds_to(name)
      apply_filter &.filter_by_responds_to(name)
    end

    def apply_filter
      filtered_types = [] of Type

      @union_types.each do |union_type|
        filtered_type = yield union_type
        if filtered_type
          filtered_types.push filtered_type
        end
      end

      case filtered_types.length
      when 0
        nil
      when 1
        filtered_types.first
      else
        program.type_merge_union_of(filtered_types)
      end
    end

    def has_def?(name)
      union_types.any? &.has_def?(name)
    end

    def each_concrete_type
      union_types.each do |type|
        if type.is_a?(HierarchyType)
          type.subtypes.each do |subtype|
            yield subtype
          end
        else
          yield type
        end
      end
    end

    def to_s
      @union_types.join " | "
    end

    def type_desc
      "union"
    end
  end

  class NilableType < UnionType
    getter :not_nil_type

    def initialize(@program, @not_nil_type)
      super(@program, [@program.nil, @not_nil_type] of Type)
    end

    def union?
      false
    end

    def nilable?
      true
    end

    def passed_by_val?
      false
    end

    def to_s
      "#{@not_nil_type}?"
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

  module HierarchyTypeLookup
    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self)
      base_type_lookup = hierarchy_lookup(base_type)
      concrete_classes = cover()
      concrete_classes = [concrete_classes] of Type if concrete_classes.is_a?(Type)

      unless base_type_lookup.abstract && name == "allocate"
        base_type_matches = base_type_lookup.lookup_matches(name, arg_types, yields, self)
        if !base_type.abstract && !base_type_matches.cover_all?
          return Matches.new(base_type_matches.matches, base_type_matches.cover, base_type_lookup, false)
        end
      end

      all_matches = {} of Int32 => Matches
      matches = (base_type_matches && base_type_matches.matches) || [] of Match

      instance_type.subtypes(base_type).each do |subtype|
        assert_type subtype, NonGenericOrGenericClassInstanceType

        unless subtype.value?
          subtype_lookup = hierarchy_lookup(subtype)
          subtype_hierarchy_lookup = hierarchy_lookup(subtype.hierarchy_type)

          subtype_matches = subtype_lookup.lookup_matches_with_modules(name, arg_types, yields, subtype_hierarchy_lookup, subtype_hierarchy_lookup)
          concrete = concrete_classes.any? { |c| c.type_id == subtype.type_id }
          if concrete && !subtype_matches.cover_all? && !base_type_matches.not_nil!.cover_all?
            covered_by_superclass = false
            superclass = subtype.superclass
            while superclass && superclass != base_type
              superclass_lookup = hierarchy_lookup(superclass)
              superclass_hierarchy_lookup = hierarchy_lookup(superclass.hierarchy_type)
              superclass_matches = all_matches[superclass.type_id] ||= superclass_lookup.lookup_matches_with_modules(name, arg_types, yields, superclass_hierarchy_lookup, superclass_hierarchy_lookup)
              if superclass_matches.cover_all?
                covered_by_superclass = true
                break
              end
              superclass = superclass.superclass
            end

            unless covered_by_superclass
              return Matches.new(subtype_matches.matches, subtype_matches.cover, subtype_lookup, false)
            end
          end

          if !subtype_matches.empty? && (subtype_matches_matches = subtype_matches.matches)
            subtype_matches_matches.concat matches
            matches = subtype_matches_matches
          end
        end
      end

      Matches.new(matches, matches.length > 0, self)
    end

    def hierarchy_lookup(type)
      type
    end
  end

  class HierarchyType < Type
    include MultiType
    include DefInstanceContainer
    include HierarchyTypeLookup
    include InstanceVarContainer

    getter program
    getter base_type

    # delegate [:lookup_similar_defs, :allocated, :allocated=] => :base_type

    def initialize(@program, @base_type)
    end

    def lookup_first_def(name, yields)
      base_type.lookup_first_def(name, yields)
    end

    def lookup_defs(name)
      base_type.lookup_defs(name)
    end

    def lookup_instance_var(name, create = true)
      base_type.lookup_instance_var(name, create)
    end

    def index_of_instance_var(name)
      base_type.index_of_instance_var(name)
    end

    def lookup_macro(name, args_length)
      base_type.lookup_macro(name, args_length)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      base_type.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def has_instance_var_in_initialize?(name)
      base_type.has_instance_var_in_initialize?(name)
    end

    def all_instance_vars
      base_type.all_instance_vars
    end

    def abstract
      base_type.abstract
    end

    def allocated
      base_type.allocated
    end

    def allocated=(allocated)
      base_type.allocated = allocated
    end

    def common_ancestor(other)
      base_type.common_ancestor(other)
    end

    def metaclass
      @metaclass ||= HierarchyTypeMetaclass.new(program, self)
    end

    # def immutable=(immutable)
    #   each do |type|
    #     type.immutable = immutable
    #   end
    # end

    def is_subclass_of?(other)
      base_type.is_subclass_of?(other)
    end

    def hierarchy?
      true
    end

    def cover
      if base_type.abstract
        cover = [] of Type
        base_type.subclasses.each do |s|
          s_cover = s.hierarchy_type.cover
          if s_cover.is_a?(Array)
            cover.concat s_cover
          else
            cover.push s_cover
          end
        end
        cover
      else
        base_type
      end
    end

    def cover_length
      if base_type.abstract
        sum = 0
        base_type.subclasses.each { |s| sum += s.hierarchy_type.cover_length }
        sum
      else
        1
      end
    end

    def filter_by(type)
      restrict(type, self, nil, nil)
    end

    def each
      subtypes.each do |subtype|
        yield subtype
      end
    end

    def each_concrete_type
      subtypes.each do |subtype|
        unless subtype.abstract
          yield subtype
        end
      end
    end

    def subtypes
      subtypes = [] of Type
      collect_subtypes(base_type, subtypes)
      subtypes
    end

    def subtypes(type)
      subtypes = [] of Type
      type.subclasses.each do |subclass|
        collect_subtypes subclass, subtypes
      end
      subtypes
    end

    def collect_subtypes(type, subtypes)
      unless type.is_a?(GenericClassType)
        subtypes << type
      end
      type.subclasses.each do |subclass|
        collect_subtypes subclass, subtypes
      end
    end

    def to_s
      "#{base_type}+"
    end

    def name
      to_s
    end

    def union?
      true
    end

    def passed_by_val?
      true
    end
  end

  class HierarchyTypeMetaclass < Type
    include DefInstanceContainer
    include HierarchyTypeLookup

    getter program
    getter instance_type

    def initialize(@program, @instance_type)
    end

    delegate base_type, instance_type
    delegate cover, instance_type

    def lookup_first_def(name, yields)
      instance_type.base_type.metaclass.lookup_first_def(name, yields)
    end

    def hierarchy_lookup(type)
      type.metaclass
    end

    def hierarchy_metaclass?
      true
    end

    def lookup_macro(name, args_length)
      nil
    end

    def metaclass?
      true
    end

    def to_s
      "#{instance_type}:Class"
    end
  end

  class FunType < Type
    include DefContainer
    include DefInstanceContainer

    getter program
    getter fun_types

    def initialize(@program, @fun_types)
      args = arg_types.map_with_index { |type, i| Arg.new_with_type("arg#{i}", type) }
      add_def Def.new("call", args, Primitive.new(:fun_call, return_type))
      add_def Def.new("arity", ([] of Arg), NumberLiteral.new(fun_types.length - 1, :i32))
    end

    def arg_types
      fun_types[0 .. -2]
    end

    def return_type
      fun_types.last
    end

    def parents
      nil
    end

    def primitive_like?
      fun_types.all? &.primitive_like?
    end

    def fun_type?
      true
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end

    def to_s
      "#{arg_types.join ", "} -> #{return_type}"
    end
  end

  class PaddingType < Type
    getter padding
    getter program

    def initialize(@program, @padding)
    end

    def to_s
      "Padding#{@padding}"
    end
  end
end
