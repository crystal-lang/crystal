module Crystal
  class Type
    include Enumerable

    def metaclass
      @metaclass ||= Metaclass.new(self)
    end

    def instance_type
      self
    end

    def ==(other)
      equal?(other)
    end

    def eql?(other)
      self == other
    end

    def each
      yield self
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

    def nilable_able?
      false
    end

    def pointer_type?
      false
    end

    def passed_as_self?
      true
    end

    def is_restriction_of?(type, owner)
      type.nil? || equal?(type) ||
        type.is_a?(UnionType) && type.types.any? { |union_type| self.is_restriction_of?(union_type, owner) } ||
        generic && container.equal?(type.container) && name == type.name && type.type_vars.values.map(&:type).compact.length == 0 ||
        parents.any? { |parent| parent.is_restriction_of?(type, owner) }
    end

    def implements?(other_type)
      equal?(other_type)
    end

    def filter_by(other_type)
      implements?(other_type) ? self : nil
    end

    def generic
      false
    end

    def restrict(other, owner)
      ((other.nil? || equal?(other)) && self) ||
      (other.is_a?(UnionType) && program.union_of(*other.types.each { |union_type| self.restrict(union_type, owner) })) ||
      (generic && container.equal?(other.container) && name == other.name && !other.type_vars.values.any?(&:type) && self) ||
      (parents.first && parents.first.is_restriction_of?(other, owner) && self)
    end

    def is_subclass_of?(type)
      false
    end

    def to_s
      name
    end

    def self.merge(*types)
      types = types.compact
      return nil if types.empty?
      types.first.program.type_merge(*types)
    end

    def self.clone(types)
      types_context = {}
      types.map { |type| type.clone(types_context) }
    end
  end

  class ContainedType < Type
    attr_accessor :name
    attr_accessor :container

    def initialize(name, container)
      @name = name
      @container = container
    end

    def program
      @container.program
    end

    def full_name
      @container && !@container.is_a?(Program) ? "#{@container}::#{@name}" : @name
    end

    def to_s
      full_name
    end
  end

  class Def
    def is_restriction_of?(other, owner)
      args.zip(other.args).each do |self_arg, other_arg|
        self_type = self_arg.type || self_arg.type_restriction
        other_type = other_arg.type || other_arg.type_restriction
        return false if self_type == nil && other_type != nil
        if self_type != nil && other_type != nil
          return false unless self_type.is_restriction_of?(other_type, owner)
        end
      end
      true
    end
  end

  module DefContainer
    def add_def(a_def)
      a_def.owner = self if a_def.respond_to?(:owner=)
      restrictions = a_def.args.map(&:type_restriction)
      @defs[a_def.name] ||= {}
      @defs[a_def.name][[restrictions, a_def.yields]] = a_def

      index = a_def.args.length - 1
      while index >= 0 && a_def.args[index].default_value
        @defs[a_def.name][[restrictions[0 ... index], a_def.yields]] = a_def
        add_sorted_def(a_def, index)
        index -= 1
      end

      add_sorted_def(a_def, a_def.args.length)

      a_def
    end

    def add_sorted_def(a_def, args_length)
      sorted_defs = @sorted_defs[[a_def.name, args_length, a_def.yields]]
      append = sorted_defs.each_with_index do |ex_def, i|
        if a_def.is_restriction_of?(ex_def, self)
          sorted_defs.insert(i, a_def)
          break false
        end
      end
      sorted_defs << a_def if append
    end

    def match_def_args(args, def_restrictions, owner)
      match = Match.new
      0.upto(args.length - 1) do |i|
        arg_type = args[i]
        restriction = def_restrictions[i]

        match_arg_type = match_arg(arg_type, restriction, owner, match.free_vars) or return nil
        match.arg_types.push match_arg_type
      end
      match
    end

    def match_arg(arg_type, restriction, owner, free_vars)
      case restriction
      when nil
        arg_type
      when :self
        arg_type && arg_type.is_restriction_of?(owner, owner) && owner
      when NewGenericClass
        arg_type && arg_type.generic && match_generic_type(arg_type, restriction, owner, free_vars) && arg_type
      when Ident
        type = free_vars[restriction.names] || owner.lookup_type(restriction.names)
        if type
          arg_type && arg_type.is_restriction_of?(type, owner) && arg_type.restrict(type, owner)
        else
          free_vars[restriction.names] = arg_type
        end
      when IdentUnion
        restriction.idents.any? do |ident|
          match_arg(arg_type, ident, owner, free_vars)
        end && arg_type
      when Type
        arg_type.is_restriction_of?(restriction, owner) && restriction
      end
    end

    def match_generic_type(arg_type, restriction, owner, free_vars)
      return false unless arg_type.name == restriction.name.names.last
      return false unless arg_type.type_vars.length == restriction.type_vars.length

      arg_type.type_vars.each.with_index do |name_and_type_var, i|
        arg_type_var = name_and_type_var[1]
        restriction_var = restriction.type_vars[i]
        return false unless match_arg(arg_type_var.type, restriction_var, owner, free_vars)
      end
      true
    end

    def lookup_matches(name, arg_types, yields, owner = self)
      if @sorted_defs && @sorted_defs.has_key?([name, arg_types.length, yields])
        defs = @sorted_defs[[name, arg_types.length, yields]]
        matches = []
        defs.each do |a_def|
          def_restrictions = a_def.args.map(&:type_restriction)
          match = match_def_args(arg_types, def_restrictions, owner)
          if match
            match.def = a_def
            matches.push match
            break if match.arg_types == arg_types
          end
        end
        return matches
      end

      if parents && !(name == 'new' && owner.is_a?(Metaclass))
        parents.each do |parent|
          matches = parent.lookup_matches(name, arg_types, yields, owner)
          return matches if matches && matches.any?
        end
      end

      nil
    end

    def lookup_def(name, args, yields, owner = self)
      defs = @defs[name]
      error_matches = defs.values if defs
      if defs
        if args
          matches = []
          defs.each do |def_restrictions_and_yields, a_def|
            def_restrictions, def_yields = def_restrictions_and_yields
            next false if def_yields != yields
            next false if def_restrictions.length != args.length
            free_vars = match_def_args(args.map(&:type), def_restrictions, owner)
            if free_vars
              matches.push [a_def, free_vars]
            end
          end

          return matches.first if matches.length == 1

          error_matches = matches.map { |m| m[0] } if matches.length > 0

          minimals = matches.select do |a_def, free_vars|
            matches.all? { |m| m[0].equal?(a_def) || a_def.is_restriction_of?(m[0], owner) }
          end
          return minimals.first if minimals.length == 1

          error_matches = minimals if minimals.length > 0
        else
          return defs.first[1] if defs.length == 1
        end
      end

      if parents && !(name == 'new' && owner.is_a?(Metaclass))
        parents.each do |parent|
          result, free_vars, errors = parent.lookup_def(name, args, yields, owner)
          return [result, free_vars, errors] if result
        end
      end

      [nil, nil, error_matches]
    end

    def lookup_first_def(name)
      defs = @defs[name]
      if defs && defs.length == 1
        return defs.first[1]
      end
      nil
    end

    def add_def_instance(name, arg_types, typed_def)
      @def_instances[[name] + arg_types.map(&:object_id)] = typed_def
    end

    def lookup_def_instance(name, arg_types)
      @def_instances[[name] + arg_types.map(&:object_id)]
    end

    def add_macro(a_def)
      @macros ||= {}
      @macros[a_def.name] ||= {}
      @macros[a_def.name][a_def.args.length] = a_def
    end

    def lookup_macro(name, args_length)
      if @macros && (macros = @macros[name]) && (macro = macros[args_length])
        return macro
      end

      if parents
        parents.each do |parent|
          macro = parent.lookup_macro(name, args_length)
          return macro if macro
        end
      end

      nil
    end
  end

  class ModuleType < ContainedType
    include DefContainer

    attr_accessor :defs
    attr_accessor :sorted_defs
    attr_accessor :types
    attr_accessor :parents
    attr_accessor :type_vars

    def initialize(name, container = nil, parents = [])
      super(name, container)
      @parents = parents
      @defs = {}
      @sorted_defs ||= Hash.new { |h, k| h[k] = [] }
      @def_instances = {}
      @types = {}
    end

    def generic
      @type_vars
    end

    def include(mod)
      @parents.insert 0, mod unless @parents.any? { |parent| parent.equal?(mod) }
    end

    def implements?(other_type)
      super || parents.any? { |parent| parent.implements?(other_type) }
    end

    def lookup_type(names, already_looked_up = {})
      return nil if already_looked_up[object_id]
      already_looked_up[object_id] = true

      if type_vars && names.length == 1 && type_var = type_vars[names[0]]
        return type_var.type
      end

      type = self
      names.each do |name|
        type = type.types[name]
        break unless type
      end

      return type if type

      parents.each do |parent|
        match = parent.lookup_type(names, already_looked_up)
        return match if match
      end

      container ? container.lookup_type(names, already_looked_up) : nil
    end

    def to_s
      return full_name unless generic
      type_vars_to_s = type_vars.map { |name, var| var.type ? var.type.to_s : name }.join ', '
      "#{full_name}(#{type_vars_to_s})"
    end
  end

  class ClassType < ModuleType
    def initialize(name, parent_type, container = nil)
      super(name, container, parent_type ? [parent_type] : [])
    end

    def superclass
      @superclass ||= @parents.find { |parent| parent.is_a?(ClassType) }
    end

    def is_subclass_of?(type)
      return true if equal?(type)

      superclass && superclass.is_subclass_of?(type)
    end
  end

  class PrimitiveType < ClassType
    attr_reader :llvm_type
    attr_reader :llvm_size

    def initialize(name, parent_type, llvm_type, llvm_size, container = nil)
      super(name, parent_type, container)
      @llvm_type = llvm_type
      @llvm_size = llvm_size
    end

    def nil_type?
      @nil_type ||= name == 'Nil'
    end

    def llvm_name
      name
    end

    def clone(*)
      self
    end
  end

  class ObjectType < ClassType
    attr_accessor :instance_vars
    attr_accessor :depth
    attr_accessor :subclasses
    attr_reader :hash
    @@id = 0

    def initialize(name, parent_type = nil, container = nil)
      super
      @instance_vars = {}
      @subclasses = []
      @hash = name.hash
      if parent_type
        @depth = parent_type.depth + 1
        parent_type.subclasses.push self
      else
        @depth = 0
      end
    end

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

    def add_def(a_def)
      super

      if a_def.instance_vars
        a_def.instance_vars.each do |ivar|
          unless superclass.has_instance_var?(ivar)
            @instance_vars[ivar] ||= Var.new(ivar)
          end
        end
      end

      a_def
    end

    def has_instance_var?(name)
      (superclass &&  superclass.has_instance_var?(name)) || @instance_vars[name]
    end

    def lookup_instance_var(name, create = true)
      if superclass && (var = superclass.lookup_instance_var(name, false))
        return var
      end

      if create
        @instance_vars[name] ||= Var.new name
      else
        @instance_vars[name]
      end
    end

    def each_instance_var(&block)
      if superclass
        superclass.each_instance_var(&block)
      end

      @instance_vars.each(&block)
    end

    def all_instance_vars
      if superclass
        superclass.all_instance_vars.merge(@instance_vars)
      else
        @instance_vars
      end
    end

    def ==(other)
      equal?(other) || (generic && (structurally_equal?(other) || (other.is_a?(UnionType) && other == self)))
    end

    def structurally_equal?(other)
      other.is_a?(ObjectType) && name == other.name && type_vars == other.type_vars && all_instance_vars == other.all_instance_vars
    end

    def llvm_type
      @llvm_type ||= LLVM::Pointer(llvm_struct_type)
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end

    def llvm_struct_type
      unless @llvm_struct_type
        @llvm_struct_type = LLVM::Struct(llvm_name)
        @llvm_struct_type.element_types = @instance_vars.values.map(&:llvm_type)
      end
      @llvm_struct_type
    end

    def llvm_name
      if generic
        @id ||= (@@id += 1)
        "#{name}#{@id}"
      else
        name
      end
    end

    def nilable_able?
      true
    end

    def index_of_instance_var(name)
      @instance_vars.keys.index(name)
    end

    def clone(types_context = {})
      return self if !generic

      obj = types_context[object_id] and return obj

      obj = types_context[object_id] = ObjectType.new name, superclass, @container
      obj.instance_vars = Hash[instance_vars.map do |name, var|
        cloned_var = var.clone
        cloned_var.type = var.type.clone(types_context) if var.type
        cloned_var.bind_to cloned_var
        [name, cloned_var]
      end]
      obj.defs = defs
      obj.sorted_defs = sorted_defs
      obj.types = types
      obj.parents = parents
      obj.type_vars = Hash[type_vars.map { |k, v| [k, Var.new(k)] }] if type_vars
      obj
    end
  end

  class PointerType < ClassType
    def initialize(parent_type = nil, container = nil)
      super("Pointer", parent_type, container)
    end

    def var
      @type_vars["T"]
    end

    def ==(other)
      equal?(other) || (other.is_a?(PointerType) && type_vars == other.type_vars) || (other.is_a?(UnionType) && other == self)
    end

    def hash
      1
    end

    def clone(types_context = {})
      pointer = types_context[object_id] and return pointer

      pointer = types_context[object_id] = PointerType.new @parent_type, @container
      pointer.defs = defs
      pointer.sorted_defs = sorted_defs
      pointer.types = types
      pointer.parents = parents
      pointer.type_vars = Hash[type_vars.map { |k, v| [k, Var.new(k)] }] if type_vars
      pointer
    end

    def nilable_able?
      true
    end

    def pointer_type?
      true
    end

    def llvm_type
      @llvm_type ||= var.type.is_a?(StructType) ? var.type.llvm_type : LLVM::Pointer(var.type.llvm_type)
    end

    def llvm_name
      @llvm_name ||= "Pointer<#{var.type.llvm_name}>"
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end
  end

  class UnionType < Type
    attr_reader :types

    def initialize(*types)
      @types = types
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

    def target_type
      self
    end

    def filter_by(other_type)
      filtered_types = @types.map { |type| type.filter_by(other_type) }.compact
      case filtered_types.length
      when 0
        nil
      when 1
        filtered_types[0]
      else
        UnionType.new(*filtered_types)
      end
    end

    def nilable?
      @nilable ||= (@types.length == 2 &&
        (@types[0].nil_type? && types[1].nilable_able? && types[1] ||
         @types[1].nil_type? && types[0].nilable_able? && types[0]))
    end

    def nilable_type
      @nilable
    end

    def union?
      !nilable?
    end

    def set
      @set ||= types.to_set
    end

    def llvm_type
      unless @llvm_type
        if nilable?
          @llvm_type = nilable_type.llvm_type
        else
          @llvm_type = LLVM::Struct(llvm_name)
          @llvm_type.element_types = [LLVM::Int, llvm_value_type]
        end
      end
      @llvm_type
    end

    def llvm_name
      "[#{types.map(&:llvm_name).join ', '}]"
    end

    def llvm_size
      @llvm_size ||= llvm_value_size + 4
    end

    def llvm_value_type
      @llvm_value_type ||= LLVM::Type.array(LLVM::Int, llvm_value_size.fdiv(LLVM::Int.type.width / 8).ceil)
    end

    def llvm_value_size
      @llvm_value_size ||= @types.map(&:llvm_size).max
    end

    def index_of_type(type)
      @types.index type
    end

    def parents
      []
    end

    def each(&block)
      types.each(&block)
    end

    def hash
      @hash ||= set.hash
    end

    def ==(other)
      return true if equal?(other)
      set = set()
      (other.is_a?(UnionType) && set == other.set) || (!other.is_a?(UnionType) && set.length == 1 && types[0] == other)
    end

    def clone(types_context = {})
      cloned = types_context[object_id] and return cloned
      types_context[object_id] = UnionType.new(*types.map { |type| type.clone(types_context) })
    end

    def name
      "Union"
    end

    def is_restriction_of?(type, owner)
      types.any? { |sub| sub.is_restriction_of?(type, owner) }
    end

    def restrict(type, owner)
      program.union_of(*types.select { |sub| sub.is_restriction_of?(type, owner) })
    end

    def to_s
      types.join " | "
    end
  end

  class Metaclass < ModuleType
    attr_reader :name
    attr_reader :type

    def initialize(type)
      super("#{type}:Class", type.container)
      @type = type
      add_def Def.new('name', [], StringLiteral.new(type.to_s))
      add_def Def.new('simple_name', [], StringLiteral.new(type.name))
      add_def Def.new('inspect', [], Call.new(nil, 'to_s'))
      add_def Def.new('to_s', [], Call.new(nil, 'name'))
    end

    def parents
      type.parents ? type.parents.map(&:metaclass) : nil
    end

    def instance_type
      type
    end

    def lookup_type(names)
      instance_type.lookup_type(names)
    end

    def llvm_type
      LLVM::Int
    end

    def llvm_name
      name
    end

    def llvm_size
      4
    end

    def generic
      type.generic
    end

    def type_vars
      type.type_vars
    end

    def to_s
      "#{instance_type}:Class"
    end
  end

  class LibType < ModuleType
    attr_accessor :libname

    def initialize(name, libname = nil, container = nil)
      super(name, container)
      @libname = libname
    end

    def metaclass
      self
    end

    def fun(name, real_name, args, return_type, varargs)
      instance = add_def External.new(name, args)
      instance.real_name = real_name
      instance.varargs = varargs
      instance.owner = self
      instance.type = return_type
    end

    def passed_as_self?
      false
    end

    def ==(other)
      other.is_a?(LibType) && other.name == name && other.libname == libname
    end

    def to_s
      name
    end
  end

  class TypeDefType < ContainedType
    attr_accessor :type

    def initialize(name, type, container = nil)
      super(name, container)
      @type = type
    end

    def ==(other)
      other.is_a?(TypeDefType) && other.name == name && other.type == type
    end

    def llvm_type
      type.llvm_type
    end

    def llvm_name
      type.llvm_name
    end

    def llvm_size
      type.llvm_size
    end

    def nilable_able?
      type.nilable_able?
    end

    def pointer_type?
      type.pointer_type?
    end

    def clone(*)
      self
    end

    def to_s
      name
    end
  end

  class StructType < ContainedType
    include DefContainer

    attr_accessor :vars
    attr_accessor :defs
    attr_accessor :sorted_defs

    def initialize(name, vars, container = nil)
      super(name, container)
      @name = name
      @vars = Hash[vars.map { |var| [var.name, var] }]
      @defs = {}
      @sorted_defs ||= Hash.new { |h, k| h[k] = [] }
      @def_instances = {}
      @vars.values.each do |var|
        add_def Def.new("#{var.name}=", [Arg.new_with_type('value', var.type)], StructSet.new(var.name))
        add_def Def.new(var.name, [], StructGet.new(var.name))
      end
    end

    def parents
      nil
    end

    def metaclass
      @metaclass ||= begin
        metaclass = Metaclass.new(self)
        metaclass.add_def Def.new('new', [], StructAlloc.new(self))
        metaclass
      end
    end

    def llvm_name
      name
    end

    def llvm_type
      @llvm_type ||= LLVM::Pointer(llvm_struct_type)
    end

    def llvm_size
      Crystal::Program::POINTER_SIZE
    end

    def llvm_struct_type
      unless @llvm_struct_type
        @llvm_struct_type = LLVM::Struct(llvm_name)
        @llvm_struct_type.element_types = @vars.values.map(&:llvm_type)
      end
      @llvm_struct_type
    end

    def index_of_var(name)
      @vars.keys.index(name)
    end

    def ==(other)
      other.is_a?(StructType) && other.name == name && other.vars == vars
    end

    def clone(*)
      self
    end

    def to_s
      return @to_s if @to_s
      @to_s = "..."
      vars_to_s = vars.map {|name, var| "#{name}: #{var.type}"}.join ', '
      @to_s = nil
      "#{name}<#{vars_to_s}>"
    end
  end

  class Const < ContainedType
    attr_accessor :value

    def initialize(name, value, container = nil)
      super(name, container)
      @value = value
    end

    def to_s
      "#{super} = #{value}"
    end
  end

  class SelfType
    def self.is_restriction_of?(type, owner)
      owner.is_restriction_of?(type, owner)
    end

    def self.to_s
      "self"
    end

    def self.parents
      []
    end
  end

  class TypeVarType
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def is_restriction_of?(type, owner)
      @type_var = owner.type_vars[name]
      @type_var.type.is_restriction_of?(type, owner)
    end

    def to_s
      @type_var ? @type_var.type.to_s : name
    end
  end

  class HierarchyType
    attr_accessor :base_type

    def initialize(base_type)
      @base_type = base_type
    end

    def ==(other)
      other.is_a?(HierarchyType) && base_type == other.base_type
    end

    def is_restriction_of?(type, owner)
      type.is_subclass_of?(self.base_type) || self.base_type.is_subclass_of?(type)
    end

    def restrict(type, owner)
      if type.is_subclass_of?(self.base_type)
        type.hierarchy_type
      elsif self.base_type.is_subclass_of?(type)
        self
      else
        nil
      end
    end

    def each(&block)
      each2 base_type, &block
    end

    def each2(type, &block)
      block.call type
      type.subclasses.each do |subclass|
        each2 subclass, &block
      end
    end

    def program
      base_type.program
    end

    def to_s
      "#{base_type}+"
    end
  end
end