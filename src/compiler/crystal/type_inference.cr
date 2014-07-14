require "program"
require "visitor"
require "ast"
require "type_inference/*"

module Crystal
  class Program
    def infer_type(node)
      node.accept TypeVisitor.new(self)
      expand_def_macros
      fix_empty_types node
      after_type_inference node
    end
  end

  class TypeVisitor < Visitor
    ValidGlobalAttributes = ["ThreadLocal"]
    ValidExternalVarAttributes = ["ThreadLocal"]
    ValidStructDefAttributes = ["Packed"]
    ValidDefAttributes = ["AlwaysInline", "NoInline", "ReturnsTwice"]

    getter mod
    property! scope
    getter! typed_def
    property! untyped_def
    getter block
    property call
    property type_lookup
    property fun_literal_context
    property types
    property block_nest

    # These are the free variables that came from matches. We look up
    # here first if we find a single-element Path like `T`.
    property free_vars

    # These are the variables and types that come from a block specification
    # like `&block : Int32 -> Int32`. When doing `yield 1` we need to verify
    # that the yielded expression has the type that the block specification said.
    property yield_vars

    # In vars we store the types of variables as we traverse the nodes.
    # These type are not cummulative: if you do `x = 1`, 'x' will have
    # type Int32. Then if you do `x = false`, 'x' will have type Bool.
    getter vars

    # Here we store the cummulative types of variables as we traverse the nodes.
    getter meta_vars

    getter is_initialize

    def initialize(@mod, vars = MetaVars.new, @typed_def = nil, meta_vars = nil)
      @types = [@mod] of Type
      @while_stack = [] of While
      @vars = vars
      @needs_type_filters = 0
      @unreachable = false
      @block_nest = 0
      @typeof_nest = 0
      @is_initialize = typed_def && typed_def.name == "initialize"
      @used_ivars_in_calls_in_initialize = nil
      @in_type_args = 0

      # We initialize meta_vars from vars given in the constructor.
      # We store those meta vars either in the typed def or in the program
      # so the codegen phase knows the cummulative types to do allocas.
      unless meta_vars
        if typed_def = @typed_def
          meta_vars = typed_def.vars = MetaVars.new
        else
          meta_vars = @mod.vars
        end
        vars.each do |name, var|
          meta_var = new_meta_var(name)
          meta_var.bind_to(var)
          meta_vars[name] = meta_var
        end
      end

      @meta_vars = meta_vars
    end

    def new_meta_var(name)
      meta_var = MetaVar.new(name)
      meta_var.context = current_context
      meta_var
    end

    def block=(@block)
      @block_context = @block
    end

    def visit_any(node)
      @unreachable = false
      true
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : Nop)
      node.type = @mod.nil
    end

    def visit(node : NilLiteral)
      node.type = @mod.nil
    end

    def visit(node : BoolLiteral)
      node.type = mod.bool
    end

    def visit(node : NumberLiteral)
      node.type = case node.kind
                  when :i8 then mod.int8
                  when :i16 then mod.int16
                  when :i32 then mod.int32
                  when :i64 then mod.int64
                  when :u8 then mod.uint8
                  when :u16 then mod.uint16
                  when :u32 then mod.uint32
                  when :u64 then mod.uint64
                  when :f32 then mod.float32
                  when :f64 then mod.float64
                  else raise "Invalid node kind: #{node.kind}"
                  end
    end

    def visit(node : CharLiteral)
      node.type = mod.char
    end

    def visit(node : SymbolLiteral)
      node.type = mod.symbol
      mod.symbols.add node.value
    end

    def visit(node : StringLiteral)
      node.type = mod.string
    end

    def visit(node : Var)
      # We declare out variables
      # TODO: check that the out variable didn't exist before
      if node.out
        @meta_vars[node.name] = new_meta_var(node.name)
        @vars[node.name] = new_meta_var(node.name)
        return
      end

      var = @vars[node.name]?
      if var
        meta_var = @meta_vars[node.name]
        check_closured meta_var

        if var.nil_if_read
          meta_var.bind_to(@mod.nil_var) unless meta_var.dependencies.try &.any? &.same?(@mod.nil_var)
          node.bind_to(@mod.nil_var)
        end

        if meta_var.closured
          var.bind_to(meta_var)
        end

        node.bind_to(var)

        if needs_type_filters?
          @type_filters = not_nil_filter(node)
        end
      elsif node.name == "self"
        node.raise "there's no self in this scope"
      else
        node.raise "read before definition of '#{node.name}'"
      end
    end

    def visit(node : DeclareVar)
      case var = node.var
      when Var
        node.declared_type.accept self
        node.type = node.declared_type.type.instance_type
        var.bind_to node

        meta_var = new_meta_var(var.name)
        meta_var.bind_to(var)

        @vars[var.name] = meta_var
        @meta_vars[var.name] = meta_var
      when InstanceVar
        type = scope? || current_type
        if @untyped_def
          node.declared_type.accept self
          node.type = node.declared_type.type.instance_type
          ivar = lookup_instance_var var
          ivar.bind_to node
          var.bind_to node
        end
        if type.is_a?(NonGenericClassType)
          node.declared_type.accept self
          node.type = node.declared_type.type.instance_type
          type.declare_instance_var(var.name, node.type)
        elsif type.is_a?(GenericClassType)
          type.declare_instance_var(var.name, node.declared_type)
        else
          node.raise "can only declare instance variables of a non-generic class, not a #{type.type_desc} (#{type})"
        end
      end

      false
    end

    def visit(node : Global)
      var = mod.global_vars[node.name]?
      unless var
        var = Var.new(node.name)
        var.bind_to mod.nil_var
        mod.global_vars[node.name] = var
      end
      node.bind_to var
    end

    def visit(node : InstanceVar)
      var = lookup_instance_var node
      node.bind_to(var)

      if @is_initialize
        if node.out
          @vars[node.name] = MetaVar.new(node.name)
        elsif !@vars.has_key? node.name
          ivar = scope.lookup_instance_var(node.name)
          ivar.bind_to @mod.nil_var
        end
      end
    end

    def end_visit(node : ReadInstanceVar)
      obj_type = node.obj.type
      unless obj_type.is_a?(InstanceVarContainer)
        node.raise "#{obj_type} doesn't have instance vars"
      end

      ivar = obj_type.lookup_instance_var?(node.name, false)
      unless ivar
        node.raise "#{obj_type} doesn't have an instance var named '#{node.name}'"
      end

      node.bind_to ivar
    end

    def visit(node : ClassVar)
      node.bind_to lookup_class_var(node)
    end

    def lookup_instance_var(node)
      scope = @scope

      if scope
        if scope.is_a?(Crystal::Program)
          node.raise "can't use instance variables at the top level"
        elsif scope.is_a?(PrimitiveType) #|| scope.metaclass?
          node.raise "can't use instance variables inside #{@scope}"
        end

        if scope.metaclass?
          node.raise "@instance_vars are not yet allowed in metaclasses: use @@class_vars instead"
        elsif scope.is_a?(InstanceVarContainer)
          var = scope.lookup_instance_var node.name
          unless scope.has_instance_var_in_initialize?(node.name)
            begin
              var.bind_to mod.nil_var
            rescue ex : Crystal::Exception
              node.raise "#{node} not in initialize so it's nilable", ex
            end
          end
        else
          node.raise "Bug: #{scope} is not an InstanceVarContainer"
        end

        raise "Bug: var is nil" unless var

        check_self_closured

        var
      else
        node.raise "can't use instance variables at the top level"
      end
    end

    def lookup_class_var(node, bind_to_nil_if_non_existent = true)
      scope = ((@typed_def && !@fun_literal_context) ? @scope : current_type).not_nil!
      if scope.is_a?(MetaclassType)
        owner = scope.class_var_owner
      else
        owner = scope
      end
      class_var_owner = owner as ClassVarContainer

      bind_to_nil = bind_to_nil_if_non_existent && !class_var_owner.has_class_var?(node.name)

      var = class_var_owner.lookup_class_var node.name
      var.bind_to mod.nil_var if bind_to_nil

      node.owner = class_var_owner
      node.var = var
      node.class_scope = !@typed_def

      var
    end

    def end_visit(node : Expressions)
      node.bind_to node.last unless node.empty?
    end

    def visit(node : Assign)
      type_assign node.target, node.value, node
      false
    end

    def type_assign(target : Var, value, node)
      var_name = target.name

      value.accept self

      value_type_filters = @type_filters
      @type_filters = nil

      target.bind_to value
      node.bind_to value

      meta_var = (@meta_vars[var_name] ||= new_meta_var(var_name))
      meta_var.bind_to value
      meta_var.assigned_to = true
      check_closured meta_var

      simple_var = MetaVar.new(var_name)
      simple_var.bind_to(target)

      if meta_var.closured
        simple_var.bind_to(meta_var)
      end

      @vars[var_name] = simple_var

      # If inside a begin part of an exception handler, bind this type to
      # the variable that will be used in the rescue/else blocks.
      if exception_handler_vars = @exception_handler_vars
        var = (exception_handler_vars[var_name] ||= MetaVar.new(var_name))
        var.bind_to(value)
      end

      if needs_type_filters?
        @type_filters = and_type_filters(not_nil_filter(target), value_type_filters)
      end
    end

    def type_assign(target : InstanceVar, value, node)
      # Check if this is an instance variable initializer
      unless @scope
        current_type = current_type()
        if current_type.is_a?(ClassType)
          ivar_visitor = TypeVisitor.new(mod)
          value.accept ivar_visitor

          current_type.add_instance_var_initializer(target.name, value, ivar_visitor.meta_vars)
          var = current_type.lookup_instance_var(target.name, true)
        end
      end

      unless var
        value.accept self
        var = lookup_instance_var target
      end

      target.bind_to var

      node.bind_to value
      var.bind_to node

      if @is_initialize
        var_name = target.name

        meta_var = (@meta_vars[var_name] ||= new_meta_var(var_name))
        meta_var.bind_to value
        meta_var.assigned_to = true

        simple_var = MetaVar.new(var_name)
        simple_var.bind_to(target)

        used_ivars_in_calls_in_initialize = @used_ivars_in_calls_in_initialize
        if used_ivars_in_calls_in_initialize.try(&.includes?(var_name)) || (@block_nest > 0 && !@vars.has_key?(var_name))
          ivar = scope.lookup_instance_var(var_name)
          ivar.bind_to @mod.nil_var
        end

        @vars[var_name] = simple_var
      end
    end

    def type_assign(target : Path, value, node)
      type = current_type.types[target.names.first]?
      if type
        target.raise "already initialized constant #{target}"
      end

      target.bind_to value

      current_type.types[target.names.first] = Const.new(@mod, current_type, target.names.first, value, @types.dup, @scope)

      node.type = @mod.nil
    end

    def type_assign(target : Global, value, node)
      check_valid_attributes target, ValidGlobalAttributes, "global variable"

      value.accept self

      var = mod.global_vars[target.name]?
      unless var
        var = Var.new(target.name)
        if @typed_def
          var.bind_to mod.nil_var
        end
        mod.global_vars[target.name] = var
      end
      var.add_attributes(target.attributes)

      target.bind_to var

      node.bind_to value
      var.bind_to node
    end

    def type_assign(target : ClassVar, value, node)
      value.accept self

      var = lookup_class_var target, !!@typed_def
      target.bind_to var

      node.bind_to value
      var.bind_to node
    end

    def type_assign(target, value, node)
      raise "Bug: unknown assign target in type inference: #{target}"
    end

    def visit(node : Def)
      if receiver = node.receiver
        # TODO: hack
        if receiver.is_a?(Var) && receiver.name == "self"
          target_type = current_type.metaclass
        else
          target_type = lookup_path_type(receiver).metaclass
        end
      else
        target_type = current_type
      end
      target_type.add_def node
      node.set_type @mod.nil
      false
    end

    def end_visit(node : Def)
      check_valid_attributes node, ValidDefAttributes, "def"
    end

    def visit(node : Macro)
      begin
        current_type.metaclass.add_macro node
      rescue ex
        node.raise ex.message
      end

      node.set_type @mod.nil
      false
    end

    def visit(node : Undef)
      unless current_type.undef(node.name)
        node.raise "undefined method #{node.name} for #{current_type.type_desc} #{current_type}"
      end
    end

    def visit(node : Yield)
      node.raise "can't yield from function literal" if @fun_literal_context
      true
    end

    def end_visit(node : Yield)
      call = @call.not_nil!
      block = call.block || node.raise("no block given")

      if (yield_vars = @yield_vars) && !node.scope
        yield_vars.each_with_index do |var, i|
          exp = node.exps[i]?
          if exp
            # TODO: this should really be var.type.implements?(exp.type)
            unless exp.type.is_restriction_of?(var.type, exp.type)
              exp.raise "argument ##{i + 1} of yield expected to be #{var.type}, not #{exp.type}"
            end
            exp.freeze_type = true
          elsif !var.type.nil_type?
            node.raise "missing argument ##{i + 1} of yield with type #{var.type}"
          end
        end
      end

      bind_block_args_to_yield_exps block, node

      unless block.visited
        call.bubbling_exception do
          if node_scope = node.scope
            block.scope = node_scope.type
          end
          ignore_type_filters do
            block.accept call.parent_visitor.not_nil!
          end
        end
      end

      node.bind_to block

      @type_filters = nil
    end

    def bind_block_args_to_yield_exps(block, node)
      block.args.each_with_index do |arg, i|
        exp = node.exps[i]?
        arg.bind_to(exp ? exp : mod.nil_var)
      end
    end

    def visit(node : Block)
      return if node.visited

      node.visited = true
      node.context = current_non_block_context

      before_block_vars = node.vars.try(&.dup) || MetaVars.new

      meta_vars = @meta_vars.dup
      node.args.each do |arg|
        meta_var = MetaVar.new(arg.name)
        meta_var.context = node
        meta_var.bind_to(arg)

        # TODO: check if we need a second meta-var
        before_block_vars[arg.name] = meta_var
        meta_vars[arg.name] = meta_var
      end

      @block_nest += 1

      block_visitor = TypeVisitor.new(mod, before_block_vars, @typed_def, meta_vars)
      block_visitor.yield_vars = @yield_vars
      block_visitor.free_vars = @free_vars
      block_visitor.untyped_def = @untyped_def
      block_visitor.call = @call
      block_visitor.scope = node.scope || @scope
      block_visitor.block = node
      block_visitor.type_lookup = type_lookup
      block_visitor.block_nest = @block_nest

      node.body.accept block_visitor

      @block_nest -= 1

      # Check re-assigned variables and bind them.
      bind_vars block_visitor.vars, node.vars
      bind_vars block_visitor.vars, node.after_vars

      node.vars = meta_vars

      node.bind_to node.body

      false
    end

    def bind_vars(from_vars, to_vars)
      if to_vars
        from_vars.each do |name, block_var|
          to_vars[name]?.try &.bind_to(block_var)
        end
      end
    end

    def visit(node : FunLiteral)
      fun_vars = @vars.dup
      meta_vars = @meta_vars.dup

      node.def.args.each do |arg|
        # It can happen that the argument has a type already,
        # when converting a block to a fun literal
        if restriction = arg.restriction
          restriction.accept self
          arg.type = restriction.type.instance_type.hierarchy_type
        elsif !arg.type?
          arg.raise "function argument '#{arg.name}' must have a type"
        end

        fun_var = MetaVar.new(arg.name, arg.type)
        fun_vars[arg.name] = fun_var

        meta_var = MetaVar.new(arg.name)
        meta_var.context = node.def
        meta_var.bind_to fun_var
        meta_vars[arg.name] = meta_var
      end

      node.bind_to node.def
      node.def.bind_to node.def.body
      node.def.vars = meta_vars

      block_visitor = TypeVisitor.new(mod, fun_vars, node.def, meta_vars)
      block_visitor.types = @types
      block_visitor.yield_vars = @yield_vars
      block_visitor.free_vars = @free_vars
      block_visitor.untyped_def = node.def
      block_visitor.call = @call
      block_visitor.scope = @scope
      block_visitor.type_lookup = type_lookup
      block_visitor.fun_literal_context = @fun_literal_context || @typed_def || @mod
      block_visitor.block_nest = @block_nest

      node.def.body.accept block_visitor

      if node.def.closure
        context = current_non_block_context
        context.closure = true if context.is_a?(Def)
      end

      false
    end

    def visit(node : FunPointer)
      if obj = node.obj
        obj.accept self
      end

      call = Call.new(obj, node.name)
      prepare_call(call)

      call.args = Array(ASTNode).new(node.args.length)
      node.args.each_with_index do |arg, i|
        arg.accept(self)
        call.args << Var.new("arg#{i}", arg.type.instance_type)
      end

      begin
        call.recalculate
      rescue ex : Crystal::Exception
        node.raise "error instantiating #{node}", ex
      end

      node.call = call
      node.bind_to call

      false
    end

    def end_visit(node : Fun)
      if inputs = node.inputs
        types = inputs.map &.type.instance_type
      else
        types = [] of Type
      end

      if output = node.output
        types << output.type.instance_type
      else
        types << mod.void
      end

      node.type = mod.fun_of(types)
    end

    def end_visit(node : SimpleOr)
      node.bind_to node.left
      node.bind_to node.right

      false
    end

    def visit(node : Call)
      prepare_call(node)

      if expand_macro(node)
        return false
      end

      check_super_in_initialize node

      obj = node.obj
      block_arg = node.block_arg

      ignore_type_filters do
        if obj
          obj.accept(self)

          check_lib_call node, obj.type?

          if check_special_new_call(node, obj.type?)
            return false
          end
        end

        node.args.each &.accept(self)
        block_arg.try &.accept self
      end

      obj.try &.add_input_observer(node)
      node.args.each &.add_input_observer(node)
      block_arg.try &.add_input_observer node

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
          before_var.nil_if_read = var.nil_if_read
          before_vars[name] = before_var

          after_var = MetaVar.new(name)
          after_var.bind_to(var)
          after_var.nil_if_read = var.nil_if_read
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

      node.recalculate

      check_call_in_initialize node

      @type_filters = nil
      @unreachable = true if node.no_returns?

      false
    end

    def prepare_call(node)
      node.mod = mod

      if node.global
        node.scope = @mod
      else
        node.scope = @scope || @types.last.metaclass
      end
      node.parent_visitor = self
    end

    # If it's a super call inside an initialize we treat
    # set instance vars from superclasses to not-nil
    def check_super_in_initialize(node)
      if @is_initialize && node.name == "super" && !node.obj
        superclass = scope.superclass

        while superclass
          superclass.instance_vars_in_initialize.try &.each do |name|
            meta_var = MetaVar.new(name)
            meta_var.bind_to scope.lookup_instance_var(name)
            @vars[name] = meta_var
          end

          superclass = superclass.superclass
        end
      end
    end

    # Check if it's a call to self. In that case, all instance variables
    # not mentioned so far will be considered nil.
    def check_call_in_initialize(node)
      return unless @is_initialize
      return if @typeof_nest > 0

      node_obj = node.obj
      if !node_obj || (node_obj.is_a?(Var) && node_obj.name == "self")
        ivars = gather_instance_vars_read node
        if ivars
          used_ivars_in_calls_in_initialize = @used_ivars_in_calls_in_initialize
          if used_ivars_in_calls_in_initialize
            @used_ivars_in_calls_in_initialize = used_ivars_in_calls_in_initialize | ivars
          else
            @used_ivars_in_calls_in_initialize = ivars
          end
        end
      end
    end

    # Fill function literal argument types for C functions
    def check_lib_call(node, obj_type)
      return unless obj_type.is_a?(LibType)

      method = nil

      node.args.each_with_index do |arg, index|
        next unless arg.is_a?(FunLiteral)
        next unless arg.def.args.any? { |def_arg| !def_arg.restriction && !def_arg.type? }

        method ||= obj_type.lookup_first_def(node.name, false)
        return unless method

        method_arg = method.args[index]?
        next unless method_arg

        method_arg_type = method_arg.type
        next unless method_arg_type.is_a?(FunInstanceType)

        arg.def.args.each_with_index do |def_arg, def_arg_index|
          if !def_arg.restriction && !def_arg.type?
            def_arg.type = method_arg_type.fun_types[def_arg_index]?
          end
        end
      end
    end

    # Check if it's FunType#new
    def check_special_new_call(node, obj_type)
      return false unless obj_type
      return false unless obj_type.metaclass?

      instance_type = obj_type.instance_type.remove_typedef

      if node.name == "new" && instance_type.is_a?(FunInstanceType)
        return special_fun_type_new_call(node, instance_type)
      end

      false
    end

    def special_fun_type_new_call(node, fun_type)
      if node.args.length != 0
        node.raise "wrong number of arguments for #{fun_type}#new (#{node.args.length} for 0)"
      end

      block = node.block
      unless block
        node.raise "#{fun_type}#new is expected to be invoked with a block, but no block was given"
      end

      if block.args.length > fun_type.fun_types.length - 1
        node.raise "wrong number of block arguments for #{fun_type}#new (#{block.args.length} for #{fun_type.fun_types.length - 1})"
      end

      # We create a ->(...) { } from the block
      fun_args = fun_type.arg_types.map_with_index do |arg_type, index|
        block_arg = block.args[index]?
        Arg.new_with_type(block_arg.try(&.name) || @mod.new_temp_var_name, arg_type)
      end

      fun_def = Def.new("->", fun_args, block.body)
      fun_literal = FunLiteral.new(fun_def)
      fun_literal.location = node.location
      fun_literal.expected_return_type = fun_type.return_type
      fun_literal.accept self

      node.bind_to fun_literal
      node.expanded = fun_literal

      true
    end

    class InstanceVarsCollector < Visitor
      getter ivars

      def initialize(@scope, @vars)
      end

      def visit(node : InstanceVar)
        unless @vars.has_key?(node.name)
          ivars = @ivars ||= Set(String).new
          ivars << node.name
        end
      end

      def visit(node : Assign)
        node.value.accept self
        false
      end

      def visit(node : Call)
        visited = @visited

        node.target_defs.try &.each do |target_def|
          if target_def.owner == @scope
            next if visited.try &.includes?(target_def.object_id)

            visited = @visited ||= Set(typeof(object_id)).new
            visited << target_def.object_id

            target_def.body.accept self
          end
        end

        true
      end

      def visit(node : ASTNode)
        true
      end
    end

    def gather_instance_vars_read(node)
      collector = InstanceVarsCollector.new(scope, @vars)
      node.accept collector
      collector.ivars
    end

    def expand_macro(node)
      return false if node.obj || node.name == "super"

      the_macro = node.lookup_macro
      return false unless the_macro

      generated_nodes = expand_macro(the_macro, node) do
        @mod.expand_macro (@scope || current_type), the_macro, node
      end

      node.expanded = generated_nodes
      node.bind_to generated_nodes

      true
    end

    def visit(node : MacroExpression)
      expand_inline_macro node
    end

    def visit(node : MacroIf)
      expand_inline_macro node
    end

    def visit(node : MacroFor)
      expand_inline_macro node
    end

    def expand_inline_macro(node)
      the_macro = Macro.new("macro_#{node.object_id}", [] of Arg, node)
      the_macro.location = node.location

      generated_nodes = expand_macro(the_macro, node) do
        @mod.expand_macro (@scope || current_type), node
      end

      node.expanded = generated_nodes
      node.bind_to generated_nodes

      false
    end

    def expand_macro(the_macro, node)
      begin
        generated_source = yield
      rescue ex : Crystal::Exception
        node.raise "expanding macro", ex
      end

      generated_nodes = @mod.parse_macro_source(generated_source, the_macro, node, Set.new(@vars.keys))
      generated_nodes.accept self
      generated_nodes
    end

    def visit(node : Return)
      node.raise "can't return from top level" unless @typed_def

      if node.exps.empty?
        node.exps << NilLiteral.new
      end

      true
    end

    def end_visit(node : Return)
      typed_def = @typed_def.not_nil!
      node.exps.each do |exp|
        typed_def.bind_to exp
      end
      @unreachable = true
    end

    def visit(node : Generic)
      node.in_type_args = @in_type_args > 0

      node.name.accept self

      @in_type_args += 1
      node.type_vars.each &.accept self
      @in_type_args -= 1

      return false if node.type?

      instance_type = node.name.type.instance_type
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

      node.instance_type = instance_type
      node.type_vars.each &.add_observer(node)
      node.update

      false
    end

    def visit(node : IsA)
      node.obj.accept self

      @in_type_args += 1
      node.const.accept self
      @in_type_args -= 1

      node.type = mod.bool
      const = node.const

      # When doing x.is_a?(A) and A turns out to be a constant (not a type),
      # replace it with a === comparison. Most usually this happens in a case expression.
      if const.is_a?(Path) && const.target_const
        comp = Call.new(const, "===", [node.obj])
        comp.location = node.location
        comp.accept self
        node.syntax_replacement = comp
        node.bind_to comp
        return
      end

      if needs_type_filters? && (var = get_expression_var(node.obj))
        @type_filters = new_type_filter(var, SimpleTypeFilter.new(node.const.type))
      end

      false
    end

    def end_visit(node : RespondsTo)
      node.type = mod.bool
      if needs_type_filters? && (var = get_expression_var(node.obj))
        @type_filters = new_type_filter(var, RespondsToTypeFilter.new(node.name.value))
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
      end
      nil
    end

    def end_visit(node : Cast)
      obj_type = node.obj.type?
      if obj_type.is_a?(PointerInstanceType)
        to_type = node.to.type.instance_type
        if to_type.is_a?(GenericType)
          node.raise "can't cast #{obj_type} to #{to_type}"
        end
      end

      node.obj.add_observer node
      node.update
    end

    def visit(node : ClassDef)
      superclass = if node_superclass = node.superclass
                     lookup_path_type node_superclass
                   elsif node.struct
                     mod.struct
                   else
                     mod.reference
                   end

      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_path_type node.name, true
      end

      type = scope.types[name]?

      if !type && superclass
        if (!!node.struct) != (!!superclass.struct?)
          node.raise "can't make #{node.struct ? "struct" : "class"} '#{node.name}' inherit #{superclass.type_desc} '#{superclass.to_s}'"
        end
      end

      created_new_type = false

      if type
        unless type.is_a?(ClassType)
          node.raise "#{name} is not a #{node.struct ? "struct" : "class"}, it's a #{type.type_desc}"
        end

        if (!!node.struct) != (!!type.struct?)
          node.raise "#{name} is not a #{node.struct ? "struct" : "class"}, it's a #{type.type_desc}"
        end

        if node.superclass && type.superclass != superclass
          node.raise "superclass mismatch for class #{type} (#{superclass} for #{type.superclass})"
        end
      else
        unless superclass.is_a?(NonGenericClassType)
          node_superclass.not_nil!.raise "#{superclass} is not a class, it's a #{superclass.type_desc}"
        end

        created_new_type = true
        if type_vars = node.type_vars
          type = GenericClassType.new @mod, scope, name, superclass, type_vars, false
        else
          type = NonGenericClassType.new @mod, scope, name, superclass, false
        end
        type.abstract = node.abstract
        type.struct = node.struct
        scope.types[name] = type
      end

      @types.push type

      if created_new_type
        run_hooks(superclass.metaclass, type, :inherited, node)
      end

      node.body.accept self
      @types.pop

      if created_new_type
        raise "Bug" unless type.is_a?(InheritableClass)
        type.force_add_subclass
      end

      node.type = @mod.nil

      false
    end

    def run_hooks(type_with_hooks, current_type, kind, node)
      hooks = type_with_hooks.hooks
      return unless hooks

      hooks.each do |hook|
        next if hook.kind != kind

        expanded = expand_macro(hook.macro, node) do
          @mod.expand_macro current_type.instance_type, hook.macro.body
        end
        expanded.accept self
        node.add_runtime_initializer(expanded)
      end
    end

    def visit(node : ModuleDef)
      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_path_type node.name, true
      end

      type = scope.types[name]?
      if type
        unless type.module?
          node.raise "#{name} is not a module, it's a #{type.type_desc}"
        end
      else
        if type_vars = node.type_vars
          type = GenericModuleType.new @mod, scope, name, type_vars
        else
          type = NonGenericModuleType.new @mod, scope, name
        end
        scope.types[name] = type
      end

      @types.push type
      node.body.accept self
      @types.pop

      node.type = @mod.nil

      false
    end

    def visit(node : Alias)
      alias_type = AliasType.new(@mod, current_type, node.name)
      current_type.types[node.name] = alias_type
      node.value.accept self
      alias_type.aliased_type = node.value.type.instance_type

      node.type = @mod.nil

      false
    end

    def visit(node : Include)
      include_in current_type, node, :included

      node.type = @mod.nil

      false
    end

    def visit(node : Extend)
      include_in current_type.metaclass, node, :extended

      node.type = @mod.nil

      false
    end

    def visit(node : LibDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
      else
        type = LibType.new @mod, current_type, node.name, node.libname, node.libtype
        current_type.types[node.name] = type
      end
      @types.push type
      node.body.accept self
      @types.pop

      node.type = @mod.nil

      false
    end

    def visit(node : FunDef)
      if node.body && !current_type.is_a?(Program)
        node.raise "can only declare fun at lib or global scope"
      end

      args = node.args.map do |arg|
        restriction = arg.restriction.not_nil!
        restriction.accept self

        arg_type = check_primitive_like(restriction.not_nil!)

        fun_arg = Arg.new_with_type(arg.name, arg_type)
        fun_arg.location = arg.location
        fun_arg
      end

      node_return_type = node.return_type
      if node_return_type
        node_return_type.accept self
        return_type = check_primitive_like(node_return_type)
      else
        return_type = @mod.void
      end

      external = External.for_fun(node.name, node.real_name, args, return_type, node.varargs, node.body, node)
      if node_body = node.body
        vars = MetaVars.new
        args.each do |arg|
          var = MetaVar.new(arg.name, arg.type)
          var.bind_to var
          vars[arg.name] = var
        end
        external.set_type(nil)

        visitor = TypeVisitor.new(@mod, vars, external)
        visitor.untyped_def = external
        visitor.scope = @mod
        visitor.block_nest = @block_nest

        begin
          node_body.accept visitor
        rescue ex : Crystal::Exception
          node.raise ex.message, ex
        end

        inferred_return_type = @mod.type_merge([node_body.type?, external.type?])

        if return_type && return_type != @mod.void && inferred_return_type != return_type
          node.raise "expected fun to return #{return_type} but it returned #{inferred_return_type}"
        end

        external.set_type(return_type)

        if node.name == Crystal::RAISE_NAME
          external.raises = true
        end
      elsif node.name == Crystal::MAIN_NAME
        external.raises = true
      end

      begin
        old_external = current_type.add_def external
      rescue ex
        node.raise ex.message
      end

      if old_external.is_a?(External)
        old_external.dead = true
      end

      if node.body
        current_type.add_def_instance external.object_id, external.args.map(&.type), nil, external
      end

      node.type = @mod.nil

      false
    end

    def end_visit(node : FunDef)
      check_valid_attributes node, ValidDefAttributes, "fun"
    end

    def end_visit(node : TypeDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        typed_def_type = check_primitive_like node.type_spec
        current_type.types[node.name] = TypeDefType.new @mod, current_type, node.name, typed_def_type
      end
    end

    def end_visit(node : StructDef)
      check_valid_attributes node, ValidStructDefAttributes, "struct"

      type = process_struct_or_union_def node, CStructType
      type.packed = true if node.has_attribute?("Packed")
    end

    def end_visit(node : UnionDef)
      process_struct_or_union_def node, CUnionType
    end

    def visit(node : EnumDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        if base_type = node.base_type
          base_type.accept self
          enum_base_type = base_type.type.instance_type
          unless enum_base_type.is_a?(IntegerType)
            base_type.raise "enum base type must be an integer type"
          end
        else
          enum_base_type = @mod.int32
        end

        counter = 0
        node.constants.each do |constant|
          if default_value = constant.default_value
            counter = interpret_enum_value(default_value)
          end
          constant.default_value = NumberLiteral.new(counter, enum_base_type.kind)
          counter += 1
        end
        current_type.types[node.name] = CEnumType.new(@mod, current_type, node.name, enum_base_type, node.constants)
      end
      false
    end

    def interpret_enum_value(node : NumberLiteral)
      case node.kind
      when :i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64
        node.value.to_i
      else
        node.raise "enum constant value must be an integer, not #{node.kind}"
      end
    end

    def interpret_enum_value(node : Call)
      obj = node.obj
      unless obj
        node.raise "invalid enum constant value"
      end
      if node.args.length != 1
        node.raise "invalid enum constant value"
      end

      left = interpret_enum_value(obj)
      right = interpret_enum_value(node.args.first)

      case node.name
      when "+"  then left + right
      when "-"  then left - right
      when "*"  then left * right
      when "/"  then left / right
      when "&"  then left & right
      when "|"  then left | right
      when "<<" then left << right
      when ">>" then left >> right
      when "%"  then left % right
      else
        node.raise "invalid enum constant value"
      end
    end

    def interpret_enum_value(node : ASTNode)
      node.raise "invalid enum constant value"
    end

    def visit(node : ExternalVar)
      check_valid_attributes node, ValidExternalVarAttributes, "external var"

      node.type_spec.accept self

      var_type = check_primitive_like node.type_spec

      type = current_type as LibType
      type.add_var node.name, var_type, (node.real_name || node.name), node.attributes

      false
    end

    def visit(node : Path)
      type = resolve_ident(node)
      case type
      when Const
        unless type.value.type?
          old_types, old_scope, old_vars, old_meta_vars, old_type_lookup = @types, @scope, @vars, @meta_vars, @type_lookup
          @types, @scope, @vars, @meta_vars, @type_lookup = type.scope_types, type.scope, MetaVars.new, MetaVars.new, nil
          type.value.accept self
          type.vars = @meta_vars
          @types, @scope, @vars, @meta_vars, @type_lookup = old_types, old_scope, old_vars, old_meta_vars, old_type_lookup
        end
        node.target_const = type
        node.bind_to type.value
      when Type
        node.type = check_type_in_type_args(type.remove_alias_if_simple)
      when ASTNode
        node.syntax_replacement = type
        node.bind_to type
      end
    end

    def end_visit(node : Union)
      node.type = @mod.type_merge(node.types.map &.type.instance_type)
    end

    def end_visit(node : Hierarchy)
      node.type = check_type_in_type_args node.name.type.instance_type.hierarchy_type
    end

    def end_visit(node : Metaclass)
      node.type = node.name.type.hierarchy_type.metaclass
    end

    def check_type_in_type_args(type)
      if @in_type_args > 0
        type
      else
        type.metaclass
      end
    end

    def visit(node : If)
      request_type_filters do
        node.cond.accept self
      end

      cond_type_filters = @type_filters
      cond_vars = @vars

      @type_filters = nil
      @vars = cond_vars.dup
      @unreachable = false

      filter_vars cond_type_filters

      node.then.accept self

      then_vars = @vars
      then_type_filters = @type_filters
      @type_filters = nil
      then_unreachable = @unreachable

      @vars = cond_vars.dup
      @unreachable = false

      # The only cases where we can deduce something for the 'else'
      # block is when the condition is a Var (in the else it must be
      # nil), IsA (in the else it's not that type) or RespondsTo
      # (in the else it doesn't respond to that message).
      case node.cond
      when Var, IsA, RespondsTo
        filter_vars cond_type_filters, &.not
      end

      node.else.accept self

      else_vars = @vars
      else_type_filters = @type_filters
      @type_filters = nil
      else_unreachable = @unreachable

      merge_if_vars node, cond_vars, then_vars, else_vars, then_unreachable, else_unreachable

      if needs_type_filters?
        case node.binary
        when :and
          @type_filters = and_type_filters(and_type_filters(cond_type_filters, then_type_filters), else_type_filters)
        # TODO: or type filters
        # when :or
        #   node.type_filters = or_type_filters(node.then.type_filters, node.else.type_filters)
        end
      end

      @unreachable = then_unreachable && else_unreachable

      node.bind_to [node.then, node.else]

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
    def merge_if_vars(node, cond_vars, then_vars, else_vars, then_unreachable, else_unreachable)
      all_vars_names = Set(String).new
      then_vars.each_key do |name|
        all_vars_names << name
      end
      else_vars.each_key do |name|
        all_vars_names << name
      end

      all_vars_names.each do |name|
        cond_var = cond_vars[name]?
        then_var = then_vars[name]?
        else_var = else_vars[name]?

        # Check wether the var didn't change at all
        next if then_var.same?(else_var)

        if_var = MetaVar.new(name)
        if_var.nil_if_read = !!(then_var.try(&.nil_if_read) || else_var.try(&.nil_if_read))

        if then_var && else_var
          if_var.bind_to then_var unless then_unreachable
          if_var.bind_to else_var unless else_unreachable
        elsif then_var
          if_var.bind_to then_var unless then_unreachable
          if cond_var
            if_var.bind_to cond_var
          elsif !else_unreachable
            if_var.bind_to @mod.nil_var
            if_var.nil_if_read = true
          end
        elsif else_var
          if_var.bind_to else_var unless else_unreachable
          if cond_var
            if_var.bind_to cond_var
          elsif !then_unreachable
            if_var.bind_to @mod.nil_var
            if_var.nil_if_read = true
          end
        end

        @vars[name] = if_var
      end
    end

    def visit(node : While)
      old_while_vars = @while_vars
      before_cond_vars = @vars.dup

      request_type_filters do
        node.cond.accept self
      end

      cond_type_filters = @type_filters

      after_cond_vars = @vars.dup
      @while_vars = after_cond_vars

      filter_vars cond_type_filters

      @type_filters = nil
      @block, old_block = nil, @block

      @while_stack.push node
      node.body.accept self

      merge_while_vars before_cond_vars, after_cond_vars, @vars, node.break_vars

      @while_stack.pop
      @block = old_block
      @while_vars = old_while_vars

      false
    end

    # Here we assign the types of variables after a while.
    def merge_while_vars(before_cond_vars, after_cond_vars, while_vars, all_break_vars)
      after_while_vars = MetaVars.new

      while_vars.each do |name, while_var|
        before_cond_var = before_cond_vars[name]?
        after_cond_var = after_cond_vars[name]?

        # If a variable was assigned in the condition, it has that type.
        if after_cond_var && !after_cond_var.same?(before_cond_var)
          after_while_var = MetaVar.new(name)
          after_while_var.bind_to(after_cond_var)
          after_while_var.nil_if_read = after_cond_var.nil_if_read
          after_while_vars[name] = after_while_var

        # If there was a previous variable, we use that type merged
        # with the last type inside the while.
        elsif before_cond_var
          before_cond_var.bind_to(while_var)
          after_while_var = MetaVar.new(name)
          after_while_var.bind_to(before_cond_var)
          after_while_var.bind_to(while_var)
          after_while_var.nil_if_read = before_cond_var.nil_if_read || while_var.nil_if_read
          after_while_vars[name] = after_while_var

        # Otherwise, it's a new variable inside the while: used
        # outside it must be nilable.
        else
          nilable_var = MetaVar.new(name)
          nilable_var.bind_to(while_var)
          nilable_var.bind_to(@mod.nil_var)
          nilable_var.nil_if_read = true
          after_while_vars[name] = nilable_var
        end
      end

      @vars = after_while_vars

      # We also need to merge types from breaks inside while.
      if all_break_vars
        all_break_vars.each do |break_vars|
          break_vars.each do |name, var|
            @vars[name].bind_to(var)
          end
        end
      end
    end

    def end_visit(node : While)
      unless node.has_breaks
        node_cond = node.cond
        if node_cond.is_a?(BoolLiteral) && node_cond.value == true
          node.type = mod.no_return
          return
        end
      end

      node.type = @mod.nil
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

    def filter_vars(filters)
      filters.try &.each do |name, filter|
        existing_var = @vars[name]
        filtered_var = MetaVar.new(name)
        filtered_var.bind_to(existing_var.filtered_by(yield filter))
        @vars[name] = filtered_var
      end
    end


    def end_visit(node : Break)
      container = @while_stack.last? || (block.try &.break)
      node.raise "Invalid break" unless container

      if container.is_a?(While)
        container.has_breaks = true

        break_vars = (container.break_vars = container.break_vars || [] of MetaVars)
        break_vars.push @vars.dup
      else
        container.bind_to(node.exps.length > 0 ? node.exps[0] : mod.nil_var)
        bind_vars @vars, block.not_nil!.after_vars
      end

      @unreachable = true
    end

    def end_visit(node : Next)
      if block = @block
        if node.exps.empty?
          block.bind_to @mod.nil_var
        else
          block.bind_to node.exps.first
        end

        bind_vars @vars, block.vars
        bind_vars @vars, block.after_vars
      elsif @while_stack.empty?
        node.raise "Invalid next"
      else
        bind_vars @vars, @while_vars
      end

      @unreachable = true
    end

    def visit(node : Primitive)
      case node.name
      when :binary
        visit_binary node
      when :cast
        visit_cast node
      when :allocate
        visit_allocate node
      when :pointer_malloc
        visit_pointer_malloc node
      when :pointer_set
        visit_pointer_set node
      when :pointer_get
        visit_pointer_get node
      when :pointer_address
        node.type = @mod.uint64
      when :pointer_new
        visit_pointer_new node
      when :pointer_realloc
        node.type = scope
      when :pointer_add
        node.type = scope
      when :argc
        node.type = @mod.int32
      when :argv
        node.type = @mod.pointer_of(@mod.pointer_of(@mod.uint8))
      when :float32_infinity
        node.type = @mod.float32
      when :float64_infinity
        node.type = @mod.float64
      when :struct_new
        node.type = scope.instance_type
      when :struct_set
        node.bind_to @vars["value"]
      when :struct_get
        visit_struct_get node
      when :union_new
        node.type = scope.instance_type
      when :union_set
        node.bind_to @vars["value"]
      when :union_get
        visit_union_get node
      when :external_var_set
        # Nothing to do
      when :external_var_get
        # Nothing to do
      when :object_id
        node.type = mod.uint64
      when :object_crystal_type_id
        node.type = mod.int32
      when :symbol_hash
        node.type = mod.int32
      when :symbol_to_s
        node.type = mod.string
      when :class
        node.type = scope.metaclass
      when :fun_call, :fun_closure?
        # Nothing to do
      when :pointer_diff
        node.type = mod.int64
      when :class_name
        node.type = mod.string
      when :tuple_length
        node.type = mod.int32
      when :tuple_indexer
        visit_tuple_indexer node
      else
        node.raise "Bug: unhandled primitive in type inference: #{node.name}"
      end
    end

    def visit_binary(node)
      case typed_def.name
      when "+", "-", "*", "/"
        t1 = scope
        t2 = typed_def.args[0].type
        node.type = t1.integer? && t2.float? ? t2 : t1
      when "==", "<", "<=", ">", ">=", "!="
        node.type = @mod.bool
      when "%", "<<", ">>", "|", "&", "^"
        node.type = scope
      else
        raise "Bug: unknown binary operator #{typed_def.name}"
      end
    end

    def visit_cast(node)
      node.type =
        case typed_def.name
        when "to_i", "to_i32", "ord" then mod.int32
        when "to_i8" then mod.int8
        when "to_i16" then mod.int16
        when "to_i32" then mod.int32
        when "to_i64" then mod.int64
        when "to_u", "to_u32" then mod.uint32
        when "to_u8" then mod.uint8
        when "to_u16" then mod.uint16
        when "to_u32" then mod.uint32
        when "to_u64" then mod.uint64
        when "to_f", "to_f64" then mod.float64
        when "to_f32" then mod.float32
        when "chr" then mod.char
        else
          raise "Bug: unkown cast operator #{typed_def.name}"
        end
    end

    def visit_allocate(node)
      instance_type = scope.instance_type

      if instance_type.is_a?(GenericClassType)
        node.raise "can't create instance of generic class #{instance_type} without specifying its type vars"
      end

      if !instance_type.hierarchy? && instance_type.abstract
        node.raise "can't instantiate abstract #{instance_type.type_desc} #{instance_type}"
      end

      instance_type.allocated = true
      node.type = instance_type
    end

    def visit_pointer_malloc(node)
      if scope.instance_type.is_a?(GenericClassType)
        node.raise "can't malloc pointer without type, use Pointer(Type).malloc(size)"
      end

      node.type = scope.instance_type
    end

    def visit_pointer_set(node)
      scope = @scope as PointerInstanceType

      value = @vars["value"]

      scope.var.bind_to value
      node.bind_to value
    end

    def visit_pointer_get(node)
      scope = @scope as PointerInstanceType

      node.bind_to scope.var
    end

    def visit_pointer_new(node)
      if scope.instance_type.is_a?(GenericClassType)
        node.raise "can't create pointer without type, use Pointer(Type).new(address)"
      end

      node.type = scope.instance_type
    end

    def visit_struct_get(node)
      scope = @scope as CStructType
      node.bind_to scope.vars[untyped_def.name]
    end

    def visit_union_get(node)
      scope = @scope as CUnionType
      node.bind_to scope.vars[untyped_def.name]
    end

    def visit_tuple_indexer(node)
      tuple_type = scope as TupleInstanceType
      node.type = @mod.type_merge tuple_type.tuple_types
    end

    def visit(node : Self)
      node.type = scope.instance_type
    end

    def visit(node : PointerOf)
      var = case node_exp = node.exp
            when Var
              meta_var = @meta_vars[node_exp.name]
              meta_var.assigned_to = true
              meta_var
            when InstanceVar
              lookup_instance_var node_exp
            when IndirectRead
              node_exp.accept self
              visit_indirect(node_exp)
            else
              node.raise "can't take address of #{node}"
            end
      node.bind_to var
    end

    def visit(node : TypeOf)
      node.in_type_args = @in_type_args > 0

      old_in_type_args = @in_type_args
      @in_type_args = 0

      @typeof_nest += 1
      node.expressions.each &.accept self
      @typeof_nest -= 1

      @in_type_args = old_in_type_args

      node.bind_to node.expressions

      false
    end

    def end_visit(node : SizeOf)
      node.type = @mod.int32
    end

    def end_visit(node : InstanceSizeOf)
      node.type = @mod.int32
    end

    def visit(node : Rescue)
      if node_types = node.types
        types = node_types.map do |type|
          type.accept self
          instance_type = type.type.instance_type
          unless instance_type.is_subclass_of?(@mod.exception)
            type.raise "#{type} is not a subclass of Exception"
          end
          instance_type
        end
      end

      if node_name = node.name
        var = @vars[node_name] = new_meta_var(node_name)
        meta_var = @meta_vars[node_name] = new_meta_var(node_name)
        meta_var.bind_to(var)

        if types
          unified_type = @mod.type_merge(types).not_nil!
          unified_type = unified_type.hierarchy_type unless unified_type.is_a?(HierarchyType)
        else
          unified_type = @mod.exception.hierarchy_type
        end
        var.set_type(unified_type)
        var.freeze_type = true

        node.set_type(var.type)
      end

      node.body.accept self

      false
    end

    def visit(node : ExceptionHandler)
      old_exception_handler_vars = @exception_handler_vars

      # Save old vars to know if new variables are declared inside begin/rescue/else
      before_body_vars = @vars.dup

      # Any variable assigned in the body (begin) will have, inside rescue/else
      # blocks, all types that were assigned to them, because we can't know at which
      # point an exception is raised.
      exception_handler_vars = @exception_handler_vars = @vars.dup

      node.body.accept self

      @exception_handler_vars = nil

      if node.rescues || node.else
        # Any variable introduced in the begin block is possibly nil
        # in the rescue/else blocks because we can't know if an exception
        # was raised before assigning any of the vars.
        exception_handler_vars.each do |name, var|
          unless before_body_vars[name]?
            var.nil_if_read = true
          end
        end

        # Now, using these vars, visit all rescue/else blocks and keep
        # the results in this variable.
        all_rescue_vars = [] of MetaVars

        node.rescues.try &.each do |a_rescue|
          @vars = exception_handler_vars.dup
          @unreachable = false
          a_rescue.accept self
          all_rescue_vars << @vars unless @unreachable
        end

        node.else.try do |a_else|
          @vars = exception_handler_vars.dup
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
          node.ensure.try &.accept self
        end
      end

      # If there were no rescue/else blocks or all of them were unreachable
      unless all_rescue_vars
        if node_ensure = node.ensure
          # Variables in the ensure block might be nil because we don't know
          # if an exception was thrown before any assignment.
          @vars.each do |name, var|
            unless before_body_vars[name]?
              var.nil_if_read = true
            end
          end

          node_ensure.accept self
        end

        # However, those previous variables can't be nil afterwards:
        # if an exception was raised then we won't running the code
        # after the ensure clause, so variables don't matter. But if
        # an exception was not raised then all variables were declared
        # successfuly.
        @vars.each do |name, var|
          unless before_body_vars[name]?
            var.nil_if_read = false
          end
        end
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

      old_exception_handler_vars = @exception_handler_vars

      false
    end

    def merge_rescue_vars(body_vars, all_rescue_vars)
      after_vars = MetaVars.new

      all_rescue_vars.each do |rescue_vars|
        rescue_vars.each do |name, var|
          after_var = (after_vars[name] ||= new_meta_var(name))
          if var.nil_if_read || !body_vars[name]?
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

    def end_visit(node : IndirectRead)
      var = visit_indirect(node)
      node.bind_to var
    end

    def end_visit(node : IndirectWrite)
      var = visit_indirect(node)
      if var.type != node.value.type
        unless node.value.type.is_implicitly_converted_in_c_to?(var.type)
          type = node.obj.type as PointerInstanceType
          node.raise "field '#{node.names.join "->"}' of struct #{type.element_type} has type #{var.type}, not #{node.value.type}"
        end
      end

      node.bind_to node.value
    end

    def visit_indirect(node)
      type = node.obj.type
      if type.is_a?(PointerInstanceType)
        element_type = type.element_type
        var = nil
        node.names.each do |name|
          # TOOD remove duplicate code
          case element_type
          when CStructType
            var = element_type.vars[name]?
            if var
              var_type = var.type
              element_type = var_type
            else
              node.raise "#{element_type.type_desc} #{element_type} has no field '#{name}'"
            end
          when CUnionType
            var = element_type.vars[name]?
            if var
              var_type = var.type
              element_type = var_type
            else
              node.raise "#{element_type.type_desc} #{element_type} has no field '#{name}'"
            end
          else
            node.raise "#{element_type.type_desc} is not a struct or union, it's a #{element_type}"
          end
        end

        return var.not_nil!
      end

      node.raise "#{type} is not a pointer to a struct or union, it's a #{type.type_desc} #{type}"
    end

    def end_visit(node : TupleLiteral)
      node.elements.each &.add_observer(node)
      node.update
      false
    end

    def visit(node : TupleIndexer)
      node.type = (scope as TupleInstanceType).tuple_types[node.index] as Type
      false
    end

    def include_in(current_type, node, kind)
      node_name = node.name
      if node_name.is_a?(Generic)
        type = lookup_path_type(node_name.name)
      else
        type = lookup_path_type(node_name)
      end

      unless type.module?
        node_name.raise "#{node_name} is not a module, it's a #{type.type_desc}"
      end

      if node_name.is_a?(Generic)
        unless type.is_a?(GenericModuleType)
          node_name.raise "#{type} is not a generic module"
        end

        if type.type_vars.length != node_name.type_vars.length
          node_name.raise "wrong number of type vars for #{type} (#{node_name.type_vars.length} for #{type.type_vars.length})"
        end

        mapping = Hash.zip(type.type_vars, node_name.type_vars)
        module_to_include = IncludedGenericModule.new(@mod, type, current_type, mapping)
      else
        if type.is_a?(GenericModuleType)
          if current_type.is_a?(GenericType)
            current_type_type_vars_length = current_type.type_vars.length
            if current_type_type_vars_length != type.type_vars.length
              node_name.raise "#{type} wrong number of type vars for #{type} (#{current_type_type_vars_length} for #{current_type.type_vars.length})"
            end

            mapping = {} of String => ASTNode
            type.type_vars.zip(current_type.type_vars) do |type_var, current_type_var|
              mapping[type_var] = Path.new([current_type_var])
            end
            module_to_include = IncludedGenericModule.new(@mod, type, current_type, mapping)
          else
            node_name.raise "#{type} is a generic module"
          end
        else
          module_to_include = type
        end
      end

      begin
        current_type.include module_to_include
        run_hooks type.metaclass, current_type, kind, node
      rescue ex
        node_name.raise ex.message
      end
    end

    def process_struct_or_union_def(node, klass)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        fields = node.fields.map do |field|
          field_type = check_primitive_like field.restriction.not_nil!
          Var.new(field.name, field_type)
        end
        current_type.types[node.name] = klass.new @mod, current_type, node.name, fields
      end
    end

    def check_valid_attributes(node, valid_attributes, desc)
      if attrs = node.attributes
        attrs.each do |attr|
          unless valid_attributes.includes?(attr.name)
            attr.raise "illegal attribute for #{desc}, valid attributes are: #{valid_attributes.join ", "}"
          end
        end
      end
    end

    def lookup_path_type(node : Self, create_modules_if_missing = false)
      current_type
    end

    def lookup_path_type(node : Path, create_modules_if_missing = false)
      target_type = resolve_ident(node, create_modules_if_missing)
      if target_type.is_a?(Type)
        target_type.remove_alias_if_simple
      else
        node.raise "#{node} must be a type here, not #{target_type}"
      end
    end

    def lookup_path_type(node, create_modules_if_missing = false)
      raise "lookup_path_type not implemented for #{node}"
    end

    def resolve_ident(node : Path, create_modules_if_missing = false)
      free_vars = @free_vars
      if free_vars && !node.global && (type = free_vars[node.names.first]?)
        target_type = type
        if node.names.length > 1
          target_type = target_type.lookup_type(node.names[1 .. -1])
        end
      else
        base_lookup = node.global ? mod : (@type_lookup || @scope || @types.last)
        target_type = base_lookup.lookup_type node

        unless target_type
          if create_modules_if_missing
            next_type = base_lookup
            node.names.each do |name|
              next_type = base_lookup.lookup_type([name])
              if next_type
                if next_type.is_a?(ASTNode)
                  node.raise "execpted #{name} to be a type"
                end
              else
                next_type = NonGenericModuleType.new(@mod, base_lookup, name)
                base_lookup.types[name] = next_type
              end
              base_lookup = next_type
            end
            target_type = next_type
          else
            similar_name = base_lookup.lookup_similar_type_name(node)
          end
        end
      end

      unless target_type
        error_msg = String.build do |msg|
          msg << "undefined constant #{node}"
          msg << " \e[1;33m(did you mean '#{similar_name}'?)\e[0m" if similar_name
        end
        node.raise error_msg
      end

      target_type
    end

    def check_primitive_like(node)
      type = node.type.instance_type
      unless type.primitive_like?
        msg = String.build do |msg|
          msg << "only primitive types, pointers, structs, unions and enums are allowed in lib declarations"
          msg << " (did you mean Int32?)" if type == @mod.int
          msg << " (did you mean Float32?)" if type == @mod.float
        end
        node.raise msg
      end

      if type.c_enum?
        type = @mod.int32
      elsif type.is_a?(TypeDefType) && type.typedef.fun?
        type = type.typedef
      end

      type
    end

    def current_type
      @types.last
    end

    def check_closured(var)
      if var.name == "self"
        check_self_closured
        return
      end

      context = current_context
      var_context = var.context
      if !var_context.same?(context)
        # If the contexts are not the same, it might be that we are in a block
        # inside a method, or a block inside another block. We don't want
        # those cases to closure a variable. So if any context is a block
        # we go to the block's context (a def or a fun literal) and compare
        # if those are the same to determine whether the variable is closured.
        context = context.context if context.is_a?(Block)
        var_context = var_context.context if var_context.is_a?(Block)

        closured = !context.same?(var_context)
        if closured
          var.closured = true
          context.closure = true if context.is_a?(Def)
        end
      end
    end

    def check_self_closured
      if (context = @fun_literal_context) && context.is_a?(Def)
        context.self_closured = true

        non_block_context = current_non_block_context
        non_block_context.closure = true if non_block_context.is_a?(Def)
      end
    end

    def current_context
      @block_context || current_non_block_context
    end

    def current_non_block_context
      @typed_def || @mod
    end

    def lookup_var_or_instance_var(var : Var)
      @vars[var.name]
    end

    def lookup_var_or_instance_var(var : InstanceVar)
      scope = @scope as InstanceVarContainer
      scope.lookup_instance_var(var.name)
    end

    def lookup_var_or_instance_var(var)
      raise "Bug: trying to lookup var or instance var but got #{var}"
    end

    def bind_meta_var(var : Var)
      @meta_vars[var.name].bind_to(var)
    end

    def bind_meta_var(var : InstanceVar)
      # Nothing to do
    end

    def bind_meta_var(var)
      raise "Bug: trying to bind var or instance var but got #{var}"
    end

    def bind_initialize_instance_vars(owner)
      names_to_remove = [] of String

      @vars.each do |name, var|
        if name.starts_with? '@'
          if var.nil_if_read
            ivar = owner.lookup_instance_var(name)
            ivar.bind_to @mod.nil_var
          end

          names_to_remove << name
        end
      end

      names_to_remove.each do |name|
        @meta_vars.delete name
        @vars.delete name
      end
    end

    def and_type_filters(filters1, filters2)
      if filters1 && filters2
        new_filters = new_type_filter
        all_keys = (filters1.keys + filters2.keys).uniq!
        all_keys.each do |name|
          filter1 = filters1[name]?
          filter2 = filters2[name]?
          if filter1 && filter2
            new_filters[name] = TypeFilter.and(filter1, filter2)
          elsif filter1
            new_filters[name] = filter1
          elsif filter2
            new_filters[name] = filter2
          end
        end
        new_filters
      elsif filters1
        filters1
      else
        filters2
      end
    end

    def or_type_filters(filters1, filters2)
      # TODO: or type filters
      nil
    end

    def negate_filters(filters_hash)
      negated_filters = new_type_filter
      filters_hash.each do |name, filter|
        negated_filters[name] = NotFilter.new(filter)
      end
      negated_filters
    end

    def new_type_filter
      {} of String => TypeFilter
    end

    def new_type_filter(node, filter)
      new_filter = new_type_filter
      new_filter[node.name] = filter
      new_filter
    end

    def not_nil_filter(node)
      new_type_filter(node, NotNilFilter.instance)
    end

    def needs_type_filters?
      @needs_type_filters > 0
    end

    def request_type_filters
      @type_filters = nil
      @needs_type_filters += 1
      begin
        yield
      ensure
        @needs_type_filters -= 1
      end
    end

    def ignore_type_filters
      needs_type_filters, @needs_type_filters = @needs_type_filters, 0
      begin
        yield
      ensure
        @needs_type_filters = needs_type_filters
      end
    end

    def lookup_similar_var_name(name)
      tolerance = (name.length / 5.0).ceil
      # TODO: check this
      @meta_vars.each_key do |var_name|
        if levenshtein(var_name, name) <= tolerance
          return var_name
        end
      end
      nil
    end

    def visit(node : And)
      raise "Bug: And node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : Or)
      raise "Bug: Or node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : Require)
      raise "Bug: Require node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : RangeLiteral)
      raise "Bug: RangeLiteral node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : Case)
      raise "Bug: Case node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : When)
      raise "Bug: When node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : RegexLiteral)
      raise "Bug: RegexLiteral node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : ArrayLiteral)
      expand(node)
    end

    def visit(node : HashLiteral)
      expand(node)
    end

    def expand(node)
      expanded = @mod.literal_expander.expand node
      expanded.accept self
      node.expanded = expanded
      node.bind_to expanded
      false
    end

    def visit(node : Unless)
      raise "Bug: Unless node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : StringInterpolation)
      raise "Bug: StringInterpolation node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : MultiAssign)
      raise "Bug: MultiAssign node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : Until)
      raise "Bug: Until node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : MacroLiteral)
      raise "Bug: shouldn't visit macro literal in type inference"
    end
  end
end
