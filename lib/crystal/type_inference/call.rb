module Crystal
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

      if has_unions_in_obj? || (obj && obj.type.has_restricted_defs?(name) && has_unions_in_args?)
        compute_dispatch
        return
      end

      owner, self_type, untyped_def_and_error_matches = compute_owner_self_type_and_untyped_def
      untyped_def, error_matches = untyped_def_and_error_matches

      check_method_exists untyped_def, error_matches
      check_args_match untyped_def

      if untyped_def.is_a?(External)
        typed_def = untyped_def
        check_args_type_match typed_def
      else
        arg_types = args.map &:type
        typed_def = untyped_def.lookup_instance(arg_types) ||
                    self_type.lookup_def_instance(name, arg_types) ||
                    parent_visitor.lookup_def_instance(owner, untyped_def, arg_types)
        unless typed_def
          # puts "#{obj ? obj.type : scope}.#{name}"
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

      @recalculate_count ||= 0
      @recalculate_count += 1
      recalculate_count = @recalculate_count

      self.bind_to typed_def
      self.bind_to(block.break) if block

      if recalculate_count == @recalculate_count
        self.target_def = typed_def
      end
    end

    def compute_dispatch
      if @dispatch
        @dispatch.recalculate_for_call(self)
      else
        @dispatch = Dispatch.new
        self.bind_to @dispatch
        self.target_def = @dispatch
        @dispatch.initialize_for_call(self)
      end
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
          raise "instantiating '#{obj.type.name}##{name}(#{args.map(&:type).join ', '})'", ex
        else
          raise "instantiating '#{name}(#{args.map(&:type).join ', '})'", ex
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
        var = Var.new(arg.name, type)
        var.location = arg.location
        args[arg.name] = var
        arg.type = type
      end

      if self.args.length < untyped_def.args.length
        typed_def.args = typed_def.args[0 ... self.args.length]
      end

      # Declare name = default_value for each default value that wasn't given
      self.args.length.upto(untyped_def.args.length - 1).each do |index|
        arg = untyped_def.args[index]
        assign = Assign.new(Var.new(arg.name), arg.default_value.clone)
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
      has_unions_in_obj? || has_unions_in_args?
    end

    def has_unions_in_obj?
      obj && obj.type.is_a?(UnionType)
    end

    def has_unions_in_args?
      args.any? { |a| a.type.is_a?(UnionType) }
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
        raise "wrong number of arguments for '#{full_name}' (#{args.length} for #{error_matches[0].args.length})"
      elsif error_matches.length == 1 && !block && error_matches[0].yields
        raise "#{full_name} expects a block"
      elsif error_matches.length == 1 && block && !error_matches[0].yields
        raise "#{full_name} doesn't expect a block"
      else
        msg = "no overload or ambiguos call for '#{full_name}' with types #{args.map { |arg| arg.type.full_name }.join ', '}\n"
        msg << "Overloads are:"
        error_matches.each do |error_match|
          msg << "\n - #{full_name}(#{error_match.args.map { |arg| arg.name + (arg.type ? (" : " + arg.type.full_name) : '') }.join ', '})"
        end
        raise msg
      end
    end

    def check_args_match(untyped_def)
      call_args_count = args.length
      all_args_count = untyped_def.args.length

      if untyped_def.is_a?(External) && untyped_def.varargs && call_args_count >= all_args_count
        return
      end

      required_args_count = untyped_def.args.count { |arg| !arg.default_value }

      return if required_args_count <= call_args_count && call_args_count <= all_args_count

      raise "wrong number of arguments for '#{full_name}' (#{args.length} for #{untyped_def.args.length})"
    end

    def full_name
      obj ? "#{obj.type.full_name}##{name}" : name
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

      if typed_def.varargs
        typed_def.args.length.upto(args.length - 1) do |i|
          if mod.string.equal?(self.args[i].type)
            string_conversions ||= []
            string_conversions << i
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
end