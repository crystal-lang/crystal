require_relative "program"
require_relative 'ast'
require_relative 'type_inference/ast'
require_relative 'type_inference/ast_node'
require_relative 'type_inference/call'
require_relative 'type_inference/match'

module Crystal
  class Program
    def infer_type(node, options = {})
      if node
        if options[:stats]
          infer_type_with_stats node, options
        elsif options[:prof]
          infer_type_with_prof node
        else
          node.accept TypeVisitor.new(self)
          fix_empty_types node, self
        end
      end
    end

    def infer_type_with_stats(node, options)
      options[:total_bm] += options[:bm].report('type inference:') { node.accept TypeVisitor.new(self) }
      options[:total_bm] += options[:bm].report('fix empty types') { fix_empty_types node, self }
    end

    def infer_type_with_prof(node)
      Profiler.profile_to('type_inference.html') { node.accept TypeVisitor.new(self) }
      Profiler.profile_to('fix_empty_types.html') { fix_empty_types node, self }
    end
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
    attr_accessor :owner
    attr_accessor :untyped_def
    attr_accessor :typed_def
    attr_accessor :arg_types
    attr_accessor :block
    @@regexps = {}
    @@counter = 0

    def initialize(mod, vars = {}, scope = nil, parent = nil, call = nil, owner = nil, untyped_def = nil, typed_def = nil, arg_types = nil, free_vars = nil, yield_vars = nil)
      @mod = mod
      @vars = vars
      @scope = scope
      @parent = parent
      @call = call
      @owner = owner
      @untyped_def = untyped_def
      @typed_def = typed_def
      @arg_types = arg_types
      @free_vars = free_vars
      @yield_vars = yield_vars
      @types = [mod]
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

    def end_visit_range_literal(node)
      return if node.expanded

      new_generic = NewGenericClass.new(Ident.new(['Range'], true), [Ident.new(["Nil"], true), Ident.new(["Nil"], true)])

      node.mod = mod
      node.new_generic_class = new_generic
      node.set_type(mod.range_of(node.from.type, node.to.type))

      node.expanded = Call.new(new_generic, 'new', [node.from, node.to, BoolLiteral.new(node.exclusive)])
      node.expanded.accept self

      node.bind_to node.from, node.to
    end

    def visit_regexp_literal(node)
      return if node.expanded

      name = @@regexps[node.value]
      name = @@regexps[node.value] = "Regexp#{@@regexps.length}" unless name

      unless mod.types[name]
        value = Call.new(Ident.new(['Regexp'], true), 'new', [StringLiteral.new(node.value)])
        value.accept self
        mod.types[name] = Const.new mod, name, value
      end

      node.expanded = Ident.new([name], true)
      node.expanded.accept self

      node.type = node.expanded.type
    end

    def visit_class_method(node)
      node.type = @scope.metaclass
    end

    def visit_def(node)
      if node.has_default_arguments?
        node.expand_default_arguments.each do |expansion|
          expansion.accept self
        end
        return
      end

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
      target_type.add_macro node
      false
    end

    def visit_class_def(node)
      superclass = if node.superclass
                 lookup_ident_type node.superclass
               else
                 mod.reference
               end

      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is not a class" unless type.is_a?(ClassType)
        if node.superclass && type.superclass != superclass
          node.raise "superclass mismatch for class #{type.name} (#{superclass.name} for #{type.superclass.name})"
        end
      else
        if node.type_vars
          type = GenericClassType.new current_type, node.name, superclass, node.type_vars
        else
          type = NonGenericClassType.new current_type, node.name, superclass
        end
        type.abstract = node.abstract
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
        node.raise "#{node.name} is not a module" unless type.module?
      else
        if node.type_vars
          type = GenericModuleType.new current_type, node.name, node.type_vars
        else
          type = NonGenericModuleType.new current_type, node.name
        end
        current_type.types[node.name] = type
      end

      @types.push type

      true
    end

    def end_visit_module_def(node)
      @types.pop
    end

    def visit_include(node)
      if node.name.is_a?(NewGenericClass)
        type = lookup_ident_type(node.name.name)
      else
        type = lookup_ident_type(node.name)
      end

      unless type.module?
        node.name.raise "#{node.name} is not a module"
      end

      if node.name.is_a?(NewGenericClass)
        unless type.generic?
          node.name.raise "#{type} is not a generic module"
        end

        if type.type_vars.length != node.name.type_vars.length
          node.name.raise "wrong number of type vars for #{type} (#{node.name.type_vars.length} for #{type.type_vars.length})"
        end

        type_vars_types = node.name.type_vars.map do |type_var|
          type_var_name = type_var.names[0]
          if current_type.generic? && current_type.type_vars.include?(type_var_name)
            type_var_name
          else
            lookup_ident_type(type_var)
          end
        end

        mapping = Hash[type.type_vars.zip(type_vars_types)]
        current_type.include IncludedGenericModule.new(type, current_type, mapping)
      else
        if type.generic?
          if current_type.generic?
            current_type_type_vars_length = current_type.type_vars.length
          else
            current_type_type_vars_length = 0
          end

          if current_type_type_vars_length != type.type_vars.length
            node.name.raise "#{type} is a generic module"
          end

          mapping = Hash[type.type_vars.zip(current_type.type_vars)]
          current_type.include IncludedGenericModule.new(type, current_type, mapping)
        else
          current_type.include type
        end
      end

      false
    end

    def visit_lib_def(node)
      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is not a lib" unless type.is_a?(LibType)
      else
        current_type.types[node.name] = type = LibType.new current_type, node.name, node.libname
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
        fun_arg.type_restriction = fun_arg.type = maybe_ptr_type(arg.type.type.instance_type, arg.ptr)
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

        current_type.types[node.name] = TypeDefType.new current_type, node.name, typed_def_type
      end
    end

    def end_visit_struct_def(node)
      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is already defined"
      else
        current_type.types[node.name] = StructType.new(current_type, node.name, node.fields.map { |field| Var.new(field.name, field.type.type.instance_type) })
      end
    end

    def maybe_ptr_type(type, ptr)
      ptr.times do
        ptr_type = mod.pointer_of(type)
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

    def lookup_instance_var(node)
      if @scope.is_a?(Crystal::Program)
        node.raise "can't use instance variables at the top level"
      elsif @scope.is_a?(PrimitiveType)
        node.raise "can't use instance variables inside #{@scope.name}"
      end

      var = @scope.lookup_instance_var node.name
      if !@scope.has_instance_var_in_initialize?(node.name)
        var.bind_to mod.nil_var
      end

      node.bind_to var
      var
    end

    def visit_assign(node)
      type_assign(node.target, node.value, node)
      node.type_filters = node.value.type_filters
      false
    rescue Crystal::FrozenTypeException => ex
      node.raise "assinging to #{node.target}", ex
    end

    def visit_multi_assign(node)
      node.targets.each_with_index do |target, i|
        type_assign(target, node.values[i])
      end
      node.bind_to mod.nil_var
      false
    end

    def type_assign(target, value, node = nil)
      case target
      when Var
        value.accept self

        var = lookup_var target.name
        target.bind_to var

        if node
          node.bind_to value
          var.bind_to node
        else
          var.bind_to value
        end

      when InstanceVar
        value.accept self

        var = lookup_instance_var target

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

        current_type.types[target.names.first] = Const.new(current_type, target.names.first, value, @types.clone, @scope)
      when Global
        value.accept self

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

      @while_stack.push node
      node.body.accept self if node.body
      @while_stack.pop

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

      if node.then
        @type_filter_stack.push node.cond.type_filters if node.cond.type_filters

        node.then.accept self

        @type_filter_stack.pop if node.cond.type_filters
      end

      if node.else
        node.else.accept self
      end

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
        unless type.value.type
          old_types, old_scope = @types, @scope
          @types, @scope = type.types, type.scope
          type.value.accept self
          @types, @scope = old_types, old_scope
        end
        node.target_const = type
        node.bind_to(type.value)
      else
        node.type = type.metaclass
      end
    end

    def lookup_ident_type(node)
      if node.names.length == 1 && @free_vars && type = @free_vars[node.names]
        return type
      end

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
      if @scope.instance_type.is_a?(GenericClassType)
        node.raise "can't create instance of generic class #{@scope.instance_type} without specifying its type vars"
      end

      if @scope.instance_type.abstract
        node.raise "can't instantiate abstract class #{@scope.instance_type}"
      end

      @scope.instance_type.allocated = true
      node.type = @scope.instance_type
    end

    def end_visit_array_literal(node)
      return if node.expanded

      if node.elements.length == 0
        node.expanded = Call.new(NewGenericClass.new(Ident.new(['Array'], true), [node.of]), 'new')
        node.expanded.accept self
        node.bind_to node.expanded
        return false
      end

      ary_name = temp_name()

      length = node.elements.length
      capacity = length < 16 ? 16 : 2 ** Math.log(length, 2).ceil

      if node.of
        new_generic = NewGenericClass.new(Ident.new(['Array'], true), [node.of])
      else
        new_generic = NewGenericClass.new(Ident.new(['Array'], true), [Ident.new(["Nil"], true)])

        node.mod = mod
        node.new_generic_class = new_generic
        node.set_type(mod.array_of(mod.type_merge(*node.elements.map(&:type))))
      end

      new_generic.location = node.location

      ary_new = Call.new(new_generic, 'new', [IntLiteral.new(capacity)])
      ary_new.location = node.location

      ary_assign = Assign.new(Var.new(ary_name), ary_new)
      ary_assign.location = node.location

      ary_assign_length = Call.new(Var.new(ary_name), 'length=', [IntLiteral.new(length)])
      ary_assign_length.location = node.location

      exps = [ary_assign, ary_assign_length]
      node.elements.each_with_index do |elem, i|
        get_buffer = Call.new(Var.new(ary_name), 'buffer')
        get_buffer.location = node.location

        assign_index = Call.new(get_buffer, :[]=, [IntLiteral.new(i), elem])
        assign_index.location = node.location

        exps << assign_index
      end
      exps << Var.new(ary_name)

      exps = Expressions.new exps
      exps.accept self
      node.expanded = exps

      if node.of
        node.bind_to exps
      else
        node.bind_to *node.elements
      end

      false
    end

    def end_visit_hash_literal(node)
      return if node.expanded

      if node.keys.empty?
        new_generic = NewGenericClass.new(Ident.new(['Hash'], true), [node.of_key, node.of_value])
        exps = Call.new(new_generic, 'new')
      else
        hash_name = temp_name()

        if node.of_key
          new_generic = NewGenericClass.new(Ident.new(['Hash'], true), [node.of_key, node.of_value])
        else
          new_generic = NewGenericClass.new(Ident.new(['Hash'], true), [Ident.new(["Nil"], true), Ident.new(["Nil"], true)])

          key_var = Var.new("K")
          key_var.bind_to *node.keys

          value_var = Var.new("V")
          value_var.bind_to *node.values

          node.mod = mod
          node.new_generic_class = new_generic
          node.bind_to key_var, value_var
        end

        hash_new = Call.new(new_generic, 'new')
        hash_assign = Assign.new(Var.new(hash_name), hash_new)

        exps = [hash_assign]
        node.keys.each_with_index do |key, i|
          exps << Call.new(Var.new(hash_name), :[]=, [key, node.values[i]])
        end
        exps << Var.new(hash_name)
        exps = Expressions.new exps
      end

      exps.accept self
      node.expanded = exps

      if node.of_key
        node.bind_to exps
      end

      false
    end

    def end_visit_yield(node)
      block = @call.block or node.raise "no block given"

      if @yield_vars
        @yield_vars.each_with_index do |var, i|
          exp = node.exps[i]
          if exp
            if !exp.type.equal?(var.type)
              exp.raise "argument ##{i + 1} of yield expected to be #{var.type}, not #{exp.type}"
            end
            exp.freeze_type = true
          elsif !var.type.nil_type?
            node.raise "missing argument ##{i + 1} of yield with type #{var.type}"
          end
        end
      end

      block.args.each_with_index do |arg, i|
        exp = node.exps[i]
        if exp
          arg.bind_to exp
        else
          arg.bind_to mod.nil_var
        end
      end

      node.bind_to block.body if block.body
    end

    def visit_block(node)
      if node.body
        block_vars = @vars.clone
        node.args.each do |arg|
          block_vars[arg.name] = arg
        end

        block_visitor = TypeVisitor.new(mod, block_vars, @scope, @parent, @call, @owner, @untyped_def, @typed_def, @arg_types)
        block_visitor.block = node
        node.body.accept block_visitor
      end
      false
    end

    def visit_and(node)
      return if node.expanded

      temp_var = Var.new(temp_name())
      node.expanded = If.new(Assign.new(temp_var, node.left), node.right, temp_var)
      node.expanded.binary = :and
      node.expanded.accept self
      node.bind_to node.expanded
      node.type_filters = node.left.type_filters

      false
    end

    def visit_or(node)
      return if node.expanded

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
      node.recalculate

      node.obj.accept self if node.obj
      node.args.each { |arg| arg.accept self }

      node.bubbling_exception do
        node.block.accept self if node.block
      end

      false
    end

    def end_visit_ident_union(node)
      node.type = mod.type_merge *node.idents.map { |ident| ident.type.instance_type }
    end

    def end_visit_new_generic_class(node)
      return if node.type

      instance_type = node.name.type.instance_type
      unless instance_type.type_vars
        node.raise "#{instance_type} is not a generic class"
      end

      if instance_type.type_vars.length != node.type_vars.length
        node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{instance_type.type_vars.length})"
      end
      generic_type = instance_type.instantiate(node.type_vars.map { |var| var.type.instance_type })
      node.type = generic_type.metaclass
      false
    end

    def expand_macro(node)
      return false if node.obj || node.name == 'super'

      untyped_def = node.scope.lookup_macro(node.name, node.args.length) || mod.lookup_macro(node.name, node.args.length)
      return false unless untyped_def

      macro_name = "#macro_#{untyped_def.object_id}"

      macros_cache_key = [untyped_def.object_id] + node.args.map { | arg| arg.class.object_id }
      unless typed_def = mod.macros_cache[macros_cache_key]
        typed_def = Def.new(macro_name, untyped_def.args.map(&:clone), untyped_def.body ? untyped_def.body.clone : nil)
        mod.macros_cache[macros_cache_key] = typed_def
      end

      macro_call = Call.new(nil, macro_name, node.args.map(&:to_crystal_node))
      macro_nodes = Expressions.new [typed_def, macro_call]

      mod.infer_type macro_nodes

      if macro_nodes.type != mod.string
        node.raise "macro return value must be a String, not #{macro_nodes.type}"
      end

      macro_arg_types = macro_call.args.map(&:type)
      fun = untyped_def.lookup_instance(macro_arg_types)
      unless fun
        mod.build macro_nodes, nil, false, mod.macro_llvm_mod
        fun = mod.macro_llvm_mod.functions[macro_call.target_def.mangled_name(nil)]
        untyped_def.add_instance fun, macro_arg_types
      end

      mod.load_libs

      macro_args = node.args.map &:to_crystal_binary
      macro_value = mod.macro_engine.run_function fun, *macro_args

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
        @typed_def.bind_to exp
      end
    end

    def end_visit_is_a(node)
      node.type = mod.bool
      if node.obj.is_a?(Var)
        node.type_filters = {node.obj.name => node.const.type.instance_type}
      end
    end

    def visit_pointer_of(node)
      node.mod = mod
      var = if node.var.is_a?(Var)
              lookup_var node.var.name
            else
              lookup_instance_var node.var
            end
      node.bind_to var
      false
    end

    def visit_pointer_malloc(node)
      if @scope.instance_type.is_a?(GenericClassType)
        node.raise "can't malloc pointer without type, use Pointer(Type).malloc(size)"
      end

      node.type = @scope.instance_type
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
      if type.class?
        node.type = type
      else
        node.type = mod.pointer_of(type)
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
      unless var
        var = Var.new name
        @vars[name] = var
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
