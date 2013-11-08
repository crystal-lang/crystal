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
    getter mod
    getter! scope
    getter! typed_def
    getter! untyped_def
    property block

    def initialize(@mod, @vars = {} of String => Var, @scope = nil, @parent = nil, @call = nil, @owner = nil, @untyped_def = nil, @typed_def = nil, @arg_types = nil, @free_vars = nil, @yield_vars = nil, @type_filter_stack = [new_type_filter])
      @types = [@mod] of Type
      @while_stack = [] of While
      typed_def = @typed_def
      typed_def.vars = @vars if typed_def
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
                  when :i8
                    mod.int8
                  when :i16
                    mod.int16
                  when :i32
                    mod.int32
                  when :i64
                    mod.int64
                  when :u8
                    mod.uint8
                  when :u16
                    mod.uint16
                  when :u32
                    mod.uint32
                  when :u64
                    mod.uint64
                  when :f32
                    mod.float32
                  when :f64
                    mod.float64
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
      var = @vars[node.name]
      filter = build_var_filter var
      node.bind_to(filter || var)
      node.type_filters = and_type_filters(not_nil_filter(node), var.type_filters)
    end

    def visit(node : DeclareVar)
      node.type = lookup_ident_type(node.declared_type).instance_type

      var = Var.new(node.name)
      var.bind_to node

      node.var = var

      @vars[node.name] = var

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
      node.type_filters = not_nil_filter(node)
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
        elsif scope.is_a?(PrimitiveType) || scope.metaclass?
          node.raise "can't use instance variables inside #{@scope}"
        end

        if scope.is_a?(InstanceVarContainer)
          var = scope.lookup_instance_var node.name
          unless scope.has_instance_var_in_initialize?(node.name)
            var.bind_to mod.nil_var
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
      if scope.is_a?(Metaclass)
        owner = scope.class_var_owner
      else
        owner = scope
      end
      class_var_owner = owner

      assert_type class_var_owner, ClassVarContainer
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

      var = lookup_var target.name
      target.bind_to var

      node.bind_to value
      var.bind_to node

      var.type_filters = node.type_filters = and_type_filters(not_nil_filter(target), value.type_filters) if node
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

    def type_assign(target : Ident, value, node)
      type = current_type.types[target.names.first]?
      if type
        target.raise "already initialized constant #{target}"
      end

      target.bind_to value

      current_type.types[target.names.first] = Const.new(@mod, current_type, target.names.first, value, @types.clone, @scope)

      node.type = @mod.nil
    end

    def type_assign(target : Global, value, node)
      value.accept self

      var = mod.global_vars[target.name]?
      unless var
        var = Var.new(target.name)
        if @typed_def
          var.bind_to mod.nil_var
        end
        mod.global_vars[target.name] = var
      end

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
          target_type = lookup_ident_type(receiver).metaclass
        end
      else
        target_type = current_type
      end

      target_type.add_def node

      node.set_type(@mod.nil)

      false
    end

    def visit(node : Macro)
      if receiver = node.receiver
        # TODO: hack
        if receiver.is_a?(Var) && receiver.name == "self"
          target_type = current_type.metaclass
        else
          target_type = lookup_ident_type(receiver).metaclass
        end
      else
        target_type = current_type
      end

      target_type.add_macro node

      node.set_type(@mod.nil)

      false
    end

    def end_visit(node : TypeMerge)
      node.bind_to node.expressions
    end

    def end_visit(node : Yield)
      call = @call.not_nil!
      block = call.block || node.raise("no block given")

      if (yield_vars = @yield_vars) && !node.scope
        yield_vars.each_with_index do |var, i|
          exp = node.exps[i]?
          if exp
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
          block.accept call.parent_visitor.not_nil!
        end
      end

      node.bind_to block.body
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
        block_vars[arg.name] = arg
      end

      block_visitor = TypeVisitor.new(mod, block_vars, (node.scope || @scope), @parent, @call, @owner, @untyped_def, @typed_def, @arg_types, @free_vars, @yield_vars) #, @type_filter_stack)
      block_visitor.block = node
      node.body.accept block_visitor
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
      # node.block_arg.add_observer node, :update_input if node.block_arg
      node.recalculate

      obj.accept self if obj
      node.args.each &.accept(self)
      # node.block_arg.accept self if node.block_arg

      false
    end

    def prepare_call(node)
      node.mod = mod

      # if node.global
      #   node.scope = @mod
      # else
        node.scope = @scope || @types.last.metaclass
      # end
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

    def end_visit(node : NewGenericClass)
      return if node.type?

      instance_type = node.name.type.instance_type
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.type_vars.length != node.type_vars.length
        node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{instance_type.type_vars.length})"
      end
      node.instance_type = instance_type
      node.type_vars.each &.add_observer(node)
      node.update
      false
    end

    def end_visit(node : IsA)
      node.type = mod.bool
      obj = node.obj
      if obj.is_a?(Var)
        node.type_filters = new_type_filter(obj, SimpleTypeFilter.new(node.const.type.instance_type))
      end
    end

    def visit(node : ClassDef)
      superclass = if node_superclass = node.superclass
                     lookup_ident_type node_superclass
                   else
                     mod.reference
                   end

      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_ident_type node.name
      end

      type = scope.types[name]?
      if type
        node.raise "#{name} is not a class, it's a #{type.type_desc}" unless type.is_a?(ClassType)
        if node.superclass && type.superclass != superclass
          node.raise "superclass mismatch for class #{type} (#{superclass} for #{type.superclass})"
        end
      else
        unless superclass.is_a?(NonGenericClassType)
          node_superclass.not_nil!.raise "#{superclass} is not a class, it's a #{superclass.type_desc}"
        end

        needs_force_add_subclass = true
        if type_vars = node.type_vars
          type = GenericClassType.new @mod, scope, name, superclass, type_vars, false
        else
          type = NonGenericClassType.new @mod, scope, name, superclass, false
        end
        type.abstract = node.abstract
        scope.types[name] = type
      end

      @types.push type
      node.body.accept self
      @types.pop

      if needs_force_add_subclass
        raise "Bug" unless type.is_a?(InheritableClass)
        type.force_add_subclass
      end

      node.type = @mod.nil

      false
    end

    def visit(node : ModuleDef)
      if node.name.names.length == 1 && !node.name.global
        scope = current_type
        name = node.name.names.first
      else
        name = node.name.names.pop
        scope = lookup_ident_type node.name
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

    def visit(node : Include)
      node_name = node.name

      if node_name.is_a?(NewGenericClass)
        type = lookup_ident_type(node_name.name)
      else
        type = lookup_ident_type(node_name)
      end

      unless type.module?
        node.name.raise "#{node.name} is not a module, it's a #{type.type_desc}"
      end

      current_type = current_type()

      if node_name.is_a?(NewGenericClass)
        unless type.is_a?(GenericModuleType)
          node_name.raise "#{type} is not a generic module"
        end

        if type.type_vars.length != node_name.type_vars.length
          node_name.raise "wrong number of type vars for #{type} (#{node_name.type_vars.length} for #{type.type_vars.length})"
        end

        type_vars_types = node_name.type_vars.map do |type_var|
          if type_var.is_a?(SelfType)
            current_type
          else
            unless type_var.is_a?(Ident)
              type_var.raise "only simple names are supported for now, not #{type_var}"
            end

            type_var_name = type_var.names[0]
            if current_type.is_a?(GenericType) && current_type.type_vars.includes?(type_var_name)
              type_var_name
            else
              lookup_ident_type(type_var)
            end
          end
        end

        mapping = Hash.zip(type.type_vars, type_vars_types)
        current_type.include IncludedGenericModule.new(@mod, type, current_type, mapping)
      else
        if type.is_a?(GenericModuleType)
          if current_type.is_a?(GenericType)
            current_type_type_vars_length = current_type.type_vars.length
            if current_type_type_vars_length != type.type_vars.length
              node_name.raise "#{type} wrong number of type vars for #{type} (#{current_type_type_vars_length} for #{current_type.type_vars.length})"
            end

            mapping = Hash.zip(type.type_vars, current_type.type_vars)
            current_type.include IncludedGenericModule.new(@mod, type, current_type, mapping)
          else
            node_name.raise "#{type} is a generic module"
          end
        else
          current_type.include type
        end
      end

      node.type = @mod.nil

      false
    end

    def visit(node : LibDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
      else
        type = LibType.new @mod, current_type, node.name, node.libname
        current_type.types[node.name] = type
      end
      @types.push type

      node.type = @mod.nil
    end

    def end_visit(node : LibDef)
      @types.pop
    end

    def visit(node : FunDef)
      if node.body && !current_type.is_a?(Program)
        node.raise "can only declare fun at lib or global scope"
      end

      args = node.args.map do |arg|
        restriction = arg.type_restriction.not_nil!
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
        vars = {} of String => Var
        args.each do |arg|
          var = Var.new(arg.name, arg.type)
          var.bind_to var
          vars[arg.name] = var
        end
        external.set_type(nil)

        visitor = TypeVisitor.new(@mod, vars, @mod, self, nil, nil, external, external, args.map(&.type))
        begin
          node_body.accept visitor
        rescue ex
          node.raise ex.message
        end

        inferred_return_type = @mod.type_merge([node_body.type, external.type?])

        if return_type && return_type != @mod.void && inferred_return_type != return_type
          node.raise "expected fun to return #{return_type} but it returned #{inferred_return_type}"
        end

        external.set_type(return_type)
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
      visit_struct_or_union_def node, CStructType
    end

    def end_visit(node : UnionDef)
      visit_struct_or_union_def node, CUnionType
    end

    def visit_struct_or_union_def(node, klass)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        fields = node.fields.map do |field|
          field_type = check_primitive_like field.type_restriction.not_nil!
          Var.new(field.name, field_type)
        end
        current_type.types[node.name] = klass.new @mod, current_type, node.name, fields
      end
    end

    def visit(node : EnumDef)
      type = current_type.types[node.name]?
      if type
        node.raise "#{node.name} is already defined"
      else
        counter = 0
        node.constants.each do |constant|
          if default_value = constant.default_value
            assert_type default_value, NumberLiteral
            counter = default_value.value.to_i
          else
            constant.default_value = NumberLiteral.new(counter, :i32)
          end
          counter += 1
        end
        current_type.types[node.name] = CEnumType.new(@mod, current_type, node.name, node.constants)
      end
    end

    def visit(node : ExternalVar)
      node.type_spec.accept self

      var_type = check_primitive_like node.type_spec

      type = current_type
      assert_type type, LibType

      type.add_var node.name, var_type

      false
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
      # elsif type.type_def_type? && type.typedef.fun_type?
      #   type = type.typedef
      end

      type
    end

    def visit(node : Ident)
      type = lookup_ident_type(node)
      if type.is_a?(Const)
        unless type.value.type?
          old_types, old_scope, old_vars = @types, @scope, @vars
          @types, @scope, @vars = type.scope_types, type.scope, ({} of String => Var)
          type.value.accept self
          @types, @scope, @vars = old_types, old_scope, old_vars
        end
        node.target_const = type
        node.bind_to type.value
      else
        node.type = type.metaclass
      end
    end

    def visit(node : If)
      node.cond.accept self
      node_cond_type_filters = node.cond.type_filters

      if node.then.nop?
        node.then.accept self
      else
        then_filters = node_cond_type_filters || new_type_filter

        pushing_type_filters(then_filters) do
          node.then.accept self
        end
      end

      if node.else.nop?
        node.else.accept self
      else
        if (filters = node_cond_type_filters) && !node.cond.is_a?(If)
          else_filters = negate_filters(filters)
        else
          else_filters = new_type_filter
        end

        pushing_type_filters(else_filters) do
          node.else.accept self
        end
      end

      case node.binary
      when :and
        node.type_filters = and_type_filters(and_type_filters(node_cond_type_filters, node.then.type_filters), node.else.type_filters)
      when :or
        node.type_filters = or_type_filters(node.then.type_filters, node.else.type_filters)
      end

      # If the then branch exists, we can safely assume that tyhe type
      # filters after the if will be those of the condition, negated
      if node.then.no_returns? && node_cond_type_filters && !@type_filter_stack.empty?
        @type_filter_stack[-1] = and_type_filters(@type_filter_stack.last, negate_filters(node_cond_type_filters))
      end

      # If the else branch exits, we can safely assume that the type
      # filters in the condition will still apply after the if
      if (node.else.no_returns? || node.else.returns?) && node_cond_type_filters && !@type_filter_stack.empty?
        @type_filter_stack[-1] = and_type_filters(@type_filter_stack.last, node_cond_type_filters)
      end

      false
    end

    def end_visit(node : If)
      node.bind_to [node.then, node.else]
    end

    def visit(node : While)
      node.cond.accept self

      @while_stack.push node
      if type_filters = node.cond.type_filters
        pushing_type_filters(type_filters) do
          node.body.accept self
        end
      else
        node.body.accept self
      end

      @while_stack.pop

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
      when :pointer_cast
        visit_pointer_cast node
      when :byte_size
        node.type = @mod.uint64
      when :argc
        node.type = @mod.int32
      when :argv
        node.type = @mod.pointer_of(@mod.pointer_of(@mod.char))
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
        node.type = mod.char_pointer
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

      if instance_type.is_a?(ClassType) && instance_type.abstract
        node.raise "can't instantiate abstract class #{instance_type}"
      end

      # instance_type.allocated = true
      node.type = instance_type
    end

    def visit_pointer_malloc(node)
      if scope.instance_type.is_a?(GenericClassType)
        node.raise "can't malloc pointer without type, use Pointer(Type).malloc(size)"
      end

      node.type = scope.instance_type
    end

    def visit_pointer_set(node)
      scope = @scope
      assert_type scope, PointerInstanceType

      value = @vars["value"]

      scope.var.bind_to value
      node.bind_to value
    end

    def visit_pointer_get(node)
      scope = @scope
      assert_type scope, PointerInstanceType

      node.bind_to scope.var
    end

    def visit_pointer_new(node)
      if scope.instance_type.is_a?(GenericClassType)
        node.raise "can't create pointer without type, use Pointer(Type).new(address)"
      end

      node.type = scope.instance_type
    end

    def visit_pointer_cast(node)
      type = @vars["type"].type.instance_type
      if type.class?
        node.type = type
      else
        node.type = mod.pointer_of(type)
      end
    end

    def visit_struct_get(node)
      untyped_def = @untyped_def.not_nil!
      scope = @scope
      assert_type scope, CStructType
      node.bind_to scope.vars[untyped_def.name]
    end

    def visit_union_get(node)
      untyped_def = @untyped_def.not_nil!
      scope = @scope
      assert_type scope, CUnionType
      node.bind_to scope.vars[untyped_def.name]
    end

    def visit(node : PointerOf)
      node.mod = @mod
      node_var = node.var
      var = case node_var
            when Var
              lookup_var node_var.name
            when InstanceVar
              lookup_instance_var node_var
            else
              raise "Bug: #{node}.ptr"
            end
      node.bind_to var
    end

    def end_visit(node : TypeMerge)
      node.bind_to node.expressions
    end

    def lookup_var(name)
      @vars[name] ||= Var.new(name)
    end

    def lookup_var_or_instance_var(var : Var)
      lookup_var(var.name)
    end

    def lookup_var_or_instance_var(var : InstanceVar)
      scope = @scope
      assert_type scope, InstanceVarContainer

      scope.lookup_instance_var(var.name)
    end

    def lookup_var_or_instance_var(var)
      raise "Bug: trying to lookup var or instance var but got #{var}"
    end

    def lookup_ident_type(node : Ident)
      free_vars = @free_vars
      if free_vars && !node.global && (type = free_vars[node.names.first]?)
        if node.names.length == 1
          target_type = type.not_nil!
        else
          target_type = type.not_nil!.lookup_type(node.names[1 .. -1])
        end
      elsif node.global
        target_type = mod.lookup_type node.names
      else
        target_type = (@scope || @types.last).lookup_type node.names
      end

      unless target_type
        node.raise "uninitialized constant #{node}"
      end

      target_type
    end

    def lookup_ident_type(node)
      raise "lookup_ident_type not implemented for #{node}"
    end

    def build_var_filter(var)
      filters = [] of TypeFilter
      @type_filter_stack.each do |hash|
        filter = hash[var.name]?
        filters.push filter if filter
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

    def pushing_type_filters(filters)
      @type_filter_stack.push(filters)
      yield
      @type_filter_stack.pop
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

    def current_type
      @types.last
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

    def visit(node : RegexpLiteral)
      raise "Bug: RegexpLiteral node '#{node}' (#{node.location}) should have been eliminated in normalize"
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
