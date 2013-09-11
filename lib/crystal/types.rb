module Crystal
  class Type
    extend Forwardable
    include Enumerable

    @@type_id = 0

    def metaclass
      @metaclass ||= Metaclass.new(self)
    end

    def each
      yield self
    end

    def module?
      false
    end

    def class?
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

    def metaclass?
      false
    end

    def hierarchy_metaclass?
      false
    end

    def union?
      false
    end

    def nilable?
      false
    end

    def nil_type?
      false
    end

    def includes_type?(type)
      equal?(type)
    end

    def pointer?
      false
    end

    def hierarchy?
      false
    end

    def value?
      false
    end

    def integer?
      false
    end

    def float?
      false
    end

    def passed_as_self?
      true
    end

    def passed_by_val?
      false
    end

    def no_return?
      false
    end

    def primitive_like?
      false
    end

    def instance_type
      self
    end

    def implements?(other_type)
      equal?(other_type)
    end

    def filter_by(other_type)
      implements?(other_type) ? self : nil
    end

    def generic?
      false
    end

    def is_subclass_of?(type)
      equal?(type)
    end

    def allocated
      true
    end

    def cover
      self
    end

    def cover_length
      1
    end

    def llvm_name
      to_s
    end

    def type_desc
      to_s
    end

    def self.merge(*types)
      types = types.compact
      return nil if types.empty?
      types.first.program.type_merge(*types)
    end

    if ENV["PRINT_TYPES"] == "1"
      def type_id
        @type_id ||= begin
          type = (@@type_id += 1)
          puts "#{self}: #{type}"
          type
        end
      end
    else
      def type_id
        @type_id ||= (@@type_id += 1)
      end
    end
  end

  class NoReturnType < Type
    attr_reader :program

    def initialize(program)
      @program = program
    end

    def lookup_matches(*)
      Matches.new(nil, nil, nil, false)
    end

    def lookup_first_def(*)
      nil
    end

    def lookup_defs(*)
      []
    end

    def lookup_similar_defs(*)
      nil
    end

    def no_return?
      true
    end

    def primitive_like?
      true
    end

    def to_s
      "NoReturn"
    end
  end

  class ContainedType < Type
    attr_reader :container
    attr_reader :types

    def initialize(container)
      @container = container
      @types = {}
    end

    def program
      container.program
    end
  end

  module MatchesLookup
    def match_def_args(args, def_restrictions, owner, type_lookup)
      match = Match.new
      match.type_lookup = type_lookup
      0.upto(args.length - 1) do |i|
        arg_type = args[i]
        restriction = def_restrictions[i]

        match_arg_type = match_arg(arg_type, restriction, owner, type_lookup, match.free_vars) or return nil
        match.arg_types.push match_arg_type
      end
      match
    end

    def match_arg(arg_type, restriction, owner, type_lookup, free_vars)
      case restriction
      when nil
        arg_type
      when SelfType
        arg_type && arg_type.restrict(owner)
      when NewGenericClass
        if arg_type.is_a?(UnionType)
          arg_type.each do |arg_type2|
            if match_arg(arg_type2, restriction, owner, type_lookup, free_vars)
              return arg_type2
            end
          end
          nil
        elsif arg_type.is_a?(HierarchyType)
          raise "Matching #{arg_type} with #{restriction} is not supported yet"
        else
          arg_type && arg_type.generic? && match_generic_type(arg_type, restriction, owner, type_lookup, free_vars) && arg_type
        end
      when Ident
        type = free_vars[restriction.names]
        unless type
          if restriction.global
            type = program.lookup_type(restriction.names)
          else
            type = type_lookup.lookup_type(restriction.names)
          end
        end
        if type
          arg_type && arg_type.restrict(type)
        else
          free_vars[restriction.names] = arg_type
        end
      when IdentUnion
        matches = restriction.idents.map do |ident|
          match_arg(arg_type, ident, owner, type_lookup, free_vars)
        end
        matches.length > 0 ? program.type_merge(*matches) : nil
      when Type
        arg_type.is_restriction_of?(restriction, owner) && restriction
      end
    end

    def match_generic_type(arg_type, restriction, owner, type_lookup, free_vars)
      restriction_type = type_lookup.lookup_type(restriction.name.names)
      return false unless restriction_type
      return false unless arg_type.generic_class.equal?(restriction_type)
      return false unless arg_type.type_vars.length == restriction.type_vars.length

      arg_type.type_vars.each.with_index do |name_and_type_var, i|
        arg_type_var = name_and_type_var[1]
        restriction_var = restriction.type_vars[i]
        return false unless match_arg(arg_type_var.type, restriction_var, owner, type_lookup, free_vars)
      end
      true
    end

    def lookup_matches_without_parents(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      if defs = self.sorted_defs[[name, arg_types.length, yields]]
        matches_array ||= []
        defs.each do |a_def|
          def_restrictions = a_def.args.map(&:type_restriction)
          match = match_def_args(arg_types, def_restrictions, owner, type_lookup)
          if match
            match.def = a_def
            match.owner = owner
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
      matches_array ||= []

      matches = lookup_matches_without_parents(name, arg_types, yields, owner, type_lookup, matches_array)
      return matches unless matches.empty?

      if parents && !(name == 'new' && owner.metaclass?)
        parents.each do |parent|
          type_lookup = parent
          if parent.is_a?(IncludedGenericModule)
            type_lookup = parent
            parent_owner = owner
          elsif parent.module?
            parent_owner = owner
          else
            break
          end

          parent_matches = parent.lookup_matches_without_parents(name, arg_types, yields, parent_owner, type_lookup, matches.matches)
          return parent_matches unless parent_matches.empty?

          matches = parent_matches unless !parent_matches.matches || parent_matches.matches.empty?
        end
      end

      Matches.new(matches.matches, matches.cover, owner, false)
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self, matches_array = nil)
      matches_array ||= []

      matches = lookup_matches_without_parents(name, arg_types, yields, owner, type_lookup, matches_array)
      return matches if matches.cover_all?

      if parents && !(name == 'new' && owner.metaclass?)
        parents.each do |parent|
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
      defs = self.defs[name].values.select { |a_def| !!a_def.yields == yields }
      defs.length == 1 ? defs.first : nil
    end

    def lookup_defs(name)
      defs = self.defs[name]
      return defs.values unless defs.empty?

      parents.each do |parent|
        defs = parent.lookup_defs(name)
        return defs unless defs.empty?
      end

      []
    end

    def lookup_similar_defs(name, args_length, yields)
      return nil unless name =~ /\A[a-z_]/

      self.defs.each do |def_name, defs|
        next unless def_name =~ /\A[a-z_]/

        defs.each do |filter, overload|
          next if filter[0].length != args_length || filter[1] != yields

          if Levenshtein.distance(def_name.to_s, name.to_s) <= 2
            return def_name
          end
        end
      end

      parents.each do |parent|
        similar_def = parent.lookup_similar_defs(name, args_length, yields)
        return similar_def if similar_def
      end

      nil
    end

    def lookup_macro(name, args_length)
      if (macros = self.macros[name]) && (macro = macros[args_length])
        return macro
      end

      parents.each do |parent|
        macro = parent.lookup_macro(name, args_length)
        return macro if macro
      end

      nil
    end
  end

  module DefContainer
    include MatchesLookup

    def defs
      @defs ||= Hash.new { |h, k| h[k] = {} }
    end

    def sorted_defs
      @sorted_defs ||= Hash.new { |h, k| h[k] = [] }
    end

    def macros
      @macros ||= Hash.new { |h, k| h[k] = {} }
    end

    def add_def(a_def)
      a_def.owner = self if a_def.respond_to?(:owner=)
      restrictions = a_def.args.map(&:type_restriction)
      old_def = self.defs[a_def.name][[restrictions, !!a_def.yields]]
      self.defs[a_def.name][[restrictions, !!a_def.yields]] = a_def
      add_sorted_def(a_def, a_def.args.length)
      old_def
    end

    def add_sorted_def(a_def, args_length)
      sorted_defs = self.sorted_defs[[a_def.name, args_length, !!a_def.yields]]
      sorted_defs.each_with_index do |ex_def, i|
        if a_def.is_restriction_of?(ex_def, self)
          sorted_defs.insert(i, a_def)
          return
        end
      end
      sorted_defs << a_def
    end

    def add_macro(a_def)
      self.macros[a_def.name][a_def.args.length] = a_def
    end

    def filter_by_responds_to(name)
      has_def?(name) ? self : nil
    end

    def has_def?(name)
      self.defs.has_key?(name) || self.defs.has_key?(name.to_sym)
    end
  end

  module DefInstanceContainer
    def def_instances
      @def_instances ||= {}
    end

    def add_def_instance(def_object_id, arg_types, block_type, typed_def)
      def_instances[def_instance_key(def_object_id, arg_types, block_type)] = typed_def
    end

    def lookup_def_instance(def_object_id, arg_types, block_type)
      def_instances[def_instance_key(def_object_id, arg_types, block_type)]
    end

    def def_instance_key(def_object_id, arg_types, block_type)
      key = [def_object_id]
      key.concat arg_types.map(&:type_id)
      key.push block_type.type_id if block_type
      key
    end
  end

  class ModuleType < ContainedType
    include DefContainer

    attr_reader :name
    attr_reader :parents

    def initialize(container, name)
      super(container)
      @name = name
      @parents = []
    end

    def include(mod)
      parents.insert 0, mod unless parents.any? { |parent| parent.equal?(mod) }
    end

    def implements?(other_type)
      super || parents.any? { |parent| parent.implements?(other_type) }
    end

    def lookup_type(names, already_looked_up = {}, lookup_in_container = true)
      return nil if already_looked_up[type_id]

      if lookup_in_container
        already_looked_up[type_id] = true
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
      container && !container.is_a?(Program) ? "#{container}::#{name}" : name
    end

    def type_desc
      "module"
    end

    def to_s
      full_name
    end
  end

  class NonGenericModuleType < ModuleType
    include DefInstanceContainer

    def module?
      true
    end
  end

  module GenericType
    attr_reader :type_vars

    def generic_types
      @generic_types ||= {}
    end

    def instantiate(type_vars)
      key = type_vars.map(&:type_id)
      if (instance = generic_types[key])
        return instance
      end

      instance = instance_class.new(self, Hash[
        self.type_vars.zip(type_vars).map do |name, type|
          var = Var.new(name, type)
          var.bind_to var
          [name, var]
        end
      ])

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

    def initialize(container, name, type_vars)
      super(container, name)
      @type_vars = type_vars
    end

    def module?
      true
    end

    def to_s
      "#{super}(#{type_vars.join ', '})"
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
      @instance_vars ||= {}
    end

    def owns_instance_var?(name)
      owned_instance_vars.include?(name) || (superclass && superclass.owns_instance_var?(name))
    end

    def remove_instance_var(name)
      owned_instance_vars.delete(name)
      instance_vars.delete(name)
    end

    def lookup_instance_var(name, create = true)
      if superclass && (var = superclass.lookup_instance_var(name, false))
        return var
      end

      if create || owned_instance_vars.include?(name)
        instance_vars[name] ||= Var.new name
      else
        instance_vars[name]
      end
    end

    def index_of_instance_var(name)
      if superclass
        index = superclass.index_of_instance_var(name)
        if index
          index
        else
          index = instance_vars.keys.index(name)
          if index
            superclass.all_instance_vars_count + index
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
      if superclass
        superclass.all_instance_vars.merge(instance_vars)
      else
        instance_vars
      end
    end

    def all_instance_vars_count
      if superclass
        superclass.all_instance_vars_count + instance_vars.length
      else
        instance_vars.length
      end
    end

    def has_instance_var_in_initialize?(name)
      instance_vars_in_initialize && instance_vars_in_initialize.include?(name) || (superclass && superclass.has_instance_var_in_initialize?(name))
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end
  end

  module ClassVarContainer
    def class_vars
      @class_vars ||= {}
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
      superclass.notify_subclass_added if superclass
    end

    def add_subclass_observer(observer)
      @subclass_observers ||= []
      @subclass_observers << observer
    end

    def remove_subclass_observer(observer)
      @subclass_observers.delete(observer) if @subclass_observers
    end

    def notify_subclass_added
      if @subclass_observers
        @subclass_observers.each do |observer|
          observer.on_new_subclass
        end
      end
    end
  end

  class ClassType < ModuleType
    include InheritableClass

    attr_reader :superclass
    attr_reader :subclasses
    attr_reader :depth
    attr_reader :allocated
    attr_accessor :abstract
    attr_accessor :owned_instance_vars
    attr_accessor :instance_vars_in_initialize

    def initialize(container, name, superclass, add_subclass = true)
      super(container, name)
      if superclass
        @superclass = superclass
        @depth = superclass.depth + 1
      else
        @depth = 0
      end
      @subclasses = []
      @parents = [superclass] if superclass
      @owned_instance_vars = Set.new

      force_add_subclass if add_subclass
    end

    def force_add_subclass
      @superclass.add_subclass(self) if @superclass
    end

    def allocated=(allocated)
      @allocated = allocated
      superclass.allocated = allocated if superclass
    end

    def is_subclass_of?(type)
      super || (superclass && superclass.is_subclass_of?(type))
    end

    def add_def(a_def)
      super

      if a_def.instance_vars
        a_def.instance_vars.each do |ivar|
          unless superclass.owns_instance_var?(ivar)
            unless owned_instance_vars.include?(ivar)
              owned_instance_vars.add(ivar)
              each_subclass(self) do |subclass|
                subclass.remove_instance_var(ivar)
              end
            end
          end
        end

        if a_def.name == 'initialize'
          if @instance_vars_in_initialize
            @instance_vars_in_initialize = @instance_vars_in_initialize & a_def.instance_vars
          else
            @instance_vars_in_initialize = a_def.instance_vars
          end

          unless a_def.calls_super
            sup = superclass
            while sup
              sup.instance_vars_in_initialize &= a_def.instance_vars
              sup = sup.superclass
            end
          end
        end
      end

      a_def
    end

    def each_subclass(type, &block)
      type.subclasses.each do |subclass|
        block.call subclass
        each_subclass subclass, &block
      end
    end

    def type_desc
      "class"
    end
  end

  class NonGenericClassType < ClassType
    include InstanceVarContainer
    include ClassVarContainer
    include DefInstanceContainer

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(self)
        metaclass.add_def Def.new('allocate', [], Allocate.new)
        metaclass
      end
    end

    def hierarchy_type
      @hierarchy_type ||= HierarchyType.new(self)
    end

    def class?
      true
    end
  end

  class PrimitiveType < ClassType
    include DefInstanceContainer

    attr_reader :llvm_type
    attr_reader :llvm_size

    def initialize(container, name, superclass, llvm_type, llvm_size)
      super(container, name, superclass)
      @llvm_type = llvm_type
      @llvm_size = llvm_size
    end

    def allocated
      true
    end

    def value?
      true
    end

    def primitive_like?
      true
    end
  end

  class IntegerType < PrimitiveType
    attr_reader :rank

    def initialize(container, name, superclass, llvm_type, llvm_size, rank)
      super(container, name, superclass, llvm_type, llvm_size)
      @rank = rank
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
      8 * 2 ** ((@rank - 1) / 2)
    end

    def suffix
      signed? ? "i#{bits}" : "u#{bits}"
    end
  end

  class FloatType < PrimitiveType
    attr_reader :rank

    def initialize(container, name, superclass, llvm_type, llvm_size, rank)
      super(container, name, superclass, llvm_type, llvm_size)
      @rank = rank
    end

    def float?
      true
    end

    def suffix
      @rank == 9 ? "f32" : "f64"
    end
  end

  class NilType < PrimitiveType
    def nil_type?
      true
    end

    def type_id
      0
    end
  end

  class ValueType < NonGenericClassType
    def value?
      true
    end
  end

  class GenericClassType < ClassType
    include GenericType

    def initialize(container, name, superclass, type_vars, add_subclass = true)
      super(container, name, superclass, add_subclass)
      @type_vars = type_vars
    end

    def instance_class
      GenericClassInstanceType
    end

    def class?
      true
    end

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(self)
        metaclass.add_def Def.new('allocate', [], Allocate.new)
        metaclass
      end
    end

    def to_s
      "#{super}(#{type_vars.join ', '})"
    end
  end

  class GenericClassInstanceType < Type
    include InheritableClass
    include InstanceVarContainer
    include ClassVarContainer
    include DefInstanceContainer
    include MatchesLookup

    attr_reader :generic_class
    attr_reader :type_vars
    attr_reader :subclasses
    attr_accessor :allocated

    delegate [:program, :abstract, :superclass, :depth, :defs, :sorted_defs, :macros, :instance_vars_in_initialize, :owned_instance_vars] => :generic_class

    def initialize(generic_class, type_vars)
      @generic_class = generic_class
      @subclasses = []
      @type_vars = type_vars
    end

    def after_initialize
      @generic_class.superclass.add_subclass(self)
    end

    def hierarchy_type
      @hierarchy_type ||= HierarchyType.new(self)
    end

    def class?
      true
    end

    def generic?
      true
    end

    def metaclass
      @metaclass ||= GenericClassInstanceMetaclass.new(self)
    end

    def is_subclass_of?(type)
      super || generic_class.is_subclass_of?(type)
    end

    def implements?(other_type)
      super || generic_class.parents.any? { |parent| parent.implements?(other_type) }
    end

    def lookup_type(names, already_looked_up = {}, lookup_in_container = true)
      return nil if already_looked_up[type_id]
      already_looked_up[type_id] = true

      if names.length == 1 && type_var = type_vars[names[0]]
        return type_var.type
      end

      type = generic_class
      names.each do |name|
        type = type.types[name]
        break unless type
      end

      return type if type

      parents.each do |parent|
        match = parent.lookup_type(names, already_looked_up, false)
        return match if match
      end

      lookup_in_container && generic_class.container ? generic_class.container.lookup_type(names, already_looked_up) : nil
    end

    def parents
      generic_class.parents.map do |t|
        if t.is_a?(IncludedGenericModule)
          IncludedGenericModule.new(t.module, self, t.mapping)
        else
          t
        end
      end
    end

    def to_s
      "#{generic_class.full_name}(#{type_vars.values.map(&:type).join ', '})"
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

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end
  end

  class IncludedGenericModule < Type
    attr_reader :module
    attr_reader :including_class
    attr_reader :mapping

    delegate [:container, :name, :implements?, :lookup_matches, :lookup_matches_without_parents, :lookup_defs, :lookup_similar_defs, :match_arg, :lookup_macro, :parents] => :@module

    def initialize(a_module, a_class, mapping)
      @module = a_module
      @including_class = a_class
      @mapping = mapping
    end

    def lookup_type(names, already_looked_up = {}, lookup_in_container = true)
      if names.length == 1 && m = @mapping[names[0]]
        if m.is_a?(Type)
          return m
        end

        if @including_class.is_a?(GenericClassInstanceType)
          type_var = @including_class.type_vars[m[0]]
          return type_var ? type_var.type : nil
        end
      end

      @module.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def to_s
      "#{@module}(#{@including_class})"
    end
  end

  module MultiType
    def concrete_types
      types = []
      each_concrete_type do |type|
        types << type
      end
      types
    end
  end

  class UnionType < Type
    include MultiType

    attr_reader :types

    def initialize(*types)
      @types = types
    end

    def includes_type?(other_type)
      types.any? { |type| type.includes_type?(other_type) }
    end

    def program
      @types[0].program
    end

    def implements?(other_type)
      raise "'implements?' shouln't be invoked on a UnionType"
    end

    def metaclass
      self
    end

    def instance_type
      self
    end

    def cover
      types.map { |t| t.cover }.flatten
    end

    def cover_length
      sum = 0
      types.each { |t| sum += t.cover_length }
      sum
    end

    def filter_by(other_type)
      filtered_types = @types.map { |type| type.filter_by(other_type) }.compact
      case filtered_types.length
      when 0
        nil
      when 1
        filtered_types[0]
      else
        program.type_merge(*filtered_types)
      end
    end

    def filter_by_responds_to(name)
      filtered_types = @types.map { |type| type.filter_by_responds_to(name) }.compact
      case filtered_types.length
      when 0
        nil
      when 1
        filtered_types[0]
      else
        program.type_merge(*filtered_types)
      end
    end

    def has_def?(name)
      @types.any? { |type| type.has_def?(name) }
    end

    def nilable?
      @nilable ||= (@types.length == 2 &&
        (@types[0].nil_type? && types[1].class? && types[1] ||
         @types[1].nil_type? && types[0].class? && types[0]))
    end

    def nilable_type
      @nilable
    end

    def union?
      !nilable?
    end

    def passed_by_val?
      union?
    end

    def llvm_size
      @llvm_size ||= llvm_value_size + 4
    end

    def llvm_value_size
      @llvm_value_size ||= @types.map(&:llvm_size).max
    end

    def parents
      []
    end

    def each(&block)
      types.each(&block)
    end

    def each_concrete_type(&block)
      types.each do |type|
        if type.hierarchy?
          type.each(&block)
        else
          yield type
        end
      end
    end

    def to_s
      if nilable?
        "#{nilable_type}?"
      else
        types.join " | "
      end
    end
  end

  class Metaclass < Type
    include DefContainer
    include DefInstanceContainer

    attr_reader :instance_type

    delegate [:program, :lookup_type, :lookup_class_var, :has_class_var?, :class_var_owner, :abstract] => :instance_type

    def initialize(instance_type)
      @instance_type = instance_type
    end

    def parents
      instance_type.parents.map(&:metaclass)
    end

    def metaclass?
      true
    end

    def llvm_size
      4
    end

    def to_s
      "#{instance_type}:Class"
    end
  end

  class GenericClassInstanceMetaclass < Type
    include MatchesLookup
    include DefInstanceContainer

    attr_reader :instance_type

    delegate [:add_def, :defs, :sorted_defs, :macros] => :'instance_type.generic_class.metaclass'
    delegate [:program, :type_vars, :lookup_type, :abstract] => :'instance_type'

    def initialize(instance_type)
      @instance_type = instance_type
    end

    def metaclass?
      true
    end

    def parents
      instance_type.parents.map(&:metaclass)
    end

    def llvm_size
      4
    end

    def to_s
      "#{instance_type}:Class"
    end
  end

  class LibType < ModuleType
    attr_accessor :libname

    def initialize(container, name, libname = nil)
      super(container, name)
      @libname = libname
    end

    def metaclass
      self
    end

    def add_def(a_def)
      existing = defs[a_def.name]
      if existing.length > 0
        existing = existing.first[1]
        if existing.compatible_with?(a_def)
          return
        else
          raise "fun redefinition with different signature (was #{existing.to_s})"
        end
      end

      super
    end

    def add_var(name, type)
      arg = Arg.new_with_restriction('value', type)
      arg.set_type(type)

      setter = External.new("#{name}=", [arg], LibSet.new(name, type))
      setter.real_name = "*#{to_s}.#{name}="
      setter.owner = self
      setter.set_type(type)

      getter = External.new(name, [], LibGet.new(name, type))
      getter.real_name = "*#{to_s}.#{name}"
      getter.owner = self
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

    def to_s
      name
    end
  end

  class TypeDefType < ContainedType
    attr_accessor :name
    attr_accessor :typedef

    delegate [:llvm_name, :llvm_size, :pointer?, :lookup_matches, :lookup_first_def, :parents] => :typedef

    def initialize(container, name, typedef)
      super(container)
      @name = name
      @typedef = typedef
    end

    def primitive_like?
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

    attr_reader :name
    attr_reader :vars

    def initialize(container, name, vars)
      super(container)
      @name = name
      @vars = Hash[vars.map { |var| [var.name, var] }]
      @vars.values.each do |var|
        add_def Def.new("#{var.name}=", [Arg.new_with_restriction('value', var.type)], StructSet.new(var.name))
        add_def Def.new(var.name, [], StructGet.new(var.name))
      end
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self)
      # Convert name to String, because when using a keyword as a field it comes as s Symbol.
      super(name.to_s, arg_types, yields, owner, type_lookup)
    end

    def c_struct?
      true
    end

    def primitive_like?
      true
    end

    def parents
      []
    end

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(self)
        metaclass.add_def Def.new('new', [], StructAlloc.new(self))
        metaclass
      end
    end

    def llvm_name
      "struct.#{to_s}"
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end

    def index_of_var(name)
      @vars.keys.index(name)
    end

    def inspect
      return @to_s if @to_s
      @to_s = "..."
      vars_to_s = vars.map {|name, var| "#{name}: #{var.type}"}.join ', '
      @to_s = nil
      "#{container}::#{name}<#{vars_to_s}>"
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

    attr_reader :name
    attr_reader :vars

    def initialize(container, name, vars)
      super(container)
      @name = name
      @vars = Hash[vars.map { |var| [var.name, var] }]
      @vars.values.each do |var|
        add_def Def.new("#{var.name}=", [Arg.new_with_restriction('value', var.type)], UnionSet.new(var.name))
        add_def Def.new(var.name, [], UnionGet.new(var.name))
      end
    end

    def lookup_matches(name, arg_types, yields, owner = self, type_lookup = self)
      # Convert name to String, because when using a keyword as a field it comes as s Symbol.
      super(name.to_s, arg_types, yields, owner, type_lookup)
    end

    def c_union?
      true
    end

    def primitive_like?
      true
    end

    def parents
      []
    end

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(self)
        metaclass.add_def Def.new('new', [], UnionAlloc.new(self))
        metaclass
      end
    end

    def llvm_name
      "union.#{to_s}"
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end

    def inspect
      return @to_s if @to_s
      @to_s = "..."
      vars_to_s = vars.map {|name, var| "#{name}: #{var.type}"}.join ', '
      @to_s = nil
      "#{container}::#{name}<#{vars_to_s}>"
    end

    def type_desc
      "union"
    end

    def to_s
      "#{container}::#{name}"
    end
  end

  class CEnumType < ContainedType
    attr_reader :name
    attr_reader :base_type

    def initialize(container, name, constants)
      super(container)

      @name = name

      constants.each do |constant|
        @types[constant.name] = Const.new(self, constant.name, constant.default_value)
      end
    end

    def c_enum?
      true
    end

    def primitive_like?
      true
    end

    def parents
      []
    end

    def type_desc
      "enum"
    end

    def to_s
      "#{container}::#{name}"
    end
  end

  class Const < ContainedType
    attr_reader :name
    attr_reader :value
    attr_reader :types
    attr_reader :scope

    def initialize(container, name, value, types = nil, scope = nil)
      super(container)
      @name = name
      @value = value
      @types = types
      @scope = scope
    end

    def full_name
      container && !container.is_a?(Program) ? "#{container.to_s}::#{name}" : name
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
      concrete_classes = Array(cover())

      unless base_type_lookup.abstract && name == "allocate"
        base_type_matches = base_type_lookup.lookup_matches(name, arg_types, yields, self)
        if !base_type.abstract && !base_type_matches.cover_all?
          return Matches.new(base_type_matches.matches, base_type_matches.cover, base_type_lookup, false)
        end
      end

      all_matches = {}
      matches = (base_type_matches && base_type_matches.matches) || []

      instance_type.each_subtype(base_type) do |subtype|
        next if subtype.value?

        subtype_lookup = hierarchy_lookup(subtype)
        subtype_hierarchy_lookup = hierarchy_lookup(subtype.hierarchy_type)

        subtype_matches = subtype_lookup.lookup_matches_with_modules(name, arg_types, yields, subtype_hierarchy_lookup, subtype_hierarchy_lookup)
        concrete = concrete_classes.any? { |c| c.type_id == subtype.type_id }
        if concrete && !subtype_matches.cover_all? && !base_type_matches.cover_all?
          covered_by_superclass = false
          superclass = subtype.superclass
          while !superclass.equal?(base_type)
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

        if !subtype_matches.empty? && subtype_matches.matches
          subtype_matches.matches.concat matches
          matches = subtype_matches.matches
        end
      end

      Matches.new(matches, matches.length > 0)
    end

    def hierarchy_lookup(type)
      type
    end
  end

  class HierarchyType < Type
    include MultiType
    include DefInstanceContainer
    include HierarchyTypeLookup

    attr_accessor :base_type

    delegate [:lookup_first_def, :lookup_defs, :lookup_similar_defs, :lookup_instance_var, :index_of_instance_var, :lookup_macro,
              :lookup_type, :has_instance_var_in_initialize?, :allocated, :program, :metaclass,
              :abstract, :allocated=] => :base_type

    def initialize(base_type)
      @base_type = base_type
      @def_instances = {}
    end

    def metaclass
      @metaclass ||= HierarchyTypeMetaclass.new(self)
    end

    def immutable=(immutable)
      each do |type|
        type.immutable = immutable
      end
    end

    def hierarchy?
      true
    end

    def cover
      if base_type.abstract
        base_type.subclasses.map { |s| s.hierarchy_type.cover }.flatten
      else
        base_type
      end
    end

    def cover_length
      if base_type.abstract
        sum = 0
        base_type.subclasses.each { |s| sum += s.cover_length }
        sum
      else
        1
      end
    end

    def filter_by(type)
      restrict(type)
    end

    def each_concrete_type(&block)
      each(&block)
    end

    def each(&block)
      each2 base_type, &block
    end

    def each2(type, &block)
      # TODO: what if self is Object+ and we have Array(T)
      unless type.is_a?(GenericClassType)
        block.call type
      end
      each_subtype(type, &block)
    end

    def each_subtype(type, &block)
      type.subclasses.each do |subclass|
        each2 subclass, &block
      end
    end

    def subtypes
      subtypes = []
      each { |subtype| subtypes << subtype }
      subtypes
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

    def llvm_name
      to_s
    end

    def llvm_size
      4 + Crystal::Program::POINTER_SIZE
    end
  end

  class HierarchyTypeMetaclass < Type
    include DefInstanceContainer
    include HierarchyTypeLookup

    attr_reader :instance_type

    delegate [:base_type, :cover] => :instance_type
    delegate [:lookup_first_def] => :'instance_type.base_type.metaclass'

    def initialize(instance_type)
      @instance_type = instance_type
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

    def llvm_size
      4
    end

    def to_s
      "#{instance_type}:Class"
    end
  end

  class FunType < Type
    include DefContainer
    include DefInstanceContainer

    attr_reader :types

    def initialize(*types)
      @types = types
      add_def Def.new("call", [], FunCall.new(return_type))
    end

    def return_type
      types.last
    end

    def program
      return_type.program
    end

    def parents
      []
    end

    def to_s
      "-> #{types.last}"
    end
  end

end
