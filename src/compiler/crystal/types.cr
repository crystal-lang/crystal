require "levenshtein"
require "./syntax/ast"

module Crystal
  # Abstract base class of all types
  abstract class Type
    # Returns the program where this type belongs.
    getter program

    def initialize(@program : Program)
    end

    # Returns any doc comments associated to this type.
    def doc : String?
      nil
    end

    # Returns all locations where this type is declared
    def locations : Array(Location)?
      nil
    end

    # Returns `true` if this type has the give attribute.
    def has_attribute?(name)
      false
    end

    # An opaque id of every type. 0 for Nil, non zero for others, so we can
    # sort types by opaque_id and have Nil in the beginning.
    def opaque_id
      self.is_a?(NilType) ? 0_u64 : object_id
    end

    # The namespace this type belongs to. Every type belongs to
    # a namespace, and, when not explicit, the namespace is the `Program` itself.
    def namespace : ModuleType
      program
    end

    # Returns `true` if this type is abstract.
    def abstract?
      false
    end

    # Returns `true` if this type is a struct.
    def struct?
      false
    end

    # Returns `true` if this is an extern C struct or union (`extern_union?` tells which one)
    def extern?
      false
    end

    # Returns `true` if this is an extern C union (`extern?` will be `true` too)
    def extern_union?
      false
    end

    # Returns `true` if this type has the `@[Packed]` attribute on it
    # (only applicable for C structs)
    def packed?
      false
    end

    # Returns `true` if this type inherits from `Reference` or if this
    # is a union type where all types are reference types or nil.
    # In this case this type can be represented with a single pointer.
    def reference_like?
      case self
      when NilType, NilableType, NilableReferenceUnionType, ReferenceUnionType
        true
      when NonGenericClassType
        !self.struct?
      when GenericClassInstanceType
        !self.struct?
      when VirtualType
        !self.struct?
      else
        false
      end
    end

    # Returns the methods defined in this type, indexed by their name.
    # This does not include methods defined in ancestors.
    def defs : Hash(String, Array(DefWithMetadata))?
      nil
    end

    # Returns all macros defines in this type, indexed by their name.
    # This does not inlcude methods defined in ancestors.
    def macros : Hash(String, Array(Macro))?
      nil
    end

    # Returns this type's metaclass, which holds class methods for this type.
    getter metaclass : Type do
      metaclass = MetaclassType.new(program, self)
      initialize_metaclass(metaclass)
      metaclass
    end

    # Initializes a metaclass.
    # Some subtypes (classes) add an `allocate` method so a class can be instantiated.
    protected def initialize_metaclass(metaclass)
      # Nothing
    end

    # Returns `true` if this type can be used in a generic type argument.
    def allowed_in_generics?
      true
    end

    # Returns direct subclasses of this type.
    def subclasses : Array(Type)
      [] of Type
    end

    # Returns all subclasses of this type, including subclasses of
    # subclasses recursively.
    def all_subclasses
      subclasses = [] of Type
      append_subclasses(self, subclasses)
      subclasses
    end

    private def append_subclasses(type, subclasses)
      type.subclasses.each do |subclass|
        subclasses << subclass
        append_subclasses subclass, subclasses
      end
    end

    # Returns `true` if this type has no subclasses.
    def leaf?
      subclasses.size == 0
    end

    def class?
      false
    end

    def module?
      false
    end

    def metaclass?
      case self
      when MetaclassType, GenericClassInstanceMetaclassType, VirtualMetaclassType
        true
      else
        false
      end
    end

    def pointer?
      self.is_a?(PointerInstanceType)
    end

    def nil_type?
      self.is_a?(NilType)
    end

    def bool_type?
      self.is_a?(BoolType)
    end

    def no_return?
      self.is_a?(NoReturnType)
    end

    def virtual?
      self.is_a?(VirtualType)
    end

    def virtual_metaclass?
      self.is_a?(VirtualMetaclassType)
    end

    def proc?
      self.is_a?(ProcInstanceType)
    end

    def void?
      self.is_a?(VoidType)
    end

    def virtual_type
      self
    end

    def virtual_type!
      self
    end

    def instance_type
      self
    end

    def generic_class
      raise "Bug: #{self} doesn't implement generic_class"
    end

    def includes_type?(type)
      self == type
    end

    def remove_typedef
      self
    end

    def class_var_owner
      self
    end

    def has_in_type_vars?(type)
      false
    end

    def allows_instance_vars?
      case self
      when program.object, program.value,
           program.number, program.int, program.float,
           PrimitiveType, program.reference
        false
      else
        true
      end
    end

    # Should `new` be looked up in ancestors?
    #
    # This is `true` if this type doesn't define any
    # `initialize` methods.
    def lookup_new_in_ancestors?
      false
    end

    def devirtualize
      self.is_a?(VirtualTypeLookup) ? self.base_type : self
    end

    def implements?(other_type : Type)
      return true if self == other_type

      other_type = other_type.remove_alias
      case other_type
      when UnionType
        other_type.union_types.any? do |union_type|
          implements?(union_type)
        end
      when VirtualType
        implements?(other_type.base_type)
      when VirtualMetaclassType
        implements?(other_type.base_type.metaclass)
      else
        self == other_type
      end
    end

    def covariant?(other_type : Type)
      return true if self == other_type

      case other_type
      when UnionType
        other_type.union_types.any? do |union_type|
          covariant?(union_type)
        end
      else
        false
      end
    end

    def filter_by(other_type)
      restrict other_type, MatchContext.new(self, self, strict: true)
    end

    def filter_by_responds_to(name)
      nil
    end

    def add_instance_var_initializer(name, value, meta_vars)
      raise "Bug: #{self} doesn't implement add_instance_var_initializer"
    end

    def declare_instance_var(name, type_var)
      raise "Bug: #{self} doesn't implement declare_instance_var"
    end

    def types
      raise "Bug: #{self} has no types"
    end

    def types?
      nil
    end

    def parents
      nil
    end

    def ancestors
      ancestors = [] of Type
      collect_ancestors(ancestors)
      ancestors
    end

    protected def collect_ancestors(ancestors)
      parents.try &.each do |parent|
        ancestors << parent
        parent.collect_ancestors(ancestors)
      end
    end

    # Returns this type's superclass, or `nil` if it doesn't have one
    def superclass : Type?
      nil
    end

    def append_to_expand_union_types(types)
      types << self
    end

    def solve_type_vars(type_vars : Array(TypeVar))
      types = type_vars.map do |type_var|
        if type_var.is_a?(ASTNode)
          self.lookup_type(type_var).virtual_type
        else
          type_var
        end
      end
      Type.merge!(types)
    end

    def lookup_defs(name : String, lookup_ancestors_for_new : Bool = false)
      all_defs = [] of Def
      lookup_defs(name, all_defs, lookup_ancestors_for_new)
      all_defs
    end

    def lookup_defs(name : String, all_defs : Array(Def), lookup_ancestors_for_new : Bool? = false)
      self.defs.try &.[name]?.try &.each do |item|
        all_defs << item.def unless all_defs.find(&.same?(item.def))
      end

      if lookup_ancestors_for_new || self.lookup_new_in_ancestors? ||
         !(name == "new" || name == "initialize")
        parents.try &.each do |parent|
          parent.lookup_defs(name, all_defs, lookup_ancestors_for_new)
        end
      end
    end

    def lookup_defs_without_parents(name : String)
      all_defs = [] of Def
      lookup_defs_without_parents(name, all_defs)
      all_defs
    end

    def lookup_defs_without_parents(name : String, all_defs : Array(Def))
      self.defs.try &.[name]?.try &.each do |item|
        all_defs << item.def unless all_defs.find(&.same?(item.def))
      end
    end

    def lookup_defs_with_modules(name)
      if (list = self.defs.try &.[name]?) && !list.empty?
        return list.map(&.def)
      end

      parents.try &.each do |parent|
        next unless parent.module?

        parent_defs = parent.lookup_defs_with_modules(name)
        return parent_defs unless parent_defs.empty?
      end

      [] of Def
    end

    def lookup_first_def(name, block)
      block = !!block
      defs.try &.[name]?.try &.find(&.yields.==(block)).try &.def
    end

    def lookup_macro(name, args : Array, named_args)
      if macros = self.macros.try &.[name]?
        match = macros.find &.matches?(args, named_args)
        return match if match
      end

      instance_type.parents.try &.each do |parent|
        parent_macro = parent.metaclass.lookup_macro(name, args, named_args)
        return parent_macro if parent_macro
      end

      nil
    end

    def lookup_macros(name)
      if macros = self.macros.try &.[name]?
        return macros
      end

      parents.try &.each do |parent|
        parent_macros = parent.lookup_macros(name)
        return parent_macros if parent_macros
      end

      nil
    end

    def add_including_type(mod)
      raise "Bug: #{self} doesn't implement add_including_type"
    end

    def including_types
      raise "Bug: #{self} doesn't implement including_types"
    end

    def instance_vars
      raise "Bug: #{self} doesn't implement instance_vars"
    end

    def all_instance_vars
      raise "Bug: #{self} doesn't implement all_instance_vars"
    end

    def index_of_instance_var(name)
      raise "Bug: #{self} doesn't implement index_of_instance_var"
    end

    def index_of_instance_var?(name)
      raise "Bug: #{self} doesn't implement index_of_instance_var?"
    end

    def lookup_instance_var(name, create = true)
      raise "Bug: #{self} doesn't implement lookup_instance_var"
    end

    def lookup_instance_var?(name, create = false)
      raise "Bug: #{self} doesn't implement lookup_instance_var?"
    end

    def lookup_instance_var_with_owner(name)
      lookup_instance_var_with_owner?(name).not_nil!
    end

    def lookup_instance_var_with_owner?(name)
      raise "Bug: #{self} doesn't implement lookup_instance_var_with_owner?"
    end

    def has_instance_var_initializer?(name)
      false
    end

    def has_def?(name)
      defs.try(&.has_key?(name)) || parents.try(&.any?(&.has_def?(name)))
    end

    def all_instance_vars_count
      raise "Bug: #{self} doesn't implement all_instance_vars_count"
    end

    def add_subclass(subclass)
      raise "Bug: #{self} doesn't implement add_subclass"
    end

    def depth
      0
    end

    def type_desc
      to_s
    end

    def remove_alias
      self
    end

    def remove_alias_if_simple
      self
    end

    def remove_indirection
      self
    end

    def generic_nest
      0
    end

    def inspect(io)
      to_s(io)
    end

    def to_s(io)
      to_s_with_options(io)
    end

    abstract def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
  end

  # A type that has a name and can be inside a namespace.
  # For example in `Foo::Bar`, `Foo` is the namespace and `Bar` is the name.
  #
  # There are other types that have a name but it can be deduced from other(s) type(s),
  # so they don't inherit NamedType: a union type, a metaclass, etc.
  abstract class NamedType < Type
    getter namespace : ModuleType
    getter name : String
    getter locations : Array(Location)?
    property doc : String?

    def initialize(program, @namespace, @name)
      super(program)
    end

    # Adds a location to this type.
    def add_location(location : Location)
      locations = @locations ||= [] of Location
      locations << location
    end

    getter(types) { {} of String => NamedType }

    def types?
      @types
    end

    def append_full_name(io)
      unless namespace.is_a?(Program)
        namespace.to_s_with_options(io, generic_args: false)
        io << "::"
      end
      io << @name
    end

    def full_name
      String.build { |io| append_full_name(io) }
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      append_full_name(io)
    end
  end

  record NamedArgumentType, name : String, type : Type do
    def self.from_args(named_args : Array(NamedArgument)?)
      named_args.try &.map { |named_arg| new(named_arg.name, named_arg.value.type) }
    end
  end

  record CallSignature,
    name : String,
    arg_types : Array(Type),
    block : Block?,
    named_args : Array(NamedArgumentType)?

  # A Def with some metadata to speed up matching it against
  # a call signature, or against other defs:
  # - max_size: the maxinum number of arguments that can be passed to the method
  # - min_size: the minimum number of arguments that can be passed to the method
  # - yields: whether the method has a block
  record DefWithMetadata,
    min_size : Int32,
    max_size : Int32,
    yields : Bool,
    def : Def do
    def self.new(a_def : Def)
      min_size, max_size = a_def.min_max_args_sizes
      new min_size, max_size, !!a_def.yields, a_def
    end
  end

  record Hook, kind : Symbol, macro : Macro

  record DefInstanceKey,
    def_object_id : UInt64,
    arg_types : Array(Type),
    block_type : Type?,
    named_args : Array(NamedArgumentType)?

  module DefInstanceContainer
    getter(def_instances) { {} of DefInstanceKey => Def }

    def add_def_instance(key, typed_def)
      def_instances[key] = typed_def
    end

    def lookup_def_instance(key)
      def_instances[key]?
    end
  end

  abstract class ModuleType < NamedType
    getter defs : Hash(String, Array(DefWithMetadata))?
    getter macros : Hash(String, Array(Macro))?
    getter hooks : Array(Hook)?
    getter(parents) { [] of Type }

    def add_def(a_def)
      a_def.owner = self

      if a_def.visibility.public? && a_def.name == "initialize"
        a_def.visibility = Visibility::Protected
      end

      item = DefWithMetadata.new(a_def)

      defs = (@defs ||= {} of String => Array(DefWithMetadata))
      list = defs[a_def.name] ||= [] of DefWithMetadata
      list.each_with_index do |ex_item, i|
        if item.restriction_of?(ex_item, self)
          if ex_item.restriction_of?(item, self)
            list[i] = item
            a_def.previous = ex_item
            ex_item.def.next = a_def
            return ex_item.def
          else
            list.insert(i, item)
            return nil
          end
        end
      end
      list << item

      nil
    end

    def add_macro(a_def)
      case a_def.name
      when "inherited"
        return add_hook :inherited, a_def
      when "included"
        return add_hook :included, a_def
      when "extended"
        return add_hook :extended, a_def
      when "method_added"
        return add_hook :method_added, a_def, args_size: 1
      when "method_missing"
        if a_def.args.size != 1
          raise TypeException.new "macro 'method_missing' expects 1 argument (call)"
        end
      end

      macros = (@macros ||= {} of String => Array(Macro))
      array = (macros[a_def.name] ||= [] of Macro)
      index = array.index { |existing_macro| a_def.overrides?(existing_macro) }
      if index
        array[index] = a_def
      else
        array.push a_def
      end
    end

    def add_hook(kind, a_def, args_size = 0)
      if a_def.args.size != args_size
        case args_size
        when 0
          raise TypeException.new "macro '#{kind}' must not have arguments"
        when 1
          raise TypeException.new "macro '#{kind}' must have a argument"
        else
          raise TypeException.new "macro '#{kind}' must have #{args_size} arguments"
        end
      end

      hooks = @hooks ||= [] of Hook
      hooks << Hook.new(kind, a_def)
    end

    def filter_by_responds_to(name)
      has_def?(name) ? self : nil
    end

    def include(mod)
      if mod == self
        raise TypeException.new "cyclic include detected"
      else
        unless parents.includes?(mod)
          parents.insert 0, mod
          mod.add_including_type(self)
        end
      end
    end

    def implements?(other_type)
      other_type = other_type.remove_alias
      super || parents.any? &.implements?(other_type)
    end

    def covariant?(other_type)
      super || parents.any? &.covariant?(other_type)
    end

    def type_desc
      "module"
    end
  end

  module ClassVarContainer
    getter(class_vars) { {} of String => MetaTypeVar }

    def class_vars?
      @class_vars
    end

    def lookup_class_var(name)
      lookup_class_var?(name).not_nil!
    end

    def lookup_class_var?(name)
      class_var = @class_vars.try &.[name]?
      return class_var if class_var

      ancestors.each do |ancestor|
        next unless ancestor.is_a?(ClassVarContainer)

        class_var = ancestor.class_vars?.try &.[name]?
        if class_var
          var = MetaTypeVar.new(name, class_var.type)
          var.owner = self
          var.thread_local = class_var.thread_local?
          var.initializer = class_var.initializer
          var.bind_to(class_var)
          self.class_vars[name] = var
          return var
        end
      end

      nil
    end
  end

  module SubclassObservable
    def add_subclass_observer(observer)
      observers = (@subclass_observers ||= [] of Call)
      observers << observer
    end

    def remove_subclass_observer(observer)
      @subclass_observers.try &.delete(observer)
    end

    def notify_subclass_added
      @subclass_observers.try &.dup.each &.on_new_subclass
    end
  end

  module InstanceVarInitializerContainer
    class InstanceVarInitializer
      getter name : String
      property value : ASTNode
      getter meta_vars : MetaVars

      def initialize(@name, @value, @meta_vars)
      end
    end

    getter instance_vars_initializers : Array(InstanceVarInitializer)?

    def add_instance_var_initializer(name, value, meta_vars)
      initializers = @instance_vars_initializers ||= [] of InstanceVarInitializer
      initializer = InstanceVarInitializer.new(name, value, meta_vars)
      initializers << initializer
      initializer
    end

    def has_instance_var_initializer?(name)
      @instance_vars_initializers.try(&.any? { |init| init.name == name }) ||
        ancestors.any?(&.has_instance_var_initializer?(name))
    end
  end

  class NonGenericModuleType < ModuleType
    include ClassVarContainer
    include SubclassObservable

    def add_including_type(type)
      including_types = @including_types ||= [] of Type
      including_types.push type

      notify_subclass_added
    end

    def including_types
      if including_types = @including_types
        all_types = Array(Type).new(including_types.size)
        including_types.each do |including_type|
          add_to_including_types(including_type, all_types)
        end
        program.type_merge_union_of(all_types)
      else
        nil
      end
    end

    def raw_including_types
      @including_types
    end

    def append_to_expand_union_types(types)
      if including_types = @including_types
        including_types.each &.append_to_expand_union_types(types)
      else
        types << self
      end
    end

    def remove_indirection
      if including_types = self.including_types
        including_types.remove_indirection
      else
        self
      end
    end

    def add_to_including_types(type : GenericType, all_types)
      type.generic_types.each_value do |generic_type|
        all_types << generic_type unless all_types.includes?(generic_type)
      end
      type.subclasses.each do |subclass|
        add_to_including_types subclass, all_types
      end
    end

    def add_to_including_types(type, all_types)
      virtual_type = type.virtual_type
      all_types << virtual_type unless all_types.includes?(virtual_type)
    end

    def filter_by_responds_to(name)
      including_types.try &.filter_by_responds_to(name)
    end

    def module?
      true
    end

    getter(known_instance_vars) { Set(String).new }

    def declare_instance_var(name, var_type : Type)
      @including_types.try &.each do |type|
        case type
        when Program, FileModule
          # skip
        when NonGenericModuleType
          type.declare_instance_var(name, var_type)
        when NonGenericClassType
          type.declare_instance_var(name, var_type)
        end
      end
    end

    def add_instance_var_initializer(name, value, meta_vars)
      @including_types.try &.each do |type|
        case type
        when Program, FileModule
          # skip
        when NonGenericModuleType
          type.add_instance_var_initializer(name, value, meta_vars)
        when NonGenericClassType
          type.add_instance_var_initializer(name, value, meta_vars)
        end
      end
    end
  end

  # A module that is related to a file and contains its private defs.
  class FileModule < NonGenericModuleType
    include DefInstanceContainer

    getter(vars) { MetaVars.new }

    def vars?
      @vars
    end
  end

  abstract class ClassType < ModuleType
    include DefInstanceContainer
    include SubclassObservable
    include InstanceVarInitializerContainer

    setter metaclass : Type?
    getter superclass : Type?
    getter subclasses = [] of Type
    getter depth : Int32
    property? :abstract; @abstract = false
    property? :struct; @struct = false
    property? allowed_in_generics = true
    property? lookup_new_in_ancestors = false

    property? extern = false
    property? extern_union = false
    property? packed = false

    def initialize(program, namespace, name, @superclass, add_subclass = true)
      super(program, namespace, name)
      @depth = superclass ? (superclass.depth + 1) : 0
      parents.push superclass if superclass
      force_add_subclass if add_subclass
    end

    def add_subclass(subclass)
      subclasses << subclass
      notify_subclass_added

      superclass = superclass()
      while superclass.is_a?(SubclassObservable)
        superclass.notify_subclass_added
        superclass = superclass.superclass
      end
    end

    def force_add_subclass
      superclass.try &.add_subclass(self)
    end

    def struct?
      @struct
    end

    def has_attribute?(name)
      return true if packed? && name == "Packed"
      false
    end

    def type_desc
      case
      when extern? && extern_union?
        "union"
      when struct?
        "struct"
      else
        "class"
      end
    end
  end

  module InstanceVarContainer
    getter(instance_vars) { {} of String => MetaTypeVar }

    def lookup_instance_var(name, create = true)
      lookup_instance_var?(name, create).not_nil!
    end

    def lookup_instance_var?(name, create = false)
      if var = superclass.try &.lookup_instance_var?(name, false)
        return var
      end

      ivar = instance_vars[name]?
      if !ivar && create
        ivar = MetaTypeVar.new(name)
        ivar.owner = self
        instance_vars[name] = ivar
      end
      ivar
    end

    record InstanceVarWithOwner, instance_var : MetaTypeVar, owner : Type

    def lookup_instance_var_with_owner?(name)
      if result = superclass.try &.lookup_instance_var_with_owner?(name)
        return result
      end

      ivar = instance_vars[name]?
      if ivar
        InstanceVarWithOwner.new(ivar, self)
      else
        nil
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
          index = instance_vars.key_index(name)
          if index
            sup.all_instance_vars_count + index
          else
            nil
          end
        end
      else
        instance_vars.key_index(name)
      end
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
        sup.all_instance_vars_count + instance_vars.size
      else
        instance_vars.size
      end
    end
  end

  class NonGenericClassType < ClassType
    include InstanceVarContainer
    include ClassVarContainer

    protected def initialize_metaclass(metaclass)
      metaclass.add_def Def.new("allocate", body: Primitive.new("allocate"))
    end

    def virtual_type
      if leaf? && !abstract?
        self
      elsif struct? && abstract? && !leaf?
        virtual_type!
      elsif struct?
        self
      else
        virtual_type!
      end
    end

    def virtual_type!
      @virtual_type ||= VirtualType.new(program, self)
    end

    def class?
      true
    end

    def declare_instance_var(name, type : Type)
      ivar = lookup_instance_var(name)
      ivar.type = type
      ivar.bind_to ivar
      ivar.freeze_type = type
    end

    def declare_instance_var(name, type_vars : Array(TypeVar))
      type = solve_type_vars(type_vars)

      ivar = lookup_instance_var(name, create: true)
      ivar.type = type
      ivar.bind_to ivar
      ivar.freeze_type = type
    end

    def covariant?(other_type)
      other_type = other_type.base_type if other_type.is_a?(VirtualType)
      implements?(other_type) || super
    end

    def add_instance_var_initializer(name, value, meta_vars)
      super

      var = lookup_instance_var(name, true)
      var.bind_to(value)

      program.after_inference_types << self
    end
  end

  class PrimitiveType < ClassType
    include ClassVarContainer

    getter bytes : Int32

    def initialize(program, namespace, name, superclass, @bytes : Int32)
      super(program, namespace, name, superclass)
      self.struct = true
    end

    def abstract?
      false
    end
  end

  class BoolType < PrimitiveType
  end

  class CharType < PrimitiveType
  end

  class IntegerType < PrimitiveType
    getter rank : Int32
    getter kind : Symbol

    def initialize(program, namespace, name, superclass, bytes, @rank, @kind)
      super(program, namespace, name, superclass, bytes)
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
    getter rank : Int32

    def initialize(program, namespace, name, superclass, bytes, @rank)
      super(program, namespace, name, superclass, bytes)
    end

    def kind
      @bytes == 4 ? :f32 : :f64
    end
  end

  class SymbolType < PrimitiveType
  end

  class NilType < PrimitiveType
  end

  class NoReturnType < NamedType
    # NoReturn can be assigned to any other type (because it never will)
    def implements?(other_type)
      true
    end
  end

  class VoidType < NamedType
  end

  alias TypeVar = Type | ASTNode

  module GenericType
    getter type_vars : Array(String)
    property splat_index : Int32?
    property? double_variadic = false
    getter(generic_types) { {} of Array(TypeVar) => Type }

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      instance_type_vars = {} of String => ASTNode
      type_var_index = 0
      self.type_vars.each_with_index do |name, index|
        if splat_index == index
          types = [] of TypeVar
          (type_vars.size - (self.type_vars.size - 1)).times do
            types << type_vars[type_var_index]
            type_var_index += 1
          end
          var = Var.new(name, program.tuple_of(types))
          var.bind_to(var)
          instance_type_vars[name] = var
        else
          type_var = type_vars[type_var_index]
          case type_var
          when Type
            var = Var.new(name, type_var)
            var.bind_to var
            instance_type_vars[name] = var
          when ASTNode
            instance_type_vars[name] = type_var
          end
          type_var_index += 1
        end
      end

      instance = self.new_generic_instance(program, self, instance_type_vars)
      run_instance_vars_initializers self, self, instance

      generic_types[type_vars] = instance
      initialize_instance instance

      instance.after_initialize

      # Notify modules that an instance was added
      notify_parent_modules_subclass_added(self)

      instance
    end

    def notify_parent_modules_subclass_added(type)
      type.parents.try &.each do |parent|
        parent.notify_subclass_added if parent.is_a?(NonGenericModuleType)
        notify_parent_modules_subclass_added parent
      end
    end

    getter inherited : Array(Type)?

    def add_inherited(type)
      inherited = @inherited ||= [] of Type
      inherited << type
    end

    def add_instance_var_initializer(name, value, meta_vars)
      initializer = super

      # Make sure to type the initializer for existing instantiations
      generic_types.each_value do |instance|
        run_instance_var_initializer(initializer, instance)
      end

      @inherited.try &.each do |inherited|
        run_instance_var_initializer(initializer, inherited)
        if inherited.is_a?(GenericClassType)
          inherited.add_instance_var_initializer(name, value, meta_vars)
        end
      end

      initializer
    end

    def run_instance_vars_initializers(real_type, type : GenericClassType | ClassType, instance)
      if superclass = type.superclass
        run_instance_vars_initializers(real_type, superclass, instance)
      end

      type.instance_vars_initializers.try &.each do |initializer|
        run_instance_var_initializer initializer, instance
      end
    end

    def run_instance_vars_initializers(real_type, type : InheritedGenericClass, instance)
      run_instance_vars_initializers real_type, type.extended_class, instance
    end

    def run_instance_vars_initializers(real_type, type, instance)
      # Nothing
    end

    def run_instance_var_initializer(initializer, instance : GenericClassInstanceType | NonGenericClassType)
      meta_vars = MetaVars.new
      visitor = MainVisitor.new(program, vars: meta_vars, meta_vars: meta_vars)
      visitor.scope = instance
      value = initializer.value.clone
      value.accept visitor
      instance_var = instance.lookup_instance_var(initializer.name)
      instance_var.bind_to(value)
      instance.add_instance_var_initializer(initializer.name, value, meta_vars)
    end

    def run_instance_var_initializer(initializer, instance)
      # Nothing
    end

    def initialize_instance(instance)
      # Nothing
    end
  end

  class GenericModuleType < ModuleType
    include GenericType

    def initialize(program, namespace, name, @type_vars)
      super(program, namespace, name)
    end

    def module?
      true
    end

    def allowed_in_generics?
      false
    end

    def type_desc
      "generic module"
    end

    def add_including_type(type)
      including_types = @including_types ||= [] of Type
      including_types.push type
    end

    def raw_including_types
      @including_types
    end

    getter(known_instance_vars) { Set(String).new }

    getter declared_instance_vars : Hash(String, Array(TypeVar))?

    def declare_instance_var(name, type_var : TypeVar)
      declare_instance_var(name, [type_var] of TypeVar)
    end

    def declare_instance_var(name, type_vars : Array(TypeVar))
      declared_instance_vars = (@declared_instance_vars ||= {} of String => Array(TypeVar))
      declared_instance_vars[name] = type_vars

      @inherited.try &.each do |inherited|
        inherited.declare_instance_var(name, type_vars)
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      super
      if generic_args
        io << "("
        type_vars.each_with_index do |type_var, i|
          io << ", " if i > 0
          type_var.to_s(io)
        end
        io << ")"
      end
    end
  end

  class GenericClassType < ClassType
    include GenericType

    def initialize(program, namespace, name, superclass, @type_vars : Array(String), add_subclass = true)
      super(program, namespace, name, superclass, add_subclass)
    end

    def class?
      true
    end

    def allowed_in_generics?
      false
    end

    def new_generic_instance(program, generic_type, type_vars)
      GenericClassInstanceType.new program, generic_type, type_vars
    end

    getter(known_instance_vars) { Set(String).new }

    getter declared_instance_vars : Hash(String, Array(TypeVar))?

    def declare_instance_var(name, type_var : TypeVar)
      declare_instance_var(name, [type_var] of TypeVar)
    end

    def declare_instance_var(name, type_vars : Array(TypeVar))
      declared_instance_vars = (@declared_instance_vars ||= {} of String => Array(TypeVar))
      declared_instance_vars[name] = type_vars

      generic_types.each do |key, instance|
        instance.declare_instance_var(name, type_vars)
      end

      @inherited.try &.each do |inherited|
        inherited.declare_instance_var(name, type_vars)
      end
    end

    def initialize_instance(instance)
      if decl_ivars = @declared_instance_vars
        decl_ivars.each do |name, type_vars|
          type = instance.solve_type_vars(type_vars)

          ivar = MetaTypeVar.new(name, type)
          ivar.owner = instance
          ivar.bind_to ivar
          ivar.freeze_type = type
          instance.instance_vars[name] = ivar
        end
      end
    end

    protected def initialize_metaclass(metaclass)
      metaclass.add_def Def.new("allocate", body: Primitive.new("allocate"))
    end

    def type_desc
      struct? ? "generic struct" : "generic class"
    end

    def including_types
      instances = generic_types.values
      subclasses.each do |subclass|
        if subclass.is_a?(GenericClassType)
          subtypes = subclass.including_types
          instances << subtypes if subtypes
        else
          instances << subclass
        end
      end
      program.union_of instances
    end

    def remove_indirection
      if including_types = self.including_types
        including_types.remove_indirection
      else
        self
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      super
      if generic_args
        io << "("
        type_vars.each_with_index do |type_var, i|
          io << ", " if i > 0
          type_var.to_s(io)
        end
        io << ")"
      end
    end
  end

  class GenericClassInstanceType < Type
    include InstanceVarContainer
    include InstanceVarInitializerContainer
    include ClassVarContainer
    include DefInstanceContainer

    getter generic_class : GenericClassType
    getter type_vars : Hash(String, ASTNode)
    getter subclasses = [] of Type
    getter generic_nest : Int32

    def initialize(program, @generic_class, @type_vars, generic_nest = nil)
      super(program)
      @generic_nest = generic_nest || (1 + @type_vars.values.max_of { |node| node.type?.try(&.generic_nest) || 0 })
    end

    def after_initialize
      @generic_class.superclass.not_nil!.add_subclass(self)
    end

    def parents
      generic_class.parents.map do |t|
        case t
        when IncludedGenericModule
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        when InheritedGenericClass
          InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
        else
          t
        end
      end
    end

    def virtual_type
      self
    end

    delegate leaf?, depth, defs, superclass, macros, abstract?, struct?,
      type_desc, namespace, lookup_new_in_ancestors?,
      splat_index, double_variadic?, to: @generic_class

    def declare_instance_var(name, type_vars : Array(TypeVar))
      type = solve_type_vars(type_vars)

      ivar = MetaTypeVar.new(name, type)
      ivar.owner = self
      ivar.bind_to ivar
      ivar.freeze_type = type
      self.instance_vars[name] = ivar
    end

    def filter_by_responds_to(name)
      @generic_class.filter_by_responds_to(name) ? self : nil
    end

    def class?
      true
    end

    getter(metaclass) { GenericClassInstanceMetaclassType.new(self.program, self) }

    def implements?(other_type)
      other_type = other_type.remove_alias
      super || generic_class.implements?(other_type)
    end

    def covariant?(other_type)
      if other_type.is_a?(GenericClassInstanceType)
        super
      else
        implements?(other_type)
      end
    end

    def has_in_type_vars?(type)
      type_vars.each_value do |type_var|
        case type_var
        when Var
          return true if type_var.type.includes_type?(type) || type_var.type.has_in_type_vars?(type)
        when Type
          return true if type_var.includes_type?(type) || type_var.has_in_type_vars?(type)
        end
      end
      false
    end

    def add_instance_var_initializer(name, value, meta_vars)
      super

      program.after_inference_types << self
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      generic_class.append_full_name(io)
      io << "("
      i = 0
      type_vars.each_value do |type_var|
        io << ", " if i > 0
        if type_var.is_a?(Var)
          if i == splat_index
            tuple = type_var.type.as(TupleInstanceType)
            tuple.tuple_types.each_with_index do |tuple_type, j|
              io << ", " if j > 0
              tuple_type = tuple_type.devirtualize unless codegen
              tuple_type.to_s_with_options(io, codegen: codegen)
            end
          else
            type_var_type = type_var.type
            type_var_type = type_var_type.devirtualize unless codegen
            type_var_type.to_s_with_options(io, skip_union_parens: true, codegen: codegen)
          end
        else
          type_var.to_s(io)
        end
        i += 1
      end
      io << ")"
    end
  end

  class PointerType < GenericClassType
    def new_generic_instance(program, generic_type, type_vars)
      PointerInstanceType.new program, generic_type, type_vars
    end

    def type_desc
      "generic struct"
    end
  end

  class PointerInstanceType < GenericClassInstanceType
    def var
      type_vars["T"]
    end

    def element_type
      var.type
    end

    def type_desc
      "struct"
    end
  end

  class StaticArrayType < GenericClassType
    def new_generic_instance(program, generic_type, type_vars)
      n = type_vars["N"]
      unless n.is_a?(NumberLiteral)
        raise TypeException.new "can't instantiate StaticArray(T, N) with N = #{n.type} (N must be an integer)"
      end

      value = n.value.to_i
      if value < 0
        raise TypeException.new "can't instantiate StaticArray(T, N) with N = #{value} (N must be positive)"
      end

      StaticArrayInstanceType.new program, generic_type, type_vars
    end
  end

  class StaticArrayInstanceType < GenericClassInstanceType
    def var
      type_vars["T"]
    end

    def size
      type_vars["N"]
    end

    def element_type
      var.type
    end
  end

  class TupleType < GenericClassType
    @splat_index = 0
    @struct = true

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      types = type_vars.map do |type_var|
        unless type_var.is_a?(Type)
          type_var.raise "argument to Tuple must be a type, not #{type_var}"
        end
        type_var
      end
      instance = TupleInstanceType.new(program, types)
      generic_types[type_vars] = instance
      initialize_instance instance
      instance.after_initialize
      instance
    end

    def new_generic_instance(program, generic_type, type_vars)
      raise "Bug: TupleType#new_generic_instance shouldn't be invoked"
    end

    def type_desc
      "tuple"
    end
  end

  class TupleInstanceType < GenericClassInstanceType
    getter tuple_types : Array(Type)

    def initialize(program, @tuple_types)
      generic_nest = 1 + (@tuple_types.empty? ? 0 : @tuple_types.max_of(&.generic_nest))
      var = Var.new("T", self)
      var.bind_to var
      super(program, program.tuple, {"T" => var} of String => ASTNode, generic_nest)
    end

    def tuple_indexer(index)
      indexers = @tuple_indexers ||= {} of Int32 => Def
      tuple_indexer(indexers, index)
    end

    def tuple_metaclass_indexer(index)
      indexers = @tuple_metaclass_indexers ||= {} of Int32 => Def
      tuple_indexer(indexers, index)
    end

    def size
      tuple_types.size
    end

    private def tuple_indexer(indexers, index)
      indexers[index] ||= begin
        body = index == -1 ? NilLiteral.new : TupleIndexer.new(index)
        indexer = Def.new("[]", [Arg.new("index")], body)
        indexer.owner = self
        indexer
      end
    end

    def implements?(other : Type)
      return true if self == other

      if other.is_a?(TupleInstanceType)
        return false unless self.size == other.size

        tuple_types.zip(other.tuple_types) do |self_tuple_type, other_tuple_type|
          return false unless self_tuple_type.implements?(other_tuple_type)
        end

        return true
      end

      super
    end

    def var
      type_vars["T"]
    end

    def has_in_type_vars?(type)
      tuple_types.any? { |tuple_type| tuple_type.includes_type?(type) || tuple_type.has_in_type_vars?(type) }
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      io << "Tuple("
      @tuple_types.each_with_index do |tuple_type, i|
        io << ", " if i > 0
        tuple_type = tuple_type.devirtualize unless codegen
        tuple_type.to_s_with_options(io, skip_union_parens: true, codegen: codegen)
      end
      io << ")"
    end

    def type_desc
      "tuple"
    end
  end

  class NamedTupleType < GenericClassType
    @struct = true
    @double_variadic = true
    @instantiations = {} of Array(NamedArgumentType) => Type

    def instantiate(type_vars)
      raise "can't instantiate NamedTuple type yet"
    end

    def instantiate_named_args(entries : Array(NamedArgumentType))
      @instantiations[entries] ||= NamedTupleInstanceType.new(program, entries)
    end

    def new_generic_instance(program, generic_type, type_vars)
      raise "Bug: NamedTupleType#new_generic_instance shouldn't be invoked"
    end

    def type_desc
      "named tuple"
    end
  end

  class NamedTupleInstanceType < GenericClassInstanceType
    getter entries

    def initialize(program, @entries : Array(NamedArgumentType))
      generic_nest = 1 + (@entries.empty? ? 0 : @entries.max_of(&.type.generic_nest))
      var = Var.new("T", self)
      var.bind_to var
      super(program, program.named_tuple, {"T" => var} of String => ASTNode, generic_nest)
    end

    def name_index(name)
      @entries.index &.name.==(name)
    end

    def name_type(name)
      @entries.find(&.name.==(name)).not_nil!.type
    end

    def tuple_indexer(index)
      indexers = @tuple_indexers ||= {} of Int32 => Def
      tuple_indexer(indexers, index)
    end

    private def tuple_indexer(indexers, index)
      indexers[index] ||= begin
        body = index == -1 ? NilLiteral.new : TupleIndexer.new(index)
        indexer = Def.new("[]", [Arg.new("index")], body)
        indexer.owner = self
        indexer
      end
    end

    def implements?(other)
      if other.is_a?(NamedTupleInstanceType)
        return nil unless self.size == other.size

        self_entries = self.entries.sort_by &.name
        other_entries = other.entries.sort_by &.name

        self_entries.zip(other_entries) do |self_entry, other_entry|
          return nil unless self_entry.name == other_entry.name
          return nil unless self_entry.type.implements?(other_entry.type)
        end

        self
      else
        super
      end
    end

    def size
      entries.size
    end

    def var
      type_vars["T"]
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      io << "NamedTuple("
      @entries.each_with_index do |entry, i|
        io << ", " if i > 0
        if Symbol.needs_quotes?(entry.name)
          entry.name.inspect(io)
        else
          io << entry.name
        end
        io << ": "
        entry_type = entry.type
        entry_type = entry_type.devirtualize unless codegen
        entry_type.to_s_with_options(io, skip_union_parens: true, codegen: codegen)
      end
      io << ")"
    end

    def type_desc
      "tuple"
    end
  end

  class IncludedGenericModule < Type
    getter module : GenericModuleType
    getter including_class : Type
    getter mapping : Hash(String, ASTNode)

    def initialize(program, @module, @including_class, @mapping)
      super(program)
    end

    def add_including_type(type)
      @module.add_including_type type
    end

    delegate namespace, name, defs, macros, implements?, lookup_defs,
      lookup_defs_with_modules, lookup_macro, lookup_macros, has_def?,
      metaclass, to: @module

    def parents
      @module.parents.map do |t|
        case t
        when IncludedGenericModule
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        when InheritedGenericClass
          InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
        else
          t
        end
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      @module.to_s(io)
      io << "("
      @including_class.to_s(io)
      io << ")"
      io << @mapping
    end
  end

  class InheritedGenericClass < Type
    getter extended_class : Type
    property! extending_class : Type
    getter mapping : Hash(String, ASTNode)

    def initialize(program, @extended_class, @mapping, @extending_class = nil)
      super(program)
    end

    getter(metaclass) { InheritedGenericClass.new(@program, @extended_class.metaclass, @mapping, @extending_class) }

    def type_vars
      mapping.keys
    end

    delegate depth, superclass, add_subclass, namespace, name,
      defs, macros, implements?, lookup_defs, lookup_defs_with_modules,
      lookup_macro, lookup_macros, has_def?,
      notify_subclass_added, to: @extended_class

    def lookup_instance_var?(name, create = false)
      nil
    end

    def lookup_instance_var_with_owner?(name)
      nil
    end

    def all_instance_vars
      {} of String => Var
    end

    def index_of_instance_var?(name)
      nil
    end

    def all_instance_vars_count
      0
    end

    def parents
      @extended_class.parents.try &.map do |t|
        case t
        when IncludedGenericModule
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        when InheritedGenericClass
          InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
        else
          t
        end
      end
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      @extended_class.to_s(io)
      io << "("
      @extending_class.to_s(io)
      io << ")"
      io << @mapping
    end
  end

  class LibType < ModuleType
    getter link_attributes : Array(LinkAttribute)?
    property? used = false

    def add_link_attributes(link_attributes)
      if link_attributes
        my_link_attributes = @link_attributes ||= [] of LinkAttribute
        link_attributes.each do |attr|
          my_link_attributes << attr unless my_link_attributes.includes?(attr)
        end
      end
    end

    def metaclass
      self
    end

    def add_var(name, type, real_name, thread_local)
      setter = External.new("#{name}=", [Arg.new("value", type: type)], Primitive.new("external_var_set", type), real_name)
      setter.set_type(type)
      setter.thread_local = thread_local

      getter = External.new("#{name}", [] of Arg, Primitive.new("external_var_get", type), real_name)
      getter.set_type(type)
      getter.thread_local = thread_local

      add_def setter
      add_def getter
    end

    def type_desc
      "lib"
    end
  end

  class TypeDefType < NamedType
    include DefInstanceContainer

    getter typedef : Type

    def initialize(program, namespace, name, @typedef)
      super(program, namespace, name)
    end

    delegate remove_typedef, remove_indirection, pointer?, defs,
      macros, reference_link?, to: typedef

    def parents
      # We need to repoint "self" in included generic modules to this typedef,
      # so "self" restrictions match and don't point to the typdefed type.
      typedef_parents = typedef.parents.try(&.dup) || [] of Type

      if typedef_parents
        typedef_parents.each_with_index do |t, i|
          case t
          when IncludedGenericModule
            typedef_parents[i] = IncludedGenericModule.new(program, t.module, self, t.mapping)
          when InheritedGenericClass
            typedef_parents[i] = InheritedGenericClass.new(program, t.extended_class, t.mapping, self)
          end
        end
      end

      typedef_parents
    end

    def type_def_type?
      true
    end

    def type_desc
      "type def"
    end
  end

  class AliasType < NamedType
    getter? value_processed = false
    property! aliased_type : Type

    def initialize(program, namespace, name, @value : ASTNode)
      super(program, namespace, name)
      @simple = true
    end

    delegate lookup_defs, lookup_defs_with_modules, lookup_first_def,
      lookup_macro, lookup_macros, types, types?, to: aliased_type

    def remove_alias
      process_value
      if aliased_type = @aliased_type
        aliased_type.remove_alias
      else
        @simple = false
        self
      end
    end

    def remove_alias_if_simple
      process_value
      @simple ? remove_alias : self
    end

    def remove_indirection
      process_value
      if aliased_type = @aliased_type
        aliased_type.remove_indirection
      else
        @simple = false
        self
      end
    end

    def allowed_in_generics?
      process_value
      if aliased_type = @aliased_type
        aliased_type.remove_alias.allowed_in_generics?
      else
        true
      end
    end

    def process_value
      return if @value_processed
      @value_processed = true
      @aliased_type = namespace.lookup_type(@value, allow_typeof: false)
    end

    def includes_type?(other)
      remove_indirection.includes_type?(other)
    end

    def type_desc
      "alias"
    end
  end

  class EnumType < ModuleType
    include DefInstanceContainer
    include ClassVarContainer

    getter base_type : IntegerType
    getter? flags : Bool

    def initialize(program, namespace, name, @base_type, flags)
      super(program, namespace, name)

      @flags = !!flags

      add_def Def.new("value", [] of Arg, Primitive.new("enum_value", @base_type))
      metaclass.as(ModuleType).add_def Def.new("new", [Arg.new("value", type: @base_type)], Primitive.new("enum_new", self))
    end

    def parents
      @parents ||= [program.enum] of Type
    end

    def add_constant(constant)
      types[constant.name] = const = Const.new(program, self, constant.name, constant.default_value.not_nil!)
      program.class_var_and_const_initializers << const
      const
    end

    def has_attribute?(name)
      return true if flags? && name == "Flags"
      false
    end

    def lookup_new_in_ancestors?
      true
    end

    def type_desc
      "enum"
    end
  end

  class MetaclassType < ClassType
    include ClassVarContainer
    include InstanceVarContainer

    getter program : Program
    getter instance_type : Type

    def initialize(@program, @instance_type : Type, super_class = nil, name = nil)
      super_class ||= if instance_type.is_a?(ClassType) && instance_type.superclass
                        instance_type.superclass.not_nil!.metaclass
                      elsif instance_type.is_a?(EnumType)
                        @program.enum.metaclass
                      else
                        @program.class_type
                      end
      unless name
        if instance_type.module?
          name = "#{@instance_type}:Module"
        else
          name = "#{@instance_type}:Class"
        end
      end
      super(@program, @program, name, super_class)
    end

    def metaclass
      @program.class_type
    end

    delegate abstract?, generic_nest, lookup_new_in_ancestors?, to: instance_type

    def class_var_owner
      instance_type
    end

    def virtual_type
      instance_type.virtual_type.metaclass
    end

    def virtual_type!
      instance_type.virtual_type!.metaclass
    end

    def remove_typedef
      if instance_type.is_a?(TypeDefType)
        return instance_type.remove_typedef.metaclass
      end
      self
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      io << @name
    end
  end

  class GenericClassInstanceMetaclassType < Type
    include DefInstanceContainer

    getter instance_type : Type

    def initialize(program, @instance_type)
      super(program)
    end

    @parents : Array(Type)?

    def parents
      @parents ||= begin
        parents = [] of Type
        parents << (instance_type.superclass.try(&.metaclass) || @program.class_type)
        parents
      end
    end

    delegate defs, macros, to: instance_type.generic_class.metaclass
    delegate type_vars, abstract?, generic_nest, lookup_new_in_ancestors?, to: instance_type

    def class_var_owner
      instance_type
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      instance_type.to_s(io)
      io << ":Class"
    end
  end

  module MultiType
    def concrete_types
      types = [] of Type
      each_concrete_type { |type| types << type }
      types
    end

    def union_types
      union_types = program.type_merge_union_of(concrete_types)
      union_types || base_type
    end
  end

  class GenericUnionType < GenericClassType
    @splat_index = 0
    @struct = true

    def instantiate(type_vars)
      types = type_vars.map do |type_var|
        unless type_var.is_a?(Type)
          type_var.raise "argument to Proc must be a type, not #{type_var}"
        end
        type_var
      end
      program.type_merge(types) || program.no_return
    end

    def new_generic_instance(program, generic_type, type_vars)
      raise "Bug: GenericUnionType#new_generic_instance shouldn't be invoked"
    end

    def type_desc
      "union"
    end
  end

  # Base class for union types.
  abstract class UnionType < Type
    include MultiType

    getter union_types : Array(Type)

    def initialize(program, @union_types)
      super(program)
    end

    def parents
      @parents ||= [@program.value] of Type
    end

    def superclass
      @program.value
    end

    def generic_class
      @program.union
    end

    def metaclass
      @metaclass ||= GenericClassInstanceMetaclassType.new(program, self)
    end

    def generic_nest
      union_types.max_of &.generic_nest
    end

    def includes_type?(other_type)
      union_types.any? &.includes_type?(other_type)
    end

    def covariant?(other_type)
      union_types.all? &.covariant? other_type
    end

    def filter_by_responds_to(name)
      filtered_types = union_types.compact_map &.filter_by_responds_to(name)
      program.type_merge_union_of filtered_types
    end

    def each_concrete_type
      union_types.each do |type|
        if type.is_a?(VirtualType)
          type.subtypes.each do |subtype|
            yield subtype
          end
        else
          yield type
        end
      end
    end

    def virtual_type
      if union_types.any? { |t| t.virtual_type != t }
        program.type_merge(union_types.map(&.virtual_type)).not_nil!
      else
        self
      end
    end

    def expand_union_types
      if union_types.any?(&.is_a?(NonGenericModuleType))
        types = [] of Type
        union_types.each &.append_to_expand_union_types(types)
        types
      else
        union_types
      end
    end

    def implements?(other_type : Type)
      other_type = other_type.remove_alias
      self == other_type || union_types.all?(&.implements?(other_type))
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      io << "(" unless skip_union_parens
      union_types = @union_types
      # Make sure to put Nil at the end
      if nil_type_index = @union_types.index(&.nil_type?)
        union_types = @union_types.dup
        union_types << union_types.delete_at(nil_type_index)
      end
      union_types.each_with_index do |type, i|
        io << " | " if i > 0
        type = type.devirtualize unless codegen
        type.to_s_with_options(io, codegen: codegen)
      end
      io << ")" unless skip_union_parens
    end

    def type_desc
      "union"
    end
  end

  # A union type that has two types: Nil and another Reference type.
  # Can be represented as a maybe-null pointer where the type id
  # of the type that is not nil is known at compile time.
  class NilableType < UnionType
    def initialize(@program, not_nil_type)
      super(@program, [@program.nil, not_nil_type] of Type)
    end

    def not_nil_type
      @union_types.last
    end
  end

  # A union type that has Nil and other reference-like types.
  # Can be represented as a maybe-null pointer but the type id is
  # not known at compile time.
  class NilableReferenceUnionType < UnionType
  end

  # A union type that doesn't have nil, and all types are reference-like.
  # Can be represented as a never-null pointer.
  class ReferenceUnionType < UnionType
  end

  # A union type of nil and a single function type.
  class NilableProcType < UnionType
    def initialize(@program, proc_type)
      super(@program, [@program.nil, proc_type] of Type)
    end

    def proc_type
      @union_types.last.remove_typedef.as(ProcInstanceType)
    end
  end

  # A union type of nil and a single pointer type.
  class NilablePointerType < UnionType
    def initialize(@program, pointer_type)
      super(@program, [@program.nil, pointer_type] of Type)
    end

    def pointer_type
      @union_types.last.remove_typedef.as(PointerInstanceType)
    end
  end

  # A union type that doesn't match any of the previous definitions,
  # so it can contain Nil with primitive types, or Reference types with
  # primitives types.
  # Must be represented as a union.
  class MixedUnionType < UnionType
  end

  class Const < NamedType
    property value : ASTNode
    property vars : MetaVars?
    property? used = false
    property? visited = false
    property visitor : MainVisitor?

    def initialize(program, namespace, name, @value)
      super(program, namespace, name)
    end

    def type_desc
      "constant"
    end
  end

  module VirtualTypeLookup
    def filter_by_responds_to(name)
      filtered = virtual_lookup(base_type).filter_by_responds_to(name)
      return filtered.virtual_type if filtered

      result = [] of Type
      collect_filtered_by_responds_to(name, base_type, result)
      program.type_merge_union_of(result)
    end

    def collect_filtered_by_responds_to(name, type, result)
      type.subclasses.each do |subclass|
        unless subclass.is_a?(GenericClassType)
          filtered = virtual_lookup(subclass).filter_by_responds_to(name)
          if filtered
            result << virtual_lookup(subclass).virtual_type
            next
          end
        end

        collect_filtered_by_responds_to(name, subclass, result)
      end
    end
  end

  # A virtual type represents a type or any of its subclasses. It's created
  # automatically by the compiler when a type is used in a generic argument
  # and it either has subtypes, or it's abstract. A virtual type never exists
  # for a non-abstract type that doesn't have subtypes.
  #
  # A virtual type is denoted, internally, with a '+' sign following the type.
  #
  # ```
  # class Foo
  # end
  #
  # class Bar < Foo
  # end
  #
  # # Here the compiler actually makes this be [] of Foo+, so the array
  # # can actually hold a Foo or a Bar, transparently.
  # ary = [] of Foo
  #
  # # Here the compiler leaves it as [] of Bar, because Bar has no subclasses.
  # another = [] of Bar
  # ```
  class VirtualType < Type
    include MultiType
    include DefInstanceContainer
    include VirtualTypeLookup
    include InstanceVarContainer
    include ClassVarContainer

    getter base_type : NonGenericClassType

    def initialize(program, @base_type)
      super(program)
    end

    delegate leaf?, superclass, lookup_first_def, lookup_defs,
      lookup_defs_with_modules, lookup_instance_var, lookup_instance_var?,
      lookup_instance_var_with_owner, lookup_instance_var_with_owner?,
      index_of_instance_var, lookup_macro, lookup_macros, all_instance_vars,
      abstract?, implements?, covariant?, ancestors, struct?, to: base_type

    def remove_indirection
      if struct?
        union_types
      else
        self
      end
    end

    def metaclass
      @metaclass ||= VirtualMetaclassType.new(program, self)
    end

    def each_concrete_type
      subtypes.each do |subtype|
        yield subtype unless subtype.abstract?
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

    def lookup_class_var?(name)
      class_var = @class_vars.try &.[name]?
      return class_var if class_var

      class_var = base_type.lookup_class_var?(name)
      if class_var
        var = MetaTypeVar.new(name, class_var.type)
        var.owner = self
        var.thread_local = class_var.thread_local?
        var.initializer = class_var.initializer
        var.bind_to(class_var)
        self.class_vars[name] = var
        return var
      end

      nil
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      base_type.to_s(io)
      io << "+"
    end

    def name
      to_s
    end
  end

  class VirtualMetaclassType < Type
    include DefInstanceContainer
    include VirtualTypeLookup
    include ClassVarContainer

    getter instance_type : VirtualType

    def initialize(program, @instance_type)
      super(program)
    end

    def parents
      @parents ||= [instance_type.superclass.try(&.metaclass) || @program.class_type] of Type
    end

    def leaf?
      instance_type.leaf?
    end

    delegate base_type, lookup_first_def, to: instance_type

    def each_concrete_type
      instance_type.subtypes.each do |type|
        yield type.metaclass
      end
    end

    def lookup_class_var?(name)
      class_var = @class_vars.try &.[name]?
      return class_var if class_var

      class_var = base_type.instance_type.lookup_class_var?(name)
      if class_var
        var = MetaTypeVar.new(name, class_var.type)
        var.owner = self
        var.thread_local = class_var.thread_local?
        var.initializer = class_var.initializer
        var.bind_to(class_var)
        self.class_vars[name] = var
        return var
      end

      nil
    end

    def implements?(other : VirtualMetaclassType)
      base_type.implements?(other.base_type)
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      instance_type.to_s_with_options(io, codegen: codegen)
      io << ":Class"
    end
  end

  class ProcType < GenericClassType
    @splat_index = 0
    @struct = true

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      types = type_vars.map do |type_var|
        unless type_var.is_a?(Type)
          type_var.raise "argument to Proc must be a type, not #{type_var}"
        end
        type_var
      end
      return_type = types.pop
      instance = ProcInstanceType.new(program, types, return_type)
      generic_types[type_vars] = instance
      initialize_instance instance
      instance.after_initialize
      instance
    end

    def allowed_in_generics?
      false
    end

    def new_generic_instance(program, generic_type, type_vars)
      raise "Bug: ProcType#new_generic_instance shouldn't be invoked"
    end

    def type_desc
      "function"
    end
  end

  class ProcInstanceType < GenericClassInstanceType
    getter program : Program
    getter arg_types : Array(Type)
    getter return_type : Type

    def initialize(@program, @arg_types, @return_type)
      t_var = Var.new("T", @program.tuple_of(@arg_types))
      t_var.bind_to t_var

      r_var = Var.new("R", @return_type)
      r_var.bind_to r_var

      super(program, program.proc, {"T" => t_var, "R" => r_var} of String => ASTNode)
    end

    def struct?
      true
    end

    def parents
      @parents ||= [@program.proc] of Type
    end

    def implements?(other : Type)
      if other.is_a?(ProcInstanceType)
        if (self.return_type.no_return? || other.return_type.void?) &&
           arg_types == other.arg_types
          return true
        end
      end
      super
    end

    def to_s_with_options(io : IO, skip_union_parens : Bool = false, generic_args : Bool = true, codegen = false)
      io << "Proc("
      arg_types.each_with_index do |type, i|
        type = type.devirtualize unless codegen
        type.to_s_with_options(io, codegen: codegen)
        io << ", "
      end
      return_type = self.return_type
      return_type = return_type.devirtualize unless codegen
      return_type.to_s_with_options(io, codegen: codegen)
      io << ")"
    end
  end
end
