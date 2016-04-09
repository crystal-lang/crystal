require "./base_type_visitor"

module Crystal
  # Guess the type of global, class and instance variables
  # from assignments to them.
  class TypeGuessVisitor < BaseTypeVisitor
    getter globals
    getter class_vars

    class TypeInfo
      property type
      property outside_def

      def initialize(@type : Type)
        @outside_def = false
      end
    end

    @args : Array(Arg)?
    @block_arg : Arg?

    def initialize(mod)
      super(mod)

      @globals = {} of String => TypeInfo
      @class_vars = {} of ClassVarContainer => Hash(String, TypeInfo)

      # This is to prevent infinite resolution of constants, like in
      #
      # ```
      # A = B
      # B = A
      # $x = A
      # ```
      @consts = [] of Const

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
          add_type_info(@globals, target.name, type)
        end
        return type
      when ClassVar
        owner = class_var_owner(node)

        # If the class variable already exists no need to guess its type
        if var = owner.class_vars[target.name]?
          return var.type
        end

        type = guess_type(node.value)
        if type
          owner_vars = @class_vars[owner] ||= {} of String => TypeInfo
          add_type_info(owner_vars, target.name, type)
        end
        return type
      else
        node.value.accept self
      end
      nil
    end

    def add_type_info(vars, name, type)
      info = vars[name]?
      unless info
        info = TypeInfo.new(type)
        info.outside_def = true if @outside_def
        vars[name] = info
      else
        info.type = Type.merge!(type, info.type)
        info.outside_def = true if @outside_def
        vars[name] = info
      end
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

      # If it's something like T.new, guess T.
      # If it's something like T(X).new, guess T(X).
      if node.name == "new" && obj && (obj.is_a?(Path) || obj.is_a?(Generic))
        type = lookup_type?(obj)
        return type if type
      end

      # If it's `new(...)` and this is a non-generic class type, guess it to be that class
      if node.name == "new" && !obj && current_type.is_a?(NonGenericClassType)
        return current_type if current_type
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
      if args = @args
        # Find an argument with the same name as this variable
        arg = args.find { |arg| arg.name == node.name }
        if arg
          # If the argument has a restriction, guess the type from it
          if restriction = arg.restriction
            type = lookup_type?(restriction)
            return type if type
          end

          # If the argument has a default value, guess the type from it
          if default_value = arg.default_value
            return guess_type(default_value)
          end
        end
      end

      # Try to guess type from a block argument with the same name
      if (block_arg = @block_arg) && block_arg.name == node.name
        restriction = block_arg.restriction
        if restriction
          type = lookup_type?(restriction)
          return type if type
        end
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

    def guess_type(node : Unless)
      then_type = guess_type(node.then)
      else_type = guess_type(node.else)
      guess_from_two(then_type, else_type)
    end

    def guess_type(node : Case)
      types = nil

      node.whens.each do |when|
        type = guess_type(when.body)
        next unless type

        types ||= [] of Type
        types << type
      end

      if node_else = node.else
        type = guess_type(node_else)
        if type
          types ||= [] of Type
          types << type
        end
      end

      types ? Type.merge!(types) : nil
    end

    def guess_type(node : Path)
      type = lookup_type?(node)
      return nil unless type

      if type.is_a?(Const)
        # Don't solve a constant we've already seen
        return nil if @consts.includes?(type)

        @consts.push(type)
        type = guess_type(type.value)
        @consts.pop
        type
      else
        type.virtual_type.metaclass
      end
    end

    def guess_type(node : Expressions)
      last = node.expressions.last?
      last ? guess_type(last) : nil
    end

    def guess_type(node : Assign)
      process_assign(node)
    end

    def guess_type(node : Not)
      @mod.bool
    end

    def guess_type(node : IsA)
      @mod.bool
    end

    def guess_type(node : RespondsTo)
      @mod.bool
    end

    def guess_type(node : SizeOf)
      @mod.int32
    end

    def guess_type(node : InstanceSizeOf)
      @mod.int32
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

    def visit(node : EnumDef)
      check_outside_block_or_exp node, "declare enum"

      pushing_type(node.resolved_type) do
        node.members.each &.accept self
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
      # If this method was redefined and this new method doesn't
      # call `previous_def`, this method will never be called,
      # so we ignore it
      if (next_def = node.next) && !next_def.calls_previous_def
        return false
      end

      check_outside_block_or_exp node, "declare def"

      node.runtime_initializers.try &.each &.accept self

      @outside_def = false
      @args = node.args
      @block_arg = node.block_arg
      node.body.accept self
      @block_arg = nil
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
