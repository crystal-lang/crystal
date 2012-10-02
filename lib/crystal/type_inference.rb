require 'observer'

module Crystal
  class ASTNode
    attr_accessor :type
    attr_accessor :observers

    def type=(type)
      return if type.nil? || @type == type
      @type = type
      notify_observers
    end

    def add_observer(observer, func=:update)
      @observers ||= {}
      @observers[observer] = func
      observer.send func, self, @type if @type
    end

    def notify_observers
      return if @observers.nil?
      @observers.each do |observer, func|
        observer.send func, self, @type
      end
    end

    def add_type(type)
      return if type.nil?
      if @type.nil?
        self.type = type
      else
        self.type = Type.merge(@type, type)
      end
    end

    def update(node, type)
      add_type(type)
    end

    def raise(message, inner = nil)
      Kernel::raise Crystal::Exception.new(message, self, inner)
    end
  end

  class Call
    attr_accessor :target_def
    attr_accessor :mod

    def update_input(node, type)
      recalculate
    end

    def recalculate
      return unless can_calculate_type?

      scope = obj ? obj.type : mod

      if has_unions?
        dispatch = Dispatch.new(mod, name, scope, args.map(&:type))
        dispatch.add_observer self
        self.target_def = dispatch
        return
      end

      untyped_def = scope.defs[name]

      check_method_exists untyped_def
      check_args_match untyped_def

      arg_types = args.map &:type
      typed_def = untyped_def.lookup_instance(arg_types)
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

        untyped_def.add_instance typed_def

        begin
          typed_def.body.accept TypeVisitor.new(@mod, args, scope)
        rescue Crystal::Exception => ex
          raise "instantiating '#{name}'", ex
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
    def initialize(mod, name, scope, arg_types)
      @mod = mod
      @name = name
      @scope = scope
      @arg_types = arg_types
    end
  end

  def infer_type(node)
    mod = Crystal::Module.new
    node.accept TypeVisitor.new(mod)
    mod
  end

  class TypeVisitor < Visitor
    attr_accessor :mod

    def initialize(mod, vars = {}, scope = nil)
      @mod = mod
      @vars = vars
      @scope = scope
    end

    def visit_bool(node)
      node.type = mod.bool
    end

    def visit_int(node)
      node.type = mod.int
    end

    def visit_float(node)
      node.type = mod.float
    end

    def visit_char(node)
      node.type = mod.char
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
      var = lookup_instance_var node.name
      var.add_observer node
    end

    def end_visit_assign(node)
      node.value.add_observer node

      if node.target.is_a?(InstanceVar)
        var = lookup_instance_var node.target.name
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

    def visit_call(node)
      if node.obj.is_a?(Const) && node.name == 'new'
        type = mod.types[node.obj.name] or node.obj.raise("uninitialized constant #{node.obj.name}")
        node.type = type.clone
        return false
      end

      node.mod = mod
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

    def lookup_instance_var(name)
      var = @scope.instance_vars[name]
      unless var
        var = Var.new name
        @scope.instance_vars[name] = var
      end
      var
    end
  end
end