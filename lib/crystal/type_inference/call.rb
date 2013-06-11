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
      types_signature = args.map { |arg| arg.type.type_id }
      types_signature << obj.type.type_id if obj
      return if @types_signature == types_signature
      @types_signature = types_signature

      unbind_from *@target_defs if @target_defs
      unbind_from block.break if block
      @subclass_notifier.remove_subclass_observer(self) if @subclass_notifier

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

      if matches.empty?
        if def_name == 'new' && owner.metaclass? && owner.instance_type.class? && !owner.instance_type.pointer?
          new_matches = define_new owner, arg_types
          matches = new_matches unless new_matches.empty?
        else
          # This is tricky: if no matches are found we might want to use method missing,
          # but first we need to check if the program defines that method.
          unless owner.equal?(mod)
            mod_matches = mod.lookup_matches(def_name, arg_types, !!block)
            if mod_matches.empty? && owner.lookup_first_def('method_missing')
              match = Match.new
              match.def = define_method_missing owner, def_name
              match.owner = self_type
              match.arg_types = arg_types
              matches = Matches.new([match], true)
            else
              matches = mod_matches unless mod_matches.empty?
            end
          end
        end
      end

      if matches.empty?
        raise_matches_not_found(matches.owner || owner, def_name, matches)
      end

      if owner.hierarchy?
        owner.base_type.add_subclass_observer(self)
        @subclass_notifier = owner.base_type
      end

      typed_defs = matches.map do |match|
        yield_vars = match_block_arg(match)
        use_cache = !block || match.def.block_arg || match.def.yields == 0
        block_type = block && block.body && match.def.block_arg ? block.body.type : nil

        typed_def = match.owner.lookup_def_instance(match.def.object_id, match.arg_types, block_type) if use_cache
        unless typed_def
          # puts "#{owner}##{name}(#{arg_types.join ', '})#{block_type ? "{ #{block_type} }" : ""}"
          typed_def, typed_def_args = prepare_typed_def_with_args(match.def, owner, match.owner, match.arg_types)
          match.owner.add_def_instance(match.def.object_id, match.arg_types, block_type, typed_def) if use_cache
          if typed_def.body
            bubbling_exception do
              visitor = TypeVisitor.new(@mod, typed_def_args, match.owner, parent_visitor, self, owner, match.def, typed_def, match.arg_types, match.free_vars, yield_vars)
              typed_def.body.accept visitor
            end
          end
        end
        typed_def
      end
    end

    def on_new_subclass
      @types_signature = nil
      recalculate
    end

    def match_block_arg(match)
      yield_vars = nil

      if (block_arg = match.def.block_arg) || match.def.yields == 0
        ident_lookup = IdentLookupVisitor.new(mod, match)

        if block_arg && block_arg.inputs
          yield_vars = block_arg.inputs.each_with_index.map do |input, i|
            Var.new("var#{i}", lookup_node_type(ident_lookup, input))
          end
          block.args.each_with_index do |arg, i|
            var = yield_vars[i]
            if var
              arg.bind_to var
            else
              arg.bind_to mod.nil_var
            end
          end
        else
          block.args.each do |arg|
            arg.bind_to mod.nil_var
          end
        end

        block.accept parent_visitor

        if block_arg && block_arg.output
          block_type = block.body ? block.body.type : mod.nil
          matched = match.type_lookup.match_arg(block_type, block_arg.output, match.owner, match.owner, match.free_vars)
          unless matched
            raise "block expected to return #{block_arg.output}, not #{block_type}"
          end
          block.body.freeze_type = true if block.body
        end
      end

      yield_vars
    end

    def lookup_node_type(visitor, node)
      node.accept visitor
      visitor.type
    end

    class IdentLookupVisitor < Visitor
      attr_reader :type

      def initialize(mod, match)
        @mod = mod
        @match = match
      end

      def visit_ident(node)
        if node.names.length == 1 && @match.free_vars && type = @match.free_vars[node.names]
          @type = type
          return
        end

        @type = (node.global ? @mod : @match.type_lookup).lookup_type(node.names)

        unless @type
          node.raise("uninitialized constant #{node}")
        end
      end

      def visit_new_generic_class(node)
        node.name.accept self

        instance_type = @type
        unless instance_type.type_vars
          node.raise "#{instance_type} is not a generic class"
        end

        if instance_type.type_vars.length != node.type_vars.length
          node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.length} for #{instance_type.type_vars.length})"
        end

        type_vars = []
        node.type_vars.each do |type_var|
          type_var.accept self
          type_vars.push @type
        end

        @type = instance_type.instantiate(type_vars)
        false
      end
    end

    def raise_matches_not_found(owner, def_name, matches = nil)
      if owner.struct?
        if def_name.end_with?('=')
          def_name = def_name[0 .. -2]
        end

        var = owner.vars[def_name]
        if var
          args[0].raise "field '#{def_name}' of struct #{owner} has type #{var.type}, not #{args[0].type}"
        else
          raise "struct #{owner} has no field '#{def_name}'"
        end
      end

      defs = owner.lookup_defs(def_name)
      if defs.empty?
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

      if defs_matching_args_length.length > 0
        if block && defs_matching_args_length.all? { |a_def| !a_def.yields }
          raise "'#{full_name(owner)}' is not expected to be invoked with a block, but a block was given"
        elsif !block && defs_matching_args_length.all?(&:yields)
          raise "'#{full_name(owner)}' is expected to be invoked with a block, but no block was given"
        end
      end

      arg_names = []

      msg = "no overload matches '#{full_name(owner)}'"
      msg << " with types #{args.map(&:type).join ', '}" if args.length < 0
      msg << "\n"
      msg << "Overloads are:"
      defs.each do |a_def|
        arg_names.push a_def.args.map(&:name)

        msg << "\n - #{full_name(owner)}(#{a_def.args.map { |arg| arg.name + ((arg_type = arg.type || arg.type_restriction) ? (" : #{arg_type}") : '') }.join ', '}"
          msg << ", &block" if a_def.yields
        msg << ")"
      end

      if matches && matches.cover.is_a?(Cover)
        missing = matches.cover.missing
        arg_names = arg_names.uniq
        arg_names = arg_names.length == 1 ? arg_names[0] : nil
        unless missing.empty?
          msg << "\nCouldn't find overloads for these types:"
          missing.each_with_index do |missing_types|
            if arg_names
              msg << "\n - #{full_name(owner)}(#{missing_types.each_with_index.map { |missing_type, i| "#{arg_names[i]} : #{missing_type}" }.join ', '}"
            else
              msg << "\n - #{full_name(owner)}(#{missing_types.join ', '}"
            end
            msg << ", &block" if block
            msg << ")"
          end
        end
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
          if self.args[i].type.nil_type? && expected_type.pointer?
            nil_conversions ||= []
            nil_conversions << i
          elsif (mod.string.equal?(self.args[i].type) || mod.string.hierarchy_type.equal?(self.args[i].type)) && expected_type.pointer? && mod.char.equal?(expected_type.var.type)
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
        var.bind_to(var)
        args[arg.name] = var
        arg.type = type
      end

      [typed_def, args]
    end

    def obj_and_args_types_set?
      args.all?(&:type) && (obj.nil? || obj.type)
    end

    def define_new(scope, arg_types)
      matches = scope.instance_type.lookup_matches('initialize', arg_types, !!block)
      if matches.empty?
        defs = scope.instance_type.lookup_defs('initialize')
        if defs.length > 0
          raise_matches_not_found scope.instance_type, 'initialize'
        end

        if defs.length == 0 && arg_types.length > 0
          raise "wrong number of arguments for '#{full_name(scope.instance_type)}' (#{self.args.length} for 0)"
        end

        alloc = Call.new(nil, 'allocate')

        match = Match.new
        match.def = scope.add_def Def.new('new', [], [alloc])
        match.owner = scope
        match.arg_types = arg_types
        Matches.new([match], true)
      else
        ms = matches.map do |match|
          if match.free_vars.empty?
            alloc = Call.new(nil, 'allocate')
          else
            type_vars = Array.new(scope.instance_type.type_vars.length)
            match.free_vars.each do |names, type|
              if names.length == 1
                idx = scope.instance_type.type_vars.index(names[0])
                if idx
                  type_vars[idx] = Ident.new(names)
                end
              end
            end

            if type_vars.all?
              new_generic = NewGenericClass.new(Ident.new([scope.instance_type.name]), type_vars)
              alloc = Call.new(new_generic, 'allocate')
            else
              alloc = Call.new(nil, 'allocate')
            end
          end

          var = Var.new('x')
          new_vars = args.each_with_index.map { |x, i| Var.new("arg#{i}") }
          new_args = args.each_with_index.map do |x, i|
            arg = Arg.new("arg#{i}")
            arg.type_restriction = match.def.args[i].type_restriction if match.def.args[i]
            arg
          end

          init = Call.new(var, 'initialize', new_vars)

          new_match = Match.new
          new_match.def = scope.add_def Def.new('new', new_args, [
            Assign.new(var, alloc),
            init,
            var
          ])
          new_match.owner = scope
          new_match.arg_types = match.arg_types
          new_match.free_vars = match.free_vars
          new_match
        end
        Matches.new(ms, true)
      end
    end

    def define_method_missing(scope, name)
      missing_args = self.args.each_with_index.map { |arg, i| Arg.new("arg#{i}") }
      missing_vars = self.args.each_with_index.map { |arg, i| Var.new("arg#{i}") }
      args = missing_vars.empty? ? NilLiteral.new : ArrayLiteral.new(missing_vars)

      missing_def = Def.new(name, missing_args, [
        Call.new(nil, 'method_missing', [SymbolLiteral.new(name.to_s), args])
      ])
      missing_def = mod.normalize(missing_def)
      scope.add_def missing_def
    end

    def full_name(owner)
      owner.is_a?(Program) ? name : "#{owner}##{name}"
    end
  end
end
