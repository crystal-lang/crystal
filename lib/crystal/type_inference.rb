module Crystal
  def infer_type(node)
    mod = Crystal::Module.new
    node.accept TypeVisitor.new(mod)
    unify node
    mod
  end

  class ASTNode
    attr_accessor :type
    attr_accessor :observers

    def type=(type)
      return if type.nil? || @type == type
      @type = type
      notify_observers
    end

    def add_observer(observer, func = :update)
      @observers ||= {}
      @observers[observer] = func
      observer.send func, @type if @type
    end

    def notify_observers
      return unless @observers
      @observers.each do |observer, func|
        observer.send func, @type
      end
    end

    def add_type(new_type)
      return unless new_type

      self.type = @type ? Type.merge(@type, new_type) : new_type
      new_type.add_observer self if is_a?(Var)
    end

    def update(type)
      add_type(type)
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
      recalculate
    end

    def recalculate
      return unless can_calculate_type?

      if has_unions?
        dispatch = Dispatch.new(self)
        dispatch.add_observer self
        self.target_def = dispatch
        return
      end

      scope, untyped_def = compute_scope_and_untyped_def

      check_method_exists untyped_def
      check_args_match untyped_def

      arg_types = args.map &:type
      typed_def = untyped_def.lookup_instance(arg_types) || parent_visitor.lookup_def_instance(scope, untyped_def, arg_types)
      unless typed_def
        check_frozen untyped_def, arg_types

        typed_def = untyped_def.clone
        typed_def.owner = scope

        args = {}
        args['self'] = Var.new('self', obj.type) if obj
        typed_def.args.each_with_index do |arg, index|
          type = self.args[index].type
          args[arg.name] = Var.new(arg.name, type)
          typed_def.args[index].type = type
        end

        if typed_def.body
          begin
            typed_def.body.accept TypeVisitor.new(@mod, args, scope, parent_visitor, [scope, untyped_def, arg_types, typed_def])
          rescue Crystal::Exception => ex
            if obj
              raise "instantiating '#{obj.type.name}##{name}'", ex
            else
              raise "instantiating '#{name}'", ex
            end
          end
        end
      end

      typed_def.body.add_observer self if typed_def.body

      self.target_def = typed_def
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

    def add_instance(a_def)
      @instances ||= {}
      @instances[a_def.args.map(&:type)] = a_def
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
          subcall.add_observer self
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

  class Var
    def update_from_object_type(_)
      if type.is_a?(UnionType)
        add_type(type.types.to_a.first)
      end
    end
  end

  class TypeVisitor < Visitor
    attr_accessor :mod

    def initialize(mod, vars = {}, scope = nil, parent = nil, call = nil)
      @mod = mod
      @vars = vars
      @scope = scope
      @parent = parent
      @call = call
      @class_defs = []
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
      var.add_observer node
    end

    def visit_instance_var(node)
      var = @scope.lookup_instance_var node.name
      var.add_observer node
    end

    def end_visit_assign(node)
      node.value.add_observer node

      if node.target.is_a?(InstanceVar)
        var = @scope.lookup_instance_var node.target.name
      else
        var = lookup_var node.target.name
      end
      node.add_observer var
    end

    def end_visit_expressions(node)
      if node.last
        node.last.add_observer node
      else
        node.type = mod.void
      end
    end

    def end_visit_while(node)
      node.type = mod.void
    end

    def end_visit_if(node)
      node.then.add_observer node
      node.else.add_observer node if node.else
    end

    def visit_const(node)
      type = mod.types[node.name] or node.raise("uninitialized constant #{node.name}")
      node.type = type.metaclass
    end

    def visit_alloc(node)
      type = lookup_object_type(node.type.name)
      node.type = type ? type : node.type.clone
    end

    def visit_static_array_new(node)
      node.type = mod.static_array.clone
    end

    def visit_static_array_set(node)
      @vars['value'].add_observer @scope.element_type_var
      @vars['value'].add_observer node
    end

    def visit_static_array_get(node)
      @scope.element_type_var.add_observer node
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