require "../types"

module Crystal
  class TypeLookup < Visitor
    getter! type : Type
    @root : Type
    @self_type : Type
    @raise : Bool

    def self.lookup(root_type, node, self_type = root_type, allow_typeof = true)
      lookup = new root_type, self_type, allow_typeof: allow_typeof
      node.clone.accept lookup
      lookup.type.not_nil!
    end

    def self.lookup?(root_type, node, self_type = root_type, allow_typeof = true)
      lookup = new root_type, self_type, raise: false, allow_typeof: allow_typeof
      node.clone.accept lookup
      lookup.type?
    end

    def initialize(@root)
      @self_type = @root
      @raise = true
      @allow_typeof = true
    end

    def initialize(@root, @self_type, @raise = true, @allow_typeof = true)
    end

    delegate program, to: @root

    def visit(node : ASTNode)
      true
    end

    def visit(node : Path)
      the_type = @root.lookup_type(node)
      if the_type && the_type.is_a?(Type)
        @type = the_type.remove_alias_if_simple
      else
        TypeLookup.check_cant_infer_generic_type_parameter(@root, node) if @raise

        node.raise("undefined constant #{node}") if @raise
      end
    end

    def visit(node : Union)
      types = node.types.map do |ident|
        @type = nil
        ident.accept self
        return false if !@raise && !@type

        Crystal.check_type_allowed_in_generics(ident, type, "can't use #{type} in a union type")

        type.virtual_type
      end
      @type = program.type_merge(types)
      false
    end

    def visit(node : Metaclass)
      node.name.accept self
      @type = type.virtual_type.metaclass.virtual_type
      false
    end

    def visit(node : Generic)
      node.name.accept self
      return false if !@raise && !@type

      instance_type = self.type
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.is_a?(NamedTupleType)
        named_args = node.named_args
        unless named_args
          node.raise "can only instantiate NamedTuple with named arguments"
        end

        entries = named_args.map do |named_arg|
          node = named_arg.value

          if node.is_a?(NumberLiteral)
            node.raise "can't use number as type for NamedTuple"
          end

          node.accept self
          return false if !@raise && !@type

          Crystal.check_type_allowed_in_generics(node, type, "can't use #{type} as a generic type argument")
          NamedArgumentType.new(named_arg.name, type.virtual_type)
        end

        begin
          @type = instance_type.instantiate_named_args(entries)
        rescue ex : Crystal::Exception
          node.raise "instantiating #{node}", inner: ex if @raise
        end

        return false
      elsif instance_type.splat_index
        if node.named_args
          node.raise "can only use named arguments with NamedTuple"
        end

        min_needed = instance_type.type_vars.size - 1
        if node.type_vars.size < min_needed
          node.wrong_number_of "type vars", instance_type, node.type_vars.size, "#{min_needed}+"
        end
      else
        if node.named_args
          node.raise "can only use named arguments with NamedTuple"
        end

        if instance_type.type_vars.size != node.type_vars.size
          node.wrong_number_of "type vars", instance_type, node.type_vars.size, instance_type.type_vars.size
        end
      end

      type_vars = Array(TypeVar).new(node.type_vars.size + 1)
      node.type_vars.each do |type_var|
        case type_var
        when NumberLiteral
          type_vars << type_var
        when Splat
          @type = nil
          type_var.exp.accept self
          return false if !@raise && !@type

          splat_type = type
          if splat_type.is_a?(TupleInstanceType)
            type_vars.concat splat_type.tuple_types
          else
            return false if !@raise

            type_var.raise "can only splat tuple type, not #{splat_type}"
          end
        else
          # Check the case of T resolving to a number
          if type_var.is_a?(Path) && type_var.names.size == 1
            the_type = @root.lookup_type(type_var)
            if the_type.is_a?(ASTNode)
              type_vars << the_type
              next
            end
          end

          @type = nil
          type_var.accept self
          return false if !@raise && !@type

          Crystal.check_type_allowed_in_generics(type_var, type, "can't use #{type} as a generic type argument")

          type_vars << type.virtual_type
        end
      end

      begin
        @type = instance_type.instantiate(type_vars)
      rescue ex : Crystal::Exception
        node.raise "instantiating #{node}", inner: ex if @raise
      end

      false
    end

    def visit(node : ProcNotation)
      types = [] of Type
      if inputs = node.inputs
        inputs.each do |input|
          if input.is_a?(Splat)
            input.exp.accept self
            return false if !@raise && !@type

            a_type = type
            if a_type.is_a?(TupleInstanceType)
              types.concat(a_type.tuple_types)
            else
              if @raise
                input.exp.raise "can only splat tuple type, not #{a_type}"
              else
                return false
              end
            end
          else
            input.accept self
            return false if !@raise && !@type

            Crystal.check_type_allowed_in_generics(input, type, "can't use #{type} as proc argument")

            types << type.virtual_type
          end
        end
      end

      if output = node.output
        @type = nil
        output.accept self
        return false if !@raise && !@type

        Crystal.check_type_allowed_in_generics(output, type, "can't use #{type} as proc return type")

        types << type.virtual_type
      else
        types << program.void
      end

      @type = program.proc_of(types)
      false
    end

    def visit(node : Self)
      @type = @self_type.virtual_type
      false
    end

    def visit(node : TypeOf)
      unless @allow_typeof
        if @raise
          node.raise "can't use 'typeof' here"
        else
          return false
        end
      end

      meta_vars = MetaVars{"self" => MetaVar.new("self", @self_type)}
      visitor = MainVisitor.new(program, meta_vars)
      begin
        node.expressions.each &.accept visitor
      rescue ex : Crystal::Exception
        node.raise "typing typeof", inner: ex
      end
      @type = program.type_merge node.expressions
      false
    end

    def visit(node : Underscore)
      node.raise "can't use underscore as generic type argument" if @raise
    end

    def self.check_cant_infer_generic_type_parameter(scope, node : Path)
      if scope.is_a?(MetaclassType) && (instance_type = scope.instance_type).is_a?(GenericClassType)
        first_name = node.names.first
        if instance_type.type_vars.includes?(first_name)
          node.raise "can't infer the type parameter #{first_name} for the #{instance_type.type_desc} #{instance_type}. Please provide it explicitly"
        end
      end
    end
  end

  alias ObjectIdSet = Set(UInt64)

  class Type
    def lookup_type(node : Path, lookup_in_container = true)
      (node.global ? program : self).lookup_type(node.names, lookup_in_container: lookup_in_container)
    rescue ex : Crystal::Exception
      raise ex
    rescue ex
      node.raise ex.message
    end

    def lookup_type(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      raise "Bug: #{self} doesn't implement lookup_type"
    end

    def lookup_type_in_parents(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = false)
      raise "Bug: #{self} doesn't implement lookup_type_in_parents"
    end
  end

  class NamedType
    def lookup_type(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      return nil if already_looked_up.includes?(object_id)

      if lookup_in_container
        already_looked_up.add(object_id)
      end

      type = self
      names.each_with_index do |name, i|
        next_type = type.types?.try &.[name]?
        if !next_type && i != 0
          next_type = type.lookup_type_in_parents(names[i..-1])
          if next_type
            type = next_type
            break
          end
        end
        type = next_type
        break unless type
      end

      return type if type

      parent_match = lookup_type_in_parents(names, already_looked_up)
      return parent_match if parent_match

      lookup_in_container && container ? container.lookup_type(names, already_looked_up) : nil
    end

    def lookup_type_in_parents(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = false)
      parents.try &.each do |parent|
        match = parent.lookup_type(names, already_looked_up, lookup_in_container)
        if match.is_a?(Type)
          return match
        end
      end
      nil
    end
  end

  module GenericType
    def lookup_type(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      # If we are Foo(T) and somebody looks up the type T, we return `nil` because we don't
      # know what type T is, and we don't want to continue search in the container
      if !names.empty? && type_vars.includes?(names[0])
        return nil
      end
      super
    end
  end

  class GenericClassInstanceType
    def lookup_type(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      if !names.empty? && (type_var = type_vars[names[0]]?)
        case type_var
        when Var
          type_var_type = type_var.type
        else
          type_var_type = type_var
        end

        if names.size > 1
          if type_var_type.is_a?(Type)
            type_var_type.lookup_type(names[1..-1], already_looked_up, lookup_in_container)
          else
            raise "#{names[0]} is not a type, it's #{type_var_type}"
          end
        else
          type_var_type
        end
      else
        generic_class.lookup_type(names, already_looked_up, lookup_in_container)
      end
    end
  end

  class IncludedGenericModule
    def lookup_type(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      if (names.size == 1) && (m = @mapping[names[0]]?)
        # Case of a variadic tuple
        if m.is_a?(TupleLiteral)
          types = m.elements.map do |element|
            TypeLookup.lookup(@including_class, element).as(Type)
          end
          return program.tuple_of(types)
        end

        case @including_class
        when GenericClassType, GenericModuleType
          # skip
        else
          return TypeLookup.lookup(@including_class, m)
        end
      end

      @module.lookup_type(names, already_looked_up, lookup_in_container)
    end
  end

  class InheritedGenericClass
    def lookup_type(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      if (names.size == 1) && (m = @mapping[names[0]]?)
        case extending_class
        when GenericClassType
          # skip
        else
          return TypeLookup.lookup(extending_class, m)
        end
      end

      @extended_class.lookup_type(names, already_looked_up, lookup_in_container)
    end
  end

  class UnionType
    def lookup_type(names : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      if names.size == 1 && names[0] == "T"
        return program.tuple_of(union_types)
      end
      program.lookup_type(names, already_looked_up, lookup_in_container)
    end
  end

  class TypeDefType
    def lookup_type(node : Path, lookup_in_container = true)
      typedef.lookup_type(node, lookup_in_container: lookup_in_container)
    end

    def lookup_type(node : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      typedef.lookup_type(node, already_looked_up: already_looked_up, lookup_in_container: lookup_in_container)
    end
  end

  class MetaclassType
    def lookup_type(node : Path, lookup_in_container = true)
      instance_type.lookup_type(node, lookup_in_container: lookup_in_container)
    end

    def lookup_type(node : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      instance_type.lookup_type(node, already_looked_up: already_looked_up, lookup_in_container: lookup_in_container)
    end
  end

  class GenericClassInstanceMetaclassType
    def lookup_type(node : Path, lookup_in_container = true)
      instance_type.lookup_type(node, lookup_in_container: lookup_in_container)
    end

    def lookup_type(node : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      instance_type.lookup_type(node, already_looked_up: already_looked_up, lookup_in_container: lookup_in_container)
    end
  end

  class VirtualType
    def lookup_type(node : Path, lookup_in_container = true)
      base_type.lookup_type(node, lookup_in_container: lookup_in_container)
    end

    def lookup_type(node : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      base_type.lookup_type(node, already_looked_up: already_looked_up, lookup_in_container: lookup_in_container)
    end
  end

  class VirtualMetaclassType
    def lookup_type(node : Path, lookup_in_container = true)
      instance_type.lookup_type(node, lookup_in_container: lookup_in_container)
    end

    def lookup_type(node : Array, already_looked_up = ObjectIdSet.new, lookup_in_container = true)
      instance_type.lookup_type(node, already_looked_up: already_looked_up, lookup_in_container: lookup_in_container)
    end
  end

  class AliasType
    delegate types, to: aliased_type
    delegate types?, to: aliased_type
  end
end
