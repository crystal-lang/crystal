require_relative 'ast'
require_relative 'type_inference/ast'
require_relative 'type_inference/ast_node'
require_relative 'type_inference/call'
require_relative 'type_inference/dispatch'

module Crystal
  def infer_type(node, options = {})
    mod = options[:mod] || Crystal::Program.new
    if node
      if options[:stats]
        infer_type_with_stats node, mod, options
      elsif options[:prof]
        infer_type_with_prof node, mod
      else
        node.accept TypeVisitor.new(mod)
        fix_empty_types node, mod
        mod.unify node if Crystal::UNIFY
      end
    end
    mod
  end

  def infer_type_with_stats(node, mod, options)
    options[:total_bm] += options[:bm].report('type inference:') { node.accept TypeVisitor.new(mod) }
    options[:total_bm] += options[:bm].report('fix empty types') { fix_empty_types node, mod }
    options[:total_bm] += options[:bm].report('unification:') { mod.unify node if Crystal::UNIFY }
  end

  def infer_type_with_prof(node, mod)
    Profiler.profile_to('type_inference.html') { node.accept TypeVisitor.new(mod) }
    Profiler.profile_to('fix_empty_types.html') { fix_empty_types node, mod }
    Profiler.profile_to('unification.html') { mod.unify node if Crystal::UNIFY }
  end

  class TypeFilter < ASTNode
    def initialize(types)
      @types = types
    end

    def bind_to(node)
      @node = node
      node.add_observer self
      update(node)
    end

    def update(from)
      self.type = from.type.filter_by(@types[0]) if from.type
    end

    def real_type
      @node.real_type
    end
  end

  class TypeVisitor < Visitor
    attr_accessor :mod
    attr_accessor :paths
    attr_accessor :call
    attr_accessor :block
    @@regexps = {}
    @@counter = 0

    def initialize(mod, vars = {}, scope = nil, parent = nil, call = nil)
      @mod = mod
      @vars = vars
      @vars_nest = {}
      @scope = scope
      @parent = parent
      @call = call
      @types = [mod]
      @nest_count = 0
      @while_stack = []
      @type_filter_stack = []
    end

    def visit_nil_literal(node)
      node.type = mod.nil
    end

    def visit_bool_literal(node)
      node.type = mod.bool
    end

    def visit_char_literal(node)
      node.type = mod.char
    end

    def visit_int_literal(node)
      node.type = mod.int
    end

    def visit_long_literal(node)
      node.type = mod.long
    end

    def visit_float_literal(node)
      node.type = mod.float
    end

    def visit_double_literal(node)
      node.type = mod.double
    end

    def visit_string_literal(node)
      node.type = mod.string
    end

    def visit_symbol_literal(node)
      node.type = mod.symbol
      mod.symbols << node.value
    end

    def visit_range_literal(node)
      node.expanded = Call.new(Ident.new(['Range'], true), 'new', [node.from, node.to, BoolLiteral.new(node.exclusive)])
      node.expanded.accept self
      node.type = node.expanded.type
    end

    def visit_regexp_literal(node)
      name = @@regexps[node.value]
      name = @@regexps[node.value] = "Regexp#{@@regexps.length}" unless name

      unless mod.types[name]
        value = Call.new(Ident.new(['Regexp'], true), 'new', [StringLiteral.new(node.value)])
        value.accept self
        mod.types[name] = Const.new name, value, mod
      end

      node.expanded = Ident.new([name], true)
      node.expanded.accept self

      node.type = node.expanded.type
    end

    def visit_class_method(node)
      node.type = @scope.metaclass
    end

    def visit_def(node)
      if node.receiver
        # TODO: hack
        if node.receiver.is_a?(Var) && node.receiver.name == 'self'
          target_type = current_type.metaclass
        else
          target_type = lookup_ident_type(node.receiver).metaclass
        end
      else
        target_type = current_type
      end
      node.args.each do |arg|
        if arg.type_restriction
          if arg.type_restriction == :self
            arg.type = SelfType
          else
            if target_type.generic &&
                arg.type_restriction.names.length == 1 &&
                type_var = target_type.type_vars[arg.type_restriction.names.first]
              arg.type = TypeVarType.new(type_var.name)
            else
              arg.type = lookup_ident_type(arg.type_restriction)
            end
          end
        end
      end

      target_type.add_def node
      false
    end

    def visit_macro(node)
      if node.receiver
        # TODO: hack
        if node.receiver.is_a?(Var) && node.receiver.name == 'self'
          target_type = current_type.metaclass
        else
          target_type = lookup_ident_type(node.receiver).metaclass
        end
      else
        target_type = current_type
      end
      target_type.add_def node
      false
    end

    def visit_class_def(node)
      parent = if node.superclass
                 lookup_ident_type node.superclass
               else
                 mod.object
               end

      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is not a class" unless type.is_a?(ClassType)
        if node.superclass && type.superclass != parent
          node.raise "superclass mismatch for class #{type.name} (#{parent.name} for #{type.superclass.name})"
        end
      else
        type = ObjectType.new node.name, parent, current_type
        type.type_vars = Hash[node.type_vars.map { |type_var| [type_var, Var.new(type_var)] }] if node.type_vars
        current_type.types[node.name] = type
      end

      @types.push type

      true
    end

    def end_visit_class_def(node)
      @types.pop
    end

    def visit_module_def(node)
      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is not a module" unless type.class == ModuleType
      else
        current_type.types[node.name] = type = ModuleType.new node.name, current_type
      end

      @types.push type

      true
    end

    def end_visit_module_def(node)
      @types.pop
    end

    def end_visit_include(node)
      if node.name.type.instance_type.class != ModuleType
        node.name.raise "#{node.name} is not a module"
      end

      current_type.include node.name.type.instance_type
    end

    def visit_lib_def(node)
      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
      else
        current_type.types[node.name] = type = LibType.new node.name, node.libname, current_type
      end
      @types.push type
    end

    def end_visit_lib_def(node)
      @types.pop
    end

    def end_visit_fun_def(node)
      args = node.args.map do |arg|
        fun_arg = Arg.new(arg.name)
        fun_arg.location = arg.location
        fun_arg.type = maybe_ptr_type(arg.type.type.instance_type, arg.ptr)
        fun_arg.out = arg.out
        fun_arg
      end
      return_type = maybe_ptr_type(node.return_type ? node.return_type.type.instance_type : mod.nil, node.ptr)
      current_type.fun node.name, node.real_name, args, return_type, node.varargs
    end

    def end_visit_type_def(node)
      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is already defined"
      else
        typed_def_type = maybe_ptr_type(node.type.type.instance_type, node.ptr)

        current_type.types[node.name] = TypeDefType.new node.name, typed_def_type, current_type
      end
    end

    def end_visit_struct_def(node)
      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is already defined"
      else
        current_type.types[node.name] = StructType.new(node.name, node.fields.map { |field| Var.new(field.name, field.type.type.instance_type) }, current_type)
      end
    end

    def maybe_ptr_type(type, ptr)
      ptr.times do
        ptr_type = mod.pointer.clone
        ptr_type.var.type = type
        type = ptr_type
      end
      type
    end

    def visit_struct_alloc(node)
      node.type = node.type
    end

    def visit_struct_set(node)
      struct_var = @scope.vars[node.name]

      node.bind_to @vars['value']
    end

    def visit_struct_get(node)
      struct_var = @scope.vars[node.name]
      node.bind_to struct_var
    end

    def visit_var(node)
      var = lookup_var node.name
      filter = build_var_filter var
      node.bind_to(filter || var)
    end

    def build_var_filter(var)
      types = @type_filter_stack.map { |hash| hash[var.name] }.compact
      return if types.empty?

      filter = TypeFilter.new(types)
      filter.bind_to var
      filter
    end

    def visit_global(node)
      var = mod.global_vars[node.name] or node.raise "uninitialized global #{node}"
      node.bind_to var
    end

    def visit_instance_var(node)
      lookup_instance_var node
    end

    def lookup_instance_var(node, mark_as_nilable = true)
      if @scope.is_a?(Crystal::Program)
        node.raise "can't use instance variables at the top level"
      elsif @scope.is_a?(PrimitiveType)
        node.raise "can't use instance variables inside #{@scope.name}"
      end

      new_instance_var = mark_as_nilable && !@scope.has_instance_var?(node.name)

      var = @scope.lookup_instance_var node.name
      var.bind_to mod.nil_var if mark_as_nilable && new_instance_var
      node.bind_to var
      var
    end

    def visit_assign(node)
      type_assign(node.target, node.value, node)
      node.type_filters = node.value.type_filters
      false
    end

    def visit_multi_assign(node)
      node.targets.each_with_index do |target, i|
        type_assign(target, node.values[i])
      end
      node.bind_to mod.nil_var
      false
    end

    def type_assign(target, value, node = nil)
      value.accept self

      case target
      when Var
        var = lookup_var target.name
        target.bind_to var

        if node
          node.bind_to value
          var.bind_to node
        else
          var.bind_to value
        end

      when InstanceVar
        var = lookup_instance_var target, (@nest_count > 0)

        if node
          node.bind_to value
          var.bind_to node
        else
          var.bind_to value
        end
      when Ident
        type = current_type.types[target.names.first]
        if type
          target.raise "already initialized constant #{target}"
        end

        target.bind_to value

        current_type.types[target.names.first] = Const.new(target.names.first, value, current_type)
      when Global
        var = mod.global_vars[target.name] ||= Var.new(target.name)

        target.bind_to var

        if node
          node.bind_to value
          var.bind_to node
        end
      end
    end

    def end_visit_expressions(node)
      if node.last
        node.bind_to node.last
      else
        node.type = mod.nil
      end
    end

    def visit_while(node)
      node.cond.accept self

      @nest_count += 1
      @while_stack.push node
      node.body.accept self if node.body
      @while_stack.pop
      @nest_count -= 1

      false
    end

    def end_visit_while(node)
      node.bind_to mod.nil_var
    end

    def end_visit_break(node)
      container = @while_stack.last || (block && block.break)
      node.raise "Invalid break" unless container

      if node.exps.length > 0
        container.bind_to node.exps[0]
      else
        container.bind_to mod.nil_var
      end
    end

    def visit_if(node)
      node.cond.accept self

      @nest_count += 1

      if node.then
        @type_filter_stack.push node.cond.type_filters if node.cond.type_filters

        node.then.accept self

        @type_filter_stack.pop if node.cond.type_filters
      end

      if node.else
        node.else.accept self
      end
      @nest_count -= 1

      false
    end

    def end_visit_if(node)
      node.bind_to node.then if node.then
      node.bind_to node.else if node.else
      unless node.then && node.else
        node.bind_to mod.nil_var
      end
    end

    def visit_ident(node)
      type = lookup_ident_type(node)
      if type.is_a?(Const)
        node.target_const = type
        node.bind_to(type.value)
      else
        node.type = type.metaclass
      end
    end

    def lookup_ident_type(node)
      if node.global
        target_type = mod.lookup_type node.names
      else
        target_type = (@scope || @types.last).lookup_type node.names
      end

      unless target_type
        node.raise("uninitialized constant #{node}")
      end

      target_type
    end

    def visit_allocate(node)
      allocate_type = @scope.instance_type
      type = lookup_object_type(allocate_type.name)
      node.type = type ? type : allocate_type
    end

    def visit_array_literal(node)
      if node.elements.empty?
        exps = Call.new(Ident.new(['Array'], true), 'new')
      else
        ary_name = temp_name()

        length = node.elements.length
        capacity = length < 16 ? 16 : 2 ** Math.log(length, 2).ceil

        ary_new = Call.new(Ident.new(['Array'], true), 'new', [IntLiteral.new(capacity)])
        ary_assign = Assign.new(Var.new(ary_name), ary_new)
        ary_assign_length = Call.new(Var.new(ary_name), 'length=', [IntLiteral.new(length)])

        exps = [ary_assign, ary_assign_length]
        node.elements.each_with_index do |elem, i|
          get_buffer = Call.new(Var.new(ary_name), 'buffer')
          exps << Call.new(get_buffer, :[]=, [IntLiteral.new(i), elem])
        end
        exps << Var.new(ary_name)

        exps = Expressions.new exps
      end

      exps.accept self
      node.expanded = exps
      node.bind_to exps

      false
    end

    def visit_hash_literal(node)
      if node.key_values.empty?
        exps = Call.new(Ident.new(['Hash'], true), 'new')
      else
        hash_name = temp_name()

        hash_new = Call.new(Ident.new(['Hash'], true), 'new')
        hash_assign = Assign.new(Var.new(hash_name), hash_new)

        exps = [hash_assign]
        node.key_values.each_slice(2) do |key, value|
          exps << Call.new(Var.new(hash_name), :[]=, [key, value])
        end
        exps << Var.new(hash_name)
        exps = Expressions.new exps
      end

      exps.accept self
      node.expanded = exps
      node.bind_to exps

      false
    end

    def lookup_object_type(name)
      if @scope.is_a?(ObjectType) && @scope.name == name
        if @call && @call[1].maybe_recursive
          @scope
        else
          nil
        end
      elsif @parent
        @parent.lookup_object_type(name)
      end
    end

    def lookup_def_instance(scope, untyped_def, arg_types)
      if @call && @call[0..2] == [scope, untyped_def, arg_types]
        @call[3]
      elsif @parent
        @parent.lookup_def_instance(scope, untyped_def, arg_types)
      end
    end

    def end_visit_yield(node)
      block = @call[4].block or node.raise "no block given"

      block.args.each_with_index do |arg, i|
        arg.bind_to node.exps[i]
      end
      node.bind_to block.body if block.body
    end

    def visit_block(node)
      if node.body
        block_vars = @vars.clone
        node.args.each do |arg|
          block_vars[arg.name] = arg
        end

        block_visitor = TypeVisitor.new(mod, block_vars, @scope, @parent, @call)
        block_visitor.block = node
        node.body.accept block_visitor
      end
      false
    end

    def visit_and(node)
      temp_var = Var.new(temp_name())
      node.expanded = If.new(Assign.new(temp_var, node.left), node.right, temp_var)
      node.expanded.binary = :and
      node.expanded.accept self
      node.bind_to node.expanded
      node.type_filters = node.left.type_filters

      false
    end

    def visit_or(node)
      temp_var = Var.new(temp_name())
      node.expanded = If.new(Assign.new(temp_var, node.left), temp_var, node.right)
      node.expanded.binary = :or
      node.expanded.accept self
      node.bind_to node.expanded

      false
    end

    def end_visit_simple_or(node)
      node.bind_to node.left
      node.bind_to node.right

      false
    end

    def visit_call(node)
      node.mod = mod
      node.scope = @scope || (@types.last ? @types.last.metaclass : nil)
      node.parent_visitor = self

      if expand_macro(node)
        return false
      end

      node.args.each_with_index do |arg, index|
        arg.add_observer node, :update_input
      end
      node.obj.add_observer node, :update_input if node.obj
      node.recalculate unless node.obj || node.args.any?

      node.obj.accept self if node.obj
      node.args.each { |arg| arg.accept self }

      node.bubbling_exception do
        node.block.accept self if node.block
      end

      false
    end

    def end_visit_new_generic_class(node)
      instance_type = node.name.type.instance_type
      if instance_type.type_vars.length != node.type_vars.length
        node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{instance_type.type_vars.length})"
      end
      generic_type = mod.lookup_generic_type instance_type, node.type_vars.map { |var| var.type.instance_type }
      node.type = generic_type.metaclass
      false
    end

    def expand_macro(node)
      return false if node.obj || node.name == 'super'

      owner, self_type, untyped_def_and_error_matches = node.compute_owner_self_type_and_untyped_def
      untyped_def, error_matches = untyped_def_and_error_matches
      return false unless untyped_def.is_a?(Macro)

      @@macro_llvm_mod ||= LLVM::Module.new "macros"
      @@macro_engine ||= LLVM::JITCompiler.new @@macro_llvm_mod

      macro_name = "#macro_#{untyped_def.object_id}"

      typed_def = Def.new(macro_name, untyped_def.args.map(&:clone), untyped_def.body ? untyped_def.body.clone : nil)
      macro_call = Call.new(nil, macro_name, node.args.map(&:to_crystal_node))
      macro_nodes = Expressions.new [typed_def, macro_call]

      Crystal.infer_type macro_nodes, mod: mod

      if macro_nodes.type != mod.string
        node.raise "macro return value must be a String, not #{macro_nodes.type}"
      end

      macro_arg_types = macro_call.args.map(&:type)
      fun = untyped_def.lookup_instance(macro_arg_types)
      unless fun
        Crystal.build macro_nodes, mod, nil, false, @@macro_llvm_mod
        fun = @@macro_llvm_mod.functions[macro_call.target_def.mangled_name(nil)]
        untyped_def.add_instance fun, macro_arg_types
      end

      mod.load_libs

      macro_args = node.args.map &:to_crystal_binary
      macro_value = @@macro_engine.run_function fun, *macro_args

      generated_source = macro_value.to_string

      begin
        parser = Parser.new(generated_source, [Set.new(@vars.keys)])
        generated_nodes = parser.parse
      rescue Crystal::SyntaxException => ex
        node.raise "macro didn't expand to a valid program, it expanded to:\n\n#{'=' * 80}\n#{'-' * 80}\n#{number_lines generated_source}\n#{'-' * 80}\n#{ex.to_s(generated_source)}#{'=' * 80}"
      end

      begin
        generated_nodes.accept self
      rescue Crystal::Exception => ex
        node.raise "macro didn't expand to a valid program, it expanded to:\n\n#{'=' * 80}\n#{'-' * 80}\n#{number_lines generated_source}\n#{'-' * 80}\n#{ex.to_s(generated_source)}#{'=' * 80}"
      end

      node.target_macro = generated_nodes
      node.type = generated_nodes.type

      true
    end

    def number_lines(source)
      source.lines.each_with_index.map { |line, i| "#{'%3d' % (i + 1)}. #{line.chomp}" }.join "\n"
    end

    def visit_return(node)
      if node.exps.empty?
        node.exps << NilLiteral.new
      end
      true
    end

    def end_visit_return(node)
      node.exps.each do |exp|
        @call[3].bind_to exp
      end
    end

    def end_visit_is_a(node)
      node.type = mod.bool
      if node.obj.is_a?(Var)
        node.type_filters = {node.obj.name => node.const.type.instance_type}
      end
    end

    def visit_pointer_of(node)
      ptr = mod.pointer.clone
      ptr.var = if node.var.is_a?(Var)
                  var = lookup_var node.var.name
                  node.var.bind_to var
                  var
                else
                  lookup_instance_var node.var
                end
      node.type = ptr
      false
    end

    def visit_pointer_malloc(node)
      node.type = mod.pointer.clone
    end

    def visit_pointer_realloc(node)
      node.type = @scope
    end

    def visit_pointer_get_value(node)
      node.bind_to @scope.var
    end

    def visit_pointer_set_value(node)
      @scope.var.bind_to @vars['value']
      node.bind_to @vars['value']
    end

    def visit_pointer_add(node)
      node.type = @scope
    end

    def visit_pointer_cast(node)
      type = @vars['type'].type.instance_type
      if type.is_a?(ObjectType)
        node.type = type
      else
        pointer_type = mod.pointer.clone
        pointer_type.var.type = type
        node.type = pointer_type
      end
    end

    def visit_require(node)
      node.expanded = mod.require(node.string.value, node.filename)
      false
    end

    def visit_case(node)
      temp_var = Var.new(temp_name())
      assign = Assign.new(temp_var, node.cond)

      used_assign = false

      a_if = nil
      final_if = nil
      node.whens.each do |wh|
        final_comp = nil
        wh.conds.each do |cond|
          if used_assign
            right_side = temp_var
          else
            right_side = assign
            used_assign = true
          end

          comp = Call.new(cond, :'===', [right_side])
          if final_comp
            final_comp = SimpleOr.new(final_comp, comp)
          else
            final_comp = comp
          end
        end
        wh_if = If.new(final_comp, wh.body)
        if a_if
          a_if.else = wh_if
        else
          final_if = wh_if
        end
        a_if = wh_if
      end
      a_if.else = node.else if node.else
      final_if.accept self
      node.bind_to final_if
      node.expanded = final_if
      false
    end

    def lookup_var(name)
      var = @vars[name]
      if var
        var_nest_count = @vars_nest[name]
        if var_nest_count && var_nest_count > @nest_count
          var.bind_to mod.nil_var
          @vars_nest.delete name
        end
      else
        var = Var.new name
        @vars[name] = var
        @vars_nest[name] = @nest_count
      end
      var
    end

    def lookup_var_or_instance_var(var)
      if var.is_a?(Var)
        lookup_var(var.name)
      else
        @scope.lookup_instance_var(var.name)
      end
    end

    def current_type
      @types.last
    end

    def temp_name
      @@counter += 1
      "#temp_#{@@counter}"
    end
  end
end
