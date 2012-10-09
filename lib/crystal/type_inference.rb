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
      Kernel::raise Crystal::TypeException.new(message, self, inner)
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

      typed_def.body.add_observer self
      self.target_def = typed_def
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
        untyped_def = scope.defs['new'] = Def.new('new', [], [Call.new(nil, 'alloc')])
      end
      untyped_def
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
          @calls[[obj_type] + arg_types] = subcall
        end
      end
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
    end

    def visit_bool_literal(node)
      node.type = mod.bool
    end

    def visit_int_literal(node)
      node.type = mod.int
    end

    def visit_float_literal(node)
      node.type = mod.float
    end

    def visit_char_literal(node)
      node.type = mod.char
    end

    def visit_string_literal(node)
      node.type = mod.string
    end

    def visit_def(node)
      class_def = node.parent.parent
      if class_def
        mod.types[class_def.name].defs[node.name] = node
      else
        mod.defs[node.name] = node
      end
      false
    end

    def visit_class_def(node)
      mod.types[node.name] ||= ObjectType.new node.name
      true
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
      node.else.add_observer node if node.else.any?
    end

    def visit_const(node)
      type = mod.types[node.name] or node.raise("uninitialized constant #{node.name}")
      node.type = type.metaclass
    end

    def visit_alloc(node)
      type = lookup_object_type(node.type.name)
      node.type = type ? type : node.type.clone
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