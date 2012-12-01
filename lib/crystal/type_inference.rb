require_relative 'ast'

module Crystal
  def infer_type(node, options = {})
    mod = Crystal::Program.new options
    if node
      if options[:stats]
        infer_type_with_stats node, mod
      elsif options[:prof]
        infer_type_with_prof node, mod
      else
        node.accept TypeVisitor.new(mod)
        fix_empty_arrays node, mod
        unify node if Crystal::UNIFY
      end
    end
    mod
  end

  def infer_type_with_stats(node, mod)
    require 'benchmark'
    Benchmark.bm(20, 'TOTAL:') do |bm|
      t1 = bm.report('type inference:') { node.accept TypeVisitor.new(mod) }
      t2 = bm.report('fix_empty_arrays:') { fix_empty_arrays node, mod }
      t3 = bm.report('unification:') { unify node if Crystal::UNIFY }
      [t1 + t2 + t3]
    end
  end

  def infer_type_with_prof(node, mod)
    require 'ruby-prof'
    profile_to('type_inference.html') { node.accept TypeVisitor.new(mod) }
    profile_to('fix_empty_arrays.html') { fix_empty_arrays node, mod }
    profile_to('unification.html') { unify node if Crystal::UNIFY }
  end

  def profile_to(output_filename, &block)
    result = RubyProf.profile(&block)
    printer = RubyProf::GraphHtmlPrinter.new(result)
    File.open(output_filename, "w") { |f| printer.print(f) }
  end

  class ASTNode
    attr_accessor :type
    attr_accessor :dependencies

    def set_type(type)
      @type = type
    end

    def type=(type)
      return if type.nil? || @type == type

      @type = type
      notify_observers
    end

    def bind_to(*nodes)
      @dependencies ||= []
      @dependencies += nodes
      nodes.each do |node|
        node.add_observer self
      end
      update
    end

    def add_observer(observer, func = :update)
      @observers ||= {}
      @observers[observer] = func
    end

    def notify_observers
      return unless @observers
      @observers.each do |observer, func|
        observer.send func, self
      end
    end

    def update(from = self)
      self.type = Type.merge(*dependencies.map(&:type)) if dependencies
    end

    def raise(message, inner = nil)
      Kernel::raise Crystal::TypeException.for_node(self, message, inner)
    end
  end

  class Ident
    attr_accessor :target_const
  end

  class Call
    attr_accessor :target_def
    attr_accessor :mod
    attr_accessor :scope
    attr_accessor :parent_visitor

    def update_input(*)
      recalculate(false)
    end

    def recalculate(*)
      return unless can_calculate_type?

      if has_unions?
        dispatch = Dispatch.new
        self.bind_to dispatch
        self.target_def = dispatch
        dispatch.initialize_for_call(self)
        return
      end

      scope, untyped_def = compute_scope_and_untyped_def

      check_method_exists untyped_def
      check_args_match untyped_def

      arg_types = args.map &:type
      typed_def = untyped_def.lookup_instance(arg_types) || parent_visitor.lookup_def_instance(scope, untyped_def, arg_types)
      unless typed_def
        check_frozen scope, untyped_def, arg_types

        typed_def, args = prepare_typed_def_with_args(untyped_def, scope, arg_types)

        if typed_def.body
          bubbling_exception do
            visitor = TypeVisitor.new(@mod, args, scope, parent_visitor, [scope, untyped_def, arg_types, typed_def, self])
            typed_def.body.accept visitor
          end
        end
      end

      self.bind_to typed_def.body if typed_def.body
      self.target_def = typed_def
    end

    def bubbling_exception
      begin
        yield
      rescue Crystal::Exception => ex
        if obj
          raise "instantiating '#{obj.type.name}##{name}'", ex
        else
          raise "instantiating '#{name}'", ex
        end
      end
    end

    def prepare_typed_def_with_args(untyped_def, scope, arg_types)
      args_start_index = 0

      typed_def = untyped_def.clone
      typed_def.owner = scope

      args = {}
      args['self'] = Var.new('self', scope) if scope.is_a?(Type)

      0.upto(self.args.length - 1).each do |index|
        arg = typed_def.args[index]
        type = arg_types[args_start_index + index]
        args[arg.name] = Var.new(arg.name, type)
        arg.type = type
      end

      if self.args.length < untyped_def.args.length
        typed_def.args = typed_def.args[0 ... self.args.length]
      end

      # Declare name = default_value for each default value that wasn't given
      self.args.length.upto(untyped_def.args.length - 1).each do |index|
        arg = untyped_def.args[index]
        assign = Assign.new(Var.new(arg.name), arg.default_value)
        if typed_def.body
          if typed_def.body.is_a?(Expressions)
            typed_def.body.expressions.insert 0, assign
          else
            typed_def.body = Expressions.new [assign, typed_def.body]
          end
        else
          typed_def.body = assign
        end
      end

      [typed_def, args]
    end

    def simplify
      return unless target_def.is_a?(Dispatch)

      target_def.simplify
      if target_def.calls.length == 1
        self.target_def = target_def.calls.values.first.target_def
      end
    end

    def can_calculate_type?
      args.all?(&:type) && (obj.nil? || obj.type)
    end

    def has_unions?
      (obj && obj.type.is_a?(UnionType)) || args.any? { |a| a.type.is_a?(UnionType) }
    end

    def compute_scope_and_untyped_def
      if obj
        return [obj.type, lookup_method(obj.type, name, true)]
      end

      unless scope
        return [mod, mod.defs[name]]
      end

      if name == 'super'
        parent = scope.parents.first
        if args.empty? && !has_parenthesis
          self.args = parent_visitor.call[3].args.map do |arg|
            var = Var.new(arg.name)
            var.bind_to arg
            var
          end
        end

        return [parent, lookup_method(parent, parent_visitor.call[1].name)]
      end

      untyped_def = lookup_method(scope, name)
      if untyped_def
        return [scope, untyped_def]
      end

      mod_def = mod.defs[name]
      if mod_def || !(missing = scope.defs['method_missing'])
        return [mod, mod.defs[name]]
      end

      untyped_def = define_missing scope, name
      [scope, untyped_def]
    end

    def lookup_method(scope, name, use_method_missing = false)
      untyped_def = scope.defs[name]
      unless untyped_def
        if name == 'new' && scope.is_a?(Metaclass) && scope.instance_type.is_a?(ObjectType)
          untyped_def = define_new scope, name
        elsif use_method_missing && scope.defs['method_missing']
          untyped_def = define_missing scope, name
        end
      end
      untyped_def
    end

    def define_new(scope, name)
      alloc = Call.new(nil, 'alloc')
      alloc.location = location
      alloc.name_column_number = name_column_number

      if scope.type.defs.has_key?('initialize')
        var = Var.new('x')
        new_vars = args.each_with_index.map { |x, i| Var.new("arg#{i}") }
        new_args = args.each_with_index.map { |x, i| Arg.new("arg#{i}") }

        init = Call.new(var, 'initialize', new_vars)
        init.location = location
        init.name_column_number = name_column_number
        init.name_length = 3

        untyped_def = scope.defs['new'] = Def.new('new', new_args, [
          Assign.new(var, alloc),
          init,
          var
        ])
      else
        untyped_def = scope.defs['new'] = Def.new('new', [], [alloc])
      end
    end

    def define_missing(scope, name)
      missing_args = self.args.each_with_index.map { |arg, i| Arg.new("arg#{i}") }
      missing_vars = self.args.each_with_index.map { |arg, i| Var.new("arg#{i}") }
      scope.defs[name] = Def.new(name, missing_args, [
        Call.new(nil, 'method_missing', [SymbolLiteral.new(name.to_s), ArrayLiteral.new(missing_vars)])
      ])
    end

    def check_method_exists(untyped_def)
      return if untyped_def

      if obj
        raise "undefined method '#{name}' for #{obj.type.full_name}"
      elsif args.length > 0 || has_parenthesis
        raise "undefined method '#{name}'"
      else
        raise "undefined local variable or method '#{name}'"
      end
    end

    def check_args_match(untyped_def)
      required_args_count = untyped_def.args.count { |arg| !arg.default_value }
      all_args_count = untyped_def.args.length
      call_args_count = args.length

      return if required_args_count <= call_args_count && call_args_count <= all_args_count

      raise "wrong number of arguments for '#{name}' (#{args.length} for #{untyped_def.args.length})"
    end

    def check_frozen(scope, untyped_def, arg_types)
      return unless untyped_def.is_a?(FrozenDef)

      if untyped_def.is_a?(External)
        raise "can't call #{scope.name}.#{name} with types [#{arg_types.join ', '}]"
      else
        raise "can't call #{obj.type.name}##{name} with types [#{arg_types.join ', '}]"
      end
    end
  end

  class Def
    attr_accessor :owner
    attr_accessor :instances

    def add_instance(a_def, arg_types = a_def.args.map(&:type))
      @instances ||= {}
      @instances[arg_types] = a_def
    end

    def lookup_instance(arg_types)
      @instances && @instances[arg_types]
    end
  end

  class Dispatch < ASTNode
    attr_accessor :name
    attr_accessor :obj
    attr_accessor :args
    attr_accessor :calls

    def initialize_for_call(call)
      @name = call.name
      @obj = call.obj && call.obj.type
      @args = call.args.map(&:type)
      @calls = []
      for_each_obj do |obj_type|
        for_each_args do |arg_types|
          subcall = Call.new(obj_type ? Var.new('self', obj_type) : nil, name, arg_types.map { |arg_type| Var.new(nil, arg_type) })
          subcall.mod = call.mod
          subcall.parent_visitor = call.parent_visitor
          subcall.scope = call.scope
          subcall.location = call.location
          subcall.name_column_number = call.name_column_number
          subcall.block = call.block
          self.bind_to subcall
          subcall.recalculate
          @calls << subcall
        end
      end
    end

    def simplify
      return if @simplified
      new_calls = {}
      @calls.each do |call|
        new_calls[[(call.obj ? call.obj.type : nil).object_id] + call.args.map { |arg| arg.type.object_id }] = call
      end
      @calls = new_calls
      @simplified = true
    end

    def for_each_obj(&block)
      if @obj
        @obj.each &block
      else
        yield nil
      end
    end

    def for_each_args(args = @args, arg_types = [], index = 0, &block)
      if index == args.count
        yield arg_types
      else
        args[index].each do |arg_type|
          arg_types[index] = arg_type
          for_each_args(args, arg_types, index + 1, &block)
        end
      end
    end

    def accept_children(visitor)
      @calls.each do |call|
        call.accept visitor
      end
    end
  end

  class TypeVisitor < Visitor
    attr_accessor :mod
    attr_accessor :paths
    attr_accessor :call

    def initialize(mod, vars = {}, scope = nil, parent = nil, call = nil)
      @mod = mod
      @vars = vars
      @scope = scope
      @parent = parent
      @call = call
      @types = [mod]
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

    def visit_string_literal(node)
      node.type = mod.string
    end

    def visit_symbol_literal(node)
      node.type = mod.symbol
      mod.symbols << node.value
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
      target_type.defs[node.name] = node
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
        current_type.types[node.name] = type = ObjectType.new node.name, parent, current_type
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
      current_type.fun node.name,
        node.args.map { |arg| [arg.name, arg.type.type.instance_type] },
        (node.return_type ? node.return_type.type.instance_type : nil)
    end

    def end_visit_type_def(node)
      type = current_type.types[node.name]
      if type
        node.raise "#{node.name} is already defined"
      else
        current_type.types[node.name] = TypeDefType.new node.name, node.type.type.instance_type, current_type
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

    def visit_struct_alloc(node)
      node.type = node.type
    end

    def visit_struct_set(node)
      struct_var = @scope.vars[node.name]

      check_var_type 'value', struct_var.type

      node.bind_to @vars['value']
    end

    def visit_struct_get(node)
      struct_var = @scope.vars[node.name]
      node.bind_to struct_var
    end

    def visit_var(node)
      var = lookup_var node.name
      node.bind_to var
    end

    def visit_global(node)
      var = mod.global_vars[node.name] or node.raise "uninitialized global #{node}"
      node.bind_to var
    end

    def visit_instance_var(node)
      if @scope.is_a?(Crystal::Program)
        node.raise "can't use instance variables at the top level"
      elsif @scope.is_a?(PrimitiveType)
        node.raise "can't use instance variables inside #{@scope.name}"
      end

      var = @scope.lookup_instance_var node.name
      node.bind_to var
    end

    def visit_assign(node)
      case node.target
      when Ident
        type = current_type.types[node.target.names.first]
        if type
          node.raise "already initialized constant #{node.target}"
        end

        node.value.accept self
        node.target.bind_to node.value

        current_type.types[node.target.names.first] = Const.new(node.target.names.first, node.value, current_type)
        false
      when Global
        var = mod.global_vars[node.target.name] ||= Var.new(node.target.name)

        node.value.accept self
        node.target.bind_to var

        node.bind_to node.value

        var.bind_to node
        var.update

        false
      else
        true
      end
    end

    def end_visit_assign(node)
      return if node.target.is_a?(Ident) || node.target.is_a?(Global)

      node.bind_to node.value

      case node.target
      when InstanceVar
        var = @scope.lookup_instance_var node.target.name
      else
        var = lookup_var node.target.name
      end

      var.bind_to node
      var.update
    end

    def end_visit_expressions(node)
      if node.last
        node.bind_to node.last
      else
        node.type = mod.void
      end
    end

    def end_visit_while(node)
      node.type = mod.void
    end

    def end_visit_if(node)
      node.bind_to node.then
      node.bind_to node.else if node.else
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

    def visit_alloc(node)
      type = lookup_object_type(node.type.name)
      node.type = type ? type : node.type.clone
    end

    def visit_array_literal(node)
      node.type = mod.array.clone
      node.elements.each do |elem|
        node.type.element_type_var.bind_to elem
      end
    end

    def visit_array_new(node)
      check_var_type 'size', mod.int

      node.type = mod.array.clone
      node.type.element_type_var.bind_to @vars['obj']
    end

    def visit_array_length(node)
      node.type = mod.int
    end

    def visit_array_get(node)
      check_var_type 'index', mod.int

      node.bind_to @scope.element_type_var
    end

    def visit_array_set(node)
      check_var_type 'index', mod.int

      @scope.element_type_var.bind_to @vars['value']
      node.bind_to @vars['value']
    end

    def visit_array_push(node)
      @scope.element_type_var.bind_to @vars['value']
      node.bind_to @vars['self']
    end

    def check_var_type(var_name, expected_type)
      type = @vars[var_name].type
      if type != expected_type
        @call[4].args[0].raise "#{var_name} must be #{expected_type.name}, not #{type.name}"
      end
    end

    def lookup_object_type(name)
      if @scope.is_a?(ObjectType) && @scope.name == name
        @scope
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
        node.body.accept block_visitor
      end
      false
    end

    def visit_call(node)
      node.mod = mod
      node.scope = @scope
      node.parent_visitor = self
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

    def end_visit_return(node)
      node.exps.each do |exp|
        @call[3].body.bind_to exp
      end
    end

    def end_visit_pointer_of(node)
      node.type = mod.pointer.clone
      node.type.var = if node.var.is_a?(Var)
                        lookup_var node.var.name
                      else
                        @scope.lookup_instance_var node.var.name
                      end
    end

    def visit_pointer_get_value(node)
      node.bind_to @scope.var
    end

    def visit_pointer_set_value(node)
      @scope.var.bind_to @vars['value']
      node.bind_to @vars['value']
    end

    def visit_pointer_add(node)
      check_var_type 'offset', mod.int
      node.type = @scope
    end

    def lookup_var(name)
      var = @vars[name]
      unless var
        var = Var.new name
        @vars[name] = var
      end
      var
    end

    def current_type
      @types.last
    end
  end
end
