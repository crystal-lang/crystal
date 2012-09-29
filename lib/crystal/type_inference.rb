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
        new_type = [@type, type].flatten.uniq
        new_type = new_type.first if new_type.length == 1
        return if new_type == @type
        self.type = new_type
      end
    end

    def update(node, type)
      add_type(type)
    end
  end

  class Call
    attr_accessor :target_def
    attr_accessor :mod

    def update_input(node, type)
      recalculate
    end

    def recalculate
      if can_calculate_type?
        scope = obj ? obj.type : mod
        untyped_def = scope.defs[name]

        typed_def = untyped_def.lookup_instance(args.map &:type)
        unless typed_def
          typed_def = untyped_def.clone
          typed_def.owner = scope

          args = {}
          args['self'] = Var.new('self').tap { |var| var.type = obj.type } if obj
          typed_def.args.each_with_index do |arg, index|
            args[arg.name] = Var.new(arg.name)
            args[arg.name].type = self.args[index].type
            typed_def.args[index].type = self.args[index].type
          end

          untyped_def.add_instance typed_def
          typed_def.body.accept TypeVisitor.new(@mod, typed_def.body, args, scope)
        end

        typed_def.body.add_observer self
        self.target_def = typed_def
      end
    end

    def can_calculate_type?
      return false if args.any? { |arg| arg.type.nil? }
      return false if obj && obj.type.nil?
      true
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

  def infer_type(node)
    mod = Crystal::Module.new
    node.accept TypeVisitor.new(mod, node)
    mod
  end

  class TypeVisitor < Visitor
    attr_accessor :mod

    def initialize(mod, root, vars = {}, scope = nil)
      @mod = mod
      @root = root
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

    def end_visit_call(node)
      if node.obj.is_a?(Const) && node.name == 'new'
        type = mod.types[node.obj.name] or compile_error_on_node "uninitialized constant #{node.obj.name}", node.obj
        node.type = type.clone
        return false
      end

      node.mod = mod
      node.args.each_with_index do |arg, index|
        arg.add_observer node, :update_input
      end
      node.obj.add_observer node, :update_input if node.obj
      node.recalculate
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

    def compile_error_on_node(message, node)
      compile_error message, node.line_number, node.column_number, node.name.length
    end

    def compile_error(message, line, column, length)
      str = "Error: #{message}"
      str << " in '#{scope[:obj].name}'" if scope[:obj]
      str << "\n\n"
      str << @root.source_code.lines.at(line - 1).chomp
      str << "\n"
      str << (' ' * (column - 1))
      str << '^'
      str << ('~' * (length - 1))
      str << "\n"
      str << "\n"
      @scopes.reverse_each do |scope|
        str << "in line #{scope[:line] || line}"
        str << ": '#{scope[:obj].name}'\n" if scope[:obj]
      end
      raise Crystal::Exception.new(str.strip)
    end
  end
end