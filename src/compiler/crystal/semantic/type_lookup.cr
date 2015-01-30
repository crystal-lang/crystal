require "../types"

module Crystal
  class TypeLookup < Visitor
    getter! type

    def self.lookup(root_type, node, self_type = root_type)
      lookup = new root_type, self_type
      node.accept lookup
      lookup.type.not_nil!
    end

    def initialize(@root)
      @self_type = @root
    end

    def initialize(@root, @self_type)
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
        node.raise("undefined constant #{node}")
      end
    end

    def visit(node : Union)
      types = node.types.map do |ident|
        ident.accept self
        type
      end
      @type = program.type_merge(types)
      false
    end

    def end_visit(node : Virtual)
      @type = type.instance_type.virtual_type
    end

    def end_visit(node : Metaclass)
      @type = type.virtual_type
    end

    def visit(node : Generic)
      node.name.accept self

      instance_type = @type.not_nil!
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.variadic
        min_needed = instance_type.type_vars.length - 1
        if node.type_vars.length < min_needed
          node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{min_needed}..)"
        end
      else
        if instance_type.type_vars.length != node.type_vars.length
          node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{instance_type.type_vars.length})"
        end
      end

      type_vars = node.type_vars.map do |type_var|
        type_var.accept self
        @type.not_nil! as TypeVar
      end
      @type = instance_type.instantiate(type_vars)
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
        output.accept self
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
      meta_vars = MetaVars { "self": MetaVar.new("self", @self_type) }
      visitor = TypeVisitor.new(program, meta_vars)
      node.expressions.each &.accept visitor
      @type = program.type_merge node.expressions
      false
    end

    def visit(node : Underscore)
      node.raise "can't use underscore as generic type argument"
    end
  end

  alias TypeIdSet = Set(Int32)

  class Type
    def lookup_type(node : Path)
      (node.global ? program : self).lookup_type(node.names)
    rescue ex
      node.raise ex.message
    end

    def lookup_type(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
      raise "Bug: #{self} doesn't implement lookup_type"
    end

    def lookup_type_in_parents(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = false)
      raise "Bug: #{self} doesn't implement lookup_type_in_parents"
    end
  end

  class ContainedType
    def lookup_type(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)

      if lookup_in_container
        already_looked_up.add(type_id)
      end

      type = self
      names.each_with_index do |name, i|
        next_type = type.types[name]?
        if !next_type && i != 0
          next_type = type.lookup_type_in_parents(names[i .. -1])
        end
        type = next_type
        break unless type
      end

      return type if type

      parent_match = lookup_type_in_parents(names, already_looked_up)
      return parent_match if parent_match

      lookup_in_container && container ? container.lookup_type(names, already_looked_up) : nil
    end

    def lookup_type_in_parents(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = false)
      parents.try &.each do |parent|
        match = parent.lookup_type(names, already_looked_up, lookup_in_container)
        if match.is_a?(Type)
          return match
        end
      end
      nil
    end
  end

  class GenericClassInstanceType
    def lookup_type(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
      if !names.empty? && (type_var = type_vars[names[0]]?)
        case type_var
        when Var
          type_var_type = type_var.type
        else
          type_var_type = type_var
        end

        if names.length > 1
          if type_var_type.is_a?(Type)
            type_var_type.lookup_type(names[1 .. -1], already_looked_up, lookup_in_container)
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
    def lookup_type(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
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
  end

  class InheritedGenericClass
    def lookup_type(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
      if (names.length == 1) && (m = @mapping[names[0]]?)
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
    def lookup_type(names : Array, already_looked_up = TypeIdSet.new, lookup_in_container = true)
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
end
