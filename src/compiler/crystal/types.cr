require "similar_name"

module Crystal
  abstract class Type
    include Enumerable(self)

    def each
      yield self
    end

    def metaclass
      @metaclass ||= MetaclassType.new(program, self)
    end

    def force_metaclass(metaclass)
      @metaclass = metaclass
    end

    def type_id
      @type_id ||= program.next_type_id
    end

    def type_id=(@type_id)
    end

    def passed_as_self?
      true
    end

    # Is this type passed by value if it's not a primitive type?
    def passed_by_value?
      false
    end

    def rank
      raise "Bug: #{self} doesn't implement rank"
    end

    def abstract
      false
    end

    def struct?
      false
    end

    def subclasses
      raise "Bug: #{self} doesn't implement subclasses"
    end

    def leaf?
      subclasses.length == 0
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

    def pointer?
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

    def virtual?
      false
    end

    def virtual_metaclass?
      false
    end

    def fun?
      false
    end

    def void?
      false
    end

    def reference_like?
      false
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

    def includes_type?(type)
      self == type
    end

    def remove_typedef
      self
    end

    def class_var_owner
      self
    end

    def is_implicitly_converted_in_c_to?(expected_type)
      if self.nil_type? && (expected_type.pointer? || expected_type.fun?)
        # OK: nil will be sent as pointer
        true
      elsif expected_type.is_a?(FunInstanceType) && self.is_a?(FunInstanceType) && expected_type.return_type == program.void && expected_type.arg_types == self.arg_types
        # OK: fun will be cast to return void
        true
      else
        false
      end
    end

    def allocated
      true
    end

    def allocated=(value)
      false
    end

    def implements?(other_type : Type)
      case other_type
      when UnionType
        other_type.union_types.any? do |union_type|
          implements?(union_type)
        end
      else
        self == other_type
      end
    end

    def is_subclass_of?(type)
      self == type
    end

    def filter_by(other_type)
      restrict other_type, MatchContext.new(self, self)
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

    def lookup_def_instance(key)
      raise "Bug: #{self} doesn't implement lookup_def_instance"
    end

    def add_def_instance(key, typed_def)
      raise "Bug: #{self} doesn't implement add_def_instance"
    end

    def types
      {} of String => Type
    end

    def parents
      nil
    end

    def superclass
      raise "Bug: #{self} doesn't implement superclass"
    end

    def defs
      raise "Bug: #{self} doesn't implement defs"
    end

    def add_def(a_def)
      raise "Bug: #{self} doesn't implement add_def"
    end

    def undef(def_name)
      raise "Bug: #{self} doesn't implement undef"
    end

    def lookup_defs(name)
      raise "Bug: #{self} doesn't implement lookup_defs"
    end

    def lookup_defs_with_modules(name)
      raise "Bug: #{self} doesn't implement lookup_defs_with_modules"
    end

    def lookup_first_def(name, block)
      raise "Bug: #{self} doesn't implement lookup_first_def"
    end

    def macros
      raise "Bug: #{self} doesn't implement macros"
    end

    def hooks
      nil
    end

    def add_macro(a_def)
      raise "Bug: #{self} doesn't implement add_macro"
    end

    def lookup_macro(name, args_length, named_args)
      raise "Bug: #{self} doesn't implement lookup_macro"
    end

    def lookup_macros(name)
      raise "Bug: #{self} doesn't implement lookup_macros"
    end

    def include(mod)
      raise "Bug: #{self} doesn't implement include"
    end

    def add_including_type(mod)
      raise "Bug: #{self} doesn't implement add_including_type"
    end

    def including_types
      raise "Bug: #{self} doesn't implement including_types"
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

    def index_of_instance_var?(name)
      raise "Bug: #{self} doesn't implement index_of_instance_var?"
    end

    def lookup_instance_var(name, create = true)
      raise "Bug: #{self} doesn't implement lookup_instance_var"
    end

    def lookup_instance_var?(name, create = false)
      raise "Bug: #{self} doesn't implement lookup_instance_var?"
    end

    def owns_instance_var?(name)
      raise "Bug: #{self} doesn't implement owns_instance_var?"
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

    def all_instance_vars_count
      raise "Bug: #{self} doesn't implement all_instance_vars_count"
    end

    def add_subclass(subclass)
      raise "Bug: #{self} doesn't implement add_subclass"
    end

    def notify_subclass_added
      raise "Bug: #{self} doesn't implement notify_subclass_added"
    end

    def instance_vars_in_initialize
      raise "Bug: #{self} doesn't implement instance_vars_in_initialize"
    end

    def instance_vars_in_initialize=(value)
      raise "Bug: #{self} doesn't implement instance_vars_in_initialize="
    end

    def depth
      raise "Bug: #{self} doesn't implement depth"
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

    def inspect(io)
      to_s(io)
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

  abstract class NamedType < ContainedType
    getter :name

    def initialize(program, container, @name)
      super(program, container)
    end

    def append_full_name(io)
      if @container && !@container.is_a?(Program)
        @container.to_s(io)
        io << "::"
      end
      io << @name
    end

    def to_s(io)
      append_full_name(io)
    end
  end

  record CallSignature, name, arg_types, block, named_args

  module MatchesLookup
    def lookup_first_def(name, block)
      block = !!block
      if (defs = self.defs) && (list = defs[name]?)
        value = list.find { |item| item.yields == block }
        value.try &.def
      end
    end

    def lookup_defs(name)
      all_defs = [] of Def

      self.defs.try &.[name]?.try &.each do |item|
        all_defs << item.def
      end

      unless name == "new" || name == "initialize"
        parents.try &.each do |parent|
          all_defs.concat parent.lookup_defs(name)
        end
      end

      all_defs
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

    def lookup_macro(name, args_length, named_args)
      if macros = self.macros.try &.[name]?
        match = macros.find &.matches?(args_length, named_args)
        return match if match
      end

      instance_type.parents.try &.each do |parent|
        parent_macro = parent.metaclass.lookup_macro(name, args_length, named_args)
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
  end

  record DefWithMetadata, min_length, max_length, yields, :def

  module DefContainer
    include MatchesLookup

    record Hook, kind, :macro

    getter defs
    getter macros
    getter hooks

    def add_def(a_def)
      a_def.owner = self

      if a_def.name == "initialize"
        a_def.visibility = :protected
      end

      min_length, max_length = a_def.min_max_args_lengths
      item = DefWithMetadata.new(min_length, max_length, !!a_def.yields, a_def)

      defs = (@defs ||= {} of String => Array(DefWithMetadata))
      list = defs[a_def.name] ||= [] of DefWithMetadata
      list.each_with_index do |ex_item, i|
        if item.is_restriction_of?(ex_item, self)
          if ex_item.is_restriction_of?(item, self)
            list[i] = item
            a_def.previous = ex_item.def
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

    def undef(def_name)
      found_list = @defs.try &.delete def_name
      return false unless found_list

      found_list.each do |item|
        a_def = item.def
        a_def.dead = true if a_def.is_a?(External)
      end

      true
    end

    def add_macro(a_def)
      case a_def.name
      when "inherited"
        return add_hook :inherited, a_def
      when "included"
        return add_hook :included, a_def
      when "extended"
        return add_hook :extended, a_def
      when "method_missing"
        if a_def.args.length != 3
          raise "macro 'method_missing' expects 3 arguments: name, args, block"
        end
      end

      macros = (@macros ||= {} of String => Array(Macro))
      array = (macros[a_def.name] ||= [] of Macro)
      array.push a_def
    end

    def add_hook(kind, a_def)
      if a_def.args.length != 0
        raise "macro '#{kind}' must not have arguments"
      end

      hooks = @hooks ||= [] of Hook
      hooks << Hook.new(kind, a_def)
    end

    def filter_by_responds_to(name)
      has_def?(name) ? self : nil
    end

    def has_def?(name)
      defs = self.defs()
      return false unless defs
      return true if defs.has_key?(name)

      parents.try &.each do |parent|
        return true if parent.has_def?(name)
      end

      false
    end
  end

  record DefInstanceKey, def_object_id, arg_types, block_type, named_args

  module DefInstanceContainer
    def def_instances
      @def_instances ||= {} of DefInstanceKey => Def
    end

    def add_def_instance(key, typed_def)
      def_instances[key] = typed_def
    end

    def lookup_def_instance(key)
      def_instances[key]?
    end
  end

  abstract class ModuleType < NamedType
    include DefContainer

    def parents
      @parents ||= [] of Type
    end

    def include(mod)
      if mod == self
        raise "cyclic include detected"
      else
        unless parents.includes?(mod)
          parents.insert 0, mod
          mod.add_including_type(self)
        end
      end
    end

    def implements?(other_type)
      super || parents.any? &.implements?(other_type)
    end

    def type_desc
      "module"
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
      @subclass_observers.try &.each &.on_new_subclass
    end
  end

  module InheritableClass
    include SubclassObservable

    def add_subclass(subclass)
      subclasses << subclass
      notify_subclass_added
      superclass.try &.notify_subclass_added
    end
  end

  module NonGenericOrGenericClassInstanceType
  end

  class NonGenericModuleType < ModuleType
    include DefInstanceContainer
    include ClassVarContainer
    include SubclassObservable

    def add_including_type(type)
      including_types = @including_types ||= [] of Type
      including_types.push type

      notify_subclass_added
    end

    def including_types
      if including_types = @including_types
        all_types = Array(Type).new(types.length)
        including_types.each do |including_type|
          if including_type.is_a?(GenericType)
            including_type.generic_types.each_value do |generic_type|
              all_types << generic_type
            end
          else
            all_types << including_type.virtual_type
          end
        end
        program.union_of(all_types)
      else
        nil
      end
    end

    def passed_by_value?
      including_types = including_types()
      if including_types
        including_types.passed_by_value?
      else
        false
      end
    end

    def module?
      true
    end
  end

  abstract class ClassType < ModuleType
    include InheritableClass

    getter :superclass
    getter :subclasses
    getter :depth
    property :abstract
    property :struct
    getter :owned_instance_vars
    property :instance_vars_in_initialize
    getter :allocated
    getter :instance_vars_initializers

    def initialize(program, container, name, @superclass, add_subclass = true)
      super(program, container, name)
      if superclass
        @depth = superclass.depth + 1
      else
        @depth = 0
      end
      @subclasses = [] of Type
      @abstract = false
      @struct = false
      @allocated = false
      @owned_instance_vars = Set(String).new
      parents.push superclass if superclass
      force_add_subclass if add_subclass
    end

    def force_add_subclass
      superclass.try &.add_subclass(self)
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
      super || superclass.try &.is_subclass_of?(type)
    end

    def add_def(a_def)
      super

      transfer_instance_vars a_def

      a_def
    end

    def transfer_instance_vars(a_def)
      # Don't consider macro defs here (only later, when expanded)
      return if a_def.return_type

      is_initialize = a_def.name == "initialize"

      if a_def_instance_vars = a_def.instance_vars
        a_def_instance_vars.each do |ivar|
          if superclass = superclass()
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

        if is_initialize
          unless a_def.calls_initialize
            if ivii = @instance_vars_in_initialize
              @instance_vars_in_initialize = ivii & a_def_instance_vars
            else
              @instance_vars_in_initialize = a_def_instance_vars
            end
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
      elsif is_initialize
        # If it's an initialize without instance variables,
        # then *all* instance variables are nilable
        unless a_def.calls_initialize
          @instance_vars_in_initialize = Set(String).new
        end

        unless a_def.calls_super
          sup = superclass
          while sup
            sup.instance_vars_in_initialize = Set(String).new
            sup = sup.superclass
          end
        end
      end
    end

    def transfer_instance_vars_of_mod(mod)
      if (defs = mod.defs)
        defs.each do |def_name, list|
          list.each do |item|
            transfer_instance_vars item.def
          end
        end
      end

      mod.parents.try &.each do |parent|
        transfer_instance_vars_of_mod parent
      end
    end

    record InstanceVarInitializer, name, value, meta_vars

    def add_instance_var_initializer(name, value, meta_vars)
      initializers = @instance_vars_initializers ||= [] of InstanceVarInitializer
      initializers << InstanceVarInitializer.new(name, value, meta_vars)
    end

    def include(mod)
      super mod
      transfer_instance_vars_of_mod mod
    end

    def allocated=(allocated)
      @allocated = allocated
      superclass.try &.allocated = allocated
    end

    def struct?
      @struct
    end

    def passed_by_value?
      struct?
    end

    def type_desc
      struct? ? "struct" : "class"
    end
  end

  module InstanceVarContainer
    def instance_vars
      @instance_vars ||= {} of String => Var
    end

    def owns_instance_var?(name)
      owned_instance_vars.includes?(name) || superclass.try &.owns_instance_var?(name)
    end

    def remove_instance_var(name)
      owned_instance_vars.delete(name)
      instance_vars.delete(name)
    end

    def lookup_instance_var(name, create = true)
      lookup_instance_var?(name, create).not_nil!
    end

    def lookup_instance_var?(name, create)
      if var = superclass.try &.lookup_instance_var?(name, false)
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

    def each_instance_var(&block)
      superclass.try &.each_instance_var &block
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
      instance_vars_initializers.try(&.any? { |init| init.name == name }) ||
        instance_vars_in_initialize.try(&.includes?(name)) ||
        superclass.try &.has_instance_var_in_initialize?(name)
    end
  end

  class NonGenericClassType < ClassType
    include InstanceVarContainer
    include ClassVarContainer
    include DefInstanceContainer
    include NonGenericOrGenericClassInstanceType

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        metaclass.add_def Def.new("allocate", body: Primitive.new(:allocate))
        metaclass
      end
    end

    def virtual_type
      if leaf? && !self.abstract
        self
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

    def reference_like?
      !struct?
    end

    def declare_instance_var(name, type)
      ivar = Var.new(name, type)
      ivar.bind_to ivar
      ivar.freeze_type = type
      instance_vars[name] = ivar
    end
  end

  class PrimitiveType < ClassType
    include DefInstanceContainer

    getter :bytes

    def initialize(program, container, name, superclass, @bytes : Int32)
      super(program, container, name, superclass)
      self.struct = true
    end

    def value?
      true
    end

    def primitive_like?
      true
    end

    def passed_by_value?
      false
    end

    def allocated
      true
    end

    def abstract
      false
    end

    def hierarcy_type
      self
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
    getter :kind

    def initialize(program, container, name, superclass, bytes, @rank, @kind)
      super(program, container, name, superclass, bytes)
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

    def initialize(program, container, name, superclass, bytes, @rank)
      super(program, container, name, superclass, bytes)
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

    def reference_like?
      true
    end
  end

  abstract class EmptyType < Type
    getter :program

    def initialize(@program)
    end

    def lookup_defs(name)
      [] of Def
    end

    def parents
      nil
    end

    def allocated
      true
    end

    def abstract
      false
    end
  end

  class NoReturnType < EmptyType
    def no_return?
      true
    end

    def primitive_like?
      true
    end

    def to_s(io)
      io << "NoReturn"
    end
  end

  class VoidType < EmptyType
    def void?
      true
    end

    def primitive_like?
      true
    end

    def to_s(io)
      io << "Void"
    end
  end

  class ValueType < NonGenericClassType
    def initialize(program, container, name, superclass, add_subclass = true)
      super
      self.struct = true
    end

    def value?
      true
    end

    def passed_by_value?
      false
    end
  end

  alias TypeVar = Type | ASTNode

  module GenericType
    getter type_vars
    property variadic

    def generic_types
      @generic_types ||= {} of Array(TypeVar) => Type
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      instance_type_vars = {} of String => ASTNode
      last_index = self.type_vars.length - 1
      self.type_vars.each_with_index do |name, index|
        if variadic && index == last_index
          types = [] of TypeVar
          index.upto(type_vars.length - 1) do |second_index|
            types << type_vars[second_index]
          end
          tuple_type = program.tuple.instantiate(types) as TupleInstanceType
          instance_type_vars[name] = tuple_type.var
        else
          type_var = type_vars[index]
          case type_var
          when Type
            var = Var.new(name, type_var)
            var.bind_to var
            instance_type_vars[name] = var
          when ASTNode
            instance_type_vars[name] = type_var
          end
        end
      end

      instance = self.new_generic_instance(program, self, instance_type_vars)
      generic_types[type_vars] = instance
      initialize_instance instance

      instance.after_initialize

      # Notify modules that an instance was added
      parents.try &.each do |parent|
        if parent.is_a?(NonGenericModuleType)
          parent.notify_subclass_added
        end
      end

      instance
    end

    def initialize_instance(instance)
      # Nothing
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

    def to_s(io)
      super
      io << "("
      type_vars.each_with_index do |type_var, i|
        io << ", " if i > 0
        type_var.to_s(io)
      end
      io << ")"
    end
  end

  class GenericClassType < ClassType
    include GenericType
    include DefInstanceContainer

    def initialize(program, container, name, superclass, @type_vars, add_subclass = true)
      super(program, container, name, superclass, add_subclass)
      @variadic = false
      @allocated = true
    end

    def class?
      true
    end

    def allocated=(value)
      superclass.try &.allocated = value
    end

    def new_generic_instance(program, generic_type, type_vars)
      GenericClassInstanceType.new program, generic_type, type_vars
    end

    def declare_instance_var(name, node)
      declared_instance_vars = (@declared_instance_vars ||= {} of String => ASTNode)
      declared_instance_vars[name] = node

      generic_types.each do |key, instance|
        instance = instance as GenericClassInstanceType

        visitor = TypeLookup.new(instance)
        node.accept visitor

        ivar = Var.new(name, visitor.type)
        ivar.bind_to ivar
        ivar.freeze_type = visitor.type
        instance.instance_vars[name] = ivar
      end
    end

    def initialize_instance(instance)
      if decl_ivars = @declared_instance_vars
        visitor = TypeLookup.new(instance)
        decl_ivars.each do |name, node|
          node.accept visitor

          ivar = Var.new(name, visitor.type)
          ivar.bind_to ivar
          ivar.freeze_type = visitor.type
          instance.instance_vars[name] = ivar
        end
      end
    end

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        metaclass.add_def Def.new("allocate", body: Primitive.new(:allocate))
        metaclass
      end
    end

    def has_instance_var_in_initialize?(name)
      instance_vars_initializers.try(&.any? { |init| init.name == name }) ||
        instance_vars_in_initialize.try(&.includes?(name)) ||
        superclass.try &.has_instance_var_in_initialize?(name)
    end

    def type_desc
      struct? ? "generic struct" : "generic class"
    end

    def including_types
      instances = generic_types.values
      subclasses.each do |subclass|
        if subclass.is_a?(GenericClassType)
          subtypes = subclass.including_types
          instances.concat subtypes if subtypes
        else
          instances << subclass
        end
      end
      program.union_of instances
    end

    def to_s(io)
      super
      io << "("
      type_vars.each_with_index do |type_var, i|
        io << ", " if i > 0
        type_var.to_s(io)
      end
      io << ")"
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

    def initialize(@program, generic_class, @type_vars)
      @generic_class = generic_class
      @subclasses = [] of Type
      @allocated = false
    end

    def after_initialize
      @generic_class.superclass.not_nil!.add_subclass(self)
    end

    def parents
      @parents ||= generic_class.parents.map do |t|
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

    delegate depth, @generic_class
    delegate defs, @generic_class
    delegate superclass, @generic_class
    delegate owned_instance_vars, @generic_class
    delegate instance_vars_in_initialize, @generic_class
    delegate instance_vars_initializers, @generic_class
    delegate macros, @generic_class
    delegate :abstract, @generic_class
    delegate struct?, @generic_class
    delegate passed_by_value?, @generic_class
    delegate type_desc, @generic_class

    def allocated=(allocated)
      @allocated = allocated
      superclass.try { |s| s.allocated = allocated }
    end

    def filter_by_responds_to(name)
      @generic_class.filter_by_responds_to(name) ? self : nil
    end

    def class?
      true
    end

    def reference_like?
      !struct?
    end

    def metaclass
      @metaclass ||= GenericClassInstanceMetaclassType.new(program, self)
    end

    def is_subclass_of?(type)
      super || generic_class.is_subclass_of?(type)
    end

    def implements?(other_type)
      super || generic_class.implements?(other_type)
    end

    def to_s(io)
      generic_class.append_full_name(io)
      io << "("
      i = 0
      type_vars.each_value do |type_var|
        io << ", " if i > 0
        if type_var.is_a?(Var)
          type_var.type.to_s(io)
        else
          type_var.to_s(io)
        end
        i += 1
      end
      io << ")"
    end
  end

  class PointerType < GenericClassType
    def pointer?
      true
    end

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

    def pointer?
      true
    end

    def reference_like?
      false
    end

    def allocated
      true
    end

    def primitive_like?
      var.type.primitive_like?
    end

    def type_desc
      "struct"
    end
  end

  class StaticArrayType < GenericClassType
    def new_generic_instance(program, generic_type, type_vars)
      n = type_vars["N"]
      unless n.is_a?(NumberLiteral)
        raise "can't instantiate StaticArray(T, N) with N = #{n.type} (N must be an integer)"
      end

      value = n.value.to_i
      if value < 0
        raise "can't instantiate StaticArray(T, N) with N = #{value} (N must be positive)"
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

    def allocated
      true
    end

    def primitive_like?
      var.type.primitive_like?
    end

    def reference_like?
      false
    end
  end

  class TupleType < GenericClassType
    def initialize(program, container, name, superclass, type_vars, add_subclass = true)
      super
      @variadic = true
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      types = type_vars.map { |type_var| type_var as Type }
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
    getter tuple_types

    def initialize(program, @tuple_types)
      var = Var.new("T", self)
      var.bind_to var
      super(program, program.tuple, {"T" => var} of String => ASTNode)
      @tuple_indexers = {} of Int32 => Def
    end

    def tuple_indexer(index)
      @tuple_indexers[index] ||= begin
        indexer = Def.new("[]", [Arg.new("index")], TupleIndexer.new(index))
        indexer.owner = self
        indexer
      end
    end

    def var
      type_vars["T"]
    end

    def reference_like?
      false
    end

    def passed_by_value?
      true
    end

    def allocated
      true
    end

    def instance_type
      program.tuple.instantiate tuple_types.map(&.instance_type)
    end

    def metaclass
      program.tuple.instantiate tuple_types.map(&.metaclass)
    end

    def to_s(io)
      io << "{"
      @tuple_types.each_with_index do |tuple_type, i|
        io << ", " if i > 0
        tuple_type.to_s(io)
      end
      io << "}"
    end

    def type_desc
      "tuple"
    end
  end

  class IncludedGenericModule < Type
    include MatchesLookup

    getter :program
    getter :module
    getter :including_class
    getter :mapping

    def initialize(@program, @module, @including_class, @mapping)
    end

    def add_including_type(type)
      # TODO
    end

    delegate container, @module
    delegate name, @module
    delegate defs, @module
    delegate macros, @module
    delegate implements?, @module
    delegate lookup_defs, @module
    delegate lookup_defs_with_modules, @module
    delegate lookup_macro, @module
    delegate lookup_macros, @module
    delegate has_def?, @module

    def parents
      @parents ||= @module.parents.map do |t|
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

    def to_s(io)
      @module.to_s(io)
      io << "("
      @including_class.to_s(io)
      io << ")"
      io << @mapping
    end
  end

  class InheritedGenericClass < Type
    include MatchesLookup

    getter :program
    getter :extended_class
    property! :extending_class
    getter :mapping

    def initialize(@program, @extended_class, @mapping, @extending_class = nil)
    end

    delegate depth, @extended_class
    delegate superclass, @extended_class
    delegate add_subclass, @extended_class
    delegate container, @extended_class
    delegate name, @extended_class
    delegate defs, @extended_class
    delegate macros, @extended_class
    delegate implements?, @extended_class
    delegate lookup_defs, @extended_class
    delegate lookup_defs_with_modules, @extended_class
    delegate lookup_macro, @extended_class
    delegate lookup_macros, @extended_class
    delegate has_def?, @extended_class
    delegate has_instance_var_in_initialize?, @extended_class
    delegate instance_vars_in_initialize, @extended_class
    delegate :"instance_vars_in_initialize=", @extended_class
    delegate :"allocated=", @extended_class
    delegate notify_subclass_added, @extended_class

    def lookup_instance_var?(name, create = false)
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

    def owns_instance_var?(name)
      false
    end

    def parents
      @parents ||= @extended_class.parents.map do |t|
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

    def to_s(io)
      @extended_class.to_s(io)
      io << "("
      @extending_class.to_s(io)
      io << ")"
      io << @mapping
    end
  end

  class LibType < ModuleType
    getter :link_attributes
    property? :used

    def initialize(program, container, name, @link_attributes)
      super(program, container, name)
      @used = false
    end

    def metaclass
      self
    end

    def add_def(a_def : External)
      if defs = self.defs
        if existing_defs = defs[a_def.name]?
          existing = existing_defs.first?
          if existing
            existing = existing.def as External
            unless existing.compatible_with?(a_def)
              raise "fun redefinition with different signature (was #{existing})"
            end
          end
        end
      end

      super
    end

    def add_def(a_def : Def)
      raise "Bug: shouldn't be adding a Def in a LibType"
    end

    def add_var(name, type, real_name, attributes)
      setter = External.new("#{name}=", [Arg.new("value", type: type)], Primitive.new(:external_var_set, type), real_name)
      setter.set_type(type)
      setter.attributes = attributes

      getter = External.new("#{name}", [] of Arg, Primitive.new(:external_var_get, type), real_name)
      getter.set_type(type)
      getter.attributes = attributes

      add_def setter
      add_def getter
    end

    def passed_as_self?
      false
    end

    def type_desc
      "lib"
    end
  end

  class TypeDefType < NamedType
    include DefInstanceContainer
    include MatchesLookup

    getter :typedef

    def initialize(program, container, name, @typedef)
      super(program, container, name)
    end

    def remove_typedef
      typedef.remove_typedef
    end

    delegate pointer?, typedef
    delegate defs, typedef
    delegate macros, typedef

    def parents
      typedef_parents = typedef.parents

      # We need to repoint "self" in included generic modules to this typedef,
      # so "self" restrictions match and don't point to the typdefed type.
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

    def primitive_like?
      true
    end

    def type_def_type?
      true
    end

    def type_desc
      "type def"
    end
  end

  class AliasType < NamedType
    property! :aliased_type

    def initialize(program, container, name)
      super(program, container, name)
      @simple = true
    end

    delegate lookup_defs, aliased_type
    delegate lookup_defs_with_modules, aliased_type
    delegate lookup_first_def, aliased_type
    delegate def_instances, aliased_type
    delegate add_def_instance, aliased_type
    delegate lookup_def_instance, aliased_type
    delegate lookup_macro, aliased_type
    delegate lookup_macros, aliased_type
    delegate cover, aliased_type
    delegate cover_length, aliased_type

    def remove_alias
      if aliased_type = @aliased_type
        aliased_type.remove_alias
      else
        @simple = false
        self
      end
    end

    def remove_alias_if_simple
      if @simple
        remove_alias
      else
        self
      end
    end

    def type_desc
      "alias"
    end
  end

  abstract class CStructOrUnionType < NamedType
    include DefContainer
    include DefInstanceContainer

    getter vars

    def initialize(program, container, name)
      super(program, container, name)
      @vars = {} of String => Var
    end

    def passed_by_value?
      true
    end

    def primitive_like?
      true
    end

    def parents
      nil
    end
  end

  class CStructType < CStructOrUnionType
    property :packed
    @packed = false

    def vars=(vars)
      vars.each do |var|
        @vars[var.name] = var
        add_def Def.new("#{var.name}=", [Arg.new("value", type: var.type)], Primitive.new(:struct_set))
        add_def Def.new(var.name, body: Primitive.new(:struct_get))
      end
    end

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        metaclass.add_def Def.new("new", body: Primitive.new(:struct_new))
        metaclass
      end
    end

    def index_of_var(name)
      @vars.key_index(name).not_nil!
    end

    def type_desc
      "struct"
    end
  end

  class CUnionType < CStructOrUnionType
    def vars=(vars)
      vars.each do |var|
        @vars[var.name] = var
        add_def Def.new("#{var.name}=", [Arg.new("value", type: var.type)], Primitive.new(:union_set))
        add_def Def.new(var.name, body: Primitive.new(:union_get))
      end
    end

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        metaclass.add_def Def.new("new", body: Primitive.new(:union_new))
        metaclass
      end
    end

    def type_desc
      "union"
    end
  end

  class EnumType < NamedType
    include DefContainer
    include DefInstanceContainer

    getter base_type
    getter? flags

    def initialize(program, container, name, @base_type, @flags)
      super(program, container, name)

      add_def Def.new("value", [] of Arg, Primitive.new(:enum_value, @base_type))
      metaclass.add_def Def.new("new", [Arg.new("value", type: @base_type)], Primitive.new(:enum_new, self))
    end

    def parents
      @parents ||= [program.enum] of Type
    end

    def add_constant(constant)
      @types[constant.name] = Const.new(program, self, constant.name, constant.default_value.not_nil!)
    end

    def primitive_like?
      true
    end

    def type_desc
      "enum"
    end
  end

  class MetaclassType < ClassType
    include DefContainer
    include DefInstanceContainer
    include ClassVarContainer
    include InstanceVarContainer

    getter program
    getter instance_type

    def initialize(@program, instance_type, super_class = nil, name = nil)
      @instance_type = instance_type
      super_class ||= if instance_type.is_a?(ClassType) && instance_type.superclass
                        instance_type.superclass.not_nil!.metaclass as ClassType
                      elsif instance_type.is_a?(EnumType)
                        @program.enum.metaclass as MetaclassType
                      else
                        @program.class_type
                      end
      super(@program, @program, name || "#{@instance_type}:Class", super_class)
    end

    def allocated
      true
    end

    def metaclass
      @program.class_type
    end

    delegate :abstract, instance_type

    def class_var_owner
      instance_type
    end

    def metaclass?
      true
    end

    def passed_as_self?
      false
    end

    def virtual_type
      instance_type.virtual_type.metaclass
    end

    def virtual_type!
      instance_type.virtual_type!.metaclass
    end

    def to_s(io)
      io << @name
    end
  end

  class GenericClassInstanceMetaclassType < Type
    include MatchesLookup
    include DefInstanceContainer

    getter program
    getter instance_type

    def initialize(@program, instance_type)
      @instance_type = instance_type
    end

    def parents
      @parents ||= [instance_type.superclass.try(&.metaclass) || @program.class_type] of Type
    end

    delegate add_def, instance_type.generic_class.metaclass
    delegate defs, instance_type.generic_class.metaclass
    delegate macros, instance_type.generic_class.metaclass
    delegate type_vars, instance_type
    delegate :abstract, instance_type

    def metaclass?
      true
    end

    def to_s(io)
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
  end

  # Base class for union types.
  abstract class UnionType < Type
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
      union_types.sum &.cover_length
    end

    def filter_by_responds_to(name)
      apply_filter &.filter_by_responds_to(name)
    end

    def apply_filter
      filtered_types = @union_types.compact_map do |union_type|
        yield union_type
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

    def to_s(io)
      io << "("
      @union_types.each_with_index do |union_type, i|
        io << " | " if i > 0
        union_type.to_s(io)
      end
      io << ")"
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

    def to_s(io)
      not_nil_type.to_s(io)
      io << "?"
    end
  end

  # A union type that has Nil and other reference-like types.
  # Can be represented as a maybe-null pointer but the type id is
  # not known at compile time.
  class NilableReferenceUnionType < UnionType
    def reference_like?
      true
    end
  end

  # A union type that doesn't have nil, and all types are reference-like.
  # Can be represented as a never-null pointer.
  class ReferenceUnionType < UnionType
    def reference_like?
      true
    end
  end

  # A union type of nil and a single function type.
  class NilableFunType < UnionType
    def initialize(@program, fun_type)
      super(@program, [@program.nil, fun_type] of Type)
    end

    def primitive_like?
      true
    end

    def fun_type
      @union_types.last.remove_typedef as FunInstanceType
    end

    def to_s(io)
      io << "("
      @union_types.last.to_s(io)
      io << ")"
      io << "?"
    end
  end

  # A union type of nil and a single pointer type.
  class NilablePointerType < UnionType
    def initialize(@program, pointer_type)
      super(@program, [@program.nil, pointer_type] of Type)
    end

    def primitive_like?
      true
    end

    def pointer_type
      @union_types.last.remove_typedef as PointerInstanceType
    end

    def to_s(io)
      @union_types.last.to_s(io)
      io << "?"
    end
  end


  # A union type that doesn't match any of the previous definitions,
  # so it can contain Nil with primitive types, or Reference types with
  # primitives types.
  # Must be represented as a union.
  class MixedUnionType < UnionType
    def passed_by_value?
      true
    end
  end

  class Const < NamedType
    property value
    getter scope_types
    getter scope
    property vars
    property used
    property? visited
    property? initialized

    def initialize(program, container, name, @value, @scope_types = [] of Type, @scope = nil)
      super(program, container, name)
      @used = false
      @visited = false
      @initialized = false
    end

    def type_desc
      "constant"
    end
  end

  module VirtualTypeLookup
    record Change, :type, :def

    def virtual_lookup(type)
      type
    end
  end

  class VirtualType < Type
    include MultiType
    include DefInstanceContainer
    include VirtualTypeLookup
    include InstanceVarContainer

    getter program
    getter base_type

    def initialize(@program, @base_type)
    end

    delegate leaf?, base_type
    delegate superclass, base_type
    delegate lookup_first_def, base_type
    delegate lookup_defs, base_type
    delegate lookup_defs_with_modules, base_type
    delegate lookup_instance_var, base_type
    delegate lookup_instance_var?, base_type
    delegate index_of_instance_var, base_type
    delegate lookup_macro, base_type
    delegate lookup_macros, base_type
    delegate has_instance_var_in_initialize?, base_type
    delegate all_instance_vars, base_type
    delegate owned_instance_vars, base_type
    delegate :abstract, base_type
    delegate allocated, base_type
    delegate is_subclass_of?, base_type
    delegate implements?, base_type

    def allocated=(allocated)
      base_type.allocated = allocated
    end

    def metaclass
      @metaclass ||= VirtualMetaclassType.new(program, self)
    end

    def virtual?
      true
    end

    def reference_like?
      true
    end

    def cover
      if base_type.abstract
        cover = [] of Type
        base_type.subclasses.each do |s|
          s_cover = s.virtual_type.cover
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
        base_type.subclasses.sum &.virtual_type.cover_length
      else
        1
      end
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

    def to_s(io)
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

    getter program
    getter instance_type

    def initialize(@program, instance_type)
      @instance_type = instance_type
    end

    def parents
      @parents ||= [instance_type.superclass.try(&.metaclass) || @program.class_type] of Type
    end

    def leaf?
      instance_type.leaf?
    end

    delegate base_type, instance_type
    delegate cover, instance_type
    delegate lookup_first_def, instance_type

    def virtual_lookup(type)
      type.metaclass
    end

    def virtual_metaclass?
      true
    end

    def lookup_macro(name, args_length, named_args)
      nil
    end

    def lookup_macros(name)
      nil
    end

    def metaclass?
      true
    end

    def each_concrete_type
      instance_type.each_concrete_type do |type|
        yield type.metaclass
      end
    end

    def to_s(io)
      instance_type.to_s(io)
      io << ":Class"
    end
  end

  class FunType < GenericClassType
    def initialize(program, container, name, superclass, type_vars, add_subclass = true)
      super
      @variadic = true
      @struct = true
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      types = type_vars.map { |type_var| type_var as Type }
      instance = FunInstanceType.new(program, types)
      generic_types[type_vars] = instance
      initialize_instance instance
      instance.after_initialize
      instance
    end

    def new_generic_instance(program, generic_type, type_vars)
      raise "Bug: FunType#new_generic_instance shouldn't be invoked"
    end

    def type_desc
      "function"
    end
  end

  class FunInstanceType < GenericClassInstanceType
    include DefContainer
    include DefInstanceContainer

    getter program
    getter fun_types

    def initialize(@program, @fun_types)
      var = Var.new("T", self)
      var.bind_to var
      super(program, program.function, {"T" => var} of String => ASTNode)

      args = arg_types.map_with_index { |type, i| Arg.new("arg#{i}", type: type) }

      fun_call = Def.new("call", args, Primitive.new(:fun_call, return_type))
      fun_call.raises = true

      add_def fun_call
      add_def Def.new("arity", body: NumberLiteral.new(fun_types.length - 1))
      add_def Def.new("pointer", body: Primitive.new(:fun_pointer, @program.pointer_of(@program.void)))
      add_def Def.new("closure?", body: Primitive.new(:fun_closure?, @program.bool))
    end

    def struct?
      true
    end

    def allocated
      true
    end

    def arg_types
      fun_types[0 .. -2]
    end

    def return_type
      fun_types.last
    end

    def parents
      @parents ||= [@program.function] of Type
    end

    def primitive_like?
      fun_types.all? &.primitive_like?
    end

    def passed_by_value?
      false
    end

    def fun?
      true
    end

    def to_s(io)
      io << "("
      len = fun_types.length
      fun_types.each_with_index do |fun_type, i|
        if i == len - 1
          io << " -> "
        elsif i > 0
          io << ", "
        end
        fun_type.to_s(io)
      end
      io << ")"
    end
  end
end
