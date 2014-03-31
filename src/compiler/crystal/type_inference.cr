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
    getter vars
    property call
    property type_lookup
    property in_fun_literal
    property free_vars
    property yield_vars
    property type_filter_stack

    def initialize(@mod, @vars = {} of String => Var, @typed_def = nil)
      @types = [@mod] of Type
      @while_stack = [] of While
      typed_def = @typed_def
      typed_def.vars = @vars if typed_def
      @needs_type_filters = 0
      @in_fun_literal = false
      @vars.each_value do |var|
        var.context = current_context unless var.context
      end
    end

    def block=(@block)
      @block_context = @block
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
      var = @vars[node.name]?
      if var
        check_closured var
        filter = build_var_filter var
        node.bind_to(filter || var)
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
        var.context = current_context

        @vars[var.name] = var
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

      filter = build_var_filter var
      node.bind_to(filter || var)
      if needs_type_filters?
        @type_filters = not_nil_filter(node)
      end
      node.bind_to var
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
      value.accept self

      value_type_filters = @type_filters
      @type_filters = nil

      var = lookup_var target.name
      target.bind_to var

      node.bind_to value
      var.bind_to node

      if needs_type_filters?
        @type_filters = and_type_filters(not_nil_filter(target), value_type_filters)
      end
    end

    def type_assign(target : InstanceVar, value, node)
      value.accept self

      var = lookup_instance_var target
      target.bind_to var

      # unless @typed_def.name == "initialize"
      #   @scope.immutable = false
      # end

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
      node.raise "can't yield from function literal" if @in_fun_literal
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

      block_vars = @vars.dup
      node.args.each do |arg|
        arg.context = node
        block_vars[arg.name] = arg
      end

      pushing_type_filters do
        block_visitor = TypeVisitor.new(mod, block_vars, @typed_def)
        block_visitor.type_filter_stack = @type_filter_stack
        block_visitor.yield_vars = @yield_vars
        block_visitor.free_vars = @free_vars
        block_visitor.untyped_def = @untyped_def
        block_visitor.call = @call
        block_visitor.scope = node.scope || @scope
        block_visitor.block = node
        block_visitor.type_lookup = type_lookup
        node.body.accept block_visitor
      end

      node.bind_to node.body

      false
    end

    def visit(node : FunLiteral)
      fun_vars = @vars.dup
      node.def.args.each do |arg|
        # It can happen that the argument has a type already,
        # when converting a block to a fun literal
        if restriction = arg.restriction
          restriction.accept self
          arg.type = restriction.type.instance_type
        end
        fun_vars[arg.name] = Var.new(arg.name, arg.type)
      end

      node.bind_to node.def
      node.def.bind_to node.def.body

      block_visitor = TypeVisitor.new(mod, fun_vars, node.def)
      block_visitor.type_filter_stack = @type_filter_stack
      block_visitor.yield_vars = @yield_vars
      block_visitor.free_vars = @free_vars
      block_visitor.untyped_def = node.def
      block_visitor.call = @call
      block_visitor.scope = @scope
      block_visitor.type_lookup = type_lookup
      block_visitor.in_fun_literal = true
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

      obj.add_input_observer node if obj
      node.args.each &.add_input_observer(node)
      if block_arg = node.block_arg
        block_arg.add_input_observer node
      end
      node.recalculate

      ignore_type_filters do
        obj.accept self if obj
        node.args.each &.accept(self)

        if block_arg
          block_arg.accept self
        end
      end

      @type_filters = nil

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
          old_types, old_scope, old_vars, old_type_lookup = @types, @scope, @vars, @type_lookup
          @types, @scope, @vars, @type_lookup = type.scope_types, type.scope, ({} of String => Var), nil
          type.value.accept self
          @types, @scope, @vars, @type_lookup = old_types, old_scope, old_vars, old_type_lookup
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
      @type_filters = nil

      if node.then.nop?
        node.then.accept self
      else
        pushing_type_filters(cond_type_filters) do
          node.then.accept self
        end
      end

      then_type_filters = @type_filters
      @type_filters = nil

      if node.else.nop?
        node.else.accept self
      else
        if cond_type_filters && !node.cond.is_a?(If)
          else_filters = negate_filters(cond_type_filters)
        end

        pushing_type_filters(else_filters) do
          node.else.accept self
        end
      end

      else_type_filters = @type_filters
      @type_filters = nil

      if needs_type_filters?
        case node.binary
        when :and
          @type_filters = and_type_filters(and_type_filters(cond_type_filters, then_type_filters), else_type_filters)
        # TODO: or type filters
        # when :or
        #   node.type_filters = or_type_filters(node.then.type_filters, node.else.type_filters)
        end
      end

      # If the then branch exists, we can safely assume that tyhe type
      # filters after the if will be those of the condition, negated
      type_filter_stack = @type_filter_stack
      if node.then.no_returns? && cond_type_filters && (type_filter_stack && !type_filter_stack.empty?)
        type_filter_stack[-1] = and_type_filters(type_filter_stack.last, negate_filters(cond_type_filters))
      end

      # If the else branch exits, we can safely assume that the type
      # filters in the condition will still apply after the if
      if (node.else.no_returns? || node.else.returns?) && cond_type_filters && (type_filter_stack && !type_filter_stack.empty?)
        type_filter_stack[-1] = and_type_filters(type_filter_stack.last, cond_type_filters)
      end

      false
    end

    def end_visit(node : If)
      node.bind_to [node.then, node.else]
    end

    def visit(node : While)
      request_type_filters do
        node.cond.accept self
      end

      cond_type_filters = @type_filters
      @type_filters = nil
      @block, old_block = nil, @block

      @while_stack.push node
      pushing_type_filters(cond_type_filters) do
        node.body.accept self
      end

      @while_stack.pop
      @block = old_block

      false
    end

    def end_visit(node : While)
      unless node.has_breaks
        node_cond = node.cond
        if node_cond.is_a?(BoolLiteral) && node_cond.value == true
          node.type = mod.no_return
          return
        end
      end

      node.bind_to mod.nil_var
    end

    def end_visit(node : Break)
      container = @while_stack.last? || (block.try &.break)
      node.raise "Invalid break" unless container

      if container.is_a?(While)
        container.has_breaks = true
      else
        container.bind_to(node.exps.length > 0 ? node.exps[0] : mod.nil_var)
      end
    end

    def end_visit(node : Next)
      if block = @block
        if node.exps.empty?
          block.bind_to @mod.nil_var
        else
          block.bind_to node.exps.first
        end
      elsif @while_stack.empty?
        node.raise "Invalid next"
      end
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
        node.type = @mod.pointer_of(scope.instance_type)
      when :struct_set
        node.bind_to @vars["value"]
      when :struct_get
        visit_struct_get node
      when :union_new
        node.type = @mod.pointer_of(scope.instance_type)
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
      when :math_sqrt_float32
        node.type = mod.float32
      when :math_sqrt_float64
        node.type = mod.float64
      when :float32_pow
        node.type = mod.float32
      when :float64_pow
        node.type = mod.float64
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
              lookup_var node_exp.name
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
        var = lookup_var node_name

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

    def end_visit(node : ExceptionHandler)
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

    def lookup_var(name)
      var = @vars[name] ||= begin
        var = Var.new(name)
        var.context = current_context
        var
      end
      check_closured var
      var
    end

    def check_closured(var)
      context = current_context
      if !var.context.same?(context) && !var.closured && !context.is_a?(Block)
        var.closured = true
        if context = var.context
          (context as ClosureContext).closured_vars << var
        else
          var.raise "Bug: missing closure for var #{var.name}"
        end
      end
    end

    def current_context
      @block_context || @typed_def || @mod
    end

    def lookup_var_or_instance_var(var : Var)
      lookup_var(var.name)
    end

    def lookup_var_or_instance_var(var : InstanceVar)
      scope = @scope as InstanceVarContainer
      scope.lookup_instance_var(var.name)
    end

    def lookup_var_or_instance_var(var)
      raise "Bug: trying to lookup var or instance var but got #{var}"
    end

    def build_var_filter(var)
      filters = [] of TypeFilter
      @type_filter_stack.try &.each do |hash|
        if hash
          filter = hash[var.name]?
          filters.push filter if filter
        end
      end

      return if filters.empty?

      final_filter = filters.length == 1 ? filters.first : AndTypeFilter.new(filters)

      filtered_node = TypeFilteredNode.new(final_filter)
      filtered_node.bind_to var
      filtered_node
    end

    def and_type_filters(filters1, filters2)
      if filters1 && filters2
        new_filters = new_type_filter
        all_keys = (filters1.keys + filters2.keys).uniq!
        all_keys.each do |name|
          filter1 = filters1[name]?
          filter2 = filters2[name]?
          if filter1 && filter2
            new_filters[name] = AndTypeFilter.new([filter1, filter2] of TypeFilter)
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

    def pushing_type_filters(filters = nil)
      type_filter_stack = (@type_filter_stack ||= [nil] of Hash(String, TypeFilter)?)
      type_filter_stack.push(filters)
      yield
      type_filter_stack.pop
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
      @vars.each_key do |var_name|
        pieces = var_name.split '$'
        var_name = pieces.first if pieces.length == 2
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
  end
end
