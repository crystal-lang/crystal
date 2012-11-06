require 'benchmark'

module Crystal
  def infer_type(node, options = {})
    mod = Crystal::Module.new
    if node
      if options[:stats]
        infer_type_with_stats node, mod
      elsif options[:prof]
        infer_type_with_prof node, mod
      else
        node.accept TypeVisitor.new(mod)
        unify node if Crystal::UNIFY
      end
    end
    mod
  end

  def infer_type_with_stats(node, mod)
    Benchmark.bm(20, 'TOTAL:') do |bm|
      t1 = bm.report('type inference:') { node.accept TypeVisitor.new(mod) }
      t2 = bm.report('unification:') { unify node if Crystal::UNIFY }
      [t1 + t2]
    end
  end

  def infer_type_with_prof(node, mod)
    require 'ruby-prof'
    profile_to('type_inference.html') { node.accept TypeVisitor.new(mod) }
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

  class Call
    attr_accessor :target_def
    attr_accessor :mod
    attr_accessor :scope
    attr_accessor :parent_visitor

    def update_input(*)
      recalculate(false)
    end

    if Crystal::CACHE
      # WITH CACHE
      def recalculate(apply_mutations = true)
        return unless can_calculate_type?

        if has_unions?
          stop_listen_return_type_and_args_mutations

          dispatch = Dispatch.new
          self.bind_to dispatch
          self.target_def = dispatch
          dispatch.initialize_for_call(self)
          return
        end

        scope, untyped_def = compute_scope_and_untyped_def

        check_method_exists untyped_def
        check_args_match untyped_def

        type_was_nil = self.type.nil?

        arg_types = !untyped_def.is_a?(FrozenDef) && scope.is_a?(MutableType) ? [scope] : []
        arg_types += args.map &:type

        begin
          typed_def = untyped_def.lookup_instance(arg_types, self.type)
          unless typed_def
            typed_def = instantiate(untyped_def, scope, arg_types)
          end

          if (type_was_nil || apply_mutations) && typed_def.mutations
            typed_def.mutations.each do |mutation|
              mutation.apply([nil] + arg_types) unless mutation.path.index == 0
            end
          end
        rescue Crystal::Exception => ex
          if obj
            raise "instantiating '#{obj.type.name}##{name}'", ex
          else
            raise "instantiating '#{name}'", ex
          end
        end

        self.target_def = typed_def

        return_type, found_in_parent, must_clone = compute_return_type typed_def, scope

        if return_type && (!self.type || self.type != return_type)
          return_type = return_type.clone if must_clone && !self.type

          if typed_def.mutations
            typed_def.mutations.each do |mutation|
              if mutation.path.index == 0
                mutation.apply([return_type] + arg_types, true) 
              end
            end
          end

          if found_in_parent && typed_def.body.type != return_type
            self.type = return_type
            recalculate
            return
          end

          compute_parent_path typed_def, scope, return_type

          listen_return_type_and_args_mutations(return_type, arg_types)

          self.type = return_type
        end
      end

      def instantiate(untyped_def, scope, arg_types)
        check_frozen untyped_def, arg_types
        arg_types = Type.clone(arg_types)
        scope = arg_types[0] if scope.is_a?(MutableType)

        typed_def, args = prepare_typed_def_with_args(untyped_def, scope, arg_types)

        arg_types_cloned = Type.clone(arg_types)

        if typed_def.body
          typed_def.mutations = []

          visitor = TypeVisitor.new(@mod, args, scope, parent_visitor, [scope, untyped_def, arg_types, typed_def, self])

          mutation_observers = {}
          arg_types.each_with_index do |arg_type, i|
            if arg_type.is_a?(MutableType) && !mutation_observers[arg_type.object_id]
              token = arg_type.observe_mutations do |ivar, type|
                path = visitor.paths[type.object_id]
                mutation = Mutation.new(Path.new(i + 1, *ivar.map { |var| var.is_a?(Var) ? var.name : var }), path || type)
                typed_def.mutations << mutation
              end
              mutation_observers[arg_type.object_id] = [arg_type, token]
            end
          end

          untyped_def.add_instance(typed_def, arg_types_cloned, self.type.clone)
          typed_def.body.accept visitor

          typed_def.return = compute_return visitor, typed_def, scope

          mutation_observers.values.each do |type, token|
            type.unobserve_mutations token
          end
        end

        typed_def
      end
    else
      # WITHOUT CACHE
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
          check_frozen untyped_def, arg_types

          typed_def, args = prepare_typed_def_with_args(untyped_def, scope, arg_types)

          if typed_def.body
            begin
              visitor = TypeVisitor.new(@mod, args, scope, parent_visitor, [scope, untyped_def, arg_types, typed_def, self])
              typed_def.body.accept visitor
            rescue Crystal::Exception => ex
              if obj
                raise "instantiating '#{obj.type.name}##{name}'", ex
              else
                raise "instantiating '#{name}'", ex
              end
            end
          end
        end

        self.bind_to typed_def.body if typed_def.body
        self.target_def = typed_def
      end
    end

    def prepare_typed_def_with_args(untyped_def, scope, arg_types)
      if Crystal::CACHE
        args_start_index = scope.is_a?(MutableType) ? 1 : 0
      else
        args_start_index = 0
      end

      typed_def = untyped_def.clone
      typed_def.owner = scope

      args = {}
      args['self'] = Var.new('self', scope) if scope.is_a?(Type)
      typed_def.args.each_with_index do |arg, index|
        type = arg_types[args_start_index + index]
        args[arg.name] = Var.new(arg.name, type)
        typed_def.args[index].type = type
      end

      [typed_def, args]
    end

    def listen_return_type_and_args_mutations(return_type = self.type, arg_types = nil)
      stop_listen_return_type_and_args_mutations

      unless arg_types
        scope, untyped_def = compute_scope_and_untyped_def

        arg_types = !untyped_def.is_a?(FrozenDef) && scope.is_a?(MutableType) ? [scope] : []
        arg_types += args.map &:type
      end

      if return_type.is_a?(MutableType) && !target_def.return.is_a?(Path)
        token = return_type.observe_mutations do |ivar, type|
          mutation = Mutation.new(Path.new(0, *ivar.map { |var| var.is_a?(Var) ? var.name : var }), type)
          parent_path = parent_visitor.paths[type.object_id]
          if parent_path
            parent_visitor.pending_mutations[return_type.object_id] << [mutation.path.path, parent_path]
          else
            parent_visitor.pending_mutations[type.object_id].each do |mutation_path, type_path|
              parent_visitor.pending_mutations[return_type.object_id] << [mutation.path.path + mutation_path, type_path]
            end
          end
          reinstantiate mutation
        end
        @end_mutation_observers ||= {}
        @end_mutation_observers[return_type.object_id] = [return_type, token]
      end

      arg_types.each_with_index do |arg_type, i|
        if arg_type.is_a?(MutableType)
          token = arg_type.observe_mutations do |ivar, type|
            mutation = Mutation.new(Path.new(i + 1, *ivar.map { |var| var.is_a?(Var) ? var.name : var }), type)
            reinstantiate mutation
          end
          @end_mutation_observers ||= {}
          @end_mutation_observers[arg_type.object_id] = [arg_type, token]
        end
      end
    end

    def stop_listen_return_type_and_args_mutations
      if @end_mutation_observers && @end_mutation_observers.length > 0
        @end_mutation_observers.values.each { |type, token| type.unobserve_mutations token }
        @end_mutation_observers = nil
      end
    end

    def reinstantiate(mutation)
      scope, untyped_def = compute_scope_and_untyped_def

      arg_types = !untyped_def.is_a?(FrozenDef) && scope.is_a?(MutableType) ? [scope] : []
      arg_types += args.map &:type

      cloned_def = untyped_def.lookup_instance(arg_types, self.type)
      if cloned_def
        self.target_def = cloned_def
      else
        new_context = {}
        untyped_def.add_instance(arg_types.map { |type| type.clone(new_context) }, self.type.clone(new_context))

        types_context = {}
        nodes_context = {}

        if target_def.owner.is_a?(Type)
          new_owner = target_def.owner.clone(types_context, nodes_context)
        else
          new_owner = target_def.owner
        end

        clone_proc = proc do |old_node, new_node|
          if old_node.dependencies
            new_node.bind_to *old_node.dependencies.select { |x| !x.is_a?(Dispatch) }.map { |node| node.clone(nodes_context, &clone_proc) }
          end

          new_node.set_type old_node.type.clone(types_context, nodes_context) if old_node.type && !(old_node.is_a?(Call) && old_node.target_def.is_a?(Dispatch))
          if old_node.is_a?(Call)
            if (old_node.target_def.is_a?(Dispatch))
              dispatch = Dispatch.new
              new_node.bind_to dispatch
              new_node.target_def = dispatch
              dispatch.initialize_for_call(new_node)
            else
              new_node.target_def = old_node.target_def
            end
            new_node.mod = old_node.mod
            if old_node.scope.is_a?(Type)
              new_node.scope = old_node.scope.clone(types_context, nodes_context)
            else
              new_node.scope = old_node.scope
            end
            new_node.parent_visitor = old_node.parent_visitor
            new_node.listen_return_type_and_args_mutations unless new_node.target_def.is_a?(Dispatch)

            new_node.args.each_with_index do |arg, index|
              arg.add_observer new_node, :update_input
            end
            new_node.obj.add_observer new_node, :update_input if new_node.obj
          end
        end

        cloned_def = target_def.clone(nodes_context, &clone_proc)
        cloned_def.owner = new_owner

        all_types = [cloned_def.body.type]
        all_types.push cloned_def.owner if cloned_def.owner.is_a?(Type) && !cloned_def.owner.is_a?(Metaclass)
        all_types += cloned_def.args.map(&:type)

        self.target_def = cloned_def

        mutation.apply(all_types)
      end

      self.type = cloned_def.body.type
    end

    def compute_return(visitor, typed_def, scope)
      return_type = typed_def.body.type
      unless return_type.is_a?(MutableType)
        return return_type
      end

      if scope.is_a?(ObjectType)
        ivar = scope.instance_vars.find { |name, ivar| ivar.type.object_id == return_type.object_id }
        if ivar
          return Path.new(1, ivar[0])
        end
      elsif scope.is_a?(ArrayType)
        if scope.element_type.object_id == return_type.object_id
          return Path.new(1, scope.element_type_var.name)
        end
      end

      args = scope.is_a?(Type) ? [scope] : []
      args += typed_def.args.map &:type
      index = args.find_index { |var| var.equal?(return_type) }
      if index
        return Path.new(index + 1)
      end

      path = visitor.paths[return_type.object_id]
      if path
        return path
      end

      visitor.pending_mutations[return_type.object_id].each do |path, type|
        typed_def.mutations << Mutation.new(Path.new(0, *path), type)
      end

      return_type
    end

    def compute_parent_path(typed_def, scope, return_type)
      return unless typed_def.return.is_a?(Path) && parent_visitor && parent_visitor.call

      index = typed_def.return.index
      search_id = lookup_arg_index(index, scope)
      return_id = return_type.object_id

      parent_scope = parent_visitor.call[0]
      types = parent_scope.is_a?(Crystal::Type) ? [parent_scope] : []
      types += parent_visitor.call[2]
      parent_index = types.index { |type| type.object_id == search_id }
      if parent_index
        parent_visitor.paths[return_id] ||= typed_def.return.with_index(parent_index + 1)
      else
        parent_path = parent_visitor.paths[search_id]
        parent_visitor.paths[return_id] ||= parent_path.append(typed_def.return) if parent_path
      end
    end

    def lookup_arg_index(index, scope)
      if scope.is_a?(Type)
        if index == 1
          scope.object_id
        else
          args[index - 2].type.object_id
        end
      else
        args[index - 1].type.object_id
      end
    end

    def compute_return_type(typed_def, scope)
      if typed_def.return.is_a?(Path)
        [typed_def.return.evaluate_args(scope, self.args), false, false]
      elsif typed_def.body && typed_def.body.type
        if typed_def.body.type.is_a?(MutableType)
          name = typed_def.body.type.name
          if scope.is_a?(ObjectType) && scope.name == name
            [scope, false, false]
          elsif parent_visitor && (parent_type = parent_visitor.lookup_object_type(name))
            [parent_type, true, false]
          else
            [typed_def.body.type, false, true]
          end
        else
          [typed_def.body.type, false, false]
        end
      else
        self.bind_to typed_def.body if typed_def.body
        nil
      end
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
        [obj.type, lookup_method(obj.type, name)]
      else
        if self.scope
          untyped_def = lookup_method(self.scope, name)
          if untyped_def
            [self.scope, untyped_def]
          else
            [mod, mod.defs[name]]
          end
        else
          [mod, mod.defs[name]]
        end
      end
    end

    def lookup_method(scope, name)
      untyped_def = scope.defs[name]
      if !untyped_def && name == 'new' && scope.is_a?(Metaclass)
        untyped_def = define_new scope, name
      end
      untyped_def
    end

    def define_new(scope, name)
      alloc = Call.new(nil, 'alloc')
      alloc.location = location
      alloc.name_column_number = name_column_number

      if scope.type.defs.has_key?('initialize')
        var = Var.new('x')
        new_args = args.each_with_index.map { |x, i| Var.new("arg#{i}") }

        init = Call.new(var, 'initialize', new_args)
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

    def check_method_exists(untyped_def)
      return if untyped_def

      if obj
        raise "undefined method '#{name}' for #{obj.type.name}"
      elsif args.length > 0 || has_parenthesis
        raise "undefined method '#{name}'"
      else
        raise "undefined local variable or method '#{name}'"
      end
    end

    def check_args_match(untyped_def)
      return if untyped_def.args.length == args.length

      raise "wrong number of arguments for '#{name}' (#{args.length} for #{untyped_def.args.length})"
    end

    def check_frozen(untyped_def, arg_types)
      return unless untyped_def.is_a?(FrozenDef)

      if untyped_def.is_a?(External)
        raise "can't call #{name} with types [#{arg_types.join ', '}]"
      else
        raise "can't call #{obj.type.name}##{name} with types [#{arg_types.join ', '}]"
      end
    end
  end

  class Def
    attr_accessor :owner
    attr_accessor :instances
    attr_accessor :return
    attr_accessor :mutations

    def add_instance(a_def, types = a_def.args.map(&:type), return_type = nil)
      @instances ||= {}
      @instances[[types, return_type]] = a_def
    end

    def lookup_instance(arg_types, return_type = nil)
      @instances && @instances[[arg_types, return_type]]
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
          self.bind_to subcall
          subcall.recalculate
          @calls << subcall
        end
      end
    end

    def simplify
      new_calls = {}
      @calls.each do |call|
        new_calls[[(call.obj ? call.obj.type : nil).object_id] + call.args.map { |arg| arg.type.object_id }] = call
      end
      @calls = new_calls
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
    attr_accessor :pending_mutations

    def initialize(mod, vars = {}, scope = nil, parent = nil, call = nil)
      @mod = mod
      @vars = vars
      @scope = scope
      @parent = parent
      @call = call
      @class_defs = []
      @paths = {}
      @pending_mutations = Hash.new { |h,k| h[k] = [] }
      if @call
        @call[2].each_with_index do |type, i|
          @paths[type.object_id] = Path.new(i + 1) if type.is_a?(MutableType)
        end
      end
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
      if @class_defs.empty?
        mod.defs[node.name] = node
      else
        mod.types[@class_defs.last].defs[node.name] = node
      end
      false
    end

    def visit_class_def(node)
      @class_defs.push node.name

      parent = if node.superclass
                 mod.types[node.superclass] or raise Crystal::TypeException.new("unknown class #{node.superclass}", node.line_number, node.superclass_column_number, node.superclass.length)
               else
                 mod.object
               end

      existing = mod.types[node.name]
      if existing
        if node.superclass && existing.parent_type != parent
          node.raise "superclass mismatch for class #{existing.name} (#{parent.name} for #{existing.parent_type.name})"
        end
      else
        mod.types[node.name] = ObjectType.new node.name, parent
      end
      true
    end

    def end_visit_class_def(node)
      @class_defs.pop
    end

    def visit_var(node)
      var = lookup_var node.name
      node.bind_to var
    end

    def visit_instance_var(node)
      if @scope.is_a?(Crystal::Module)
        node.raise "can't use instance variables inside a module"
      elsif @scope.is_a?(PrimitiveType)
        node.raise "can't use instance variables inside #{@scope.name}"
      end

      var = @scope.lookup_instance_var node.name
      node.bind_to var
      paths[var.type.object_id] ||= Path.new(1, node.name) if var.type
    end

    def end_visit_assign(node)
      node.bind_to node.value

      if node.target.is_a?(InstanceVar)
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

    def visit_const(node)
      type = mod.types[node.name] or node.raise("uninitialized constant #{node.name}")
      node.type = type.metaclass
    end

    if Crystal::CACHE
      def visit_alloc(node)
        type = lookup_object_type(node.type.name)
        node.type = type ? type : node.type
      end
    else
      def visit_alloc(node)
        type = lookup_object_type(node.type.name)
        node.type = type ? type : node.type.clone
      end
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
      paths[@scope.element_type.object_id] = Path.new(1, 'element')
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

    def visit_call(node)
      node.mod = mod
      node.scope = @scope
      node.parent_visitor = self
      node.args.each_with_index do |arg, index|
        arg.add_observer node, :update_input
      end
      node.obj.add_observer node, :update_input if node.obj
      node.recalculate unless node.obj || node.args.any?
      true
    end

    def lookup_var(name)
      var = @vars[name]
      unless var
        var = Var.new name
        @vars[name] = var
      end
      var
    end
  end
end
