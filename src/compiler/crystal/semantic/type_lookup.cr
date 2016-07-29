require "../types"

class Crystal::Type
  # Searches the type that corresponds to the given *node*, relative
  # to `self`.
  #
  # This method handles AST nodes in the type grammar:
  #
  # - Path: Foo::Bar::Baz
  # - Union: T | U
  # - Metaclass: T.class
  # - Generic: Foo(T)
  # - ProcNotation: T -> U
  # - TypeOf: typeof(...)
  # - Self: self
  #
  # Passing other AST nodes will raise an exception.
  #
  # *self_type* is the type that will be used when `self` is encountered
  # in the node.
  #
  # If *allow_typeof* is `false`, this method raises if there's a typeof
  # in the given node.
  #
  # If *free_vars* is given, when resolving a Path, types will be first searched
  # in the given Hash.
  #
  # For example, given:
  #
  # ```
  # class Foo
  #   class Bar(T)
  #   end
  #
  #   class Baz
  #   end
  # end
  # ```
  #
  # If `self` is `Foo` and `Bar(Baz)` is given, the result will be `Foo::Bar(Baz)`.
  def lookup_type(node : ASTNode, self_type = self.instance_type, allow_typeof = true, free_vars : Hash(String, TypeVar)? = nil) : Type
    TypeLookup.new(self, self_type, true, allow_typeof, free_vars).lookup(node).not_nil!
  end

  # Similar to `lookup_type`, but returns `nil` if a type can't be found.
  def lookup_type?(node : ASTNode, self_type = self.instance_type, allow_typeof = true, free_vars : Hash(String, TypeVar)? = nil) : Type?
    TypeLookup.new(self, self_type, false, allow_typeof, free_vars).lookup(node)
  end

  # :nodoc:
  struct TypeLookup
    def initialize(@root : Type, @self_type : Type, @raise : Bool, @allow_typeof : Bool, @free_vars : Hash(String, TypeVar)? = nil)
      @in_generic_args = 0
    end

    delegate program, to: @root

    def lookup(node : Path)
      if (free_vars = @free_vars) && node.names.size == 1
        if (type = free_vars[node.names.first]?).is_a?(Type)
          return type
        end
      end

      type = @root.lookup_path(node)
      if type.is_a?(Type)
        if @in_generic_args == 0 && type.is_a?(AliasType) && !type.aliased_type?
          if type.value_processed?
            node.raise "infinite recursive definition of alias #{type}"
          else
            type.process_value
          end
        end
        type.remove_alias_if_simple
      else
        if @raise
          Crystal.check_cant_infer_generic_type_parameter(@root, node)
          node.raise("undefined constant #{node}")
        else
          nil
        end
      end
    end

    def lookup(node : Union)
      types = node.types.map do |ident|
        type = lookup(ident)
        return if !@raise && !type
        type = type.not_nil!

        Crystal.check_type_allowed_in_generics(ident, type, "can't use #{type} in unions")

        type.virtual_type
      end
      program.type_merge(types)
    end

    def lookup(node : Metaclass)
      type = lookup(node.name)
      return if !@raise && !type
      type = type.not_nil!

      type.virtual_type.metaclass.virtual_type
    end

    def lookup(node : Generic)
      type = lookup(node.name)
      return if !@raise && !type
      type = type.not_nil!

      instance_type = type
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.is_a?(NamedTupleType)
        named_args = node.named_args
        unless named_args
          node.raise "can only instantiate NamedTuple with named arguments"
        end

        entries = named_args.map do |named_arg|
          subnode = named_arg.value

          if subnode.is_a?(NumberLiteral)
            subnode.raise "can't use number as type for NamedTuple"
          end

          type = in_generic_args { lookup(subnode) }
          return if !@raise && !type
          type = type.not_nil!

          Crystal.check_type_allowed_in_generics(subnode, type, "can't use #{type} as a generic type argument")
          NamedArgumentType.new(named_arg.name, type.virtual_type)
        end

        begin
          return instance_type.instantiate_named_args(entries)
        rescue ex : Crystal::Exception
          node.raise "instantiating #{node}", inner: ex if @raise
        end
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
          type = in_generic_args { lookup(type_var.exp) }
          return if !@raise && !type
          type = type.not_nil!

          splat_type = type
          if splat_type.is_a?(TupleInstanceType)
            type_vars.concat splat_type.tuple_types
          else
            return if !@raise

            type_var.raise "can only splat tuple type, not #{splat_type}"
          end
        else
          # Check the case of T resolving to a number
          if type_var.is_a?(Path) && type_var.names.size == 1
            type = @root.lookup_path(type_var)
            if type.is_a?(ASTNode)
              type_vars << type
              next
            end
          end

          type = in_generic_args { lookup(type_var) }
          return if !@raise && !type
          type = type.not_nil!

          Crystal.check_type_allowed_in_generics(type_var, type, "can't use #{type} as a generic type argument")

          type_vars << type.virtual_type
        end
      end

      begin
        instance_type.instantiate(type_vars)
      rescue ex : Crystal::Exception
        node.raise "instantiating #{node}", inner: ex if @raise
      end
    end

    def lookup(node : ProcNotation)
      types = [] of Type
      if inputs = node.inputs
        inputs.each do |input|
          if input.is_a?(Splat)
            type = in_generic_args { lookup(input.exp) }
            return if !@raise && !type
            type = type.not_nil!

            a_type = type
            if a_type.is_a?(TupleInstanceType)
              types.concat(a_type.tuple_types)
            else
              if @raise
                input.exp.raise "can only splat tuple type, not #{a_type}"
              else
                return
              end
            end
          else
            type = in_generic_args { lookup(input) }
            return if !@raise && !type
            type = type.not_nil!

            Crystal.check_type_allowed_in_generics(input, type, "can't use #{type} as proc argument")

            types << type.virtual_type
          end
        end
      end

      if output = node.output
        type = in_generic_args { lookup(output) }
        return if !@raise && !type
        type = type.not_nil!

        Crystal.check_type_allowed_in_generics(output, type, "can't use #{type} as proc return type")

        types << type.virtual_type
      else
        types << program.void
      end

      program.proc_of(types)
    end

    def lookup(node : Self)
      if @self_type.is_a?(Program)
        node.raise "there's no self in this scope"
      end

      @self_type.virtual_type
    end

    def lookup(node : TypeOf)
      unless @allow_typeof
        if @raise
          node.raise "can't use 'typeof' here"
        else
          return
        end
      end

      meta_vars = MetaVars{"self" => MetaVar.new("self", @self_type)}
      visitor = MainVisitor.new(program, meta_vars)
      expressions = node.expressions.clone
      begin
        expressions.each &.accept visitor
      rescue ex : Crystal::Exception
        node.raise "typing typeof", inner: ex
      end
      program.type_merge expressions
    end

    def lookup(node : Underscore)
      node.raise "can't use underscore as generic type argument" if @raise
    end

    def lookup(node : ASTNode)
      raise "Bug: unknown node in TypeLookup: #{node} #{node.class_desc}"
    end

    def in_generic_args
      @in_generic_args += 1
      value = yield
      @in_generic_args -= 1
      value
    end
  end
end
