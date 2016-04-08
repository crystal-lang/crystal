require "./base_type_visitor"

module Crystal
  class Program
    def visit_type_declarations(node)
      # First check type declarations
      visitor = TypeDeclarationVisitor.new(self)
      node.accept visitor

      # Use the last type found for global variables to declare them
      visitor.globals.each do |name, type|
        global_var = MetaTypeVar.new(name)
        global_var.owner = self
        global_var.type = type
        global_var.bind_to(global_var)
        global_var.freeze_type = type
        self.global_vars[name] = global_var
      end

      # Now use several syntactic rules to infer the types of
      # variables that don't have an explicit type set
      visitor = TypeGuessVisitor.new(self)
      node.accept visitor

      visitor.globals.each do |name, info|
        global_var = MetaTypeVar.new(name)
        global_var.owner = self

        type = info.type

        # If a global variable was never assigned outside a def,
        # it is inferred to be nilable
        type = Type.merge([type, self.nil]) unless info.outside_def

        global_var.type = type
        global_var.bind_to(global_var)
        global_var.freeze_type = type
        self.global_vars[name] = global_var
      end

      node
    end
  end

  # In this pass we check type declarations like:
  #
  #     @x : Int32
  #     @@x : Int32
  #     $x : Int32
  #
  # In this way we declare their type before the "main" code.
  #
  # This allows to put "main" code before these declarations,
  # so order matters less in the end.
  #
  # In the future these will be mandatory and after this pass
  # we'll have a complete definition of the type hierarchy and
  # their instance/class variables types.
  class TypeDeclarationVisitor < BaseTypeVisitor
    getter globals

    def initialize(mod)
      super(mod)

      # The type of global variables. The last one wins.
      @globals = {} of String => Type
    end

    def visit(node : ClassDef)
      check_outside_block_or_exp node, "declare class"

      pushing_type(node.resolved_type) do
        node.runtime_initializers.try &.each &.accept self
        node.body.accept self
      end

      false
    end

    def visit(node : ModuleDef)
      check_outside_block_or_exp node, "declare module"

      pushing_type(node.resolved_type) do
        node.body.accept self
      end

      false
    end

    def visit(node : Alias)
      check_outside_block_or_exp node, "declare alias"

      false
    end

    def visit(node : Include)
      check_outside_block_or_exp node, "include"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : Extend)
      check_outside_block_or_exp node, "extend"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : LibDef)
      check_outside_block_or_exp node, "declare lib"

      false
    end

    def visit(node : FunDef)
      false
    end

    def visit(node : TypeDeclaration)
      case var = node.var
      when Var
        node.raise "declaring the type of a local variable is not yet supported"
      when InstanceVar
        declare_instance_var(node, var)
      when ClassVar
        class_var = lookup_class_var(var, bind_to_nil_if_non_existent: false)
        var_type = lookup_type(node.declared_type)
        var_type = check_declare_var_type(node, var_type)
        class_var.freeze_type = var_type.virtual_type
      when Global
        var_type = lookup_type(node.declared_type).virtual_type
        @globals[var.name] = var_type
      end

      node.type = @mod.nil

      false
    end

    def declare_instance_var(node, var)
      type = current_type
      case type
      when NonGenericClassType
        var_type = lookup_type(node.declared_type)
        var_type = check_declare_var_type(node, var_type)
        type.declare_instance_var(var.name, var_type.virtual_type)
        return
      when GenericClassType
        type.declare_instance_var(var.name, node.declared_type)
        return
      when GenericModuleType
        type.declare_instance_var(var.name, node.declared_type)
        return
      when GenericClassInstanceType
        # OK
        return
      when Program, FileModule
        # Error, continue
      when NonGenericModuleType
        var_type = lookup_type(node.declared_type)
        var_type = check_declare_var_type(node, var_type)
        type.declare_instance_var(var.name, var_type.virtual_type)
        return
      end

      node.raise "can only declare instance variables of a non-generic class, not a #{type.type_desc} (#{type})"
    end

    def visit(node : Def)
      check_outside_block_or_exp node, "declare def"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : Macro)
      check_outside_block_or_exp node, "declare macro"

      false
    end

    def visit(node : Call)
      if node.global
        node.scope = @mod
      else
        node.scope = current_type.metaclass
      end

      if expand_macro(node, raise_on_missing_const: false)
        false
      else
        true
      end
    end

    def lookup_type(node)
      TypeLookup.lookup(current_type, node, allow_typeof: false)
    end

    def visit(node : UninitializedVar)
      false
    end

    def visit(node : Assign)
      false
    end

    def visit(node : FunLiteral)
      false
    end

    def visit(node : IsA)
      false
    end

    def visit(node : Cast)
      false
    end

    def visit(node : InstanceSizeOf)
      false
    end

    def visit(node : SizeOf)
      false
    end

    def visit(node : TypeOf)
      false
    end

    def visit(node : PointerOf)
      false
    end

    def visit(node : ArrayLiteral)
      false
    end

    def visit(node : HashLiteral)
      false
    end

    def visit(node : Path)
      false
    end

    def visit(node : Generic)
      false
    end

    def visit(node : Fun)
      false
    end

    def visit(node : Union)
      false
    end

    def visit(node : Metaclass)
      false
    end

    def visit(node : Self)
      false
    end

    def visit(node : TypeOf)
      false
    end

    def inside_block?
      false
    end
  end

  # Guess the type of global, class and instance variables
  # from assignments to them.
  class TypeGuessVisitor < BaseTypeVisitor
    getter globals

    class TypeInfo
      property type
      property outside_def

      def initialize(@type : Type)
        @outside_def = false
      end
    end

    @args : Array(Arg)?

    def initialize(mod)
      super(mod)

      @globals = {} of String => TypeInfo
      @outside_def = true
    end

    def visit(node : Assign)
      process_assign(node)
      false
    end

    def process_assign(node : Assign)
      case target = node.target
      when Global
        # If the global variable already exists no need to guess its type
        if global = @mod.global_vars[target.name]?
          return global.type
        end

        type = guess_type(node.value)
        if type
          info = @globals[target.name]?
          unless info
            info = TypeInfo.new(type)
            info.outside_def = true if @outside_def
            @globals[target.name] = info
          else
            info.type = Type.merge!(type, info.type)
            info.outside_def = true if @outside_def
            @globals[target.name] = info
          end
        end
        return type
      end
      nil
    end

    def guess_type(node : NumberLiteral)
      case node.kind
      when :i8  then mod.int8
      when :i16 then mod.int16
      when :i32 then mod.int32
      when :i64 then mod.int64
      when :u8  then mod.uint8
      when :u16 then mod.uint16
      when :u32 then mod.uint32
      when :u64 then mod.uint64
      when :f32 then mod.float32
      when :f64 then mod.float64
      else           raise "Invalid node kind: #{node.kind}"
      end
    end

    def guess_type(node : CharLiteral)
      mod.char
    end

    def guess_type(node : BoolLiteral)
      mod.bool
    end

    def guess_type(node : NilLiteral)
      mod.nil
    end

    def guess_type(node : StringLiteral)
      mod.string
    end

    def guess_type(node : StringInterpolation)
      mod.string
    end

    def guess_type(node : SymbolLiteral)
      mod.symbol
    end

    def guess_type(node : ArrayLiteral)
      if node_of = node.of
        type = lookup_type?(node_of)
        if type
          return mod.array_of(type.virtual_type)
        end
      else
        element_types = nil
        node.elements.each do |element|
          element_type = guess_type(element)
          next unless element_type

          element_types ||= [] of Type
          element_types << element_type
        end
        if element_types
          return mod.array_of(Type.merge!(element_types))
        end
      end

      nil
    end

    def guess_type(node : HashLiteral)
      if node_of = node.of
        key_type = lookup_type?(node_of.key)
        return nil unless key_type

        value_type = lookup_type?(node_of.value)
        return nil unless value_type

        return mod.hash_of(key_type.virtual_type, value_type.virtual_type)
      else
        key_types = nil
        value_types = nil
        node.entries.each do |entry|
          key_type = guess_type(entry.key)
          if key_type
            key_types ||= [] of Type
            key_types << key_type
          end

          value_type = guess_type(entry.value)
          if value_type
            value_types ||= [] of Type
            value_types << value_type
          end
        end

        if key_types && value_types
          return mod.hash_of(Type.merge!(key_types), Type.merge!(value_types))
        end
      end

      nil
    end

    def guess_type(node : RangeLiteral)
      from_type = guess_type(node.from)
      to_type = guess_type(node.to)

      if from_type && to_type
        mod.range_of(from_type, to_type)
      else
        nil
      end
    end

    def guess_type(node : RegexLiteral)
      mod.types["Regex"]
    end

    def guess_type(node : TupleLiteral)
      element_types = nil
      node.elements.each do |element|
        element_type = guess_type(element)
        return nil unless element_type

        element_types ||= [] of Type
        element_types << element_type
      end

      if element_types
        mod.tuple_of(element_types)
      else
        nil
      end
    end

    def guess_type(node : Call)
      obj = node.obj
      return nil unless obj

      # If it's something like T.new, guess T.
      # If it's something like T(X).new, guess T(X).
      if node.name == "new" && (obj.is_a?(Path) || obj.is_a?(Generic))
        type = lookup_type?(obj)
        return type if type
      end

      # If it's LibFoo.function, where LibFoo is a lib type,
      # get the type from there
      if obj.is_a?(Path)
        obj_type = lookup_type?(obj)
        if obj_type.is_a?(LibType)
          defs = obj_type.defs.try &.[node.name]?
          # There should be only one, if there is any
          defs.try &.each do |metadata|
            external = metadata.def as External
            if def_return_type = external.fun_def.return_type
              return_type = TypeLookup.lookup(obj_type, def_return_type)
              return return_type if return_type
            end
          end
        end
      end

      nil
    end

    def guess_type(node : Cast)
      lookup_type?(node.to)
    end

    def guess_type(node : UninitializedVar)
      lookup_type?(node.declared_type)
    end

    def guess_type(node : Var)
      args = @args
      return nil unless args

      # Find an argument with the same name as this variable
      arg = args.find { |arg| arg.name == node.name }
      return nil unless arg

      # If the argument has a restriction, guess the type from it
      if restriction = arg.restriction
        type = lookup_type?(restriction)
        return type if type
      end

      # If the argument has a default value, guess the type from it
      if default_value = arg.default_value
        return guess_type(default_value)
      end

      nil
    end

    def guess_type(node : BinaryOp)
      left_type = guess_type(node.left)
      right_type = guess_type(node.right)
      guess_from_two(left_type, right_type)
    end

    def guess_type(node : If)
      then_type = guess_type(node.then)
      else_type = guess_type(node.else)
      guess_from_two(then_type, else_type)
    end

    def guess_type(node : Expressions)
      last = node.expressions.last?
      last ? guess_type(last) : nil
    end

    def guess_type(node : Assign)
      process_assign(node)
    end

    def guess_type(node : Nop)
      @mod.nil
    end

    def guess_from_two(type1, type2)
      if type1
        if type2
          Type.merge!(type1, type2)
        else
          type1
        end
      else
        type2
      end
    end

    def guess_type(node : ASTNode)
      nil
    end

    def lookup_type?(node)
      TypeLookup.lookup?(current_type, node, allow_typeof: false)
    end

    def visit(node : ClassDef)
      check_outside_block_or_exp node, "declare class"

      pushing_type(node.resolved_type) do
        node.runtime_initializers.try &.each &.accept self
        node.body.accept self
      end

      false
    end

    def visit(node : ModuleDef)
      check_outside_block_or_exp node, "declare module"

      pushing_type(node.resolved_type) do
        node.body.accept self
      end

      false
    end

    def visit(node : Alias)
      check_outside_block_or_exp node, "declare alias"

      false
    end

    def visit(node : Include)
      check_outside_block_or_exp node, "include"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : Extend)
      check_outside_block_or_exp node, "extend"

      node.runtime_initializers.try &.each &.accept self

      false
    end

    def visit(node : LibDef)
      check_outside_block_or_exp node, "declare lib"

      false
    end

    def visit(node : TypeDeclaration)
      false
    end

    def visit(node : Def)
      check_outside_block_or_exp node, "declare def"

      node.runtime_initializers.try &.each &.accept self

      @outside_def = false
      @args = node.args
      node.body.accept self
      @arg = nil
      @outside_def = true

      false
    end

    def visit(node : FunDef)
      check_outside_block_or_exp node, "declare fun"

      if body = node.body
        @outside_def = false
        @args = node.args
        body.accept self
        @args = nil
        @outside_def = true
      end

      false
    end

    def visit(node : Macro)
      check_outside_block_or_exp node, "declare macro"

      false
    end

    def visit(node : Call)
      if @outside_def
        if node.global
          node.scope = @mod
        else
          node.scope = current_type.metaclass
        end

        if expand_macro(node, raise_on_missing_const: false)
          false
        else
          true
        end
      else
        true
      end
    end

    def visit(node : FunLiteral)
      node.def.body.accept self
      false
    end

    def visit(node : Cast)
      node.obj.accept self
      false
    end

    def visit(node : IsA)
      node.obj.accept self
      false
    end

    def visit(node : InstanceSizeOf)
      false
    end

    def visit(node : SizeOf)
      false
    end

    def visit(node : TypeOf)
      false
    end

    def visit(node : PointerOf)
      false
    end

    def visit(node : MacroExpression)
      false
    end

    def visit(node : MacroIf)
      false
    end

    def visit(node : MacroFor)
      false
    end

    def visit(node : Path)
      false
    end

    def visit(node : Generic)
      false
    end

    def visit(node : Fun)
      false
    end

    def visit(node : Union)
      false
    end

    def visit(node : Metaclass)
      false
    end

    def visit(node : Self)
      false
    end

    def visit(node : TypeOf)
      false
    end

    def inside_block?
      false
    end
  end
end
