require 'benchmark'

module Crystal
  def infer_type(node, stats = false)
    mod = Crystal::Module.new
    if stats
      Benchmark.bm(20, 'TOTAL:') do |bm|
        t1 = bm.report('type inference:') { node.accept TypeVisitor.new(mod) }
        t2 = bm.report('unification:') { unify node }
        [t1 + t2]
      end
    else
      node.accept TypeVisitor.new(mod)
      unify node
    end
    mod
  end

  class Path
    attr_accessor :index
    attr_accessor :path

    def initialize(index, *path)
      @index = index
      @path = path
    end

    def with_index(other_index)
      Path.new(other_index, *path)
    end

    def append(other_path)
      Path.new(index, *(path + other_path.path))
    end

    def ==(other)
      other.is_a?(Path) && index == other.index && path == other.path
    end

    def evaluate_args(obj, args)
      types = obj.is_a?(Type) ? [obj] : []
      types += args.map &:type
      evaluate_types(types)
    end

    def evaluate_types(types)
      type = types[index]
      path.each do |ivar|
        type = type.lookup_instance_var(ivar).type
      end
      type
    end

    def to_s
      str = "#{index}"
      str << '/' << path.join('/')
      str
    end
  end

  class Mutation
    attr_accessor :path
    attr_accessor :target

    def initialize(path, target)
      @path = path
      @target = target
    end

    def apply(types)
      type = types[path.index]
      var = nil
      path.path.each do |ivar|
        var = type.lookup_instance_var(ivar)
        type = var.type
      end
      new_type = target.is_a?(Type) ? target : target.evaluate_types(types)
      var.type = new_type #var.type ? Type.merge(var.type, new_type) : new_type
    end

    def ==(other)
      path == other.path && target == other.target
    end

    def with_index(index)
      Mutation.new(path.with_index(index), target)
    end

    def to_s
      "#{path} -> #{target}"
    end
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

    def bind_to(node)
      @dependencies ||= []
      dependencies << node
      node.add_observer self
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

    def update_input(type)
      recalculate(nil, false)
    end

    def recalculate(mutation = nil, apply_mutations = true)
      return unless can_calculate_type?

      if has_unions?
        dispatch = Dispatch.new(self)
        self.bind_to dispatch
        self.target_def = dispatch
        return
      end

      scope, untyped_def = compute_scope_and_untyped_def

      check_method_exists untyped_def
      check_args_match untyped_def

      type_was_nil = self.type.nil?

      arg_types = scope.is_a?(MutableType) ? [scope] : []
      arg_types += args.map &:type
      typed_def = untyped_def.lookup_instance(arg_types, self.type) ||
                  instantiate(untyped_def, scope, arg_types, mutation)

      if (type_was_nil || apply_mutations) && typed_def.mutations
        typed_def.mutations.each do |mutation|
          mutation.apply(arg_types)
        end
      end

      new_type = compute_new_type typed_def, scope
      compute_parent_path typed_def, scope, new_type

      if typed_def.mutations && parent_visitor.call && !typed_def.equal?(parent_visitor.call[3])
        compute_parent_mutations typed_def, scope
      end

      if new_type.is_a?(MutableType) && !typed_def.return.is_a?(Path)
        token = new_type.observe_mutations do |ivar, type|
          new_type.unobserve_mutations token
          mutation = Mutation.new(Path.new(0, ivar), type)
          recalculate mutation
        end
      end

      self.type = new_type
      self.target_def = typed_def
    end

    def instantiate(untyped_def, scope, arg_types, mutation)
      check_frozen untyped_def, arg_types
      arg_types = Type.clone(arg_types)
      scope = arg_types[0] if scope.is_a?(MutableType)
      args_start_index = scope.is_a?(MutableType) ? 1 : 0

      typed_def = untyped_def.clone
      typed_def.owner = scope

      args = {}
      args['self'] = Var.new('self', scope) if scope.is_a?(Type)
      typed_def.args.each_with_index do |arg, index|
        type = arg_types[args_start_index + index]
        args[arg.name] = Var.new(arg.name, type)
        typed_def.args[index].type = type
      end

      arg_types_cloned = Type.clone(arg_types)

      if typed_def.body
        begin
          typed_def.mutations = []

          visitor = TypeVisitor.new(@mod, args, scope, parent_visitor, [scope, untyped_def, arg_types, typed_def, self])

          mutation_observers = {}
          arg_types.each_with_index do |arg_type, i|
            if arg_type.is_a?(MutableType) && !mutation_observers[arg_type.object_id]
              token = arg_type.observe_mutations do |ivar, type|
                path = visitor.paths[type.object_id]
                mutation2 = Mutation.new(Path.new(i, ivar), path || type)
                typed_def.mutations << mutation2
              end
              mutation_observers[arg_type.object_id] = [arg_type, token]
            end
          end

          untyped_def.add_instance(typed_def, arg_types_cloned, self.type.clone)
          typed_def.body.accept visitor

          compute_return visitor, typed_def, scope

          mutation.apply [typed_def.body.type] if mutation

          mutation_observers.values.each do |type, token|
            type.unobserve_mutations token
          end
        rescue Crystal::Exception => ex
          if obj
            raise "instantiating '#{obj.type.name}##{name}'", ex
          else
            raise "instantiating '#{name}'", ex
          end
        end
      end

      typed_def
    end

    def compute_return(visitor, typed_def, scope)
      return_type = typed_def.body.type
      unless return_type.is_a?(MutableType)
        return typed_def.return = return_type
      end

      args = scope.is_a?(Type) ? [scope] : []
      args += typed_def.args.map &:type
      index = args.find_index { |var| var.equal?(return_type) }
      if index
        return typed_def.return = Path.new(index)
      end

      path = visitor.paths[return_type.object_id]
      if path
        return typed_def.return = path
      end

      typed_def.return = return_type
    end

    def compute_parent_path(typed_def, scope, new_type)
      return unless typed_def.return.is_a?(Path) && parent_visitor && parent_visitor.call

      index = typed_def.return.index
      search_id = lookup_arg_index(index, scope)
      return_id = new_type.object_id

      parent_scope = parent_visitor.call[0]
      types = parent_scope.is_a?(Crystal::Type) ? [parent_scope] : []
      types += parent_visitor.call[2]
      parent_index = types.index { |type| type.object_id == search_id }
      if parent_index
        parent_visitor.paths[return_id] = typed_def.return.with_index(parent_index)
      else
        parent_path = parent_visitor.paths[search_id]
        parent_visitor.paths[return_id] = parent_path.append(typed_def.return)
      end
    end

    def compute_parent_mutations(typed_def, scope)
      typed_def.mutations.each do |mutation|
        compute_parent_mutation(mutation, scope)
      end
    end

    def compute_parent_mutation(mutation, scope)
      index = mutation.path.index
      search_id = lookup_arg_index(index, scope)

      path = parent_visitor.paths[search_id]
      if path && path.path.length > 0
        new_path = path.append(mutation.path)
        if mutation.target.is_a?(Type)
          new_target = mutation.target
        else
          search_id = lookup_arg_index(mutation.target.index, scope)
          target_path = parent_visitor.paths[search_id]
          if target_path
            new_target = target_path.append(mutation.target)
          else
            new_target = mutation.target.evaluate_args(scope, args)
          end
        end
        parent_visitor.call[3].mutations << Mutation.new(new_path, new_target)
      end
    end

    def lookup_arg_index(index, scope)
      if scope.is_a?(Type)
        if index == 0
          scope.object_id
        else
          args[index - 1].type.object_id
        end
      else
        args[index].type.object_id
      end
    end

    def compute_new_type(typed_def, scope)
      if typed_def.return.is_a?(Path)
        typed_def.return.evaluate_args(scope, self.args)
      elsif typed_def.body && typed_def.body.type
        if typed_def.body.type.is_a?(MutableType)
          name = typed_def.body.type.name
          if scope.is_a?(ObjectType) && scope.name == name
            scope
          elsif parent_visitor
            parent_visitor.lookup_object_type(name) || typed_def.body.type.clone
          else
            typed_def.body.type.clone
          end
        else
          typed_def.body.type
        end
      else
        self.bind_to typed_def.body if typed_def.body
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

    def initialize(call)
      @name = call.name
      @obj = call.obj && call.obj.type
      @args = call.args.map(&:type)
      @calls = {}
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
          @calls[[obj_type.object_id] + arg_types.map(&:object_id)] = subcall
        end
      end
    end

    def simplify
      new_calls = {}
      for_each_obj do |obj_type|
        for_each_args do |arg_types|
          call_key = [obj_type.object_id] + arg_types.map(&:object_id)
          new_calls[call_key] = @calls[call_key]
        end
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
      @class_defs = []
      @paths = {}
      if @call
        @call[2].each_with_index do |type, i|
          @paths[type.object_id] = Path.new(i) if type.is_a?(MutableType)
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

    def visit_array_literal(node)
      node.type = mod.array.clone
      node.elements.each do |elem|
        node.type.element_type_var.bind_to elem
      end
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
      paths[var.type.object_id] = Path.new(0, node.name) if var.type
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

    def visit_alloc(node)
      type = lookup_object_type(node.type.name)
      node.type = type ? type : node.type
    end

    def visit_array_length(node)
      node.type = mod.int
    end

    def visit_array_get(node)
      check_array_index_is_int

      node.bind_to @scope.element_type_var
    end

    def visit_array_set(node)
      check_array_index_is_int

      @scope.element_type_var.bind_to @vars['value']
      node.bind_to @vars['value']
    end

    def visit_array_push(node)
      @scope.element_type_var.bind_to @vars['value']
      node.bind_to @vars['self']
    end

    def check_array_index_is_int
      index_type = @vars['index'].type
      if index_type != mod.int
        @call[4].args[0].raise "index must be Int, not #{index_type.name}"
      end
    end

    def lookup_object_type(name)
      if @scope.is_a?(ObjectType) && @scope.name == name
        @scope
      elsif @parent
        @parent.lookup_object_type(name)
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