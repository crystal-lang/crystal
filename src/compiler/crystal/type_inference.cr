require "program"
require "visitor"
require "ast"
require "type_inference/*"

module Crystal
  class Program
    def infer_type(node)
      node.accept TypeVisitor.new(self)
      fix_empty_types node
      after_type_inference node
    end
  end

  class TypeVisitor < Visitor
    include TypeVisitorHelper

    ValidGlobalAttributes = ["ThreadLocal"]

    getter mod
    property! scope
    getter! typed_def
    property! untyped_def
    getter block
    property call
    property type_lookup
    property fun_literal_context

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

    def initialize(@mod, vars = MetaVars.new, @typed_def = nil, meta_vars = nil)
      @types = [@mod] of Type
      @while_stack = [] of While
      typed_def = @typed_def

      @meta_vars = initialize_meta_vars @mod, vars, typed_def, meta_vars
      @vars = vars

      @needs_type_filters = 0
      @unreachable = false
    end

    # We initialize meta_vars from vars given in the constructor.
    # We store those meta vars either in the typed def or in the program
    # so the codegen phase knows the cummulative types to do allocas.
    def initialize_meta_vars(mod, vars, typed_def, meta_vars)
      unless meta_vars
        if typed_def
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

      meta_vars
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
        node.raise "Bug: missing variable declaration for: #{node.name}"
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

        if scope.is_a?(InstanceVarContainer)
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
      scope = (@typed_def ? @scope : current_type).not_nil!
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
      process_def node
      node.set_type(@mod.nil)
      false
    end

    def visit(node : Macro)
      process_macro node
      node.set_type(@mod.nil)
      false
    end

    def end_visit(node : TypeOf)
      node.bind_to node.expressions
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

      block_visitor = TypeVisitor.new(mod, before_block_vars, @typed_def, meta_vars)
      block_visitor.yield_vars = @yield_vars
      block_visitor.free_vars = @free_vars
      block_visitor.untyped_def = @untyped_def
      block_visitor.call = @call
      block_visitor.scope = node.scope || @scope
      block_visitor.block = node
      block_visitor.type_lookup = type_lookup
      node.body.accept block_visitor

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
          arg.type = restriction.type.instance_type
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
      block_visitor.yield_vars = @yield_vars
      block_visitor.free_vars = @free_vars
      block_visitor.untyped_def = node.def
      block_visitor.call = @call
      block_visitor.scope = @scope
      block_visitor.type_lookup = type_lookup
      block_visitor.fun_literal_context = @fun_literal_context || @typed_def || @mod
      node.def.body.accept block_visitor

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

      obj = node.obj
      block_arg = node.block_arg

      ignore_type_filters do
        obj.try &.accept(self)
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

    def expand_macro(node)
      return false if node.obj || node.name == "super"

      untyped_def = node.scope.lookup_macro(node.name, node.args.length)
      if !untyped_def && node.scope.metaclass? && node.scope.instance_type.module?
        untyped_def = @mod.object.metaclass.lookup_macro(node.name, node.args.length)
      end
      untyped_def ||= mod.lookup_macro(node.name, node.args.length)
      return false unless untyped_def

      macros_cache_key = MacroCacheKey.new(untyped_def.object_id, node.args.map(&.crystal_type_id))
      expander = mod.macros_cache[macros_cache_key] ||= MacroExpander.new(mod, untyped_def)

      generated_source = expander.expand node

      begin
        parser = Parser.new(generated_source, [Set.new(@vars.keys)])
        parser.filename = VirtualFile.new(untyped_def, generated_source)
        generated_nodes = parser.parse
      rescue ex : Crystal::SyntaxException
        node.raise "macro didn't expand to a valid program, it expanded to:\n\n#{"=" * 80}\n#{"-" * 80}\n#{number_lines generated_source}\n#{"-" * 80}\n#{ex.to_s(generated_source)}#{"=" * 80}"
      end

      generated_nodes = mod.normalize(generated_nodes)

      begin
        generated_nodes.accept self
      rescue ex : Crystal::Exception
        node.raise "macro didn't expand to a valid program, it expanded to:\n\n#{"=" * 80}\n#{"-" * 80}\n#{number_lines generated_source}\n#{"-" * 80}\n#{ex.to_s(generated_source)}#{"=" * 80}"
      end

      node.target_macro = generated_nodes
      node.bind_to generated_nodes

      true
    end

    def number_lines(source)
      source.lines.to_s_with_line_numbers
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

    def end_visit(node : Generic)
      process_generic(node)
    end

    def end_visit(node : IsA)
      node.type = mod.bool
      obj = node.obj
      const = node.const

      # When doing x.is_a?(A) and A turns out to be a constant (not a type),
      # replace it with a === comparison. Most usually this happens in a case expression.
      if const.is_a?(Path) && const.target_const
        comp = Call.new(const, "===", [obj])
        comp.location = node.location
        comp.accept self
        node.syntax_replacement = comp
        node.bind_to comp
      elsif obj.is_a?(Var)
        if needs_type_filters?
          @type_filters = new_type_filter(obj, SimpleTypeFilter.new(node.const.type.instance_type))
        end
      end
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

    def end_visit(node : RespondsTo)
      node.type = mod.bool
      obj = node.obj
      if obj.is_a?(Var)
        if needs_type_filters?
          @type_filters = new_type_filter(obj, RespondsToTypeFilter.new(node.name.value))
        end
      end
    end

    def visit(node : ClassDef)
      process_class_def(node) do
        node.body.accept self
      end

      node.type = @mod.nil

      false
    end

    def visit(node : ModuleDef)
      process_module_def(node) do
        node.body.accept self
      end

      node.type = @mod.nil

      false
    end

    def visit(node : Alias)
      process_alias(node)

      node.type = @mod.nil

      false
    end

    def visit(node : Include)
      process_include(node)

      node.type = @mod.nil

      false
    end

    def visit(node : Extend)
      process_extend(node)

      node.type = @mod.nil

      false
    end

    def visit(node : LibDef)
      process_lib_def(node) do
        node.body.accept self
      end

      node.type = @mod.nil

      false
    end

    def visit(node : FunDef)
      process_fun_def(node)

      false
    end

    def end_visit(node : TypeDef)
      process_type_def(node)
    end

    def end_visit(node : StructDef)
      process_struct_def node
    end

    def end_visit(node : UnionDef)
      process_union_def node
    end

    def visit(node : EnumDef)
      process_enum_def(node)
      false
    end

    def visit(node : ExternalVar)
      process_external_var(node)
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
        node.type = type.remove_alias_if_simple.metaclass
      when ASTNode
        node.syntax_replacement = type
        node.bind_to type
      end
    end

    def end_visit(node : Union)
      process_ident_union(node)
    end

    def end_visit(node : Hierarchy)
      process_hierarchy(node)
    end

    def end_visit(node : Metaclass)
      process_metaclass(node)
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
      when :object_to_cstr
        node.type = mod.uint8_pointer
      when :object_crystal_type_id
        node.type = mod.int32
      when :symbol_hash
        node.type = mod.int32
      when :symbol_to_s
        node.type = mod.string
      when :struct_hash
        node.type = mod.int32
      when :struct_equals
        node.type = mod.bool
      when :struct_to_s
        node.type = mod.string
      when :class
        node.type = scope.metaclass
      when :fun_call
        # Nothing to do
      when :pointer_diff
        node.type = mod.int64
      when :nil_pointer
        # Nothing to do
      when :pointer_null
        visit_pointer_null node
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
      instance_type = process_allocate(node)
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

    def visit_pointer_null(node)
      instance_type = scope.instance_type
      if instance_type.is_a?(GenericClassType)
        node.raise "can't instantiate pointer without type, use Pointer(Type).null"
      end

      node.type = instance_type
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

    def end_visit(node : TypeOf)
      node.bind_to node.expressions
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

    def merge_rescue_vars(before_vars, all_rescue_vars)
      after_vars = MetaVars.new

      all_rescue_vars.each do |rescue_vars|
        rescue_vars.each do |name, var|
          after_var = (after_vars[name] ||= new_meta_var(name))
          if var.nil_if_read || !before_vars[name]?
            after_var.nil_if_read = true
          end
          after_var.bind_to(var)
        end
      end

      before_vars.each do |name, var|
        after_var = (after_vars[name] ||= new_meta_var(name))
        if var.nil_if_read
          after_var.nil_if_read = true
        end
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
        type = node.obj.type as PointerInstanceType
        node.raise "field '#{node.names.join "->"}' of struct #{type.element_type} has type #{var.type}, not #{node.value.type}"
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
      node.bind_to node.exps
      false
    end

    def visit(node : TupleIndexer)
      node.type = (scope as TupleInstanceType).tuple_types[node.index] as Type
      false
    end

    def check_closured(var)
      if var.name == "self"
        check_self_closured
        return
      end

      context = current_context
      var_context = var.context
      if !var.closured && !var_context.same?(context)
        # If the contexts are not the same, it might be that we are in a block
        # inside a method, or a block inside another block. We don't want
        # those cases to closure a variable. So if any context is a block
        # we go to the block's context (a def or a fun literal) and compare
        # if those are the same to determine whether the variable is closured.
        context = context.context if context.is_a?(Block)
        var_context = var_context.context if var_context.is_a?(Block)

        var.closured = !context.same?(var_context)
      end
    end

    def check_self_closured
      if (context = @fun_literal_context) && context.is_a?(Def)
        context.self_closured = true
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
      yield
      @needs_type_filters -= 1
    end

    def ignore_type_filters
      needs_type_filters, @needs_type_filters = @needs_type_filters, 0
      yield
      @needs_type_filters = needs_type_filters
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
      raise "Bug: ArrayLiteral node '#{node}' (#{node.location}) should have been eliminated in normalize"
    end

    def visit(node : HashLiteral)
      raise "Bug: HashLiteral node '#{node}' (#{node.location}) should have been eliminated in normalize"
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
  end
end
