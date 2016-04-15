require "./base_type_visitor"

module Crystal
  # Guess the type of global, class and instance variables
  # from assignments to them.
  class TypeGuessVisitor < BaseTypeVisitor
    alias TypeDeclarationWithLocation = TypeDeclarationProcessor::TypeDeclarationWithLocation
    alias InitializeInfo = TypeDeclarationProcessor::InitializeInfo
    alias InstanceVarTypeInfo = TypeDeclarationProcessor::InstanceVarTypeInfo

    getter globals
    getter class_vars
    getter initialize_infos

    class TypeInfo
      property type
      property outside_def

      def initialize(@type : Type)
        @outside_def = false
      end
    end

    @args : Array(Arg)?
    @block_arg : Arg?

    def initialize(mod,
                   @explicit_instance_vars : Hash(Type, Hash(String, TypeDeclarationWithLocation)),
                   @guessed_instance_vars : Hash(Type, Hash(String, InstanceVarTypeInfo)),
                   @initialize_infos : Hash(Type, Array(InitializeInfo)),
                   @instance_vars_outside : Hash(Type, Array(String)))
      super(mod)

      @globals = {} of String => TypeInfo
      @class_vars = {} of ClassVarContainer => Hash(String, TypeInfo)

      # Was `self` access found? If so, instance variables assigned after it
      # don't go to an InitializeInfo (they are considered as not being assigned
      # in that initialize)
      @found_self = false
      @has_self_visitor = HasSelfVisitor.new

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

    def visit(node : Var)
      check_var_is_self(node)
    end

    def visit(node : UninitializedVar)
      var = node.var
      if var.is_a?(InstanceVar)
        add_to_initialize_info(var.name)

        case owner = current_type
        when NonGenericClassType
          process_uninitialized_instance_var_on_non_generic(owner, var, node.declared_type)
        when Program, FileModule
          # Nothing
        when NonGenericModuleType
          process_uninitialized_instance_var_on_non_generic(owner, var, node.declared_type)
        when GenericClassType
          process_uninitialized_instance_var_on_generic(owner, var, node.declared_type)
        when GenericModuleType
          process_uninitialized_instance_var_on_generic(owner, var, node.declared_type)
        end
      end
    end

    def visit(node : Assign)
      process_assign(node)
      false
    end

    def visit(node : MultiAssign)
      process_multi_assign(node)
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
        # If it's "self.class", don't consider this as self being passed to a method
        return false if self_dot_class?(node)

        guess_type_call_lib_out(node)
        true
      end
    end

    def guess_type_call_lib_out(node : Call)
      # Check if this call is LibFoo.fun(out @x), and deduce
      # the type from it
      node.args.each_with_index do |arg, index|
        next unless arg.is_a?(Out)

        exp = arg.exp
        next unless exp.is_a?(InstanceVar)

        add_to_initialize_info(exp.name)

        obj = node.obj
        next unless obj.is_a?(Path)

        obj_type = lookup_type?(obj)
        next unless obj_type.is_a?(LibType)

        defs = obj_type.defs.try &.[node.name]?
        # There should be only one, if there is any
        defs.try &.each do |metadata|
          external = metadata.def as External
          fun_def = external.fun_def?
          next unless fun_def

          fun_arg = fun_def.args[index]?
          next unless fun_arg

          type = TypeLookup.lookup?(obj_type, fun_arg.restriction.not_nil!)
          next unless type.is_a?(PointerInstanceType)

          type = type.element_type

          case owner = current_type
          when NonGenericClassType
            process_lib_out_on_non_generic(owner, exp, type)
          when Program, FileModule
            # Nothing
          when NonGenericModuleType
            process_lib_out_on_non_generic(owner, exp, type)
          when GenericClassType
            process_lib_out_on_generic(owner, exp, type)
          when GenericModuleType
            process_lib_out_on_generic(owner, exp, type)
          end
        end
      end
    end

    def process_assign(node : Assign)
      process_assign(node.target, node.value)
    end

    def process_assign(target, value)
      check_has_self(value)

      case target
      when Global
        process_assign_global(target, value)
      when ClassVar
        process_assign_class_var(target, value)
      when InstanceVar
        process_assign_instance_var(target, value)
      when Path
        # Don't guess anything from constant values
        false
      else
        # Process the right hand side in case there's an assignment there too
        value.accept self
        nil
      end
    end

    def process_multi_assign(node : MultiAssign)
      if node.targets.size == node.values.size
        node.targets.zip(node.values) do |target, value|
          process_assign(target, value)
        end
      else
        node.values.each do |value|
          check_has_self(value)
        end

        node.targets.each do |target|
          if target.is_a?(InstanceVar)
            add_to_initialize_info(target.name)
          end
        end
      end
    end

    def process_assign_global(target, value)
      # If the global variable already exists no need to guess its type
      if global = @mod.global_vars[target.name]?
        return global.type
      end

      type = guess_type(value)
      if type
        add_type_info(@globals, target.name, type)
      end
      type
    end

    def process_assign_class_var(target, value)
      owner = class_var_owner(target)

      # If the class variable already exists no need to guess its type
      if var = owner.class_vars[target.name]?
        return var.type
      end

      type = guess_type(value)
      if type
        owner_vars = @class_vars[owner] ||= {} of String => TypeInfo
        add_type_info(owner_vars, target.name, type)
      end
      type
    end

    def process_assign_instance_var(target, value)
      case owner = current_type
      when NonGenericClassType
        value = process_assign_instance_var_on_non_generic(owner, target, value)
      when Program, FileModule
        # Nothing
      when NonGenericModuleType
        value = process_assign_instance_var_on_non_generic(owner, target, value)
      when GenericClassType
        value = process_assign_instance_var_on_generic(owner, target, value)
      when GenericModuleType
        value = process_assign_instance_var_on_generic(owner, target, value)
      end

      add_to_initialize_info(target.name)

      value
    end

    def add_to_initialize_info(name)
      if !@found_self && (initialize_info = @initialize_info)
        vars = initialize_info.instance_vars ||= [] of String
        vars << name unless vars.includes?(name)
      end
    end

    def process_assign_instance_var_on_non_generic(owner, target, value)
      if @outside_def
        outside_vars = @instance_vars_outside[owner] ||= [] of String
        outside_vars << target.name unless outside_vars.includes?(target.name)
      end

      # If there is already a type restriction, skip
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        # Accept the value in case there are assigns there
        value.accept self
        return existing.type as Type
      end

      # For non-generic class we can solve the type now
      type = guess_type(value)
      if type
        owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
        add_instance_var_type_info(owner_vars, target.name, type)
      end
      type
    end

    def process_assign_instance_var_on_generic(owner, target, value)
      if @outside_def
        outside_vars = @instance_vars_outside[owner] ||= [] of String
        outside_vars << target.name unless outside_vars.includes?(target.name)
      end

      # Skip if the generic class already defines an explicit type
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        # Accept the value in case there are assigns there
        value.accept self
        return
      end

      type_vars = guess_type_vars(value)
      if type_vars
        owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
        type_vars.each do |type_var|
          add_instance_var_type_info(owner_vars, target.name, type_var)
        end
      end
      type_vars
    end

    def process_uninitialized_instance_var_on_non_generic(owner, target, value)
      # If there is already a type restriction, skip
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        return existing.type as Type
      end

      # For non-generic class we can solve the type now
      type = lookup_type?(value)
      if type
        owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
        add_instance_var_type_info(owner_vars, target.name, type)
      end
      type
    end

    def process_uninitialized_instance_var_on_generic(owner, target, value)
      # Skip if the generic class already defines an explicit type
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        return
      end

      type_vars = [value] of TypeVar
      owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
      type_vars.each do |type_var|
        add_instance_var_type_info(owner_vars, target.name, type_var)
      end
      type_vars
    end

    def process_lib_out_on_non_generic(owner, target, type)
      # If there is already a type restriction, skip
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        return existing.type as Type
      end

      owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
      add_instance_var_type_info(owner_vars, target.name, type)
    end

    def process_lib_out_on_generic(owner, target, type)
      # Skip if the generic class already defines an explicit type
      existing = @explicit_instance_vars[owner]?.try &.[target.name]?
      if existing
        return
      end

      type_vars = [type] of TypeVar
      owner_vars = @guessed_instance_vars[owner] ||= {} of String => InstanceVarTypeInfo
      type_vars.each do |type_var|
        add_instance_var_type_info(owner_vars, target.name, type_var)
      end
      type_vars
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

    def add_instance_var_type_info(vars, name, type_var)
      info = vars[name]?
      unless info
        info = InstanceVarTypeInfo.new
        info.type_vars << type_var
        info.outside_def = true if @outside_def
        vars[name] = info
      else
        info.type_vars << type_var
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
      if name = node.name
        type = lookup_type_no_check?(name)
        if type.is_a?(GenericClassType)
          element_types = guess_array_literal_element_types(node)
          if element_types
            return type.instantiate([Type.merge!(element_types)] of TypeVar)
          end
        else
          return check_allowed_in_generics(type)
        end
      elsif node_of = node.of
        type = lookup_type?(node_of)
        if type
          return mod.array_of(type)
        end
      else
        element_types = guess_array_literal_element_types(node)
        if element_types
          return mod.array_of(Type.merge!(element_types))
        end
      end

      nil
    end

    def guess_array_literal_element_types(node)
      element_types = nil
      node.elements.each do |element|
        element_type = guess_type(element)
        next unless element_type

        element_types ||= [] of Type
        element_types << element_type
      end
      element_types
    end

    def guess_type(node : HashLiteral)
      if name = node.name
        type = lookup_type_no_check?(name)
        if type.is_a?(GenericClassType)
          key_types, value_types = guess_hash_literal_key_value_types(node)
          if key_types && value_types
            return type.instantiate([Type.merge!(key_types), Type.merge!(value_types)] of TypeVar)
          end
        else
          return check_allowed_in_generics(type)
        end
      elsif node_of = node.of
        key_type = lookup_type?(node_of.key)
        return nil unless key_type

        value_type = lookup_type?(node_of.value)
        return nil unless value_type

        return mod.hash_of(key_type, value_type)
      else
        key_types, value_types = guess_hash_literal_key_value_types(node)
        if key_types && value_types
          return mod.hash_of(Type.merge!(key_types), Type.merge!(value_types))
        end
      end

      nil
    end

    def guess_hash_literal_key_value_types(node : HashLiteral)
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
      {key_types, value_types}
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
      guess_type_call_lib_out(node)

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

      # If it's Pointer(T).malloc or Pointer(T).null, guess it to Pointer(T)
      if obj.is_a?(Generic) && obj.name.single?("Pointer") &&
         (node.name == "malloc" || node.name == "null")
        type = lookup_type?(obj)
        return type if type.is_a?(PointerInstanceType)
      end

      if type = guess_type_call_pointer_malloc_two_args(node)
        return type
      end

      type = guess_type_call_lib_fun(node)
      return type if type

      nil
    end

    # If it's Pointer.malloc(size, value), infer element type from value
    # to T and then infer to Pointer(T)
    def guess_type_call_pointer_malloc_two_args(node)
      obj = node.obj

      if node.args.size == 2 && obj.is_a?(Path) &&
         obj.single?("Pointer") && node.name == "malloc"
        type = lookup_type_no_check?(obj)
        if type.is_a?(PointerType)
          element_type = guess_type(node.args[1])
          if element_type
            return @mod.pointer_of(element_type)
          end
        end
      end
      nil
    end

    def guess_type_call_lib_fun(node)
      # If it's LibFoo.function, where LibFoo is a lib type,
      # get the type from there
      obj = node.obj
      return unless obj.is_a?(Path)

      obj_type = lookup_type?(obj)
      return unless obj_type.is_a?(LibType)

      defs = obj_type.defs.try &.[node.name]?
      # There should be only one, if there is any
      defs.try &.each do |metadata|
        external = metadata.def as External
        if def_return_type = external.fun_def?.try &.return_type
          return_type = TypeLookup.lookup(obj_type, def_return_type)
          return return_type if return_type
        elsif external_type = external.type?
          # This is the case of an External being an external variable
          return external_type
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
      check_var_is_self(node)

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

    def guess_type(node : InstanceVar)
      # In an assignment like @x = @y, we use the info gathered so far for @y
      type_decl = @explicit_instance_vars[current_type]?.try &.[node.name]?
      if (type = type_decl.try &.type).is_a?(Type)
        return type
      end

      info = @guessed_instance_vars[current_type]?.try &.[node.name]?
      if info && (first = info.type_vars.first?) && first.is_a?(Type)
        first
      else
        nil
      end
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

        # Check if the const's value is actually an enum member
        if type.value.type?.try &.is_a?(EnumType)
          type.value.type
        else
          @consts.push(type)
          type = guess_type(type.value)
          @consts.pop
          type
        end
      else
        type.metaclass
      end
    end

    def guess_type(node : Expressions)
      last = node.expressions.last?
      last ? guess_type(last) : nil
    end

    def guess_type(node : Assign)
      type_var = process_assign(node)
      type_var.is_a?(Type) ? type_var : nil
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

    def guess_type_vars(node : Call)
      guess_type_call_lib_out(node)

      obj = node.obj

      # If it's something like T.new, guess T.
      # If it's something like T(X).new, guess T(X).
      if node.name == "new" && obj && (obj.is_a?(Path) || obj.is_a?(Generic))
        type = lookup_type_no_check?(obj)
        return nil if type.is_a?(GenericType)

        return [obj] of TypeVar
      end

      # If it's Pointer(T).malloc or Pointer(T).null, guess it to Pointer(T)
      if obj.is_a?(Generic) && obj.name.single?("Pointer") &&
         (node.name == "malloc" || node.name == "null")
        return [obj] of TypeVar
      end

      if type = guess_type_call_pointer_malloc_two_args(node)
        return [type] of TypeVar
      end

      if type = guess_type_call_lib_fun(node)
        return [type] of TypeVar
      end

      nil
    end

    def guess_type_vars(node : Var)
      check_var_is_self(node)

      if args = @args
        # Find an argument with the same name as this variable
        arg = args.find { |arg| arg.name == node.name }
        if arg
          # If the argument has a restriction, guess the type from it
          if restriction = arg.restriction
            return [restriction] of TypeVar
          end

          # If the argument has a default value, guess the type from it
          if default_value = arg.default_value
            return guess_type_vars(default_value)
          end
        end
      end

      # Try to guess type from a block argument with the same name
      if (block_arg = @block_arg) && block_arg.name == node.name
        restriction = block_arg.restriction
        if restriction
          return [restriction] of TypeVar
        end
      end

      nil
    end

    def guess_type_vars(node : InstanceVar)
      # In an assignment like @x = @y, we use the info gathered so far for @y
      type_decl = @explicit_instance_vars[current_type]?.try &.[node.name]?
      if type_decl
        return [type_decl.type] of TypeVar
      end

      @guessed_instance_vars[current_type]?.try &.[node.name]?.try &.type_vars
    end

    def guess_type_vars(node : BinaryOp)
      left_vars = guess_type_vars(node.left)
      right_vars = guess_type_vars(node.right)
      merge_two_type_vars(left_vars, right_vars)
    end

    def guess_type_vars(node : If)
      left_vars = guess_type_vars(node.then)
      right_vars = guess_type_vars(node.else)
      merge_two_type_vars(left_vars, right_vars)
    end

    def guess_type_vars(node : Unless)
      left_vars = guess_type_vars(node.then)
      right_vars = guess_type_vars(node.else)
      merge_two_type_vars(left_vars, right_vars)
    end

    def guess_type_vars(node : Case)
      all_type_vars = nil

      node.whens.each do |when|
        type_vars = guess_type_vars(when.body)
        next unless type_vars

        all_type_vars ||= [] of TypeVar
        all_type_vars.concat(type_vars)
      end

      if node_else = node.else
        type_vars = guess_type_vars(node_else)
        if type_vars
          all_type_vars ||= [] of TypeVar
          all_type_vars.concat(type_vars)
        end
      end

      all_type_vars
    end

    def guess_type_vars(node : Expressions)
      last = node.expressions.last?
      last ? guess_type_vars(last) : nil
    end

    def guess_type_vars(node : ArrayLiteral)
      if name = node.name
        type = lookup_type_no_check?(name)
        if type.is_a?(GenericClassType)
          element_types = guess_array_literal_element_types(node)
          if element_types
            return [type.instantiate([Type.merge!(element_types)] of TypeVar)] of TypeVar
          end
        else
          type = check_allowed_in_generics(type)
          if type
            return [type] of TypeVar
          end
        end
      end

      if node_of = node.of
        return [Generic.new(Path.global("Array"), node_of)] of TypeVar
      end

      element_types = guess_array_literal_element_types(node)
      if element_types
        return [mod.array_of(Type.merge!(element_types))] of TypeVar
      end

      nil
    end

    def guess_type_vars(node : HashLiteral)
      if name = node.name
        type = lookup_type_no_check?(name)
        if type.is_a?(GenericClassType)
          key_types, value_types = guess_hash_literal_key_value_types(node)
          if key_types && value_types
            return [type.instantiate([Type.merge!(key_types), Type.merge!(value_types)] of TypeVar)] of TypeVar
          end
        else
          type = check_allowed_in_generics(type)
          if type
            return [type] of TypeVar
          end
        end
      end

      if node_of = node.of
        return [Generic.new(Path.global("Hash"), [node_of.key, node_of.value] of ASTNode)] of TypeVar
      end

      key_types, value_types = guess_hash_literal_key_value_types(node)
      if key_types && value_types
        return [mod.hash_of(Type.merge!(key_types), Type.merge!(value_types))] of TypeVar
      end

      nil
    end

    def guess_type_vars(node : Assign)
      type_vars = process_assign(node)
      if type_vars.is_a?(Array(TypeVar))
        type_vars
      else
        nil
      end
    end

    def guess_type_vars(node : ASTNode)
      type = guess_type(node)
      if type
        [type] of TypeVar
      else
        nil
      end
    end

    def merge_two_type_vars(t1, t2)
      if t1
        if t2
          t1 + t2
        else
          t1
        end
      elsif t2
        t2
      else
        nil
      end
    end

    def check_has_self(node)
      @has_self_visitor.reset
      @has_self_visitor.accept(node)
      @found_self = true if @has_self_visitor.has_self
    end

    def check_var_is_self(node : Var)
      @found_self = true if node.name == "self"
    end

    def lookup_type?(node)
      type = TypeLookup.lookup?(current_type, node, allow_typeof: false)
      check_allowed_in_generics(type)
    end

    def lookup_type_no_check?(node)
      TypeLookup.lookup?(current_type, node, allow_typeof: false)
    end

    def check_allowed_in_generics(type)
      # Types such as Object, Int, etc., are not allowed in generics
      # and as variables types, so we disallow them.
      if type && !type.allowed_in_generics?
        # However, Reference is allowed for variables.
        if type == @mod.reference
          return type
        else
          return nil
        end
      end

      case type
      when GenericClassType, GenericModuleType
        nil
      when NonGenericClassType
        type.virtual_type
      else
        type
      end
    end

    def visit(node : ClassDef)
      check_outside_block_or_exp node, "declare class"

      @initialize_infos[node.resolved_type] ||= [] of InitializeInfo

      pushing_type(node.resolved_type) do
        node.runtime_initializers.try &.each &.accept self
        node.body.accept self
      end

      false
    end

    def visit(node : ModuleDef)
      check_outside_block_or_exp node, "declare module"

      @initialize_infos[node.resolved_type] ||= [] of InitializeInfo

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
      @found_self = false
      @args = node.args
      @block_arg = node.block_arg

      if node.name == "initialize"
        initialize_info = @initialize_info = InitializeInfo.new(node)
      end

      node.body.accept self

      if initialize_info
        @initialize_infos[current_type] << initialize_info
      end

      @initialize_info = nil
      @block_arg = nil
      @args = nil
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

  class HasSelfVisitor < Visitor
    getter has_self

    def initialize
      @has_self = false
    end

    def reset
      @has_self = false
    end

    def visit(node : Call)
      # If it's "self.class", don't consider this as self being passed to a method
      return false if self_dot_class?(node)

      true
    end

    def visit(node : Var)
      if node.name == "self"
        @has_self = true
      end
    end

    def visit(node : ASTNode)
      true
    end
  end
end

private def self_dot_class?(node : Crystal::Call)
  obj = node.obj
  obj.is_a?(Crystal::Var) && obj.name == "self" && node.name == "class" && node.args.empty?
end
