require "./semantic_visitor"

module Crystal
  class Program
    def visit_main(node, visitor : MainVisitor = MainVisitor.new(self), process_finished_hooks = false, cleanup = true)
      node.accept visitor
      program.process_finished_hooks(visitor) if process_finished_hooks

      missing_types = FixMissingTypes.new(self)
      node.accept missing_types
      program.process_finished_hooks(missing_types) if process_finished_hooks

      node = cleanup node if cleanup

      if process_finished_hooks
        finished_hooks.map! do |hook|
          hook_node = cleanup(hook.node)
          FinishedHook.new(hook.scope, hook.macro, hook_node)
        end
      end

      node
    end
  end

  # This is the main visitor of the program, ran after types have been declared
  # and their type declarations (like `@x : Int32`) have been processed.
  #
  # This visits the "main" code of the program and resolves calls, instantiates
  # methods and visits them, recursively, with other MainVisitors.
  #
  # The visitor keeps track of a method's variables (or the main program, split into
  # several files, in case of top-level code). It keeps track both of the type of a
  # variable at a single point (stored in @vars) and the combined type of all assignments
  # to it (in @meta_vars).
  #
  # Call resolution logic is in `Call#recalculate`, where method lookup is done.
  class MainVisitor < SemanticVisitor
    ValidGlobalAnnotations   = %w(ThreadLocal)
    ValidClassVarAnnotations = %w(ThreadLocal)

    getter! typed_def
    property! untyped_def : Def
    setter untyped_def
    getter block : Block?
    property call : Call?
    property path_lookup
    property fun_literal_context : Def | Program | Nil
    property parent : MainVisitor?
    property block_nest = 0
    property with_scope : Type?

    property match_context : MatchContext?

    # These are the variables and types that come from a block specification
    # like `&block : Int32 -> Int32`. When doing `yield 1` we need to verify
    # that the yielded expression has the type that the block specification said.
    property yield_vars : Array(Var)?

    # In vars we store the types of variables as we traverse the nodes.
    # These type are not cumulative: if you do `x = 1`, 'x' will have
    # type Int32. Then if you do `x = false`, 'x' will have type Bool.
    getter vars

    # Here we store the cumulative types of variables as we traverse the nodes.
    getter meta_vars : MetaVars
    property is_initialize : Bool
    property all_exception_handler_vars : Array(MetaVars)? = nil

    private enum BlockKind
      None
      While
      Block
      Ensure
    end

    # It means the last block kind. It is used to detect `break` or `next`
    # from `ensure`.
    #
    # ```
    # begin
    #   # `last_block_kind.none?`
    # ensure
    #   # `last_block_kind.ensure?`
    #   while true
    #     # `last_block_kind.while?`
    #   end
    #   loop do
    #     # `last_block_kind.block?`
    #   end
    #   # `last_block_kind.ensure?`
    # end
    # ```
    property last_block_kind : BlockKind = :none
    property? inside_ensure : Bool = false
    property? inside_constant = false
    property file_module : FileModule?

    @unreachable = false
    @is_initialize = false
    @inside_is_a = false
    @in_type_args = 0

    @while_stack = [] of While
    @type_filters : TypeFilters?
    @needs_type_filters = 0
    @typeof_nest = 0
    @found_self_in_initialize_call : Array(ASTNode)?
    @used_ivars_in_calls_in_initialize : Hash(String, Array(ASTNode))?
    @block_context : Block?
    @while_vars : MetaVars?

    # Type filters for `exp` in `!exp`, used after a `while`
    @before_not_type_filters : TypeFilters?

    def initialize(program, vars = MetaVars.new, @typed_def = nil, meta_vars = nil)
      super(program, vars)
      @is_initialize = !!(typed_def && (
        typed_def.name == "initialize" ||
        typed_def.name.starts_with?("initialize:") # Because of expanded methods from named args
      ))

      # We initialize meta_vars from vars given in the constructor.
      # We store those meta vars either in the typed def or in the program
      # so the codegen phase knows the cumulative types to do allocas.
      unless meta_vars
        if typed_def = @typed_def
          meta_vars = typed_def.vars = MetaVars.new
        else
          meta_vars = @program.vars
        end
        vars.each do |name, var|
          meta_var = new_meta_var(name)
          meta_var.bind_to(var)
          meta_vars[name] = meta_var
        end
      end

      @meta_vars = meta_vars
    end

    def initialize(*, from_main_visitor : MainVisitor)
      super(from_main_visitor.@program, from_main_visitor.@vars)
      @meta_vars = from_main_visitor.@meta_vars
      @typed_def = from_main_visitor.@typed_def
      @scope = from_main_visitor.@scope
      @path_lookup = from_main_visitor.@path_lookup
    end

    def visit_any(node)
      @unreachable = false
      super
    end

    def visit(node : FileNode)
      old_vars = @vars
      old_meta_vars = @meta_vars
      old_file_module = @file_module

      @vars = MetaVars.new
      @file_module = file_module = @program.file_module(node.filename)
      @meta_vars = file_module.vars

      node.node.accept self
      node.type = @program.nil_type

      @vars = old_vars
      @meta_vars = old_meta_vars
      @file_module = old_file_module

      false
    end

    def visit(node : Path)
      lookup_scope = @path_lookup || @scope || @current_type

      # If the lookup scope is a generic type, like Foo(T), we don't
      # want to find T in main code. For example:
      #
      # class Foo(T)
      #   Bar(T) # This T is unbound and it shouldn't be found in the lookup
      # end
      find_root_generic_type_parameters = !lookup_scope.is_a?(GenericType)

      type = lookup_scope.lookup_type_var(node,
        free_vars: free_vars,
        find_root_generic_type_parameters: find_root_generic_type_parameters,
        remove_alias: false)

      case type
      when Const
        if !type.value.type? && !type.visited?
          type.visited = true

          meta_vars = MetaVars.new
          const_def = Def.new("const", [] of Arg)
          type_visitor = MainVisitor.new(@program, meta_vars, const_def)
          type_visitor.current_type = type.namespace
          type_visitor.inside_constant = true
          type.value.accept type_visitor

          type.fake_def = const_def
          type.visitor = self
          type.used = true

          program.const_initializers << type
        end

        node.target_const = type
        node.bind_to type.value
      when Type
        # We devirtualize the type because in an expression like
        #
        #     T.new
        #
        # even if T is a virtual type that resulted from a generic
        # type argument, creating an instance or invoking methods
        # on the type itself don't need to resolve virtually.
        #
        # It's different if from a virtual type we do `v.class.new`
        # because the class could be any in the hierarchy.
        node.type = check_type_in_type_args(type.remove_alias_if_simple).devirtualize
        node.target_type = type
      when ASTNode
        type.accept self unless type.type?
        node.syntax_replacement = type
        node.bind_to type
      end

      false
    end

    def visit(node : Generic)
      node.in_type_args = @in_type_args > 0
      node.inside_is_a = @inside_is_a
      node.scope = @scope

      node.name.accept self

      @in_type_args += 1
      node.type_vars.each &.accept self
      node.named_args.try &.each &.value.accept self
      @in_type_args -= 1

      return false if node.type?

      name = node.name
      if name.is_a?(Path) && name.target_const
        node.raise "#{name} is not a type, it's a constant"
      end

      instance_type = node.name.type.instance_type
      unless instance_type.is_a?(GenericType)
        node.raise "#{instance_type} is not a generic type, it's a #{instance_type.type_desc}"
      end

      if instance_type.double_variadic?
        unless node.type_vars.empty?
          node.raise "can only instantiate NamedTuple with named arguments"
        end
      else
        if node.named_args
          node.raise "can only use named arguments with NamedTuple"
        end

        # Need to count type vars because there might be splats
        type_vars_count = 0
        knows_count = true
        node.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            if (type_var_type = type_var.type?)
              unless type_var_type.is_a?(TupleInstanceType)
                type_var.raise "argument to splat must be a tuple type, not #{type_var_type}"
              end

              type_vars_count += type_var_type.size
            else
              knows_count = false
              break
            end
          else
            type_vars_count += 1
          end
        end

        if knows_count
          if instance_type.splat_index
            min_needed = instance_type.type_vars.size
            min_needed -= 1 if instance_type.splat_index

            if type_vars_count < min_needed
              node.wrong_number_of "type vars", instance_type, type_vars_count, "#{min_needed}+"
            end
          else
            needed_count = instance_type.type_vars.size
            if type_vars_count != needed_count
              node.wrong_number_of "type vars", instance_type, type_vars_count, needed_count
            end
          end
        end
      end

      node.instance_type = instance_type.as(GenericType)
      node.type_vars.each &.add_observer(node)
      node.named_args.try &.each &.value.add_observer(node)
      node.update

      false
    end

    def visit(node : ProcNotation)
      types = [] of Type
      @in_type_args += 1

      node.inputs.try &.each do |input|
        input.accept self
        input_type = input.type
        check_not_a_constant(input)
        MainVisitor.check_type_allowed_as_proc_argument(input, input_type)
        types << input_type.virtual_type
      end

      if output = node.output
        output.accept self
        output_type = output.type
        check_not_a_constant(output)
        MainVisitor.check_type_allowed_as_proc_argument(output, output_type)
        types << output_type.virtual_type
      else
        types << program.void
      end

      @in_type_args -= 1
      node.type = program.proc_of(types)

      false
    end

    def visit(node : Union)
      @in_type_args += 1
      node.types.each &.accept self
      @in_type_args -= 1

      node.inside_is_a = @inside_is_a
      node.update

      false
    end

    def visit(node : Metaclass)
      node.name.accept self
      node.type = node.name.type.virtual_type.metaclass
      false
    end

    def visit(node : Self)
      node.type = the_self(node).instance_type
      false
    end

    def visit(node : Var)
      var = @vars[node.name]?
      if var
        if var.type?.is_a?(Program) && node.name == "self"
          node.raise "there's no self in this scope"
        end

        meta_var = @meta_vars[node.name]
        check_closured meta_var

        if var.nil_if_read?
          # Once we know a variable is nil if read we mark it as nilable
          var.bind_to(@program.nil_var)
          var.nil_if_read = false

          meta_var.bind_to(@program.nil_var) unless meta_var.dependencies.any? &.same?(@program.nil_var)
          node.bind_to(@program.nil_var)
        end

        check_mutably_closured meta_var, var

        node.bind_to(var)

        if needs_type_filters?
          @type_filters = TypeFilters.truthy(node)
        end
      elsif node.name == "self"
        current_type = current_type()
        if current_type.is_a?(Program)
          node.raise "there's no self in this scope"
        else
          node.type = current_type.metaclass
        end
      elsif node.special_var?
        special_var = define_special_var(node.name, program.nil_var)
        node.bind_to special_var
      else
        node.raise "read before assignment to local variable '#{node.name}'"
      end
      false
    end

    def visit(node : TypeDeclaration)
      case var = node.var
      when Var
        if @meta_vars[var.name]?
          node.raise "variable '#{var.name}' already declared"
        end

        meta_var = new_meta_var(var.name)
        meta_var.type = @program.no_return

        var.bind_to(meta_var)
        @meta_vars[var.name] = meta_var

        @in_type_args += 1
        node.declared_type.accept self
        @in_type_args -= 1

        check_not_a_constant(node.declared_type)

        if declared_type = node.declared_type.type?
          var_type = check_declare_var_type node, declared_type, "a variable"
          meta_var.freeze_type = var_type
        else
          node.raise "can't infer type of type declaration"
        end

        if value = node.value
          type_assign(var, value, node)

          node.bind_to value
        else
          node.type = @program.nil
        end
      when InstanceVar
        if @untyped_def
          node.raise "declaring the type of an instance variable must be done at the class level"
        end

        node.type = @program.nil
      when ClassVar
        if @untyped_def
          node.raise "declaring the type of a class variable must be done at the class level"
        end

        thread_local = check_class_var_annotations

        class_var = lookup_class_var(var)
        var.var = class_var
        class_var.thread_local = true if thread_local

        node.type = @program.nil
      else
        raise "Bug: unexpected var type: #{var.class}"
      end

      false
    end

    def visit(node : UninitializedVar)
      case var = node.var
      when Var
        if @vars[var.name]?
          var.raise "variable '#{var.name}' already declared"
        end

        @in_type_args += 1
        node.declared_type.accept self
        @in_type_args -= 1

        check_not_a_constant(node.declared_type)

        # TODO: should we be using a binding here to recompute the type?
        if declared_type = node.declared_type.type?
          var_type = check_declare_var_type node, declared_type, "a variable"
          var_type = var_type.virtual_type
          var.type = var_type
        else
          node.raise "can't infer type of type declaration"
        end

        meta_var, _ = assign_to_meta_var(var.name)
        if (existing_type = meta_var.type?) && existing_type != var_type
          node.raise "variable '#{var.name}' already declared with type #{existing_type}"
        end

        meta_var.bind_to(var)
        meta_var.freeze_type = var_type

        @vars[var.name] = meta_var

        check_exception_handler_vars(var.name, node)

        node.type = meta_var.type unless meta_var.type.no_return?
      when InstanceVar
        type = scope? || current_type
        if @untyped_def
          @in_type_args += 1
          node.declared_type.accept self
          @in_type_args -= 1

          check_declare_var_type node, node.declared_type.type, "an instance variable"
          ivar = lookup_instance_var(var, type)

          if @is_initialize
            @vars[var.name] = MetaVar.new(var.name, ivar.type)
          end
        else
          # Already handled in a previous visitor
          node.type = @program.nil
          return false
        end

        case type
        when NonGenericClassType
          @in_type_args += 1
          node.declared_type.accept self
          @in_type_args -= 1
          check_declare_var_type node, node.declared_type.type, "an instance variable"
        when GenericClassType
          # OK
        when GenericClassInstanceType
          # OK
        else
          node.raise "can only declare instance variables of a non-generic class, not a #{type.type_desc} (#{type})"
        end
      when ClassVar
        thread_local = check_class_var_annotations

        class_var = visit_class_var var
        class_var.thread_local = true if thread_local
      else
        raise "Bug: unexpected var type: #{var.class}"
      end

      node.type = @program.nil unless node.type?

      false
    end

    def check_not_a_constant(node)
      if node.is_a?(Path) && node.target_const
        node.raise "#{node.target_const} is not a type, it's a constant"
      end
    end

    def check_exception_handler_vars(var_name, node)
      # If inside a begin part of an exception handler, bind this type to
      # the variable that will be used in the rescue/else blocks.
      @all_exception_handler_vars.try &.each do |exception_handler_vars|
        var = (exception_handler_vars[var_name] ||= MetaVar.new(var_name))
        var.bind_to(node)
      end
    end

    def visit(node : Out)
      case exp = node.exp
      when Var
        if @meta_vars.has_key?(exp.name)
          exp.raise "variable '#{exp.name}' is already defined, `out` must be used to define a variable, use another name"
        end

        # We declare out variables
        @meta_vars[exp.name] = new_meta_var(exp.name)
        @vars[exp.name] = new_meta_var(exp.name)
      when InstanceVar
        var = lookup_instance_var exp
        exp.bind_to(var)

        if @is_initialize
          @vars[exp.name] = MetaVar.new(exp.name)
        end
      when Underscore
        # Nothing to do
      else
        node.raise "BUG: unexpected out exp: #{exp}"
      end

      node.bind_to node.exp

      false
    end

    def visit(node : Global)
      # Reading from a special global variable is actually
      # reading from a local variable with that same not,
      # invoking `not_nil!` on it (because these are usually
      # accessed after invoking a method that brought them
      # into the current scope, and it would be annoying
      # to ask the user to always invoke `not_nil!` on it)
      case node.name
      when "$~", "$?"
        expanded = Call.new(Var.new(node.name).at(node), "not_nil!").at(node)
        expanded.accept self
        node.bind_to expanded
        node.expanded = expanded
      else
        node.raise "BUG: there should be no use of global variables other than $~ and $?"
      end

      false
    end

    def undefined_instance_variable(owner, node)
      similar_name = owner.lookup_similar_instance_var_name(node.name)
      program.undefined_instance_variable(node, owner, similar_name)
    end

    def first_time_accessing_meta_type_var?(var)
      return false if var.uninitialized?

      if var.freeze_type
        deps = var.dependencies?
        # If no dependencies, it's the case of a global for a regex literal.
        # If there are dependencies and it's just one, it's the same var
        deps ? deps.size == 1 : false
      else
        !var.dependencies?
      end
    end

    def visit(node : InstanceVar)
      var = lookup_instance_var node
      node.bind_to(var)

      if @is_initialize &&
         @typeof_nest == 0 &&
         !@vars.has_key?(node.name) &&
         !scope.has_instance_var_initializer?(node.name)
        ivar = scope.lookup_instance_var(node.name)
        ivar.nil_reason ||= NilReason.new(node.name, :used_before_initialized, [node] of ASTNode)
        ivar.bind_to program.nil_var
      end

      false
    end

    def visit(node : ReadInstanceVar)
      visit_read_instance_var node
      false
    end

    def visit_read_instance_var(node)
      node.obj.accept self
      node.obj.add_observer node
      node.update
    end

    def visit(node : ClassVar)
      thread_local = check_class_var_annotations

      var = visit_class_var node
      var.thread_local = true if thread_local

      false
    end

    def visit_class_var(node)
      var = lookup_class_var(node)
      node.bind_to var
      node.var = var
      var
    end

    private def lookup_instance_var(node)
      lookup_instance_var(node, @scope)
    end

    private def lookup_instance_var(node, scope)
      unless scope
        node.raise "can't use instance variables at the top level"
      end

      ivar = scope.remove_typedef.lookup_instance_var(node)
      unless ivar
        undefined_instance_variable(scope, node)
      end

      check_self_closured
      ivar
    end

    def visit(node : Expressions)
      exp_count = node.expressions.size
      node.expressions.each_with_index do |exp, i|
        if i == exp_count - 1
          exp.accept self
          node.bind_to exp
        else
          ignoring_type_filters { exp.accept self }
        end
      end

      if node.empty?
        node.set_type(@program.nil)
      end

      false
    end

    def visit(node : Assign)
      type_assign node.target, node.value, node

      if @is_initialize && !@found_self_in_initialize_call
        value = node.value
        if value.is_a?(Var) && value.name == "self"
          @found_self_in_initialize_call = [value] of ASTNode
        end
      end
      false
    end

    def type_assign(target : Var, value, node, restriction = nil)
      value.accept self

      var_name = target.name
      meta_var, meta_var_existed = assign_to_meta_var(var_name)

      freeze_type = meta_var.freeze_type

      if freeze_type
        if casted_value = check_automatic_cast(value, freeze_type, node)
          value = casted_value
        end
      end

      # If this assign comes from a AssignWithRestriction node, check the restriction

      if restriction && (value_type = value.type?)
        if value_type.restrict(restriction, match_context.not_nil!)
          # OK
        else
          # Check autocast too
          restriction_type = (path_lookup || scope).lookup_type?(restriction, free_vars: free_vars)
          if casted_value = check_automatic_cast(value, restriction_type, node)
            value = casted_value
          else
            if value.is_a?(SymbolLiteral) && restriction_type.is_a?(EnumType)
              node.raise "can't autocast #{value} to #{restriction_type}: no matching enum member"
            end

            node.raise "can't restrict #{value.type} to #{restriction}"
          end
        end
      end

      target.bind_to value
      node.bind_to value

      value_type_filters = @type_filters
      @type_filters = nil

      # Save variable assignment location for debugging output
      meta_var.location ||= target.location

      begin
        meta_var.bind_to value
      rescue ex : FrozenTypeException
        target.raise ex.message
      end

      meta_var.assigned_to = true
      check_closured meta_var, mark_as_mutably_closured: meta_var_existed

      simple_var = MetaVar.new(var_name)

      # When we assign to a local variable with a fixed type, and it's
      # a Proc, we always want to keep that proc's type.
      if freeze_type && freeze_type.is_a?(ProcInstanceType)
        simple_var.bind_to(meta_var)
      else
        simple_var.bind_to(target)

        check_mutably_closured(meta_var, simple_var)
      end

      @vars[var_name] = simple_var

      check_exception_handler_vars var_name, value

      if needs_type_filters?
        @type_filters = TypeFilters.assign_var(value_type_filters, target)
      end

      if target.special_var?
        if typed_def = @typed_def
          typed_def.add_special_var(target.name)

          # Always bind with a special var with nil, so it's easier to assign it later
          # in the codegen (just store the whole value through a pointer)
          simple_var.bind_to(@program.nil_var)
          meta_var.bind_to(@program.nil_var)

          # If we are in a call's block, define the special var in the block
          if (call = @call) && call.block
            call.parent_visitor.define_special_var(target.name, value)
          end
        else
          node.raise "'#{var_name}' can't be assigned at the top level"
        end
      end
    end

    def type_assign(target : InstanceVar, value, node)
      # Check if this is an instance variable initializer
      unless @scope
        # `InstanceVar` assignment appeared in block is not checked
        # by `Crystal::InstanceVarsInitializerVisitor` because this block
        # may be passed to a macro. So, it checks here.
        if current_type.is_a?(Program) || current_type.is_a?(FileModule)
          node.raise "can't use instance variables at the top level"
        end

        # Already handled by InstanceVarsInitializerVisitor
        return
      end

      value.accept self

      var = lookup_instance_var target
      if casted_value = check_automatic_cast(value, var.type, node)
        value = casted_value
      end

      target.bind_to var
      node.bind_to value

      begin
        var.bind_to value
      rescue ex : FrozenTypeException
        target.raise ex.message
      end

      if @is_initialize
        var_name = target.name

        # Don't track instance variables nilability (for example, if they were
        # just assigned inside a branch) if they have an initializer
        unless scope.has_instance_var_initializer?(var_name)
          meta_var, _ = assign_to_meta_var(var_name)
          meta_var.bind_to value
          meta_var.assigned_to = true

          simple_var = MetaVar.new(var_name)
          simple_var.bind_to(target)
        end

        # Check if an instance variable is being assigned (for the first time)
        # and self, or that same instance variable, was used (read) before that.
        unless @vars.has_key?(var_name) || scope.has_instance_var_initializer?(var_name)
          if (found_self = @found_self_in_initialize_call) ||
             (used_ivars_node = @used_ivars_in_calls_in_initialize.try(&.[var_name]?)) ||
             (@block_nest > 0)
            ivar = scope.lookup_instance_var(var_name)
            if found_self
              ivar.nil_reason = NilReason.new(var_name, :used_self_before_initialized, found_self)
            else
              ivar.nil_reason = NilReason.new(var_name, :used_before_initialized, used_ivars_node)
            end
            ivar.bind_to program.nil_var
          end
        end

        if simple_var
          @vars[var_name] = simple_var

          check_exception_handler_vars var_name, value
        end
      end
    end

    def type_assign(target : Path, value, node)
      target.bind_to value
      node.type = @program.nil
      false
    end

    def type_assign(target : Global, value, node)
      node.raise "BUG: there should be no use of global variables other than $~ and $?"
    end

    def type_assign(target : ClassVar, value, node)
      thread_local = check_class_var_annotations

      # Outside a def is already handled by ClassVarsInitializerVisitor
      # (@exp_nest is 1 if we are at the top level because it was incremented
      # by one since we are inside an Assign)
      if !@typed_def && (@exp_nest <= 1) && !inside_block?
        var = lookup_class_var(target)
        target.var = var
        var.thread_local = true if thread_local
        return
      end

      value.accept self

      var = lookup_class_var(target)
      target.var = var
      var.thread_local = true if thread_local

      if casted_value = check_automatic_cast(value, var.type, node)
        value = casted_value
      end

      target.bind_to var

      node.bind_to value
      var.bind_to value
    end

    def type_assign(target : Underscore, value, node)
      value.accept self
      node.bind_to value
    end

    def type_assign(target, value, node)
      raise "BUG: unknown assign target in MainVisitor: #{target}"
    end

    # See if we can automatically cast the value if the types don't exactly match
    def check_automatic_cast(value, var_type, assign = nil)
      MainVisitor.check_automatic_cast(@program, value, var_type, assign)
    end

    def self.check_automatic_cast(program, value, var_type, assign = nil)
      if value.is_a?(NumberLiteral) && value.type != var_type
        literal_type = NumberAutocastType.new(program, value)
        restricted = literal_type.restrict(var_type, MatchContext.new(value.type, value.type))
        if restricted.is_a?(IntegerType) || restricted.is_a?(FloatType)
          value.type = restricted
          value.kind = restricted.kind
          assign.value = value if assign
          return value
        end
      elsif value.is_a?(SymbolLiteral) && value.type != var_type
        literal_type = SymbolAutocastType.new(program, value)
        restricted = literal_type.restrict(var_type, MatchContext.new(value.type, value.type))
        if restricted.is_a?(EnumType)
          member = restricted.find_member(value.value).not_nil!
          path = Path.new(member.name)
          path.target_const = member
          path.type = restricted
          value = path
          assign.value = value if assign
          return value
        end
      end

      nil
    end

    def visit(node : Yield)
      call = @call
      unless call
        node.raise "can't use `yield` outside a method"
      end

      if @fun_literal_context
        node.raise <<-MSG
          can't use `yield` inside a proc literal or captured block

          Make sure to read the whole docs section about blocks and procs,
          including "Capturing blocks" and "Block forwarding":

          https://crystal-lang.org/reference/syntax_and_semantics/blocks_and_procs.html
          MSG
      end

      block = call.block || node.raise("no block given")

      # This is the case of a yield when there's a captured block
      if block.fun_literal
        block_arg_name = typed_def.block_arg.not_nil!.name
        block_var = Var.new(block_arg_name).at(node)
        call = Call.new(block_var, "call", node.exps).at(node)
        call.accept self
        node.bind_to call
        node.expanded = call
        return false
      end

      node.scope.try &.accept self
      node.exps.each &.accept self

      # We use a binder to support splats and other complex forms
      binder = block.binder ||= YieldBlockBinder.new(@program, block)
      binder.add_yield(node, @yield_vars)
      binder.update

      unless block.visited?
        # When we yield, we are no longer inside `untyped_def`, so we un-nest
        untyped_def = @untyped_def
        untyped_def.block_nest -= 1 if untyped_def

        call.bubbling_exception do
          if node_scope = node.scope
            block.scope = node_scope.type
          end
          ignoring_type_filters do
            block.accept call.parent_visitor.not_nil!
          end
        end

        # And now we are back inside `untyped_def`
        untyped_def.block_nest += 1 if untyped_def
      end

      node.bind_to block

      @type_filters = nil
      false
    end

    def visit(node : Block)
      return false if node.visited?

      node.visited = true
      node.context = current_non_block_context

      before_block_vars = node.vars.try(&.dup) || MetaVars.new

      body_exps = node.body.as?(Expressions).try(&.expressions)

      # Variables that we don't want to get their type merged
      # with local variables before the block occurrence:
      # mainly block arguments (locally override vars), but
      # also block arguments that result from tuple unpacking
      # that the parser currently generated as local assignments.
      ignored_vars_after_block = nil

      meta_vars = @meta_vars.dup

      node.args.each do |arg|
        bind_block_var(node, arg, meta_vars, before_block_vars)
      end

      # If the block has unpacking, like:
      #
      #     do |(x, y)|
      #       ...
      #     end
      #
      # it was transformed to unpack the block vars inside the body:
      #
      #     do |__temp_1|
      #       x, y = __temp_1
      #       ...
      #     end
      #
      # We need to treat these variables as block arguments (so they don't override existing local variables).
      if unpacks = node.unpacks
        ignored_vars_after_block = node.args.dup
        unpacks.each_value do |unpack|
          handle_unpacked_block_argument(node, unpack, meta_vars, before_block_vars, ignored_vars_after_block)
        end
      end

      @block_nest += 1

      block_visitor = MainVisitor.new(program, before_block_vars, @typed_def, meta_vars)
      block_visitor.yield_vars = @yield_vars
      block_visitor.match_context = @match_context
      block_visitor.untyped_def = @untyped_def
      block_visitor.call = @call
      block_visitor.fun_literal_context = @fun_literal_context
      block_visitor.parent = self
      block_visitor.with_scope = node.scope || with_scope
      block_visitor.all_exception_handler_vars = @all_exception_handler_vars
      block_visitor.file_module = @file_module

      block_scope = @scope
      block_scope ||= current_type.metaclass unless current_type.is_a?(Program)

      block_visitor.scope = block_scope

      block_visitor.block = node
      block_visitor.path_lookup = path_lookup || current_type
      block_visitor.block_nest = @block_nest

      block_visitor.last_block_kind = :block
      block_visitor.inside_ensure = inside_ensure?

      node.body.accept block_visitor

      @block_nest -= 1

      # Check re-assigned variables and bind them.
      ignored_vars_after_block ||= node.args
      bind_vars block_visitor.vars, node.vars, ignored_vars_after_block
      bind_vars block_visitor.vars, node.after_vars, ignored_vars_after_block

      # Special vars, even if only assigned inside a block,
      # must be inside the def's metavars.
      meta_vars.each do |name, var|
        if var.special_var?
          define_special_var(name, var)
        end
      end

      node.vars = meta_vars

      node.bind_to node.body

      false
    end

    def handle_unpacked_block_argument(node, arg, meta_vars, before_block_vars, ignored_vars_after_block)
      case arg
      when Var
        bind_block_var(node, arg, meta_vars, before_block_vars)
        ignored_vars_after_block << Var.new(arg.name)
      when Underscore
        # Nothing
      when Splat
        handle_unpacked_block_argument(node, arg.exp, meta_vars, before_block_vars, ignored_vars_after_block)
      when Expressions
        arg.expressions.each do |exp|
          handle_unpacked_block_argument(node, exp, meta_vars, before_block_vars, ignored_vars_after_block)
        end
      end
    end

    def bind_block_var(node, target, meta_vars, before_block_vars)
      meta_var = new_meta_var(target.name, context: node)
      meta_var.bind_to(target)
      meta_vars[target.name] = meta_var

      before_block_var = new_meta_var(target.name, context: node)
      before_block_var.bind_to(target)
      before_block_vars[target.name] = before_block_var
    end

    def bind_vars(from_vars, to_vars, ignored = nil)
      if to_vars
        from_vars.each do |name, block_var|
          unless ignored.try &.find { |arg| arg.name == name }
            to_var = to_vars[name]?
            if to_var && !to_var.same?(block_var)
              to_var.try &.bind_to(block_var)
            end
          end
        end
      end
    end

    def visit(node : ProcLiteral)
      return false if node.type?

      fun_vars = @vars.dup
      meta_vars = @meta_vars.dup

      node.def.args.each do |arg|
        # It can happen that the argument has a type already,
        # when converting a block to a proc literal
        if restriction = arg.restriction
          @in_type_args += 1
          restriction.accept self
          @in_type_args -= 1
          arg_type = restriction.type
          MainVisitor.check_type_allowed_as_proc_argument(node, arg_type)
          arg.type = arg_type.virtual_type
        elsif !arg.type?
          arg.raise "parameter '#{arg.name}' of Proc literal must have a type"
        end

        fun_var = MetaVar.new(arg.name, arg.type)
        fun_vars[arg.name] = fun_var

        meta_var = new_meta_var(arg.name, context: node.def)
        meta_var.bind_to fun_var
        meta_vars[arg.name] = meta_var
      end

      if return_type = node.def.return_type
        @in_type_args += 1
        return_type.accept self
        @in_type_args -= 1
        check_not_a_constant(return_type)

        def_type = return_type.type
        MainVisitor.check_type_allowed_as_proc_argument(node, def_type)
        node.expected_return_type = def_type.virtual_type
      end

      node.bind_to node.def
      node.def.bind_to node.def.body
      node.def.vars = meta_vars

      block_visitor = MainVisitor.new(program, fun_vars, node.def, meta_vars)
      block_visitor.current_type = current_type
      block_visitor.yield_vars = @yield_vars
      block_visitor.match_context = @match_context
      block_visitor.untyped_def = node.def
      block_visitor.call = @call
      block_visitor.scope = @scope
      block_visitor.path_lookup = path_lookup
      block_visitor.fun_literal_context = @fun_literal_context || @typed_def || @program
      block_visitor.block_nest = @block_nest + 1
      block_visitor.parent = self
      block_visitor.is_initialize = @is_initialize

      node.def.body.accept block_visitor

      false
    end

    def self.check_type_allowed_as_proc_argument(node, type)
      Crystal.check_type_can_be_stored(node, type, "can't use #{type.to_s(generic_args: false)} as a Proc argument type")
    end

    def visit(node : ProcPointer)
      obj = node.obj

      if obj
        obj.accept self
      end

      # The call might have been created if this is a proc pointer at the top-level
      call = node.call? || Call.new(obj, node.name).at(obj)
      prepare_call(call)

      # A proc pointer like `->foo` where `foo` is a macro is invalid
      if expand_macro(call)
        node.raise(String.build do |io|
          io << "undefined method '#{node.name}'"
          (io << " for " << obj.type) if obj
          io << "\n\n'" << node.name << "' exists as a macro, but macros can't be used in proc pointers"
        end)
      end

      # If it's something like `->foo.bar` we turn it into a closure
      # where `foo` is assigned to a temporary variable.
      # If it's something like `->foo` then we also turn it into a closure
      # because it could be doing a mutlidispatch and that's not supported in ProcPointer.
      if !obj || obj.is_a?(Var) || obj.is_a?(InstanceVar) || obj.is_a?(ClassVar)
        expand(node)
        return false
      end

      # If it's something like `->Foo.bar` and `Foo` is not a lib type,
      # it could also be producing a multidispatch so we rewrite that too
      # (lib types can never produce a mutlidispatch and in that case we can
      # actually generate a function pointer that points right into the C fun).
      if obj.is_a?(Path) && !obj.type.is_a?(LibType)
        expand(node)
        return false
      end

      # Check if it's ->LibFoo.foo, so we deduce the type from that method
      if node.args.empty? && obj && (obj_type = obj.type).is_a?(LibType)
        matching_fun = obj_type.lookup_first_def(node.name, false)
        node.raise "undefined fun '#{node.name}' for #{obj_type}" unless matching_fun

        call.args = matching_fun.args.map_with_index do |arg, i|
          Var.new("arg#{i}", arg.type).as(ASTNode)
        end
      else
        call.args = node.args.map_with_index do |arg, i|
          arg.accept self
          arg_type = arg.type
          MainVisitor.check_type_allowed_as_proc_argument(node, arg_type)
          Var.new("arg#{i}", arg_type.virtual_type).as(ASTNode)
        end
      end

      begin
        call.recalculate
      rescue ex : Crystal::CodeError
        node.raise "error instantiating #{node}", ex
      end

      node.call = call
      node.bind_to call

      false
    end

    def visit(node : Call)
      prepare_call(node)

      if expand_macro(node)
        # It can happen that this call is inside an ArrayLiteral or HashLiteral,
        # was expanded but isn't bound to the expansion because the call (together
        # with its expansion) was cloned.
        if (expanded = node.expanded) && (node.dependencies.empty? || !node.type?)
          node.bind_to(expanded)
        end

        return false
      end

      # If the call has splats or double splats, and any of them are
      # not variables, instance variables or global variables,
      # we replace this call with a separate one that declares temporary
      # variables with this splat expressions, so we don't evaluate them
      # twice (#2677)
      if call_needs_splat_expansion?(node)
        return replace_call_splats(node)
      end

      obj = node.obj
      args = node.args
      block_arg = node.block_arg
      named_args = node.named_args

      ignoring_type_filters do
        if obj
          obj.accept(self)

          check_lib_call node, obj.type?

          if check_special_new_call(node, obj.type?)
            return false
          end

          if check_slice_literal_call(node, obj.type?)
            return false
          end
        end

        args.each &.accept(self)
        block_arg.try &.accept self
        named_args.try &.each &.value.accept self
      end

      obj.try &.set_enclosing_call(node)
      args.each &.set_enclosing_call(node)
      block_arg.try &.set_enclosing_call node
      named_args.try &.each &.value.set_enclosing_call(node)

      check_super_or_previous_def_in_initialize node

      # If the call has a block we need to create a copy of the variables
      # and bind them to the current variables. Then, when visiting
      # the block we will bind more variables to these ones if variables
      # are reassigned.
      if node.block || block_arg
        before_vars = MetaVars.new
        after_vars = MetaVars.new

        @vars.each do |name, var|
          before_var = MetaVar.new(name)
          before_var.bind_to(var)
          before_var.nil_if_read = var.nil_if_read?
          before_vars[name] = before_var

          after_var = MetaVar.new(name)
          after_var.bind_to(var)
          after_var.nil_if_read = var.nil_if_read?
          after_vars[name] = after_var
          @vars[name] = after_var
        end

        if block = node.block
          block.vars = before_vars
          block.after_vars = after_vars
        else
          node.before_vars = before_vars
        end
      end

      recalculate_call(node)

      check_call_in_initialize node

      @type_filters = nil
      @unreachable = true if node.no_returns?

      false
    end

    def prepare_call(node)
      if node.global?
        node.scope = @program
      else
        node.scope = @scope || current_type.metaclass
      end
      node.with_scope = with_scope unless node.obj
      node.parent_visitor = self
    end

    def recalculate_call(node : Call)
      node.recalculate
    end

    def call_needs_splat_expansion?(node)
      node.args.each do |arg|
        case arg
        when Splat
          exp = arg.exp
        when DoubleSplat
          exp = arg.exp
        else
          next
        end

        case exp
        when Var, InstanceVar, ClassVar, Global
          next
        else
          return true
        end
      end

      false
    end

    def replace_call_splats(node)
      expanded = node.clone

      exps = [] of ASTNode
      expanded.args.each do |arg|
        case arg
        when Splat
          exp = arg.exp
        when DoubleSplat
          exp = arg.exp
        else
          next
        end

        case exp
        when Var, InstanceVar, ClassVar, Global
          next
        end

        temp_var = @program.new_temp_var.at(arg)
        assign = Assign.new(temp_var, exp).at(arg)
        exps << assign
        case arg
        when Splat
          arg.exp = temp_var.clone.at(arg)
        when DoubleSplat
          arg.exp = temp_var.clone.at(arg)
        else
          next
        end
      end

      exps << expanded
      expansion = Expressions.from(exps).at(expanded)
      expansion.accept self
      node.expanded = expansion
      node.bind_to(expanded)

      false
    end

    # If it's a super or previous_def call inside an initialize we treat
    # set instance vars from superclasses to not-nil.
    def check_super_or_previous_def_in_initialize(node)
      if @is_initialize && (node.super? || node.previous_def?)
        all_vars = scope.all_instance_vars.keys
        all_vars -= scope.instance_vars.keys if node.super?
        all_vars.each do |name|
          instance_var = scope.lookup_instance_var(name)

          # If a variable was used before this supercall, it becomes nilable
          if @used_ivars_in_calls_in_initialize.try &.has_key?(name)
            instance_var.nil_reason ||= NilReason.new(name, :used_before_initialized, [node] of ASTNode)
            instance_var.bind_to @program.nil_var
          else
            # Otherwise, declare it as a "local" variable
            meta_var = MetaVar.new(name)
            meta_var.bind_to instance_var
            @vars[name] = meta_var
          end
        end
      end
    end

    # Checks if it's a call to self. In that case, all instance variables
    # not mentioned so far will be considered nil.
    def check_call_in_initialize(node)
      return unless @is_initialize
      return if @typeof_nest > 0

      node_obj = node.obj
      if !node_obj || (node_obj.is_a?(Var) && node_obj.name == "self")
        # Special case: when calling self.class a class method will be invoked
        # and there's no possibility of accessing instance vars, so we ignore this case.
        if node.name == "class" && node.args.empty?
          return
        end

        ivars, found_self = gather_instance_vars_read node
        if found_self
          @found_self_in_initialize_call ||= found_self
        elsif ivars
          used_ivars_in_calls_in_initialize = @used_ivars_in_calls_in_initialize
          if used_ivars_in_calls_in_initialize
            @used_ivars_in_calls_in_initialize = used_ivars_in_calls_in_initialize.merge(ivars)
          else
            @used_ivars_in_calls_in_initialize = ivars
          end
        end
      else
        # Check if any argument is "self"
        unless @found_self_in_initialize_call
          node.args.each do |arg|
            if arg.is_a?(Var) && arg.name == "self"
              @found_self_in_initialize_call = [node] of ASTNode
              return
            end
          end
        end
      end
    end

    # Fill function literal argument types for C functions
    def check_lib_call(node, obj_type)
      return unless obj_type.is_a?(LibType)

      # Error quickly if we can't find a fun
      method = obj_type.lookup_first_def(node.name, false)
      node.raise "undefined fun '#{node.name}' for #{obj_type}" unless method

      node.args.each_with_index do |arg, index|
        case arg
        when ProcLiteral
          next unless arg.def.args.any? { |def_arg| !def_arg.restriction && !def_arg.type? }

          check_lib_call_arg(method, index) do |method_arg_type|
            arg.def.args.each_with_index do |def_arg, def_arg_index|
              if !def_arg.restriction && !def_arg.type?
                def_arg.type = method_arg_type.arg_types[def_arg_index]?
              end
            end
          end
        when ProcPointer
          next unless arg.args.empty?

          check_lib_call_arg(method, index) do |method_arg_type|
            method_arg_type.arg_types.each do |arg_type|
              arg.args.push TypeNode.new(arg_type)
            end
          end
        else
          # keep checking
        end
      end
    end

    def check_lib_call_arg(method, arg_index, &)
      method_arg = method.args[arg_index]?
      return unless method_arg

      method_arg_type = method_arg.type
      return unless method_arg_type.is_a?(ProcInstanceType)

      yield method_arg_type
    end

    # Checks if it's ProcType#new
    def check_special_new_call(node, obj_type)
      return false unless obj_type
      return false unless obj_type.metaclass?

      instance_type = obj_type.instance_type.remove_typedef

      if node.name == "new"
        case instance_type
        when .extern?
          if instance_type.namespace.is_a?(LibType) && (named_args = node.named_args)
            return special_c_struct_or_union_new_with_named_args(node, instance_type, named_args)
          end
        end
      end

      false
    end

    def check_slice_literal_call(node, obj_type)
      return false unless obj_type
      return false unless obj_type.metaclass?

      instance_type = obj_type.instance_type.remove_typedef

      if node.name == "literal"
        case instance_type
        when GenericClassType # Slice
          return false unless instance_type == @program.slice
          node.raise "TODO: implement slice_literal primitive for Slice without generic arguments"
        when GenericClassInstanceType # Slice(T)
          return false unless instance_type.generic_type == @program.slice

          element_type = instance_type.type_vars["T"].type
          kind = case element_type
                 when IntegerType
                   element_type.kind
                 when FloatType
                   element_type.kind
                 else
                   node.raise "Only slice literals of primitive integer or float types can be created"
                 end

          node.args.each do |arg|
            arg.raise "Expected NumberLiteral, got #{arg.class_desc}" unless arg.is_a?(NumberLiteral)
            arg.accept self
            arg.raise "Argument out of range for a Slice(#{element_type})" unless arg.representable_in?(element_type)
          end

          # create the internal constant `$Slice:n` to hold the slice contents
          const_name = "$Slice:#{@program.const_slices.size}"
          const_value = Nop.new
          const_value.type = @program.static_array_of(element_type, node.args.size)
          const = Const.new(@program, @program, const_name, const_value)
          @program.types[const_name] = const
          @program.const_slices << Program::ConstSliceInfo.new(const_name, kind, node.args)

          # ::Slice.new(pointerof($Slice:n.@buffer), {{ args.size }}, read_only: true)
          pointer_node = PointerOf.new(ReadInstanceVar.new(Path.new(const_name).at(node), "@buffer").at(node)).at(node)
          size_node = NumberLiteral.new(node.args.size.to_s, :i32).at(node)
          read_only_node = NamedArgument.new("read_only", BoolLiteral.new(true).at(node)).at(node)
          expanded = Call.new(Path.global("Slice").at(node), "new", [pointer_node, size_node], named_args: [read_only_node]).at(node)

          expanded.accept self
          node.bind_to expanded
          node.expanded = expanded
          return true
        end
      end

      false
    end

    # Rewrite:
    #
    #     LibFoo::Struct.new arg0: value0, argN: value0
    #
    # To:
    #
    #   temp = LibFoo::Struct.new
    #   temp.arg0 = value0
    #   temp.argN = valueN
    #   temp
    def special_c_struct_or_union_new_with_named_args(node, type, named_args)
      exps = [] of ASTNode

      temp_name = @program.new_temp_var_name

      new_call = Call.new(node.obj, "new").at(node)

      new_assign = Assign.new(Var.new(temp_name).at(node), new_call).at(node)
      exps << new_assign

      named_args.each do |named_arg|
        assign_call = Call.new(Var.new(temp_name).at(named_arg), "#{named_arg.name}=", named_arg.value).at(named_arg)
        if loc = named_arg.location
          assign_call.location = loc
          assign_call.name_location = loc
        end
        exps << assign_call
      end

      exps << Var.new(temp_name).at(node)

      expanded = Expressions.new(exps).at(node)
      expanded.accept self

      node.bind_to expanded
      node.expanded = expanded

      true
    end

    class InstanceVarsCollector < Visitor
      getter ivars : Hash(String, Array(ASTNode))?
      getter found_self : Array(ASTNode)?
      @scope : Type
      @in_super : Int32
      @callstack : Array(ASTNode)
      @visited : Set(Def)?
      @vars : MetaVars

      def initialize(a_def, @scope, @vars)
        @found_self = nil
        @in_super = 0
        @callstack = [a_def] of ASTNode
      end

      def node_in_callstack(node)
        nodes = [] of ASTNode
        nodes.concat @callstack
        nodes.push node
        nodes
      end

      def visit(node : InstanceVar)
        unless @vars.has_key?(node.name)
          ivars = @ivars ||= Hash(String, Array(ASTNode)).new
          unless ivars.has_key?(node.name)
            ivars[node.name] = node_in_callstack(node)
          end
        end
        false
      end

      def visit(node : Var)
        if @in_super == 0 && node.name == "self"
          @found_self = node_in_callstack(node)
        end
        false
      end

      def visit(node : Assign)
        node.value.accept self
        false
      end

      def visit(node : Call)
        obj = node.obj

        # Skip class method
        if obj.is_a?(Var) && obj.name == "self" && node.name == "class" && node.args.empty?
          return false
        end

        if obj && !(obj.is_a?(Var) && obj.name == "self")
          # not a self-instance method: only verify arguments
          return true
        end

        visited = @visited

        node.target_defs.try &.each do |target_def|
          if target_def.owner == @scope
            next if visited.try &.includes?(target_def)

            visited = @visited ||= Set(Def).new.compare_by_identity
            visited << target_def

            @callstack.push(node)
            target_def.body.accept self
            @callstack.pop
          end
        end

        if node.super?
          @in_super += 1
        end

        true
      end

      def end_visit(node : Call)
        if node.super?
          @in_super -= 1
        end
      end

      def visit(node : ASTNode)
        true
      end
    end

    def gather_instance_vars_read(node)
      collector = InstanceVarsCollector.new(typed_def, scope, @vars)
      node.accept collector
      {collector.ivars, collector.found_self}
    end

    def visit(node : Return)
      if inside_ensure?
        node.raise "can't return from ensure"
      end

      if inside_constant?
        node.raise "can't return from constant"
      end

      typed_def = @typed_def || node.raise("can't return from top level")

      if typed_def.captured_block?
        node.raise "can't return from captured block, use next"
      end

      node.exp.try &.accept self

      node.target = typed_def

      typed_def.bind_to(node_exp_or_nil_literal(node))

      @unreachable = true

      node.type = @program.no_return

      false
    end

    def end_visit(node : Splat)
      node.bind_to node.exp
    end

    def end_visit(node : DoubleSplat)
      node.bind_to node.exp
    end

    def visit(node : Underscore)
      if @in_type_args == 0
        node.raise "can't read from _"
      else
        node.raise "can't use underscore as generic type argument"
      end
    end

    def visit(node : IsA)
      node.obj.accept self

      @in_type_args += 1
      @inside_is_a = true
      node.const.accept self
      @inside_is_a = false
      @in_type_args -= 1

      node.type = program.bool
      const = node.const

      # When doing x.is_a?(A) and A turns out to be a constant (not a type),
      # replace it with a === comparison. Most usually this happens in a case expression.
      if const.is_a?(Path) && const.target_const
        obj = node.obj.clone.at(node.obj)
        const = node.const.clone.at(node.const)
        comp = Call.new(const, "===", obj).at(node)
        comp.accept self
        node.syntax_replacement = comp
        node.bind_to comp
        return false
      end

      if needs_type_filters? && (var = get_expression_var(node.obj))
        @type_filters = TypeFilters.new var, SimpleTypeFilter.new(node.const.type)
      end

      false
    end

    def end_visit(node : RespondsTo)
      node.type = program.bool
      if needs_type_filters? && (var = get_expression_var(node.obj))
        @type_filters = TypeFilters.new var, RespondsToTypeFilter.new(node.name)
      end
    end

    # Get the variable of an expression.
    # If it's a variable, it's that variable.
    # If it's an assignment to a variable, it's that variable.
    def get_expression_var(exp)
      case exp
      when Var
        return exp
      when Assign
        target = exp.target
        return target if target.is_a?(Var)
      when Expressions
        return unless exp = exp.single_expression?
        return get_expression_var(exp)
      end
      nil
    end

    def visit(node : Cast | NilableCast)
      # If there's an `x.as(T)` inside a method, that method
      # has a chance to raise, so we must mark it as such
      if typed_def = @typed_def
        typed_def.raises = true
      end

      ignoring_type_filters do
        node.obj.accept self
      end

      @in_type_args += 1
      ignoring_type_filters do
        node.to.accept self
      end
      @in_type_args -= 1

      node.obj.add_observer node
      node.update

      false
    end

    def visit(node : FunDef)
      body = node.body.not_nil!

      external = node.external
      return_type = external.type

      vars = MetaVars.new
      external.args.each do |arg|
        var = MetaVar.new(arg.name, arg.type)
        var.bind_to var
        vars[arg.name] = var
      end

      visitor = MainVisitor.new(@program, vars, external)
      visitor.untyped_def = external
      visitor.scope = @program

      begin
        body.accept visitor
      rescue ex : Crystal::CodeError
        node.raise ex.message, ex
      end

      inferred_return_type = @program.type_merge([body.type?, external.type?])

      if return_type && return_type != @program.nil && inferred_return_type != return_type
        node.raise "expected fun to return #{return_type} but it returned #{inferred_return_type}"
      end

      external.set_type(return_type)

      false
    end

    def visit(node : If)
      request_type_filters do
        node.cond.accept self
      end

      cond_vars = @vars
      cond_type_filters = @type_filters

      # then branch
      @vars = cond_vars.dup
      @type_filters = nil
      @unreachable = false

      filter_vars cond_type_filters
      before_then_vars = @vars.dup

      node.then.accept self

      then_vars = @vars
      then_type_filters = @type_filters
      then_unreachable = @unreachable

      # else branch
      @vars = cond_vars.dup
      @type_filters = nil
      @unreachable = false

      filter_vars TypeFilters.not(cond_type_filters)
      before_else_vars = @vars.dup

      node.else.accept self

      else_vars = @vars
      else_type_filters = @type_filters
      else_unreachable = @unreachable

      merge_if_vars node, cond_vars, then_vars, else_vars, before_then_vars, before_else_vars, then_unreachable, else_unreachable

      @type_filters = nil
      if needs_type_filters?
        case node
        when .and?
          # `a && b` is expanded to `a ? b : a`
          # We don't use `else_type_filters` because if `a` is a temp var
          # assignment then `cond_type_filters` would contain more information
          @type_filters = TypeFilters.and(cond_type_filters, then_type_filters)
        when .or?
          # `a || b` is expanded to `a ? a : b`
          @type_filters = TypeFilters.or(cond_type_filters, else_type_filters)
        end
      end

      @unreachable = then_unreachable && else_unreachable

      node.bind_to({node.then, node.else})

      false
    end

    # Here we merge the variables from both branches of an if.
    # We basically:
    #   - Create a variable whose type is the merged types of the last
    #     type of each branch.
    #   - Make the variable nilable if the variable wasn't declared
    #     before the 'if' and it doesn't appear in one of the branches.
    #   - Don't use the type of a branch that is unreachable (ends with return,
    #     break or with a call that is NoReturn)
    def merge_if_vars(node, cond_vars, then_vars, else_vars, before_then_vars, before_else_vars, then_unreachable, else_unreachable)
      then_vars.each do |name, then_var|
        else_var = else_vars[name]?

        merge_if_var(name, node, cond_vars, then_var, else_var, before_then_vars, before_else_vars, then_unreachable, else_unreachable)
      end

      else_vars.each do |name, else_var|
        next if then_vars.has_key?(name)

        merge_if_var(name, node, cond_vars, nil, else_var, before_then_vars, before_else_vars, then_unreachable, else_unreachable)
      end
    end

    def merge_if_var(name, node, cond_vars, then_var, else_var, before_then_vars, before_else_vars, then_unreachable, else_unreachable)
      # Check whether the var didn't change at all
      return if then_var.same?(else_var)

      cond_var = cond_vars[name]?

      # Only copy `nil_if_read` from each branch if it's not unreachable
      then_var_nil_if_read = !then_unreachable && then_var.try(&.nil_if_read?)
      else_var_nil_if_read = !else_unreachable && else_var.try(&.nil_if_read?)
      if_var_nil_if_read = !!(then_var_nil_if_read || else_var_nil_if_read)

      # Check if no types were changes in either then 'then' and 'else' branches
      if cond_var && !then_unreachable && !else_unreachable
        if then_var.same?(before_then_vars[name]?) &&
           else_var.same?(before_else_vars[name]?)
          cond_var.nil_if_read = if_var_nil_if_read
          @vars[name] = cond_var
          return
        end
      end

      if_var = MetaVar.new(name)
      if_var.nil_if_read = if_var_nil_if_read

      if then_var && else_var
        if then_unreachable
          if_var.bind_to conditional_no_return(node.then, then_var)
        else
          if_var.bind_to then_var
        end

        if else_unreachable
          if_var.bind_to conditional_no_return(node.else, else_var)
        else
          if_var.bind_to else_var
        end
      elsif then_var
        if then_unreachable
          if_var.bind_to conditional_no_return(node.then, then_var)
        else
          if_var.bind_to then_var
        end

        if cond_var
          if_var.bind_to cond_var
        elsif !else_unreachable
          if_var.bind_to program.nil_var
          if_var.nil_if_read = true
        else
          if_var.bind_to conditional_no_return(node.else, @program.nil_var)
        end
      elsif else_var
        if else_unreachable
          if_var.bind_to conditional_no_return(node.else, else_var)
        else
          if_var.bind_to else_var
        end

        if cond_var
          if_var.bind_to cond_var
        elsif !then_unreachable
          if_var.bind_to program.nil_var
          if_var.nil_if_read = true
        else
          if_var.bind_to conditional_no_return(node.then, @program.nil_var)
        end
      end

      @vars[name] = if_var
    end

    def conditional_no_return(node, var)
      node.filtered_by NoReturnFilter.new(var)
    end

    def visit(node : While)
      old_while_vars = @while_vars

      before_cond_vars_copy = @vars.dup

      @vars.each do |name, var|
        before_var = MetaVar.new(name)
        before_var.bind_to(var)
        before_var.nil_if_read = var.nil_if_read?
        @vars[name] = before_var
      end

      before_cond_vars = @vars.dup

      request_type_filters do
        node.cond.accept self
      end

      cond_type_filters = @type_filters

      after_cond_vars = @vars.dup
      @while_vars = after_cond_vars

      filter_vars cond_type_filters

      # `node.body` may reset this status, so we capture them in a set
      # (we don't need the full MetaVars at the moment)
      after_cond_vars_nil_if_read = Set(String).new
      @vars.each do |name, var|
        after_cond_vars_nil_if_read << name if var.nil_if_read?
      end

      @type_filters = nil
      @block, old_block = nil, @block

      @while_stack.push node

      with_block_kind :while do
        node.body.accept self
      end

      cond = node.cond.single_expression
      endless_while = cond.true_literal?
      merge_while_vars endless_while, before_cond_vars_copy, before_cond_vars, after_cond_vars, after_cond_vars_nil_if_read, node.break_vars

      @while_stack.pop
      @block = old_block
      @while_vars = old_while_vars

      unless node.has_breaks?
        if endless_while
          node.type = program.no_return
          return false
        end

        filter_vars TypeFilters.not(cond_type_filters)
      end

      node.bind_to(@program.nil_var) unless endless_while

      false
    end

    # Here we assign the types of variables after a while.
    def merge_while_vars(endless, before_cond_vars_copy, before_cond_vars, after_cond_vars, after_cond_vars_nil_if_read, all_break_vars)
      after_while_vars = MetaVars.new

      @vars.each do |name, while_var|
        before_cond_var = before_cond_vars[name]?
        after_cond_var = after_cond_vars[name]?
        after_while_vars[name] = after_while_var = MetaVar.new(name)

        # After while's body, bind variables *before* the condition to the
        # ones after the body, because the loop will repeat.
        #
        # For example:
        #
        #    x = exp
        #    # x starts with the type of exp
        #    while x = x.method
        #      # but after the loop, the x above (in x.method)
        #      # should now also get the type of x.method, recursively
        #    end
        if before_cond_var && !before_cond_var.same?(while_var)
          before_cond_var.bind_to(while_var)
        end

        # If the loop is endless
        if endless
          # Suppose we have
          #
          #     x = exp1
          #     while true
          #       x = exp2
          #       break if ...
          #       x = exp3
          #       break if ...
          #       x = exp4
          #     end
          #
          # Here the type of x after the loop will never be affected by
          # `x = exp4`, because `x = exp2` must have been executed before the
          # loop may exit at the first break. Therefore, if the x right before
          # the first break is different from the last x, we don't use the
          # latter's type upon exit (but exp2 itself may depend on exp4 if it
          # refers to x).
          break_var = all_break_vars.try &.dig?(0, name)
          unless break_var && !break_var.same?(while_var)
            after_while_var.bind_to(while_var)
            if before_cond_var
              after_while_var.nil_if_read = while_var.nil_if_read?
            end
          end

          # If there wasn't a previous variable with the same name, the variable
          # is newly defined inside the while.
          unless before_cond_var
            # If not all variables with the given name end up in a break it
            # means that they can be nilable.
            # Alternatively, if any var that ends in a break is nil-if-read then
            # the resulting variable will be nil-if-read too.
            if !all_break_vars.try(&.all? &.has_key?(name)) ||
               all_break_vars.try(&.any? &.[name]?.try &.nil_if_read?)
              after_while_var.nil_if_read = true
            end
          end
        else
          # If a variable was assigned in the condition, it has that type.
          if after_cond_var && !after_cond_var.same?(before_cond_var)
            after_while_var.bind_to(after_cond_var)

            # If the variable after the condition is nil-if-read, that means the
            # assignment inside the condition might not run upon loop exit, so
            # the variable may receive the type inside the loop.
            if after_cond_vars_nil_if_read.includes?(name)
              after_while_var.nil_if_read = true
              after_while_var.bind_to(while_var) if !after_cond_var.same?(while_var)
            end

            # If there was a previous variable, we use that type merged
            # with the last type inside the while.
          elsif before_cond_var
            # We need to bind to the variable *before* the condition, even
            # before the variables that are used in the condition
            # `before_cond_vars` are modified in the while body
            after_while_var.bind_to(before_cond_vars_copy[name])
            after_while_var.bind_to(while_var)
            after_while_var.nil_if_read = before_cond_var.nil_if_read? || while_var.nil_if_read?

            # Otherwise, it's a new variable inside the while: used
            # outside it must be nilable.
          else
            after_while_var.bind_to(while_var)
            after_while_var.nil_if_read = true
          end
        end
      end

      # We also need to merge types from breaks inside while.
      all_break_vars.try &.each do |break_vars|
        break_vars.each do |name, break_var|
          after_while_var = after_while_vars[name]?
          unless after_while_var
            # Fix for issue #2441:
            # it might be that a break variable is not present
            # in the current vars after a while
            after_while_var = new_meta_var(name)
            after_while_var.bind_to(program.nil_var)
            @meta_vars[name].bind_to(program.nil_var)
            after_while_vars[name] = after_while_var
          end
          after_while_var.bind_to(break_var)
        end
      end

      @vars = after_while_vars
    end

    # If we have:
    #
    #   if a
    #     ...
    #   end
    #
    # then inside the if 'a' must not be nil.
    #
    # This is what we do here: we create a meta-variable for
    # it and filter it accordingly. This also applied to
    # .is_a? and .responds_to?.
    #
    # This also applies to 'while' conditions and also
    # to the else part of an if, but with filters inverted.
    def filter_vars(filters)
      filter_vars(filters) { |filter| filter }
    end

    def filter_vars(filters, &)
      filters.try &.each do |name, filter|
        existing_var = @vars[name]
        filtered_var = MetaVar.new(name)
        filtered_var.bind_to(existing_var.filtered_by(yield filter))
        @vars[name] = filtered_var
      end
    end

    def end_visit(node : Break)
      if last_block_kind.ensure?
        node.raise "can't use break inside ensure"
      end

      if block = @block
        node.target = block.call.not_nil!

        block.break.bind_to(node_exp_or_nil_literal(node))

        bind_vars @vars, block.after_vars, block.args
      elsif target_while = @while_stack.last?
        node.target = target_while

        break_vars = (target_while.break_vars ||= [] of MetaVars)
        break_vars.push @vars.dup
        target_while.bind_to(node_exp_or_nil_literal(node))
      else
        if @typed_def.try &.captured_block?
          node.raise "can't break from captured block, try using `next`."
        end

        node.raise "invalid break"
      end

      node.type = @program.no_return

      @unreachable = true
    end

    def end_visit(node : Next)
      if last_block_kind.ensure?
        node.raise "can't use next inside ensure"
      end

      if block = @block
        node.target = block

        block.bind_to(node_exp_or_nil_literal(node))

        bind_vars @vars, block.vars
        bind_vars @vars, block.after_vars, block.args
      elsif target_while = @while_stack.last?
        node.target = target_while

        bind_vars @vars, @while_vars
      else
        typed_def = @typed_def
        if typed_def && typed_def.captured_block?
          node.target = typed_def
          typed_def.bind_to(node_exp_or_nil_literal(node))
        else
          node.raise "invalid next"
        end
      end

      node.type = @program.no_return

      @unreachable = true
    end

    def with_block_kind(kind : BlockKind, &)
      old_block_kind, @last_block_kind = last_block_kind, kind
      old_inside_ensure, @inside_ensure = @inside_ensure, @inside_ensure || kind.ensure?
      yield
      @last_block_kind = old_block_kind
      @inside_ensure = old_inside_ensure
    end

    def visit(node : Primitive)
      # If the method where this primitive is defined has a return type, use it
      if return_type = typed_def.return_type
        node.type = (path_lookup || scope).lookup_type(return_type, free_vars: free_vars)
        return false
      end

      case node.name
      when "allocate"
        visit_allocate node
      when "pre_initialize"
        visit_pre_initialize node
      when "pointer_malloc"
        visit_pointer_malloc node
      when "pointer_set"
        visit_pointer_set node
      when "pointer_new"
        visit_pointer_new node
      when "slice_literal"
        node.raise "BUG: Slice literal should have been expanded"
      when "argc"
        # Already typed
      when "argv"
        # Already typed
      when "struct_or_union_set"
        visit_struct_or_union_set node
      when "external_var_set"
        # Nothing to do
      when "external_var_get"
        # Nothing to do
      when "class"
        node.type = scope.metaclass
      when "enum_value"
        # Nothing to do
      when "enum_new"
        # Nothing to do
      when "throw_info"
        node.type = program.pointer_of(program.void)
      when "va_arg"
        visit_va_arg node
      else
        node.raise "BUG: unhandled primitive in MainVisitor: #{node.name}"
      end

      false
    end

    def visit_va_arg(node)
      arg = call.not_nil!.args[0]? || node.raise("requires type argument")
      node.type = arg.type.instance_type
    end

    def visit_allocate(node)
      instance_type = scope.instance_type

      case instance_type
      when GenericClassType
        node.raise "can't create instance of generic class #{instance_type} without specifying its type vars"
      when UnionType
        node.raise "can't create instance of a union type"
      when PointerInstanceType
        node.raise "can't create instance of a pointer type"
      else
        if instance_type.abstract?
          if instance_type.virtual?
            # A call to "allocate" on a virtual type can happen if we have something like:
            #
            # ```
            # abstract class Foo
            # end
            #
            # class Bar < Foo
            # end
            #
            # a = [] of Foo.class
            # a << Bar
            # a << Foo
            #
            # a.map(&.new)
            # ```
            #
            # It's perfectly fine to have an array of `Foo.class`, and we can
            # put `Foo` and `Bar` in it. We should also be able to call `new`
            # on every element in the array. We'll have to trust the user doesn't
            # put abstract types there. But if they are abstract, we make that
            # call a runtime error.
            base_type = instance_type.devirtualize

            extra = Call.new(
              nil,
              "raise",
              StringLiteral.new("Can't instantiate abstract #{base_type.type_desc} #{base_type}"),
              global: true)
            extra.accept self

            # This `extra` will replace the Primitive node in CleanupTransformer later on.
            node.extra = extra
            node.type = @program.no_return
            return
          else
            # If the type is not virtual then we know for sure that the type
            # can't be instantiated, and we can produce a compile-time error.
            node.raise "can't instantiate abstract #{instance_type.type_desc} #{instance_type}"
          end
        end

        node.type = instance_type
      end
    end

    def visit_pre_initialize(node)
      instance_type = scope.instance_type

      case instance_type
      when GenericClassType
        node.raise "Can't pre-initialize instance of generic class #{instance_type} without specifying its type vars"
      when UnionType
        node.raise "Can't pre-initialize instance of a union type"
      else
        if instance_type.abstract?
          if instance_type.virtual?
            # This is the same as `.initialize`
            base_type = instance_type.devirtualize

            extra = Call.new(
              nil,
              "raise",
              StringLiteral.new("Can't pre-initialize abstract class #{base_type}"),
              global: true).at(node)
            extra.accept self

            # This `extra` will replace the Primitive node in CleanupTransformer later on.
            node.extra = extra
            node.type = @program.no_return
            return
          else
            # If the type is not virtual then we know for sure that the type
            # can't be instantiated, and we can produce a compile-time error.
            node.raise "Can't pre-initialize abstract class #{instance_type}"
          end
        end

        node.type = instance_type
      end
    end

    def visit_pointer_malloc(node)
      if scope.instance_type.is_a?(GenericClassType)
        node.raise "can't malloc pointer without type, use Pointer(Type).malloc(size)"
      end

      node.type = scope.instance_type
    end

    def visit_pointer_set(node)
      scope = scope().remove_typedef.as(PointerInstanceType)

      # We don't want to change the value of Pointer(Void) to include Nil (Nil passes as Void)
      if scope.element_type.void?
        node.type = @program.nil
        return
      end

      value = @vars["value"]

      scope.var.bind_to value
      node.bind_to value
    end

    def visit_pointer_new(node)
      if scope.instance_type.is_a?(GenericClassType)
        node.raise "can't create pointer without type, use Pointer(Type).new(address)"
      end

      node.type = scope.instance_type
    end

    def visit_struct_or_union_set(node)
      scope = @scope.as(NonGenericClassType)

      field_name = call.not_nil!.name.rchop
      expected_type = scope.instance_vars['@' + field_name].type
      value = @vars["value"]
      actual_type = value.type

      node.type = actual_type

      actual_type = actual_type.remove_alias
      unaliased_type = expected_type.remove_alias

      return if actual_type.compatible_with?(unaliased_type)
      return if actual_type.implicitly_converted_in_c_to?(unaliased_type)

      case unaliased_type
      when IntegerType
        if convert_call = convert_struct_or_union_numeric_argument(node, unaliased_type, expected_type, actual_type)
          node.extra = convert_call
          return
        end
      when FloatType
        if convert_call = convert_struct_or_union_numeric_argument(node, unaliased_type, expected_type, actual_type)
          node.extra = convert_call
          return
        end
      end

      unsafe_call = Conversions.to_unsafe(node, Var.new("value").at(node), self, actual_type, expected_type)
      if unsafe_call
        node.extra = unsafe_call
        return
      end

      node.raise "field '#{field_name}' of #{scope.type_desc} #{scope} has type #{expected_type}, not #{actual_type}"
    end

    def convert_struct_or_union_numeric_argument(node, unaliased_type, expected_type, actual_type)
      Conversions.numeric_argument(node, Var.new("value"), self, unaliased_type, expected_type, actual_type)
    end

    def visit(node : PointerOf)
      var = pointerof_var(node)

      unless var
        # Accept the exp to trigger potential errors there, like
        # "undefined local variable or method"
        node.exp.accept self

        node.exp.raise "can't take address of #{node.exp}"
      end

      node.bind_to var
      true
    end

    def pointerof_var(node)
      case exp = node.exp
      when Var
        meta_var = @meta_vars[exp.name]
        meta_var.assigned_to = true
        meta_var
      when InstanceVar
        lookup_instance_var exp
      when ClassVar
        visit_class_var exp
      when Global
        node.raise "BUG: there should be no use of global variables other than $~ and $?"
      when Path
        exp.accept self
        if const = exp.target_const
          const.pointer_read = true
          const.value
        end
      when ReadInstanceVar
        visit_read_instance_var(exp)
        exp
      when Call
        # Check lib external var
        return unless exp.args.empty? && !exp.named_args && !exp.block && !exp.block_arg

        obj = exp.obj
        return unless obj

        obj.accept(self)

        obj_type = obj.type?
        return unless obj_type.is_a?(LibType)

        obj_type.lookup_var(exp.name)
      else
        nil
      end
    end

    def visit(node : TypeOf)
      # A typeof shouldn't change the type of variables:
      # so we keep the ones before it and restore them at the end
      old_vars = @vars.dup
      old_meta_vars = @meta_vars
      @meta_vars = old_meta_vars.dup

      node.in_type_args = @in_type_args > 0

      old_in_type_args = @in_type_args
      @in_type_args = 0

      @typeof_nest += 1
      ignoring_type_filters do
        node.expressions.each &.accept self
      end
      @typeof_nest -= 1

      @in_type_args = old_in_type_args

      node.bind_to node.expressions

      @vars = old_vars
      @meta_vars = old_meta_vars

      false
    end

    def visit(node : SizeOf)
      visit_size_or_align_of(node) do |type|
        @program.size_of(type.sizeof_type)
      end
    end

    def visit(node : InstanceSizeOf)
      visit_instance_size_or_align_of(node) do |type|
        @program.instance_size_of(type.sizeof_type)
      end
    end

    def visit(node : AlignOf)
      visit_size_or_align_of(node) do |type|
        @program.align_of(type.sizeof_type)
      end
    end

    def visit(node : InstanceAlignOf)
      visit_instance_size_or_align_of(node) do |type|
        @program.instance_align_of(type.sizeof_type)
      end
    end

    private def visit_size_or_align_of(node, &)
      @in_type_args += 1
      node.exp.accept self
      @in_type_args -= 1

      type = node.exp.type?

      if type.is_a?(GenericType)
        node.exp.raise "can't take #{sizeof_description(node)} of uninstantiated generic type #{type}"
      end

      # Try to resolve the node right now to a number literal
      # (useful for sizeof/alignof inside as a generic type argument, but also
      # to make it easier for LLVM to optimize things)
      if type && !node.exp.is_a?(TypeOf) &&
         !(type.module? || (type.abstract? && type.struct?))
        expanded = NumberLiteral.new(yield(type).to_s, :i32)
        expanded.type = @program.int32
        node.expanded = expanded
      end

      node.type = @program.int32

      false
    end

    private def visit_instance_size_or_align_of(node, &)
      @in_type_args += 1
      node.exp.accept self
      @in_type_args -= 1

      type = node.exp.type?

      if type.is_a?(GenericType)
        node.exp.raise "can't take #{sizeof_description(node)} of uninstantiated generic type #{type}"
      end

      # Try to resolve the instance_sizeof right now to a number literal
      # (useful for instance_sizeof inside as a generic type argument, but also
      # to make it easier for LLVM to optimize things)
      if type && type.devirtualize.class? && !type.metaclass? && !type.struct? && !node.exp.is_a?(TypeOf)
        expanded = NumberLiteral.new(yield(type).to_s, :i32)
        expanded.type = @program.int32
        node.expanded = expanded
      end

      node.type = @program.int32

      false
    end

    private def sizeof_description(node)
      case node
      in SizeOf
        "size"
      in AlignOf
        "alignment"
      in InstanceSizeOf
        "instance size"
      in InstanceAlignOf
        "instance alignment"
      end
    end

    def visit(node : OffsetOf)
      @in_type_args += 1
      node.offsetof_type.accept self
      @in_type_args -= 1

      type = node.offsetof_type.type?
      node.offsetof_type.raise "can't use typeof inside offsetof expression" if node.offsetof_type.is_a?(TypeOf)

      case type
      when TupleInstanceType
        number = node.offset.as?(NumberLiteral)
        node.offset.raise "can't take offset of a tuple element using an instance variable, use an index" if number.nil?

        ivar_index = number.integer_value
        node.offset.raise "can't take a negative offset of a tuple" if ivar_index < 0
        if ivar_index >= type.size
          node.offset.raise "can't take offset element at index #{ivar_index} from a tuple with #{type.size} elements"
        end
      when InstanceVarContainer
        ivar = node.offset.as?(InstanceVar)
        node.offset.raise "can't take offset element of #{type} using an index, use an instance variable" if ivar.nil?

        ivar_name = ivar.name
        ivar_index = type.index_of_instance_var(ivar_name)

        node.offset.raise "type #{type} doesn't have an instance variable called #{ivar_name}" unless ivar_index
        node.offsetof_type.raise "can't take offsetof element #{ivar_name} of uninstantiated generic type #{type}" if type.is_a?(GenericType)
      else
        node.offsetof_type.raise "type #{type} can't have instance variables neither is a Tuple"
      end

      if type && (type.struct? || type.is_a?(TupleInstanceType))
        offset = @program.offset_of(type.sizeof_type, ivar_index)
      elsif type && type.instance_type.devirtualize.class?
        offset = @program.instance_offset_of(type.sizeof_type, ivar_index)
      else
        node.offsetof_type.raise "#{type} is neither a class, a struct nor a Tuple, it's a #{type.type_desc}"
      end

      expanded = NumberLiteral.new(offset.to_s, :i32)
      expanded.type = @program.int32
      node.expanded = expanded
      node.type = @program.int32

      false
    end

    private def allowed_type_in_rescue?(type : UnionType) : Bool
      type.union_types.all? do |subtype|
        allowed_type_in_rescue? subtype
      end
    end

    private def allowed_type_in_rescue?(type : Crystal::Type) : Bool
      type.implements?(@program.exception) || type.module?
    end

    def visit(node : Rescue)
      if node_types = node.types
        types = node_types.map do |type|
          type.accept self
          instance_type = type.type.instance_type

          unless self.allowed_type_in_rescue? instance_type
            type.raise "#{instance_type} cannot be used for `rescue`. Only subclasses of `Exception` and modules, or unions thereof, are allowed."
          end

          instance_type
        end
      end

      if node_name = node.name
        var = @vars[node_name] = new_meta_var(node_name)
        meta_var, _ = assign_to_meta_var(node_name)
        meta_var.bind_to(var)
        meta_var.assigned_to = true
        check_closured(meta_var)
        check_mutably_closured(meta_var, var)

        if types
          unified_type = @program.type_merge(types).not_nil!
          unified_type = unified_type.virtual_type unless unified_type.is_a?(VirtualType)
        else
          unified_type = @program.exception.virtual_type
        end
        var.type = unified_type
        var.freeze_type = unified_type

        node.set_type(var.type)
      end

      node.body.accept self

      false
    end

    def visit(node : ExceptionHandler)
      # Save old vars to know if new variables are declared inside begin/rescue/else
      before_body_vars = @vars.dup

      # Any variable assigned in the body (begin) will have, inside rescue
      # blocks, all types that were assigned to them, because we can't know at which
      # point an exception is raised.
      # We have a stack of these, to take into account nested exception handlers.
      all_exception_handler_vars = @all_exception_handler_vars ||= [] of MetaVars

      # We create different vars, though, to avoid changing the type of vars
      # before the handler.
      exception_handler_vars = @vars.dup

      all_exception_handler_vars.push exception_handler_vars

      exception_handler_vars.each do |name, var|
        new_var = new_meta_var(name)
        new_var.nil_if_read = var.nil_if_read?
        new_var.bind_to(var)
        exception_handler_vars[name] = new_var
      end

      node.body.accept self

      after_exception_handler_vars = @vars.dup

      all_exception_handler_vars.pop

      if node.rescues || node.else
        # Any variable introduced in the begin block is possibly nil
        # in the rescue blocks because we can't know if an exception
        # was raised before assigning any of the vars.
        exception_handler_vars.each do |name, var|
          unless before_body_vars[name]?
            # Instance variables inside the body must be marked as nil
            if name.starts_with?('@')
              ivar = scope.lookup_instance_var(name)
              unless ivar.type.includes_type?(@program.nil_var)
                ivar.nil_reason = NilReason.new(name, :initialized_in_rescue)
                ivar.bind_to @program.nil_var
              end
            end

            var.nil_if_read = true
          end
        end

        # Now, using these vars, visit all rescue blocks and keep
        # the results in this variable.
        all_rescue_vars = [] of MetaVars

        node.rescues.try &.each do |a_rescue|
          @vars = exception_handler_vars.dup
          @unreachable = false
          a_rescue.accept self
          all_rescue_vars << @vars unless @unreachable
        end

        # In the else block the types are the same as in the begin block,
        # because we assume no exception was raised.
        node.else.try do |a_else|
          @vars = after_exception_handler_vars.dup
          @unreachable = false
          a_else.accept self
          all_rescue_vars << @vars unless @unreachable
        end

        # If all rescue/else blocks are unreachable, then afterwards
        # the flow continues as if there were no rescue/else blocks.
        if all_rescue_vars.empty?
          all_rescue_vars = nil
        else
          # Otherwise, merge all types that resulted from all rescue/else blocks
          merge_rescue_vars exception_handler_vars, all_rescue_vars

          # And then accept the ensure part
          with_block_kind :ensure do
            node.ensure.try &.accept self
          end
        end
      end

      # If there were no rescue/else blocks or all of them were unreachable
      unless all_rescue_vars
        if node_ensure = node.ensure
          after_handler_vars = @vars
          @vars = exception_handler_vars

          # Variables in the ensure block might be nil because we don't know
          # if an exception was thrown before any assignment.
          @vars.each do |name, var|
            unless before_body_vars[name]?
              var.nil_if_read = true
            end
          end

          before_ensure_vars = @vars.dup

          with_block_kind :ensure do
            node_ensure.accept self
          end

          @vars = after_handler_vars

          # Variables declared or overwritten inside the ensure block
          # must remain after the exception handler
          exception_handler_vars.each do |name, var|
            before_var = before_ensure_vars[name]?
            @vars[name] = var unless var.same?(before_var)
          end

          # However, those previous variables can't be nil afterwards:
          # if an exception was raised then we won't be running the code
          # after the ensure clause, so variables don't matter. But if
          # an exception was not raised then all variables were declared
          # successfully.
          @vars.each do |name, var|
            unless before_body_vars[name]?
              # But if the variable is already nilable after the begin
              # block it must remain nilable
              unless after_exception_handler_vars[name]?.try &.nil_if_read?
                var.nil_if_read = false
              end
            end
          end
        else
          # If there's no ensure, because all rescue/else end with unreachable
          # we know all the vars after the exception handler will have the types
          # after the handle (begin) block.
          @vars = after_exception_handler_vars
        end
      end

      if node_ensure = node.ensure
        node_ensure.add_observer(node)
      end

      if node_else = node.else
        node.bind_to node_else
      else
        node.bind_to node.body
      end

      if node_rescues = node.rescues
        node_rescues.each do |a_rescue|
          node.bind_to a_rescue.body
        end
      end

      false
    end

    def merge_rescue_vars(body_vars, all_rescue_vars)
      after_vars = MetaVars.new

      all_rescue_vars.each do |rescue_vars|
        rescue_vars.each do |name, var|
          after_var = (after_vars[name] ||= new_meta_var(name))
          if var.nil_if_read? || !body_vars[name]?
            after_var.nil_if_read = true
          end
          after_var.bind_to(var)
        end
      end

      body_vars.each do |name, var|
        after_var = (after_vars[name] ||= new_meta_var(name))
        after_var.bind_to(var)
      end

      @vars = after_vars
    end

    def end_visit(node : TupleLiteral)
      node.elements.each &.add_observer(node)
      node.program = @program
      node.update

      node.elements.each do |element|
        if element.is_a?(Splat) && (type = element.type?)
          unless type.is_a?(TupleInstanceType)
            node.raise "argument to splat must be a tuple, not #{type}"
          end
        end
      end

      false
    end

    def end_visit(node : NamedTupleLiteral)
      node.entries.each &.value.add_observer(node)
      node.program = @program
      node.update
      false
    end

    def visit(node : TupleIndexer)
      scope = @scope
      if scope.is_a?(TupleInstanceType)
        case index = node.index
        in Range
          node.type = @program.tuple_of(scope.tuple_types[index].map &.as(Type))
        in Int32
          node.type = scope.tuple_types[index].as(Type)
        end
      elsif scope.is_a?(NamedTupleInstanceType)
        node.type = scope.entries[node.index.as(Int32)].type
      elsif scope && (instance_type = scope.instance_type).is_a?(TupleInstanceType)
        case index = node.index
        in Range
          node.type = @program.tuple_of(instance_type.tuple_types[index].map &.as(Type)).metaclass
        in Int32
          node.type = instance_type.tuple_types[index].as(Type).metaclass
        end
      elsif scope && (instance_type = scope.instance_type).is_a?(NamedTupleInstanceType)
        node.type = instance_type.entries[node.index.as(Int32)].type.metaclass
      else
        node.raise "unsupported TupleIndexer scope"
      end
      false
    end

    def visit(node : Asm)
      if outputs = node.outputs
        node.output_ptrofs = outputs.map do |output|
          ptrof = PointerOf.new(output.exp).at(output.exp)
          ptrof.accept self
          ptrof
        end
      end

      if inputs = node.inputs
        inputs.each &.exp.accept self
      end

      node.type = @program.void
      false
    end

    # # Literals

    def visit(node : Nop)
      node.type = @program.nil
      false
    end

    def visit(node : NilLiteral)
      node.type = @program.nil
      false
    end

    def visit(node : BoolLiteral)
      node.type = program.bool
      false
    end

    def visit(node : NumberLiteral)
      node.type = program.type_from_literal_kind node.kind
      false
    end

    def visit(node : CharLiteral)
      node.type = program.char
      false
    end

    def visit(node : SymbolLiteral)
      node.type = program.symbol
      program.symbols.add node.value
      false
    end

    def visit(node : StringLiteral)
      node.type = program.string
      false
    end

    def visit(node : RegexLiteral)
      expand(node)
    end

    def visit(node : ArrayLiteral)
      if name = node.name
        name.accept self
        type = name.type.instance_type
        generic_type = TypeNode.new(type).at(node) if type.is_a?(GenericClassType)
        expand_named(node, generic_type)
      else
        expand(node)
      end
    end

    def visit(node : HashLiteral)
      if name = node.name
        name.accept self
        type = name.type.instance_type
        generic_type = TypeNode.new(type).at(node) if type.is_a?(GenericClassType)
        expand_named(node, generic_type)
      else
        expand(node)
      end
    end

    def visit(node : And)
      expand(node)
    end

    def visit(node : Or)
      expand(node)
    end

    def visit(node : RangeLiteral)
      expand(node)
    end

    def visit(node : StringInterpolation)
      expand(node)

      # This allows some methods to be resolved even if the interpolated expressions doesn't
      # end up with a type because of recursive methods. We should really do something more
      # clever and robust here for the general case.
      node.type = program.string

      false
    end

    def visit(node : Case)
      # For exhaustiveness check, which is done in CleanupTransformer,
      # we need to know the type of `cond`. However, LiteralExpander will
      # work with copies of `cond` in case they are Var or InstanceVar so
      # here we type them so their type is available later on.
      cond = node.cond
      case cond
      when Var         then cond.accept(self)
      when InstanceVar then cond.accept(self)
      when TupleLiteral
        cond.elements.each do |element|
          case element
          when Var         then element.accept(self)
          when InstanceVar then element.accept(self)
          end
        end
      end

      expand(node)
      false
    end

    def visit(node : Select)
      expand(node)
      false
    end

    def visit(node : MultiAssign)
      expand(node)
      false
    end

    def expand(node)
      expand(node) { @program.literal_expander.expand node }
    end

    def expand_named(node, generic_type)
      expand(node) { @program.literal_expander.expand_named node, generic_type }
    end

    def expand(node, &)
      expanded = yield
      expanded.accept self
      node.expanded = expanded
      node.bind_to expanded
      false
    end

    def visit(node : Not)
      node.exp.accept self
      node.exp.add_observer node
      node.update

      if needs_type_filters?
        @type_filters = TypeFilters.not(@type_filters)
      end

      false
    end

    def visit(node : VisibilityModifier)
      exp = node.exp
      exp.accept self

      # Only check for calls that didn't resolve to a macro:
      # all other cases are already covered in TopLevelVisitor
      if exp.is_a?(Call) && !exp.expanded
        node.raise "can't apply visibility modifier"
      end

      node.type = @program.nil

      false
    end

    def visit(node : Arg)
      # Arg nodes are also used for Enum constants, and they
      # must be skipped here
      false
    end

    def visit(node : AssignWithRestriction)
      type_assign(
        node.assign.target.as(Var),
        node.assign.value,
        node.assign,
        restriction: node.restriction)
      node.bind_to(node.assign)
      false
    end

    def visit(node : Unreachable)
      node.type = @program.no_return
      @unreachable = true
    end

    # # Helpers

    def free_vars
      match_context.try &.bound_free_vars
    end

    def check_closured(var, mark_as_mutably_closured : Bool = false)
      return if @typeof_nest > 0

      if var.name == "self"
        check_self_closured
        return
      end

      context = current_context
      var_context = var.context
      if var_context.same?(context)
        var_context = var_context.context if var_context.is_a?(Block)
        if var.closured?
          mark_as_closured(var, var_context, mark_as_mutably_closured)
        end
      else
        # If the contexts are not the same, it might be that we are in a block
        # inside a method, or a block inside another block. We don't want
        # those cases to closure a variable. So if any context is a block
        # we go to the block's context (a def or a proc literal) and compare
        # if those are the same to determine whether the variable is closured.
        context = context.context if context.is_a?(Block)
        var_context = var_context.context if var_context.is_a?(Block)

        closured = !context.same?(var_context)
        if closured
          mark_as_closured(var, var_context, mark_as_mutably_closured)
        end
      end
    end

    def mark_as_closured(var, var_context, mark_as_mutably_closured : Bool)
      # This is a bit tricky: when we assign to a variable we create a new metavar
      # for it if it didn't exist. If it did exist, and right now we are forming
      # a closure, then we also want to mark it as readonly.
      # We already do this in `assign_to_meta_var` but that's done **before**
      # we detect a closure in an assignment. So that logic needs to be replicated here,
      # and it must happen before we actually mark is as closured.
      var.mutably_closured = true if mark_as_mutably_closured
      var.mark_as_closured

      # Go up and mark proc literal defs as closured until we get
      # to the context where the variable is defined
      visitor = self
      while visitor
        visitor_context = visitor.closure_context
        break if visitor_context == var_context

        visitor_context.closure = true if visitor_context.is_a?(Def)
        visitor = visitor.parent
      end
    end

    def check_self_closured
      return if @typeof_nest > 0

      scope = @scope
      return unless scope

      return if scope.metaclass? && !scope.virtual_metaclass?

      context = @fun_literal_context
      return unless context.is_a?(Def)

      context.self_closured = true

      # Go up and mark proc literal defs as closured until the top
      # (which should be when we leave the top Def)
      visitor = self
      while visitor
        visitor_context = visitor.closure_context
        visitor_context.closure = true if visitor_context.is_a?(Def)
        visitor = visitor.parent
      end
    end

    def current_context
      @block_context || current_non_block_context
    end

    def current_non_block_context
      @typed_def || @file_module || @program
    end

    def closure_context
      context = current_context
      context = context.context if context.is_a?(Block)
      context
    end

    def lookup_var_or_instance_var(var : Var)
      @vars[var.name]
    end

    def lookup_var_or_instance_var(var : InstanceVar)
      scope.lookup_instance_var(var.name)
    end

    def lookup_var_or_instance_var(var)
      raise "BUG: trying to lookup var or instance var but got #{var}"
    end

    def bind_meta_var(var : Var)
      @meta_vars[var.name].bind_to(var)
    end

    def bind_meta_var(var : InstanceVar)
      # Nothing to do
    end

    def bind_meta_var(var)
      raise "BUG: trying to bind var or instance var but got #{var}"
    end

    def bind_initialize_instance_vars(owner)
      names_to_remove = [] of String

      @vars.each do |name, var|
        if name.starts_with? '@'
          if var.nil_if_read?
            ivar = lookup_instance_var(var, owner)
            ivar.bind_to program.nil_var
          end

          names_to_remove << name
        end
      end

      names_to_remove.each do |name|
        @meta_vars.delete name
        @vars.delete name
      end
    end

    def check_initialize_instance_vars_types(owner)
      return if untyped_def.calls_super? ||
                untyped_def.calls_initialize?

      owner.all_instance_vars.each do |name, var|
        next if owner.has_instance_var_initializer?(name)
        next if var.type.includes_type?(@program.nil)

        meta_var = @meta_vars[name]?
        unless meta_var
          untyped_def.raise "instance variable '#{name}' of #{owner} was not initialized in this 'initialize', rendering it nilable"
        end
      end
    end

    def needs_type_filters?
      @needs_type_filters > 0
    end

    def request_type_filters(&)
      @type_filters = nil
      @needs_type_filters += 1
      begin
        yield
      ensure
        @needs_type_filters -= 1
      end
    end

    def ignoring_type_filters(&)
      needs_type_filters, @needs_type_filters = @needs_type_filters, 0
      begin
        yield
      ensure
        @needs_type_filters = needs_type_filters
      end
    end

    def lookup_similar_var_name(name)
      Levenshtein.find(name) do |finder|
        @vars.each_key do |var_name|
          finder.test(var_name)
        end
      end
    end

    def define_special_var(name, value)
      meta_var, _ = assign_to_meta_var(name)
      meta_var.bind_to value
      meta_var.bind_to program.nil_var unless meta_var.dependencies.any? &.same?(program.nil_var)
      meta_var.assigned_to = true
      check_closured meta_var

      @vars[name] = meta_var
      meta_var
    end

    def new_meta_var(name, context = current_context)
      meta_var = MetaVar.new(name)
      meta_var.context = context
      meta_var
    end

    def assign_to_meta_var(name, context = current_context)
      meta_var = @meta_vars[name]?
      meta_var_existed = !!meta_var
      if meta_var
        # This var gets assigned a new value and it already existed before this line.
        # If it's also a closured var it means it has become mutably closured.
        meta_var.mutably_closured = true if meta_var.closured?
      else
        @meta_vars[name] = meta_var = new_meta_var(name)
      end

      # If a variable is being assigned inside a while then it's considered
      # as mutably closured: it will get a value assigned to it multiple times
      # exactly because it's in a loop.
      meta_var.mutably_closured = true if inside_while?

      # If a variable is being assigned to inside a block:
      # - if the variable is a new variable then there's no need to mark is a mutably
      #   closured because unless it gets assigned again it will be a different
      #   variable allocation each time
      # - if the variable already existed but it's assigned in the same context
      #   as before, if it's not closured already then it still shouldn't
      #   be marked as mutably closured
      # - otherwise, we mark it as mutably closured. The block might happen
      #   in a while loop, or invoked multiple times: we don't know, so we must
      #   mark is as such until the compiler gets smarter (if really necessary)
      if @block && meta_var_existed && !current_context.same?(meta_var.context)
        meta_var.mutably_closured = true
      end

      {meta_var, meta_var_existed}
    end

    def block=(@block)
      @block_context = @block
    end

    def inside_block?
      @untyped_def || @block_context
    end

    def inside_while?
      !@while_stack.empty?
    end

    def lookup_class_var(node)
      class_var_owner = class_var_owner(node)
      var = class_var_owner.lookup_class_var?(node.name)
      unless var
        undefined_class_variable(node, class_var_owner)
      end
      var
    end

    def undefined_class_variable(node, owner)
      similar_name = lookup_similar_class_variable_name(node, owner)
      @program.undefined_class_variable(node, owner, similar_name)
    end

    def lookup_similar_class_variable_name(node, owner)
      Levenshtein.find(node.name) do |finder|
        owner.class_vars.each_key do |name|
          finder.test(name)
        end
      end
    end

    def check_type_in_type_args(type)
      if @in_type_args > 0
        type
      else
        type.metaclass
      end
    end

    def the_self(node)
      the_self = (@scope || current_type)
      if the_self.is_a?(Program)
        node.raise "there's no self in this scope"
      end
      the_self
    end

    # Returns node.exp if it's not nil. Otherwise,
    # creates a NilLiteral node that has the same location
    # as `node`, and returns that.
    # We use this NilLiteral when the user writes
    # `return`, `next` or `break` without arguments,
    # so that in the error trace we can show it right
    # (those expressions have a NoReturn type so we can't
    # directly bind to them).
    def node_exp_or_nil_literal(node)
      exp = node.exp
      return exp if exp

      nil_exp = NilLiteral.new
      nil_exp.location = node.location
      nil_exp.type = @program.nil
      nil_exp
    end

    # If the meta_var is closured but not readonly, then bind var
    # to it (it gets all types assigned to meta_var).
    # Otherwise, add it to the local vars so that they could be
    # bond later on, if the meta_var stops being readonly.
    def check_mutably_closured(meta_var, var)
      if meta_var.closured? && meta_var.mutably_closured?
        var.bind_to(meta_var)
      else
        meta_var.local_vars << var
      end
    end

    def visit(node : When | Unless | Until | MacroLiteral | OpAssign)
      raise "BUG: #{node.class_desc} node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : ImplicitObj)
      raise "BUG: #{node.class_desc} node '#{node}' (#{node.location}) should have been eliminated in expand"
    end
  end
end
