require "levenshtein"

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

    def nilable?
      false
    end

    def generic?
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

    def fun?
      false
    end

    def void?
      false
    end

    def reference_like?
      false
    end

    def hierarchy_type
      self
    end

    def hierarchify
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

    def is_implicitly_converted_in_c_to?(expected_type)
      if self.nil_type? && (expected_type.pointer? || expected_type.fun?)
        # OK: nil will be sent as pointer
        true
      elsif self == program.string && (expected_type.is_a?(PointerInstanceType) && expected_type.element_type == program.uint8)
        # OK: string will be sent as UInt8
        true
      elsif expected_type.is_a?(FunInstanceType) && self.is_a?(FunInstanceType) && expected_type.return_type == program.void && expected_type.arg_types == self.arg_types
        # OK: fun will be cast to return void
        true
      elsif self.struct_wrapper_of?(expected_type) || self.pointer_struct_wrapper_of?(expected_type)
        # OK: same memory layout
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
      restrict(other_type, self, nil, nil)
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

    def struct_wrapper_of?(type)
      false
    end

    def c_value_wrapper?
      false
    end

    def pointer_struct_wrapper_of?(type)
      false
    end

    def lookup_def_instance(def_object_id, arg_types, block_type)
      raise "Bug: #{self} doesn't implement lookup_def_instance"
    end

    def add_def_instance(def_object_id, arg_types, block_type, typed_def)
      raise "Bug: #{self} doesn't implement add_def_instance"
    end

    def lookup_type(node : Path)
      (node.global ? program : self).lookup_type(node.names)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      raise "Bug: #{self} doesn't implement lookup_type"
    end

    def lookup_similar_type_name(node : Path)
      (node.global ? program : self).lookup_similar_type_name(node.names)
    end

    def lookup_similar_type_name(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      nil
    end

    def types
      raise "Bug: #{self} doesn't implement types"
    end

    def parents
      raise "Bug: #{self} doesn't implement parents"
    end

    def superclass
      raise "Bug: #{self} doesn't implement superclass"
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

    def undef(def_name)
      raise "Bug: #{self} doesn't implement undef"
    end

    def lookup_matches(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
      raise "Bug: #{self} doesn't implement lookup_matches"
    end

    def lookup_matches_with_modules(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
      raise "Bug: #{self} doesn't implement lookup_matches_with_modules"
    end

    def lookup_defs(name)
      raise "Bug: #{self} doesn't implement lookup_defs"
    end

    def lookup_first_def(name, block)
      raise "Bug: #{self} doesn't implement lookup_first_def"
    end

    def lookup_similar_def_name(name, args_length, block)
      nil
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

    def lookup_macro(name, args_length)
      raise "Bug: #{self} doesn't implement lookup_macro"
    end

    def lookup_macros(name)
      raise "Bug: #{self} doesn't implement lookup_macros"
    end

    def check_method_missing(name, arg_types, block)
      false
    end

    def lookup_method_missing
      # method_missing is actually stored in the metaclass
      method_missing = metaclass.lookup_macro("method_missing", 3)
      return method_missing if method_missing

      parents.try &.each do |parent|
        method_missing = parent.lookup_method_missing
        return method_missing if method_missing
      end

      nil
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

    def index_of_instance_var?(name)
      raise "Bug: #{self} doesn't implement index_of_instance_var"
    end

    def all_instance_vars_count
      raise "Bug: #{self} doesn't implement all_instance_vars_count"
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

    def inspect
      to_s
    end

    def to_s
      String.build do |str|
        self.append_to_s(str)
      end
    end
  end

  class NoReturnType < Type
    getter :program

    def initialize(@program)
    end

    def lookup_matches(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
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

    def append_to_s(str)
      str << "NoReturn"
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

    def append_full_name(str)
      if @container && !@container.is_a?(Program)
        @container.append_to_s(str)
        str << "::"
      end
      str << @name
    end

    def append_to_s(str)
      append_full_name(str)
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
      restriction = arg.type? || arg.restriction
      arg_type.not_nil!.restrict restriction, owner, type_lookup, free_vars
    end

    def match_arg(arg_type, restriction : ASTNode, owner, type_lookup, free_vars)
      arg_type.not_nil!.restrict restriction, owner, type_lookup, free_vars
    end

    def lookup_matches_without_parents(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
      if sorted_defs = self.sorted_defs()
        if defs = sorted_defs[DefContainer::SortedDefKey.new(name, arg_types.length, !!block)]?
          found_defs = true

          defs.each do |a_def|
            match = match_def_args(arg_types, a_def, owner, type_lookup)

            if match
              matches_array ||= [] of Match
              matches_array.push match

              # If the argument types are compatible with the match's argument types,
              # we are done. We don't just compare types with ==, there is a special case:
              # a function type with return T can be transpass a restriction of a function
              # with with the same arguments but which returns Void.
              if arg_types.equals?(match.arg_types) { |x, y| x.compatible_with?(y) }
                return Matches.new(matches_array, true, owner)
              end
            end
          end
        end
      end

      Matches.new(matches_array, Cover.create(arg_types, matches_array), owner)
    end

    def lookup_matches_with_modules(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
      matches_array ||= [] of Match

      matches = lookup_matches_without_parents(name, arg_types, block, owner, type_lookup, matches_array)
      return matches unless matches.empty?

      cover = matches.cover

      if (my_parents = parents) && !(name == "new" && owner.metaclass?)
        my_parents.each do |parent|
          break unless parent.is_a?(IncludedGenericModule) || parent.module?

          matches = parent.lookup_matches_with_modules(name, arg_types, block, owner, parent, matches_array)
          return matches unless matches.empty?
        end
      end

      Matches.new(matches_array, cover, owner, false)
    end

    def lookup_matches(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
      matches_array ||= [] of Match

      matches = lookup_matches_without_parents(name, arg_types, block, owner, type_lookup, matches_array)
      return matches if matches.cover_all?

      cover = matches.cover

      if (my_parents = parents) && !(name == "new" && owner.metaclass?)
        my_parents.each do |parent|
          matches = parent.lookup_matches(name, arg_types, block, owner, parent, matches_array)
          return matches if matches.cover_all?
        end
      end

      Matches.new(matches_array, cover, owner, false)
    end

    def lookup_first_def(name, block)
      block = !!block
      if (defs = self.defs) && (hash = defs[name]?)
        hash.values.find { |a_def| !!a_def.yields == block }
      end
    end

    def lookup_defs(name)
      if (defs = self.defs) && (hash = defs[name]?)
        return hash.values unless hash.empty?
      end

      parents.try &.each do |parent|
        parent_defs = parent.lookup_defs(name)
        return parent_defs unless parent_defs.empty?
      end

      [] of Def
    end

    SuggestableName =/\A[a-z_]/

    def lookup_similar_def_name(name, args_length, block)
      return nil unless name =~ SuggestableName

      tolerance = (name.length / 5.0).ceil
      candidates = [] of String

      if (defs = self.defs)
        defs.each do |def_name, hash|
          if def_name =~ SuggestableName
            hash.each do |filter, overload|
              if filter.restrictions.length == args_length && filter.yields == !!block
                if levenshtein(def_name, name) <= tolerance
                  candidates << def_name
                end
              end
            end
          end
        end
      end

      unless candidates.empty?
        return candidates.min_by { |candidate| levenshtein(candidate, name) }
      end

      parents.try &.each do |parent|
        similar_def_name = parent.lookup_similar_def_name(name, args_length, block)
        return similar_def_name if similar_def_name
      end

      nil
    end

    def lookup_macro(name, args_length)
      if (macros = self.macros) && (hash = macros[name]?) && (a_macro = hash[args_length]?)
        return a_macro
      end

      parents.try &.each do |parent|
        parent_macro = parent.lookup_macro(name, args_length)
        return parent_macro if parent_macro
      end

      nil
    end

    def lookup_macros(name)
      if (macros = self.macros) && (hash = macros[name]?)
        return hash.values
      end

      parents.try &.each do |parent|
        parent_macros = parent.lookup_macros(name)
        return parent_macros if parent_macros
      end

      nil
    end

    def check_method_missing(name, arg_types, block)
      if !metaclass? && name != "initialize"
        # Make sure to define method missing in the whole hierarchy
        hierarchy_type = hierarchy_type()
        if hierarchy_type == self
          method_missing = lookup_method_missing
          if method_missing
            define_method_from_method_missing(method_missing, name, arg_types, block)
            return true
          end
        else
          return hierarchy_type.check_method_missing(name, arg_types, block)
        end
      end

      false
    end

    def define_method_from_method_missing(method_missing, def_name, arg_types, block)
      name_node = StringLiteral.new(def_name)
      args_nodes = [] of ASTNode
      args_nodes_names = Set(String).new
      arg_types.each_index do |index|
        arg_node_name = "_arg#{index}"
        args_nodes << MacroId.new(arg_node_name)
        args_nodes_names << arg_node_name
      end
      args_node = ArrayLiteral.new(args_nodes)
      if block
        block_vars = block.args.map_with_index do |var, index|
          Var.new("_block_arg#{index}")
        end
        yield_exps = [] of ASTNode
        block_vars.each { |block_var| yield_exps << block_var.clone }
        block_body = Yield.new(yield_exps)
        block_node = Block.new(block_vars, block_body)
      else
        block_node = Nop.new
      end
      fake_call = Call.new(nil, "method_missing", [name_node, args_node, block_node] of ASTNode)
      generated_source = program.expand_macro self, method_missing, fake_call
      generated_nodes = program.parse_macro_source(generated_source, method_missing, method_missing, args_nodes_names)

      a_def = Def.new(def_name, args_nodes_names.map { |name| Arg.new(name) }, generated_nodes)
      a_def.yields = block.try &.args.length

      owner = self
      owner = owner.base_type if owner.is_a?(HierarchyType)
      owner.add_def(a_def) if owner.is_a?(DefContainer)
    end
  end

  module DefContainer
    include MatchesLookup

    make_named_tuple DefKey, [restrictions, yields]
    make_named_tuple SortedDefKey, [name, length, yields]
    make_named_tuple Hook, [kind, :macro]

    getter defs
    getter sorted_defs
    getter macros
    getter hooks

    def add_def(a_def)
      a_def.owner = self
      restrictions = Array(Type | ASTNode | Nil).new(a_def.args.length)
      a_def.args.each { |arg| restrictions.push(arg.type? || arg.restriction) }
      key = DefKey.new(restrictions, !!a_def.yields)

      defs = (@defs ||= {} of String => Hash(DefKey, Def))
      hash = (defs[a_def.name] ||= {} of DefKey => Def)
      old_def = hash[key]?
      hash[key] = a_def

      add_sorted_def(a_def)
      old_def
    end

    def add_sorted_def(a_def)
      sorted_defs = (@sorted_defs ||= {} of SortedDefKey => Array(Def))
      key = SortedDefKey.new(a_def.name, a_def.args.length, !!a_def.yields)
      list = (sorted_defs[key] ||= [] of Def)
      list.each_with_index do |ex_def, i|
        if a_def.is_restriction_of?(ex_def, self)
          list.insert(i, a_def)
          return
        end
      end
      list << a_def
    end

    def undef(def_name)
      found_def = @defs.try &.delete def_name
      return false unless found_def

      found_def.each do |key, a_def|
        a_def.dead = true if a_def.is_a?(External)
      end

      if sorted_defs = @sorted_defs
        keys_to_remove = [] of SortedDefKey
        sorted_defs.each do |key, defs|
          if key.name == def_name
            keys_to_remove << key
          end
        end

        keys_to_remove.each do |key|
          sorted_defs.delete(key)
        end
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

      macros = (@macros ||= {} of String => Hash(Int32, Macro))
      hash = (macros[a_def.name] ||= {} of Int32 => Macro)

      args_length = a_def.args.length
      min_args_length = a_def.args.index(&.default_value) || args_length
      min_args_length.upto(args_length) do |num_args|
        hash[num_args] = a_def
      end
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

  module DefInstanceContainer
    make_named_tuple DefInstanceKey, [def_object_id, arg_types, block_type]

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

  abstract class ModuleType < NamedType
    include DefContainer

    def parents
      @parents ||= [] of Type
    end

    def include(mod)
      if mod == self
        raise "cyclic include detected"
      else
        parents.insert 0, mod unless parents.includes?(mod)
      end
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
        type = type.types[name]?
        break unless type
      end

      return type if type

      parents.each do |parent|
        match = parent.lookup_type(names, already_looked_up, false)
        return match if match
      end

      lookup_in_container && container ? container.lookup_type(names, already_looked_up) : nil
    end

    def lookup_similar_type_name(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)

      if lookup_in_container
        already_looked_up.add(type_id)
      end

      type = self
      names.each_with_index do |name, idx|
        previous_type = type
        type = previous_type.types[name]?
        unless type
          tolerance = (name.length / 5.0).ceil
          name_downcase = name.downcase
          candidates = [] of String

          previous_type.types.each_key do |type_name|
            if levenshtein(type_name.downcase, name_downcase) <= tolerance
              candidates.push type_name
            end
          end

          if candidates.empty?
            break
          else
            similar_name = candidates.min_by { |candidate| levenshtein(candidate, name) }
            return (names[0 ... idx] + [similar_name]).join "::"
          end
        end
      end

      parents.each do |parent|
        match = parent.lookup_similar_type_name(names, already_looked_up, false)
        return match if match
      end

      lookup_in_container && container ? container.lookup_similar_type_name(names, already_looked_up) : nil
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

    def class_var_owner
      self
    end
  end

  module InheritableClass
    def add_subclass(subclass)
      subclasses << subclass
      notify_subclass_added
      @superclass.try &.notify_subclass_added
    end

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

  module NonGenericOrGenericClassInstanceType
  end

  class NonGenericModuleType < ModuleType
    include DefInstanceContainer
    include ClassVarContainer

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
      @superclass.try &.add_subclass(self)
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
      is_initialize = a_def.name == "initialize"

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

        if is_initialize
          if ivii = @instance_vars_in_initialize
            @instance_vars_in_initialize = ivii & a_def_instance_vars
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
      elsif is_initialize
        # If it's an initialize without instance variables,
        # then *all* instance variables are nilable
        @instance_vars_in_initialize = Set(String).new

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
        defs.each do |def_name, hash|
          hash.each do |restrictions, a_def|
            transfer_instance_vars a_def
          end
        end
      end

      mod.parents.try &.each do |parent|
        transfer_instance_vars_of_mod parent
      end
    end

    make_named_tuple InstanceVarInitializer, [name, value, meta_vars]

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
      if superclass = @superclass
        superclass.allocated = allocated
      end
    end

    def hierarchify
      if self.abstract
        hierarchy_type
      else
        self
      end
    end

    def struct?
      @struct
    end

    def passed_by_value?
      struct?
    end

    def struct_wrapper_of?(type)
      return false unless struct?

      ivars = all_instance_vars
      return false unless ivars.length == 1

      ivars.first_value.type? == type
    end

    def c_value_wrapper?
      return false unless struct?

      ivars = all_instance_vars
      return false unless ivars.length == 1

      type = ivars.first_value.type?
      type.is_a?(CStructType) || type.is_a?(CUnionType)
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
      instance_vars_initializers.try(&.any? { |init| init.name == name }) ||
        instance_vars_in_initialize.try(&.includes?(name)) ||
        superclass.try &.has_instance_var_in_initialize?(name)
    end

    def lookup_similar_instance_var_name(name)
      tolerance = (name.length / 5.0).ceil
      candidates = [] of String

      all_instance_vars.each_key do |ivar_name|
        if name != ivar_name && levenshtein(name, ivar_name) <= tolerance
          candidates << ivar_name
        end
      end

      if candidates.empty?
        nil
      else
        candidates.min_by { |candidate| levenshtein(candidate, name) }
      end
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
        metaclass.add_def Def.new("allocate", [] of Arg, Primitive.new(:allocate))
        metaclass
      end
    end

    def hierarchy_type
      if leaf? && !self.abstract
        self
      else
        @hierarchy_type ||= begin
          HierarchyType.new(program, self)
        end
      end
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
      ivar.freeze_type = true
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

    def struct_wrapper_of?(type)
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

  class VoidType < PrimitiveType
    def void?
      true
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

  module GenericType
    getter type_vars
    property variadic

    def generic_types
      @generic_types ||= {} of Array(Type | ASTNode) => Type
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      instance_type_vars = {} of String => ASTNode
      last_index = self.type_vars.length - 1
      self.type_vars.each_with_index do |name, index|
        if variadic && index == last_index
          types = [] of Type | ASTNode
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

      instance = instance_class.new program, self, instance_type_vars
      generic_types[type_vars] = instance
      initialize_instance instance

      instance.after_initialize
      instance
    end

    def initialize_instance(instance)
      # Nothing
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

    def append_to_s(str)
      super
      str << "("
      type_vars.each_with_index do |type_var, i|
        str << ", " if i > 0
        str << type_var
      end
      str << ")"
    end
  end

  class GenericClassType < ClassType
    include GenericType

    def initialize(program, container, name, superclass, @type_vars, add_subclass = true)
      super(program, container, name, superclass, add_subclass)
      @variadic = false
    end

    def instance_class
      GenericClassInstanceType
    end

    def class?
      true
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
        ivar.freeze_type = true
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
          ivar.freeze_type = true
          instance.instance_vars[name] = ivar
        end
      end
    end

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        metaclass.add_def Def.new("allocate", [] of Arg, Primitive.new(:allocate))
        metaclass
      end
    end

    def type_desc
      struct? ? "generic struct" : "generic class"
    end

    def append_to_s(str)
      super
      str << "("
      type_vars.each_with_index do |type_var, i|
        str << ", " if i > 0
        str << type_var
      end
      str << ")"
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
        if t.is_a?(IncludedGenericModule)
          IncludedGenericModule.new(program, t.module, self, t.mapping)
        else
          t
        end
      end
    end

    def hierarchy_type
      self
    end

    delegate depth, @generic_class
    delegate defs, @generic_class
    delegate sorted_defs, @generic_class
    delegate superclass, @generic_class
    delegate owned_instance_vars, @generic_class
    delegate instance_vars_in_initialize, @generic_class
    delegate instance_vars_initializers, @generic_class
    delegate macros, @generic_class
    delegate :abstract, @generic_class
    delegate :struct?, @generic_class
    delegate :passed_by_value?, @generic_class
    delegate :type_desc, @generic_class

    def class?
      true
    end

    def generic?
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

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)
      already_looked_up.add(type_id)

      if (names.length == 1) && (type_var = type_vars[names[0]]?)
        case type_var
        when Var
          return type_var.type
        else
          return type_var
        end
      end

      type = generic_class
      names.each do |name|
        type = type.types[name]?
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

    def append_to_s(str)
      generic_class.append_full_name(str)
      str << "("
      i = 0
      type_vars.each_value do |type_var|
        str << ", " if i > 0
        if type_var.is_a?(Var)
          type_var.type.append_to_s(str)
        else
          type_var.append_to_s(str)
        end
        i += 1
      end
      str << ")"
    end
  end

  class PointerType < GenericClassType
    def instance_class
      PointerInstanceType
    end

    def pointer?
      true
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

    def pointer_struct_wrapper_of?(type)
      return false unless type.is_a?(PointerInstanceType)

      element_type.struct_wrapper_of?(type.element_type)
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
    def instance_class
      StaticArrayInstanceType
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
      add_def Def.new("length", [] of Arg, Primitive.new(:tuple_length))
      add_def Def.new("[]", ([Arg.new_with_restriction("index", Path.new(["Int32"], true))]), Primitive.new(:tuple_indexer))
      @variadic = true
    end

    def instantiate(type_vars)
      if (instance = generic_types[type_vars]?)
        return instance
      end

      types = [] of Type
      type_vars.each do |type_var|
        types << type_var as Type
      end
      instance = TupleInstanceType.new(program, types)
      generic_types[type_vars] = instance
      initialize_instance instance
      instance.after_initialize
      instance
    end

    def instance_class
      TupleInstanceType
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
      @tuple_indexers[index] ||= Def.new("[]", [Arg.new("index")], TupleIndexer.new(index))
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

    def append_to_s(str)
      str << "{"
      @tuple_types.each_with_index do |tuple_type, i|
        str << ", " if i > 0
        tuple_type.append_to_s(str)
      end
      str << "}"
    end

    def type_desc
      "tuple"
    end
  end

  class IncludedGenericModule < Type
    include MatchesLookup

    getter program
    getter :module
    getter including_class
    getter mapping

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

    def lookup_matches(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
      @module.lookup_matches(name, arg_types, block, owner, type_lookup, matches_array)
    end

    def lookup_matches_without_parents(name, arg_types, block, owner = self, type_lookup = self, matches_array = nil)
      @module.lookup_matches_without_parents(name, arg_types, block, owner, type_lookup, matches_array)
    end

    def lookup_defs(name)
      @module.lookup_defs(name)
    end

    def lookup_similar_def_name(name)
      @module.lookup_similar_def_name(name)
    end

    def lookup_macro(name, args_length)
      @module.lookup_macro(name, args_length)
    end

    def lookup_macros(name)
      @module.lookup_macros(name)
    end

    def match_arg(arg_type, arg, owner, type_lookup, free_vars)
      @module.match_arg(arg_type, arg, owner, type_lookup, free_vars)
    end

    def has_def?(name)
      @module.has_def?(name)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      if (names.length == 1) && (m = @mapping[names[0]]?)
        case @including_class
        when GenericClassType, GenericModuleType
          # skip
        else
          return TypeLookup.lookup(@including_class, m)
        end
      end

      @module.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def lookup_similar_type_name(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      @module.lookup_similar_type_name(names, already_looked_up, lookup_in_container)
    end

    def append_to_s(str)
      @module.append_to_s(str)
      str << "("
      @including_class.append_to_s(str)
      str << ")"
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
      if defs = self.defs
        if existing_defs = defs[a_def.name]?
          existing = existing_defs.first_value?
          if existing
            existing = existing as External
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
      setter = External.new("#{name}=", [Arg.new_with_type("value", type)], Primitive.new(:external_var_set, type), real_name)
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
    delegate sorted_defs, typedef
    delegate macros, typedef

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      typedef.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def parents
      typedef_parents = typedef.parents

      # We need to repoint "self" in included generic modules to this typedef,
      # so "self" restrictions match and don't point to the typdefed type.
      if typedef_parents
        typedef_parents.each_with_index do |t, i|
          if t.is_a?(IncludedGenericModule)
            typedef_parents[i] = IncludedGenericModule.new(program, t.module, self, t.mapping)
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

    def lookup_matches(name, arg_types, block, owner = self, type_lookup = self)
      aliased_type.lookup_matches(name, arg_types, block, owner, type_lookup)
    end

    def lookup_defs(name)
      aliased_type.lookup_defs(name)
    end

    def lookup_first_def(name, block)
      aliased_type.lookup_first_def(name, block)
    end

    def lookup_similar_def_name(name)
      aliased_type.lookup_similar_def_name(name)
    end

    def def_instances
      aliased_type.def_instances
    end

    def add_def_instance(def_object_id, arg_types, block_type, typed_def)
      aliased_type.add_def_instance(def_object_id, arg_types, block_type, typed_def)
    end

    def lookup_def_instance(def_object_id, arg_types, block_type)
      aliased_type.lookup_def_instance(def_object_id, arg_types, block_type)
    end

    def lookup_macro(name, args_length)
      aliased_type.lookup_macro(name, args_length)
    end

    def lookup_macros(name)
      aliased_type.lookup_macros(name)
    end

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

    def cover
      aliased_type.cover
    end

    def cover_length
      aliased_type.cover_length
    end

    def type_desc
      "alias"
    end
  end

  class CStructType < NamedType
    include DefContainer
    include DefInstanceContainer

    getter vars
    property :packed

    def initialize(program, container, name, vars)
      super(program, container, name)
      @name = name
      @vars = {} of String => Var
      @packed = false
      vars.each do |var|
        @vars[var.name] = var
        add_def Def.new("#{var.name}=", [Arg.new_with_type("value", var.type)], Primitive.new(:struct_set))
        add_def Def.new(var.name, [] of Arg, Primitive.new(:struct_get))
      end
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

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        metaclass.add_def Def.new("new", [] of Arg, Primitive.new(:struct_new))
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

  class CUnionType < NamedType
    include DefContainer
    include DefInstanceContainer

    getter vars

    def initialize(program, container, name, vars)
      super(program, container, name)
      @name = name
      @vars = {} of String => Var
      vars.each do |var|
        @vars[var.name] = var
        add_def Def.new("#{var.name}=", [Arg.new_with_type("value", var.type)], Primitive.new(:union_set))
        add_def Def.new(var.name, [] of Arg, Primitive.new(:union_get))
      end
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

    def metaclass
      @metaclass ||= begin
        metaclass = MetaclassType.new(program, self)
        metaclass.add_def Def.new("new", [] of Arg, Primitive.new(:union_new))
        metaclass
      end
    end

    def type_desc
      "union"
    end
  end

  class CEnumType < NamedType
    getter base_type

    def initialize(program, container, name, @base_type, constants)
      super(program, container, name)

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

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      instance_type.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def lookup_similar_type_name(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      instance_type.lookup_similar_type_name(names, already_looked_up, lookup_in_container)
    end

    delegate :abstract, instance_type

    def class_var_owner
      instance_type
    end

    def metaclass?
      true
    end

    def hierarchy_type
      instance_type.hierarchy_type.metaclass
    end

    def types
      raise "MetaclassType doesn't have types"
    end

    def to_s
      @name
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

    def lookup_similar_type_name(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      instance_type.lookup_similar_type_name(names, already_looked_up, lookup_in_container)
    end

    def metaclass?
      true
    end

    def append_to_s(str)
      instance_type.append_to_s(str)
      str << ":Class"
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

    def hierarchify
      if union_types.any? &.abstract
        program.type_merge(union_types.map(&.hierarchify)).not_nil!
      else
        self
      end
    end

    def append_to_s(str)
      str << "("
      @union_types.each_with_index do |union_type, i|
        str << " | " if i > 0
        union_type.append_to_s(str)
      end
      str << ")"
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

    def nilable?
      true
    end

    def not_nil_type
      @union_types.last
    end

    def append_to_s(str)
      not_nil_type.append_to_s(str)
      str << "?"
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

    def append_to_s(str)
      str << "("
      @union_types.last.append_to_s(str)
      str << ")"
      str << "?"
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

    def append_to_s(str)
      @union_types.last.append_to_s(str)
      str << "?"
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
    property! vars

    def initialize(program, container, name, @value, @scope_types = [] of Type, @scope = nil)
      super(program, container, name)
    end

    def type_desc
      "constant"
    end
  end

  module HierarchyTypeLookup
    def lookup_matches(name, arg_types, block, owner = self, type_lookup = self)
      base_type_lookup = hierarchy_lookup(base_type)
      base_type_matches = base_type_lookup.lookup_matches(name, arg_types, block, self)

      # If there are no subclasses no need to look further
      if leaf?
        return base_type_matches
      end

      base_type_covers_all = base_type_matches.cover_all?

      # If the base type doesn't cover every possible type combination, it's a failure
      if !base_type.abstract && !base_type_covers_all
        return Matches.new(base_type_matches.matches, base_type_matches.cover, base_type_lookup, false)
      end

      type_to_matches = nil
      matches = base_type_matches.matches

      # Traverse all subtypes
      instance_type.subtypes(base_type).each do |subtype|
        unless subtype.value?
          subtype = subtype as NonGenericOrGenericClassInstanceType

          subtype_lookup = hierarchy_lookup(subtype)
          subtype_hierarchy_lookup = hierarchy_lookup(subtype.hierarchy_type)

          # Check matches but without parents: only included modules
          subtype_matches = subtype_lookup.lookup_matches_with_modules(name, arg_types, block, subtype_hierarchy_lookup, subtype_hierarchy_lookup)

          # If we didn't find a match in a subclass, and the base type match is a macro
          # def, we need to copy it to the subclass so that @name, @instance_vars and other
          # macro vars resolve correctly.
          if subtype_matches.empty?
            new_subtype_matches = nil

            base_type_matches.each do |base_type_match|
              if base_type_match.def.return_type
                cloned_def = base_type_match.def.clone
                cloned_def.macro_owner = base_type_match.def.macro_owner
                subtype.add_def base_type_match.def
                new_subtype_matches ||= [] of Match
                new_subtype_matches.push Match.new(subtype, cloned_def, base_type_match.type_lookup, base_type_match.arg_types, base_type_match.free_vars)
              end
            end

            if new_subtype_matches
              subtype_matches = Matches.new(new_subtype_matches, Cover.create(arg_types, new_subtype_matches))
            end
          end

          unless subtype.leaf?
            type_to_matches ||= {} of Type => Matches
            type_to_matches[subtype] = subtype_matches
          end

          # If the subtype is non-abstract but doesn't cover all,
          # we need to check if a parent covers it
          if !subtype.abstract && !base_type_covers_all && !subtype_matches.cover_all?
            covered_by_superclass = false
            superclass = subtype.superclass
            while superclass && superclass != base_type
              superclass_matches = type_to_matches.not_nil![superclass]
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
            # We need to insert the matches before the previous ones
            # because subtypes are more specific matches
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

    def initialize(@program, @base_type)
    end

    def check_method_missing(name, arg_types, block)
      method_missing = base_type.lookup_method_missing
      defined = false
      if method_missing
        defined = base_type.define_method_from_method_missing(method_missing, name, arg_types, block) || defined
      end

      defined = add_subclasses_method_missing_matches(base_type, method_missing, name, arg_types, block) || defined
      defined
    end

    def add_subclasses_method_missing_matches(base_type, method_missing, name, arg_types, block)
      defined = false

      base_type.subclasses.each do |subclass|
        subclass = subclass as DefContainer

        # First check if we can find the method
        existing_def = subclass.lookup_first_def(name, block)
        next if existing_def

        subclass_method_missing = subclass.lookup_method_missing

        # Check if the subclass redefined the method_missing
        if subclass_method_missing && subclass_method_missing.object_id != method_missing.object_id
          subclass.define_method_from_method_missing(subclass_method_missing, name, arg_types, block)
          defined = true
        elsif method_missing
          # Otherwise, we need to define this method missing because of macro vars like @name
          subclass.define_method_from_method_missing(method_missing, name, arg_types, block)
          subclass_method_missing = method_missing
          defined = true
        end

        defined = add_subclasses_method_missing_matches(subclass, subclass_method_missing, name, arg_types, block) || defined
      end

      defined
    end

    def leaf?
      base_type.leaf?
    end

    def superclass
      base_type.superclass
    end

    def lookup_first_def(name, block)
      base_type.lookup_first_def(name, block)
    end

    def lookup_defs(name)
      base_type.lookup_defs(name)
    end

    def lookup_similar_def_name(name)
      base_type.lookup_similar_def_name(name)
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

    def lookup_macros(name)
      base_type.lookup_macros(name)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      base_type.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def lookup_similar_type_name(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      base_type.lookup_similar_type_name(names, already_looked_up, lookup_in_container)
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

    def metaclass
      @metaclass ||= HierarchyMetaclassType.new(program, self)
    end

    def is_subclass_of?(other)
      base_type.is_subclass_of?(other)
    end

    def hierarchy?
      true
    end

    def reference_like?
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
        base_type.subclasses.sum &.hierarchy_type.cover_length
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

    def append_to_s(str)
      base_type.append_to_s(str)
      str << "+"
    end

    def name
      to_s
    end
  end

  class HierarchyMetaclassType < Type
    include DefInstanceContainer
    include HierarchyTypeLookup

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

    def lookup_first_def(name, block)
      instance_type.base_type.metaclass.lookup_first_def(name, block)
    end

    def lookup_type(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      instance_type.lookup_type(names, already_looked_up, lookup_in_container)
    end

    def lookup_similar_type_name(names : Array, already_looked_up = Set(Int32).new, lookup_in_container = true)
      instance_type.lookup_similar_type_name(names, already_looked_up, lookup_in_container)
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

    def append_to_s(str)
      instance_type.append_to_s(str)
      str << ":Class"
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

      types = [] of Type
      type_vars.each do |type_var|
        types << type_var as Type
      end

      instance = FunInstanceType.new(program, types)
      generic_types[type_vars] = instance
      initialize_instance instance
      instance.after_initialize
      instance
    end

    def instance_class
      FunInstanceType
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

      args = arg_types.map_with_index { |type, i| Arg.new_with_type("arg#{i}", type) }
      add_def Def.new("call", args, Primitive.new(:fun_call, return_type))
      add_def Def.new("arity", [] of Arg, NumberLiteral.new(fun_types.length - 1, :i32))
      add_def Def.new("closure?", [] of Arg, Primitive.new(:fun_closure?, @program.bool))
      add_def Def.new("to_s", [] of Arg, StringLiteral.new(to_s))
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

    def append_to_s(str)
      str << "("
      len = fun_types.length
      fun_types.each_with_index do |fun_type, i|
        if i == len - 1
          str << " -> "
        elsif i > 0
          str << ", "
        end
        fun_type.append_to_s(str)
      end
      str << ")"
    end
  end
end
