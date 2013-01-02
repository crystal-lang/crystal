require_relative 'ast'

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

  class ASTNode
    attr_accessor :type
    attr_accessor :dependencies
    attr_accessor :creates_new_type

    def set_type(type)
      @type = type
    end

    def type=(type)
      return if type.nil? || @type.object_id == type.object_id

      @type = type
      notify_observers
    end

    def bind_to(*nodes)
      @dependencies ||= []
      @dependencies += nodes
      nodes.each do |node|
        node.add_observer self
      end

      if @dependencies.length > 1 && nodes.length == 1 && nodes[0].type
        new_type = Type.merge(@type, nodes[0].type)
      else
        new_type = Type.merge(*dependencies.map(&:type))
      end
      return if @type.object_id == new_type.object_id
      @type = new_type
      @dirty = true
      propagate
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
      @observers.keys.each &:propagate
    end

    def update(from = self)
      new_type = Type.merge(*dependencies.map(&:type)) if dependencies
      return if new_type.nil? || @type == new_type
      @type = new_type
      @dirty = true
    end

    def propagate
      if @dirty
        @dirty = false
        notify_observers
      end
    end

    def raise(message, inner = nil)
      Kernel::raise Crystal::TypeException.for_node(self, message, inner)
    end
  end

  class Ident
    attr_accessor :target_const
  end

  class ArrayLiteral
    attr_accessor :expanded
  end

  class RangeLiteral
    attr_accessor :expanded
  end

  class RegexpLiteral
    attr_accessor :expanded
  end

  class HashLiteral
    attr_accessor :expanded
  end

  class Require
    attr_accessor :expanded
  end

  class Case
    attr_accessor :expanded
  end

  class Arg
    def self.new_with_type(name, type)
      arg = Arg.new(name)
      arg.type = type
      arg
    end
  end

  class Block
    def break
      @break ||= Var.new("%break")
    end
  end

  class Call
    attr_accessor :target_def
    attr_accessor :target_macro
    attr_accessor :mod
    attr_accessor :scope
    attr_accessor :parent_visitor

    def update_input(*)
      recalculate(false)
    end

    def recalculate(*)
      set_external_out_args_type

      return unless can_calculate_type?

      # Ignore extra recalculations when more than one argument changes at the same time
      types_signature = args.map { |arg| arg.type.object_id }
      types_signature << obj.type.object_id if obj
      return if @types_signature == types_signature
      @types_signature = types_signature

      if has_unions?
        if @dispatch
          @dispatch.recalculate_for_call(self)
        else
          @dispatch = Dispatch.new
          self.bind_to @dispatch
          self.target_def = @dispatch
          @dispatch.initialize_for_call(self)
        end
        return
      end

      owner, self_type, untyped_def_and_error_matches = compute_owner_self_type_and_untyped_def
      untyped_def, error_matches = untyped_def_and_error_matches

      check_method_exists untyped_def, error_matches
      check_args_match untyped_def

      arg_types = args.map &:type

      if untyped_def.is_a?(External)
        typed_def = untyped_def
        check_args_type_match typed_def
      else
        typed_def = untyped_def.lookup_instance(arg_types) ||
                    self_type.lookup_def_instance(name, arg_types) ||
                    parent_visitor.lookup_def_instance(owner, untyped_def, arg_types)
        unless typed_def
          typed_def, args = prepare_typed_def_with_args(untyped_def, owner, self_type, arg_types)

          if typed_def.body
            bubbling_exception do
              visitor = TypeVisitor.new(@mod, args, self_type, parent_visitor, [owner, untyped_def, arg_types, typed_def, self])
              typed_def.body.accept visitor
              self.creates_new_type = typed_def.creates_new_type = typed_def.body.creates_new_type
            end
          end

          self_type.add_def_instance(name, arg_types, typed_def) if Crystal::CACHE && !block && !creates_new_type
        end
      end

      self.bind_to typed_def
      self.bind_to(block.break) if block
      self.target_def = typed_def
    end

    def set_external_out_args_type
      if obj && obj.type.is_a?(LibType)
        scope, untyped_def = obj.type, obj.type.lookup_first_def(name)
        if untyped_def
          # External call: set type of out arguments
          untyped_def.args.each_with_index do |arg, i|
            if arg.out && self.args[i]
              unless self.args[i].out
                self.args[i].raise "argument \##{i + 1} to #{untyped_def.owner.full_name}.#{untyped_def.name} must be passed as 'out'"
              end
              var = parent_visitor.lookup_var_or_instance_var(self.args[i])
              var.bind_to arg
            end
          end
        end
      end
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

    def prepare_typed_def_with_args(untyped_def, owner, self_type, arg_types)
      args_start_index = 0

      typed_def = untyped_def.clone
      typed_def.owner = owner
      typed_def.bind_to typed_def.body if typed_def.body

      args = {}
      args['self'] = Var.new('self', self_type) if self_type.is_a?(Type)

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
        call = target_def.calls.values.first
        self.target_def = call.target_def
        self.block = call.block
      end
    end

    def can_calculate_type?
      args.all?(&:type) && (obj.nil? || obj.type)
    end

    def has_unions?
      (obj && obj.type.is_a?(UnionType)) || args.any? { |a| a.type.is_a?(UnionType) }
    end

    def compute_owner_self_type_and_untyped_def
      if obj && obj.type
        if obj.type.is_a?(LibType)
          return [obj.type, obj.type, obj.type.lookup_first_def(name)]
        else
          return [obj.type, obj.type, lookup_method(obj.type, name, true)]
        end
      end

      unless scope
        return [mod, mod, mod.lookup_def(name, args, !!block)]
      end

      if name == 'super'
        parent = parent_visitor.call[0].parents.first
        if args.empty? && !has_parenthesis
          self.args = parent_visitor.call[3].args.map do |arg|
            var = Var.new(arg.name)
            var.bind_to arg
            var
          end
        end

        return [parent, scope, lookup_method(parent, parent_visitor.call[1].name)]
      end

      untyped_def, error_matches = lookup_method(scope, name)
      if untyped_def
        return [scope, scope, [untyped_def, error_matches]]
      end

      mod_def, mod_error_matches = mod.lookup_def(name, args, !!block)
      if mod_def || !(missing = scope.lookup_first_def('method_missing'))
        return [mod, mod, [mod_def, mod_error_matches || error_matches]]
      end

      untyped_def = define_missing scope, name
      [scope, scope, untyped_def]
    end

    def lookup_method(scope, name, use_method_missing = false)
      untyped_def, error_matches = scope.lookup_def(name, args, !!block)
      unless untyped_def
        if name == 'new' && scope.is_a?(Metaclass) && scope.instance_type.is_a?(ObjectType)
          untyped_def = define_new scope, name
        elsif use_method_missing && scope.lookup_first_def('method_missing')
          untyped_def = define_missing scope, name
        end
      end
      [untyped_def, error_matches]
    end

    def define_new(scope, name)
      alloc = Call.new(nil, 'alloc')
      alloc.location = location
      alloc.name_column_number = name_column_number

      the_initialize, error_matches = scope.type.lookup_def('initialize', args, !!block)
      if the_initialize
        var = Var.new('x')
        new_vars = args.each_with_index.map { |x, i| Var.new("arg#{i}") }
        new_args = args.each_with_index.map { |x, i| Arg.new("arg#{i}") }

        init = Call.new(var, 'initialize', new_vars)
        init.location = location
        init.name_column_number = name_column_number
        init.name_length = 3

        untyped_def = scope.add_def Def.new('new', new_args, [
          Assign.new(var, alloc),
          init,
          var
        ])
      else
        untyped_def = scope.add_def Def.new('new', [], [alloc])
      end
    end

    def define_missing(scope, name)
      missing_args = self.args.each_with_index.map { |arg, i| Arg.new("arg#{i}") }
      missing_vars = self.args.each_with_index.map { |arg, i| Var.new("arg#{i}") }
      scope.add_def Def.new(name, missing_args, [
        Call.new(nil, 'method_missing', [SymbolLiteral.new(name.to_s), ArrayLiteral.new(missing_vars)])
      ])
    end

    def check_method_exists(untyped_def, error_matches)
      return if untyped_def

      if !error_matches || error_matches.length == 0
        if obj
          raise "undefined method '#{name}' for #{obj.type.full_name}"
        elsif args.length > 0 || has_parenthesis
          raise "undefined method '#{name}'"
        else
          raise "undefined local variable or method '#{name}'"
        end
      elsif error_matches.length == 1 && args.length != error_matches[0].args.length
        if obj
          raise "wrong number of arguments for '#{obj.type.full_name}##{name}' (#{args.length} for #{error_matches[0].args.length})"
        else
          raise "wrong number of arguments for '#{name}' (#{args.length} for #{error_matches[0].args.length})"
        end
      else
        if obj
          msg = "no overload or ambiguos call for '#{obj.type.full_name}##{name}' with types [#{args.map { |arg| arg.type.full_name }.join ', '}]\n"
        else
          msg = "no overload or ambiguos call for '#{name}' with types [#{args.map { |arg| arg.type.full_name }.join ', '}].\n"
        end
        msg << "Overload types are:"
        error_matches.each do |error_match|
          msg << "\n - [#{error_match.args.map { |arg| arg.type ? arg.type.full_name : '?' }.join ', '}]"
        end
        raise msg
      end
    end

    def check_args_match(untyped_def)
      required_args_count = untyped_def.args.count { |arg| !arg.default_value }
      all_args_count = untyped_def.args.length
      call_args_count = args.length

      return if required_args_count <= call_args_count && call_args_count <= all_args_count

      raise "wrong number of arguments for '#{name}' (#{args.length} for #{untyped_def.args.length})"
    end

    def check_args_type_match(typed_def)
      string_conversions = nil
      nil_conversions = nil
      typed_def.args.each_with_index do |typed_def_arg, i|
        expected_type = typed_def_arg.type
        if self.args[i].type != expected_type
          if mod.nil.equal?(self.args[i].type) && expected_type.is_a?(PointerType)
            nil_conversions ||= []
            nil_conversions << i
          elsif mod.string.equal?(self.args[i].type) && expected_type.is_a?(PointerType) && mod.char.equal?(expected_type.var.type)
            string_conversions ||= []
            string_conversions << i
          else
            self.args[i].raise "argument \##{i + 1} to #{typed_def.owner.full_name}.#{typed_def.name} must be #{expected_type.full_name}, not #{self.args[i].type}"
          end
        end
      end

      if string_conversions
        string_conversions.each do |i|
          call = Call.new(self.args[i], 'cstr')
          call.mod = mod
          call.scope = scope
          call.parent_visitor = parent_visitor
          call.recalculate
          self.args[i] = call
        end
      end

      if nil_conversions
        nil_conversions.each do |i|
          self.args[i] = NilPointer.new(typed_def.args[i].type)
        end
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

  class Macro
    attr_accessor :instances

    def add_instance(fun, arg_types)
      @instances ||= {}
      @instances[arg_types] = fun
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
      @calls = {}
      recalculate(call)
    end

    def recalculate_for_call(call)
      @name = call.name
      @obj = call.obj && call.obj.type
      @args = call.args.map(&:type)
      recalculate(call)
    end

    def recalculate(call)
      for_each_obj do |obj_type|
        for_each_args do |arg_types|
          call_key = [obj_type.object_id, arg_types.map(&:object_id)]
          next if @calls[call_key]

          subcall = Call.new(obj_type ? Var.new('%self', obj_type) : nil, name, arg_types.map.with_index { |arg_type, i| Var.new("%arg#{i}", arg_type) })
          subcall.mod = call.mod
          subcall.parent_visitor = call.parent_visitor
          subcall.scope = call.scope
          subcall.location = call.location
          subcall.name_column_number = call.name_column_number
          subcall.block = call.block.clone
          subcall.block.accept call.parent_visitor if subcall.block
          subcall.recalculate
          self.bind_to subcall
          @calls[call_key] = subcall
        end
      end
    end

    def simplify
      return if @simplified
      new_calls = {}
      @calls.values.each do |call|
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
      @calls.values.each do |call|
        call.accept visitor
      end
    end
  end

  class TypeVisitor < Visitor
    attr_accessor :mod
    attr_accessor :paths
    attr_accessor :call
    attr_accessor :block
    @@regexps = {}

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
            arg.type = lookup_ident_type(arg.type_restriction)
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
        type.generic = node.generic || parent.generic
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
        fun_arg.type = maybe_ptr_type(arg.type.type.instance_type, arg.ptr)
        fun_arg.out = arg.out
        fun_arg
      end
      return_type = maybe_ptr_type(node.return_type ? node.return_type.type.instance_type : mod.nil, node.ptr)
      current_type.fun node.name, node.real_name, args, return_type
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
      node.bind_to var
      node.creates_new_type = var.creates_new_type
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
      case target
      when Var
        var = lookup_var target.name
        target.bind_to var

        value.accept self

        if node
          node.bind_to value
          var.bind_to node
        else
          var.bind_to value
        end

        if node
          node.creates_new_type = var.creates_new_type ||= value.creates_new_type
        end
      when InstanceVar
        var = lookup_instance_var target, (@nest_count > 0)

        value.accept self

        if node
          node.bind_to value
          var.bind_to node
        else
          var.bind_to value
        end

        if node
          node.creates_new_type = var.creates_new_type ||= value.creates_new_type
        end
      when Ident
        type = current_type.types[target.names.first]
        if type
          target.raise "already initialized constant #{target}"
        end

        value.accept self
        target.bind_to value

        current_type.types[target.names.first] = Const.new(target.names.first, value, current_type)
      when Global
        var = mod.global_vars[target.name] ||= Var.new(target.name)

        value.accept self
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
        node.creates_new_type = node.last.creates_new_type
      else
        node.type = mod.nil
      end
    end

    def visit_while(node)
      node.cond = Call.new(node.cond, 'to_b')
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
      node.cond = Call.new(node.cond, 'to_b')
      node.cond.accept self

      @nest_count += 1
      node.then.accept self if node.then
      node.else.accept self if node.else
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

    def visit_alloc(node)
      if !node.alloc_type.generic && Crystal::GENERIC
        node.type = node.alloc_type
      else
        type = lookup_object_type(node.alloc_type.name)
        node.type = type ? type : node.alloc_type.clone
        node.creates_new_type = true
      end
    end

    def visit_array_literal(node)
      @@array_count ||= 0
      @@array_count += 1

      if node.elements.empty?
        exps = Call.new(Ident.new(['Array'], true), 'new')
      else
        ary_name = "#array_#{@@array_count}"

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

      node.creates_new_type = node.expanded.creates_new_type

      false
    end

    def visit_hash_literal(node)
      @@hash_count ||= 0
      @@hash_count += 1

      if node.key_values.empty?
        exps = Call.new(Ident.new(['Hash'], true), 'new')
      else
        hash_name = "#hash_#{@@hash_count}"

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

      node.creates_new_type = node.expanded.creates_new_type

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
        Crystal.build macro_nodes, mod, @@macro_llvm_mod
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

    def end_visit_return(node)
      node.exps.each do |exp|
        @call[3].bind_to exp
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
      node.creates_new_type = true
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
      a_if = nil
      final_if = nil
      node.whens.each do |wh|
        final_comp = nil
        wh.conds.each do |cond|
          comp = Call.new(cond, :'===', [node.cond])
          if final_comp
            final_comp = Call.new(final_comp, :'||', [comp])
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
  end
end
