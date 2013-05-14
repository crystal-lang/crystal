module Crystal
  class Call
    attr_accessor :mod
    attr_accessor :scope
    attr_accessor :parent_visitor
    attr_accessor :target_defs
    attr_accessor :target_macro

    def target_def
      if target_defs && target_defs.length == 1
        target_defs[0]
      else
        raise "Zero or more than one target def"
      end
    end

    def update_input(*)
      recalculate(false)
    end

    def recalculate(*)
      if obj && obj.type.is_a?(LibType)
        recalculate_lib_call
        return
      end

      return unless obj_and_args_types_set?

      # Ignore extra recalculations when more than one argument changes at the same time
      types_signature = args.map { |arg| arg.type.object_id }
      types_signature << obj.type.object_id if obj
      return if @types_signature == types_signature
      @types_signature = types_signature

      unbind_from *@target_defs if @target_defs
      unbind_from block.break if block

      if obj
        if obj.type.is_a?(UnionType)
          matches = []
          obj.type.each do |type|
            matches.concat lookup_matches_in(type)
          end
        else
          matches = lookup_matches_in(obj.type)
        end
      else
        if name == 'super'
          matches = lookup_matches_in_super
        else
          matches = lookup_matches_in(scope) || lookup_matches_in(mod)
        end
      end

      @target_defs = matches

      bind_to *matches
      bind_to block.break if block
    end

    def lookup_matches_in(owner, self_type = owner, def_name = self.name)
      arg_types = args.map(&:type)
      matches = owner.lookup_matches(def_name, arg_types, !!block)

      if !matches || matches.empty?
        if def_name == 'new' && owner.is_a?(Metaclass) && owner.instance_type.is_a?(ObjectType)
          matches = define_new owner, arg_types
        else
          # This is tricky: if no matches are found we might want to use method missing,
          # but first we need to check if the program defines that method.
          unless owner.equal?(mod)
            matches = mod.lookup_matches(def_name, arg_types, !!block)
            if !matches && owner.lookup_first_def('method_missing')
              match = Match.new
              match.def = define_method_missing owner, def_name
              match.owner = self_type
              match.arg_types = arg_types
              matches = [match]
            end
          end
        end
      end

      unless matches
        raise_matches_not_found(owner, def_name)
      end

      typed_defs = matches.map do |match|
        typed_def = match.owner.lookup_def_instance(match.def.object_id, match.arg_types) unless block
        unless typed_def
          # puts "#{owner}##{name}(#{arg_types.join ', '})"
          typed_def, typed_def_args = prepare_typed_def_with_args(match.def, owner, match.owner, match.arg_types)
          match.owner.add_def_instance(match.def.object_id, match.arg_types, typed_def) unless block
          if typed_def.body
            bubbling_exception do
              visitor = TypeVisitor.new(@mod, typed_def_args, match.owner, parent_visitor, self, owner, match.def, typed_def, match.arg_types, match.free_vars)
              typed_def.body.accept visitor
            end
          end
        end
        typed_def
      end
    end

    def raise_matches_not_found(owner, def_name)
      defs = owner.lookup_defs(def_name)
      unless defs
        if obj
          raise "undefined method '#{name}' for #{owner}"
        elsif args.length > 0 || has_parenthesis
          raise "undefined method '#{name}'"
        else
          raise "undefined local variable or method '#{name}'"
        end
      end

      defs_matching_args_length = defs.select { |a_def| a_def.args.length == self.args.length }
      if defs_matching_args_length.empty?
        all_arguments_lengths = defs.map { |a_def| a_def.args.length }.uniq
        raise "wrong number of arguments for '#{full_name(owner)}' (#{self.args.length} for #{all_arguments_lengths.join ', '})"
      end

      msg = "no overload matches '#{full_name(owner)}' with types #{args.map(&:type).join ', '}\n"
      msg << "Overloads are:"
      defs.each do |a_def|
        msg << "\n - #{full_name(owner)}(#{a_def.args.map { |arg| arg.name + ((arg_type = arg.type || arg.type_restriction) ? (" : #{arg_type}") : '') }.join ', '})"
      end
      raise msg
    end

    def lookup_matches_in_super
      parent = parent_visitor.owner.parents.first
      if args.empty? && !has_parenthesis
        self.args = parent_visitor.typed_def.args.map do |arg|
          var = Var.new(arg.name)
          var.bind_to arg
          var
        end
      end

      lookup_matches_in(parent, scope, parent_visitor.untyped_def.name)
    end

    def recalculate_lib_call
      old_target_defs = @target_defs

      untyped_def = obj.type.lookup_first_def(name) or raise "undefined fun '#{name}' for #{obj.type}"

      check_args_length_match untyped_def
      check_out_args untyped_def
      return unless obj_and_args_types_set?

      check_fun_args_types_match untyped_def

      @target_defs = [untyped_def]

      self.unbind_from *old_target_defs if old_target_defs
      self.bind_to *@target_defs
    end

    def check_out_args(untyped_def)
      untyped_def.args.each_with_index do |arg, i|
        if arg.out && self.args[i]
          unless self.args[i].out
            self.args[i].raise "argument \##{i + 1} to #{untyped_def.owner}.#{untyped_def.name} must be passed as 'out'"
          end
          var = parent_visitor.lookup_var_or_instance_var(self.args[i])
          var.bind_to arg
        end
      end
    end

    def check_fun_args_types_match(typed_def)
      string_conversions = nil
      nil_conversions = nil
      typed_def.args.each_with_index do |typed_def_arg, i|
        expected_type = typed_def_arg.type_restriction
        if self.args[i].type != expected_type
          if mod.nil.equal?(self.args[i].type) && expected_type.pointer_type?
            nil_conversions ||= []
            nil_conversions << i
          elsif (mod.string.equal?(self.args[i].type) || mod.string.hierarchy_type.equal?(self.args[i].type)) && expected_type.is_a?(PointerType) && mod.char.equal?(expected_type.var.type)
            string_conversions ||= []
            string_conversions << i
          else
            self.args[i].raise "argument \##{i + 1} to #{typed_def.owner}.#{typed_def.name} must be #{expected_type}, not #{self.args[i].type}"
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

    def check_args_length_match(untyped_def)
      call_args_count = args.length
      all_args_count = untyped_def.args.length

      if untyped_def.is_a?(External) && untyped_def.varargs && call_args_count >= all_args_count
        return
      end

      required_args_count = untyped_def.args.count { |arg| !arg.default_value }

      return if required_args_count <= call_args_count && call_args_count <= all_args_count

      raise "wrong number of arguments for '#{full_name}' (#{args.length} for #{untyped_def.args.length})"
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

    def bubbling_exception
      begin
        yield
      rescue Crystal::Exception => ex
        if obj
          raise "instantiating '#{obj.type}##{name}(#{args.map(&:type).join ', '})'", ex
        else
          raise "instantiating '#{name}(#{args.map(&:type).join ', '})'", ex
        end
      end
    end

    def prepare_typed_def_with_args(untyped_def, owner, self_type, arg_types)
      args_start_index = 0

      typed_def = untyped_def.clone
      typed_def.owner = self_type
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

    def obj_and_args_types_set?
      args.all?(&:type) && (obj.nil? || obj.type)
    end

    def define_new(scope, arg_types)
      alloc = Call.new(nil, 'allocate')

      matches = scope.type.lookup_matches('initialize', arg_types, !!block)
      if matches
        matches.map do |match|
          var = Var.new('x')
          new_vars = args.each_with_index.map { |x, i| Var.new("arg#{i}") }
          new_args = args.each_with_index.map { |x, i| Arg.new("arg#{i}") }

          init = Call.new(var, 'initialize', new_vars)

          new_match = Match.new
          new_match.def = scope.add_def Def.new('new', new_args, [
            Assign.new(var, alloc),
            init,
            var
          ])
          new_match.owner = scope
          new_match.arg_types = match.arg_types
          new_match
        end
      else
        match = Match.new
        match.def = scope.add_def Def.new('new', [], [alloc])
        match.owner = scope
        match.arg_types = arg_types
        [match]
      end
    end

    def define_method_missing(scope, name)
      missing_args = self.args.each_with_index.map { |arg, i| Arg.new("arg#{i}") }
      missing_vars = self.args.each_with_index.map { |arg, i| Var.new("arg#{i}") }
      scope.add_def Def.new(name, missing_args, [
        Call.new(nil, 'method_missing', [SymbolLiteral.new(name.to_s), missing_vars.empty? ? NilLiteral.new : ArrayLiteral.new(missing_vars)])
      ])
    end

    def full_name(owner)
      owner.is_a?(Program) ? name : "#{owner}##{name}"
    end
  end
end