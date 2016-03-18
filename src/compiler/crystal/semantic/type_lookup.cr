require "../types"

module Crystal
  class TypeLookup < Visitor
    getter! type : Type
    @root : Type
    @self_type : Type
    @raise : Bool

    def self.lookup(root_type, node, self_type = root_type)
      lookup = new root_type, self_type
      node.clone.accept lookup
      lookup.type.not_nil!
    end

    def initialize(@root)
      @self_type = @root
      @raise = true
    end

    def initialize(@root, @self_type)
      @raise = true
    end

    delegate program, @root

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

        type
      end
      @type = program.type_merge(types)
      false
    end

    def end_visit(node : Virtual)
      @type = type.instance_type.virtual_type
    end

    def end_visit(node : Metaclass)
      @type = type.metaclass.virtual_type
    end

    def visit(node : Generic)
      node.name.accept self

      instance_type = @type.not_nil!
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.variadic
        min_needed = instance_type.type_vars.size - 1
        if node.type_vars.size < min_needed
          node.wrong_number_of "type vars", instance_type, node.type_vars.size, "#{min_needed}+"
        end
      else
        if instance_type.type_vars.size != node.type_vars.size
          node.wrong_number_of "type vars", instance_type, node.type_vars.size, instance_type.type_vars.size
        end
      end

      type_vars = node.type_vars.map do |type_var|
        @type = nil
        type_var.accept self
        return false if !@raise && !@type

        type.virtual_type as TypeVar
      end

      begin
        @type = instance_type.instantiate(type_vars)
      rescue ex : Crystal::Exception
        node.raise ex.message if @raise
      end

      false
    end

    def visit(node : Fun)
      types = [] of Type
      if inputs = node.inputs
        inputs.each do |input|
          input.accept self
          types << type
        end
      end

      if output = node.output
        @type = nil
        output.accept self
        return false if !@raise && !@type

        types << type
      else
        types << program.void
      end

      @type = program.fun_of(types)
      false
    end

    def visit(node : Self)
      @type = @self_type
      false
    end

    def visit(node : TypeOf)
      meta_vars = MetaVars{"self": MetaVar.new("self", @self_type)}
      visitor = MainVisitor.new(program, meta_vars)
      node.expressions.each &.accept visitor
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
    def lookup_type(node : Path)
      (node.global ? program : self).lookup_type(node.names)
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
      raise "can't lookup type in union #{self}"
    end
  end

  class TypeDefType
    delegate lookup_type, typedef
  end

  class MetaclassType
    delegate lookup_type, instance_type
  end

  class GenericClassInstanceMetaclassType
    delegate lookup_type, instance_type
  end

  class VirtualType
    delegate lookup_type, base_type
  end

  class VirtualMetaclassType
    delegate lookup_type, instance_type
  end

  class AliasType
    delegate types, aliased_type
    delegate types?, aliased_type
  end
end
