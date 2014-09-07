require "../ast"
require "../types"
require "../primitives"
require "../similar_name"
require "type_lookup"

module Crystal
  class Call
    property! scope
    property! parent_visitor
    property target_defs
    property expanded

    def mod
      scope.program
    end

    def target_def
      if defs = @target_defs
        if defs.length == 1
          return defs.first
        else
          ::raise "#{defs.length} target defs for #{self}"
        end
      end

      ::raise "Zero target defs for #{self}"
    end

    def update_input(from)
      recalculate
    end

    def recalculate
      obj = @obj
      obj_type = obj.type? if obj

      if obj_type.is_a?(LibType)
        recalculate_lib_call(obj_type)
        return
      elsif !obj || (obj_type && !obj_type.is_a?(LibType))
        check_not_lib_out_args
      end

      if args.any? &.type?.try &.no_return?
        set_type mod.no_return
        return
      end

      return unless obj_and_args_types_set?

      replace_splats

      # Ignore extra recalculations when more than one argument changes at the same time
      # types_signature = args.map { |arg| arg.type.type_id }
      # types_signature << obj.type.type_id if obj
      # return if @types_signature == types_signature
      # @types_signature = types_signature

      block = @block

      unbind_from @target_defs if @target_defs
      unbind_from block.break if block
      @subclass_notifier.try &.remove_subclass_observer(self)

      @target_defs = nil

      if block_arg = @block_arg
        replace_block_arg_with_block(block_arg)
      end

      if obj
        matches = lookup_matches_in(obj.type)
      elsif name == "super"
        matches = lookup_matches_in_super
      elsif name == "previous_def"
        matches = lookup_previous_def_matches
      else
        matches = lookup_matches_in scope
      end

      # If @target_defs is set here it means there was a recalculation
      # fired as a result of a recalculation. We keep the last one.

      return if @target_defs

      @target_defs = matches

      bind_to matches if matches
      bind_to block.break if block

      if (parent_visitor = @parent_visitor) && parent_visitor.typed_def? && matches && matches.any?(&.raises)
        parent_visitor.typed_def.raises = true
      end
    end

    def lookup_matches_in(owner : AliasType)
      lookup_matches_in(owner.remove_alias)
    end

    def lookup_matches_in(owner : UnionType)
      owner.union_types.flat_map { |type| lookup_matches_in(type) }
    end

    def lookup_matches_in(owner : Program, self_type = nil, def_name = self.name)
      lookup_matches_in_type(owner, self_type, def_name)
    end

    def lookup_matches_in(owner : NonGenericModuleType)
      including_types = owner.including_types
      if including_types
        owner.add_subclass_observer(self)
        @subclass_notifier = owner

        lookup_matches_in(including_types)
      else
        raise "no type includes #{owner}"
      end
    end

    def lookup_matches_in(owner : Type, self_type = nil, def_name = self.name)
      lookup_matches_in_type(owner, self_type, def_name)
    end

    def lookup_matches_in_type(owner, self_type, def_name)
      arg_types = args.map &.type

      signature = CallSignature.new(def_name, arg_types, block, named_args)

      matches = check_tuple_indexer(owner, def_name, args, arg_types)
      matches ||= owner.lookup_matches signature

      if matches.empty?
        if def_name == "new" && owner.metaclass? && (owner.instance_type.class? || owner.instance_type.virtual?) && !owner.instance_type.pointer?
          new_matches = define_new owner, arg_types
          unless new_matches.empty?
            if owner.virtual_metaclass?
              matches = owner.lookup_matches(signature)
            else
              matches = new_matches
            end
          end
        elsif !obj && owner != mod
          mod_matches = mod.lookup_matches(signature)
          matches = mod_matches unless mod_matches.empty?
        end
      end

      if matches.empty? && owner.class? && owner.abstract
        matches = owner.virtual_type.lookup_matches(signature)
      end

      if matches.empty?
        defined_method_missing = owner.check_method_missing(signature)
        if defined_method_missing
          matches = owner.lookup_matches(signature)
        end
      end

      if matches.empty?
        # For now, if the owner is a NoReturn just ignore the error (this call should be recomputed later)
        unless owner.no_return?
          raise_matches_not_found(matches.owner || owner, def_name, matches)
        end
      end

      # If this call is an implicit call to self
      if !obj && !mod_matches && !owner.is_a?(Program)
        parent_visitor.check_self_closured
      end

      if owner.is_a?(VirtualType)
        owner.base_type.add_subclass_observer(self)
        @subclass_notifier = owner.base_type
      end

      instantiate matches, owner, self_type
    end

    def lookup_matches_in(owner : Nil)
      raise "Bug: trying to lookup matches in nil in #{self}"
    end

    def instantiate(matches, owner, self_type = nil)
      block = @block

      typed_defs = Array(Def).new(matches.length)

      matches.each do |match|
        # Discard abstract defs for abstract classes
        next if match.def.abstract && match.context.owner.abstract

        check_visibility match
        check_not_abstract match

        yield_vars = match_block_arg(match)
        use_cache = !block || match.def.block_arg

        if block && match.def.block_arg
          if fun_literal = block.fun_literal
            block_type = fun_literal.type
          else
            block_type = block.body.type?
          end

          use_cache = false unless block_type
        end

        lookup_self_type = self_type || match.context.owner
        if self_type
          lookup_arg_types = Array(Type).new(match.arg_types.length + 1)
          lookup_arg_types.push self_type
          lookup_arg_types.concat match.arg_types
        else
          lookup_arg_types = match.arg_types
        end
        match_owner = match.context.owner

        if named_args = @named_args
          named_args_key = named_args.map { |named_arg| {named_arg.name, named_arg.value.type} }
        else
          named_args_key = nil
        end

        def_instance_key = DefInstanceKey.new(match.def.object_id, lookup_arg_types, block_type, named_args_key)
        typed_def = match_owner.lookup_def_instance def_instance_key if use_cache
        unless typed_def
          typed_def, typed_def_args = prepare_typed_def_with_args(match.def, match_owner, lookup_self_type, match.arg_types)
          match_owner.add_def_instance(def_instance_key, typed_def) if use_cache
          if return_type = typed_def.return_type
            typed_def.type = TypeLookup.lookup(match.def.macro_owner.not_nil!, return_type, match_owner)
            mod.push_def_macro typed_def
          else
            bubbling_exception do
              visitor = TypeVisitor.new(mod, typed_def_args, typed_def)
              visitor.yield_vars = yield_vars
              visitor.free_vars = match.context.free_vars
              visitor.untyped_def = match.def
              visitor.call = self
              visitor.scope = lookup_self_type
              visitor.type_lookup = match.context.type_lookup
              typed_def.body.accept visitor

              if visitor.is_initialize
                visitor.bind_initialize_instance_vars(owner)
              end
            end
          end
        end
        typed_defs << typed_def
      end

      typed_defs
    end

    def check_tuple_indexer(owner, def_name, args, arg_types)
      if owner.is_a?(TupleInstanceType) && def_name == "[]" && args.length == 1
        arg = args.first
        if arg.is_a?(NumberLiteral) && arg.kind == :i32
          index = arg.value.to_i
          if 0 <= index < owner.tuple_types.length
            indexer_def = owner.tuple_indexer(index)
            indexer_match = Match.new(indexer_def, arg_types, MatchContext.new(owner, owner))
            return Matches.new([indexer_match] of Match, true)
          else
            raise "index out of bounds for tuple #{owner}"
          end
        end
      end
      nil
    end

    def check_visibility(match)
      case match.def.visibility
      when :private
        if obj = @obj
          if obj.is_a?(Var) && obj.name == "self" && match.def.name.ends_with?('=')
            # Special case: private setter can be called with self
            return
          end
          raise "private method '#{match.def.name}' called for #{match.def.owner}"
        end
      when :protected
        unless scope.instance_type.implements?(match.def.owner.instance_type)
          raise "protected method '#{match.def.name}' called for #{match.def.owner}"
        end
      end
    end

    def check_not_abstract(match)
      if match.def.abstract
        bubbling_exception do
          owner = match.context.owner
          owner = owner.base_type if owner.is_a?(VirtualType)
          match.def.raise "abstract def #{match.def.owner}##{match.def.name} must be implemented by #{owner}"
        end
      end
    end

    def replace_splats
      return unless args.any? &.is_a?(Splat)

      new_args = [] of ASTNode
      args.each_with_index do |arg, i|
        if arg.is_a?(Splat)
          arg_type = arg.type
          unless arg_type.is_a?(TupleInstanceType)
            arg.raise "splat expects a tuple, not #{arg_type}"
          end
          arg_type.tuple_types.each_index do |index|
            tuple_indexer = Call.new(arg.exp, "[]", [NumberLiteral.new(index)] of ASTNode)
            tuple_indexer.accept parent_visitor
            new_args << tuple_indexer
            arg.remove_input_observer(self)
          end
        else
          new_args << arg
        end
      end
      self.args = new_args
    end

    def replace_block_arg_with_block(block_arg)
      block_arg_type = block_arg.type
      if block_arg_type.is_a?(FunInstanceType)
        vars = [] of Var
        args = [] of ASTNode
        block_arg_type.arg_types.map_with_index do |type, i|
          arg = Var.new("__arg#{i}")
          vars << arg
          args << arg
        end
        block = Block.new(vars, Call.new(block_arg, "call", args))
        block.vars = self.before_vars
        self.block = block
      else
        block_arg.raise "expected a function type, not #{block_arg.type}"
      end
    end

    def find_owner_trace(node, owner)
      owner_trace = [] of ASTNode

      visited = Set(typeof(object_id)).new
      visited.add node.object_id
      while deps = node.dependencies?
        dependencies = deps.select { |dep| dep.type? && dep.type.includes_type?(owner) && !visited.includes?(dep.object_id) }
        if dependencies.length > 0
          node = dependencies.first
          owner_trace << node if node
          visited.add node.object_id
        else
          break
        end
      end

      MethodTraceException.new(owner, owner_trace)
    end

    def check_not_lib_out_args
      args.each do |arg|
        if arg.is_a?(Out)
          arg.raise "out can only be used with lib funs"
        end
      end
    end

    def lookup_matches_in_super
      if args.empty? && !has_parenthesis
        copy_args_from_parent_typed_def
      end

      # TODO: do this better
      untyped_def = parent_visitor.untyped_def
      lookup = untyped_def.owner
      if lookup.is_a?(VirtualType)
        parents = lookup.base_type.parents
      else
        parents = lookup.parents
      end

      if parents && parents.length > 0
        parents_length = parents.length
        parents.each_with_index do |parent, i|
          if i == parents_length - 1 || parent.lookup_first_def(untyped_def.name, block)
            return lookup_matches_in(parent, scope, untyped_def.name)
          end
        end
      end

      nil
    end

    def lookup_previous_def_matches
      untyped_def = parent_visitor.untyped_def
      previous = untyped_def.previous
      unless previous
        raise "there is no previous definition of '#{untyped_def.name}'"
      end

      if args.empty? && !has_parenthesis
        copy_args_from_parent_typed_def
      end

      match = Match.new(previous, args.map(&.type), MatchContext.new(scope, scope))
      matches = Matches.new([match] of Match, true)
      typed_defs = instantiate matches, scope
      typed_defs.each do |typed_def|
        typed_def.next = parent_visitor.typed_def
      end
      typed_defs
    end

    def copy_args_from_parent_typed_def
      parent_args = parent_visitor.typed_def.args
      self.args = Array(ASTNode).new(parent_args.length)
      parent_args.each do |arg|
        var = Var.new(arg.name)
        var.bind_to arg
        self.args.push var
      end
    end

    def recalculate_lib_call(obj_type)
      replace_splats

      old_target_defs = @target_defs

      untyped_def = obj_type.lookup_first_def(name, false)
      raise "undefined fun '#{name}' for #{obj_type}" unless untyped_def

      check_args_length_match obj_type, untyped_def
      check_lib_out_args untyped_def
      return unless obj_and_args_types_set?

      check_fun_args_types_match obj_type, untyped_def

      (untyped_def as External).used = true

      untyped_defs = [untyped_def]
      @target_defs = untyped_defs

      self.unbind_from old_target_defs if old_target_defs
      self.bind_to untyped_defs
    end

    def check_lib_out_args(untyped_def)
      untyped_def.args.each_with_index do |arg, i|
        call_arg = self.args[i]
        if call_arg.is_a?(Out)
          arg_type = arg.type
          if arg_type.is_a?(PointerInstanceType)
            var = parent_visitor.lookup_var_or_instance_var(call_arg.exp)
            var.bind_to Var.new("out", arg_type.element_type)
            call_arg.exp.bind_to var
            parent_visitor.bind_meta_var(call_arg.exp)
          else
            call_arg.raise "argument \##{i + 1} to #{untyped_def.owner}.#{untyped_def.name} cannot be passed as 'out' because it is not a pointer"
          end
        end
      end
    end

    def on_new_subclass
      # @types_signature = nil
      recalculate
    end

    def lookup_macro
      in_macro_target &.lookup_macro(name, args.length)
    end

    def in_macro_target
      node_scope = scope
      node_scope = node_scope.metaclass unless node_scope.metaclass?

      macros = yield node_scope
      if !macros && node_scope.metaclass? && node_scope.instance_type.module?
        macros = yield mod.object.metaclass
      end
      macros ||= yield mod
      macros
    end

    def match_block_arg(match)
      block_arg = match.def.block_arg
      return unless block_arg
      return unless ((yields = match.def.yields) && yields > 0) || match.def.uses_block_arg

      yield_vars = nil

      block = @block.not_nil!
      ident_lookup = MatchTypeLookup.new(match.context)

      if inputs = block_arg.fun.inputs
        yield_vars = [] of Var
        inputs.each_with_index do |input, i|
          type = lookup_node_type(ident_lookup, input)
          type = type.virtual_type
          yield_vars << Var.new("var#{i}", type)
        end
        block.args.each_with_index do |arg, i|
          var = yield_vars[i]?
          arg.bind_to(var || mod.nil_var)
        end
      else
        block.args.each &.bind_to(mod.nil_var)
      end

      if match.def.uses_block_arg
        # Automatically convert block to function pointer
        if yield_vars
          fun_args = yield_vars.map_with_index do |var, i|
            arg = block.args[i]?
            if arg
              Arg.new_with_type(arg.name, var.type)
            else
              Arg.new_with_type(mod.new_temp_var_name, var.type)
            end
          end
        else
          fun_args = [] of Arg
        end

        # But first check if the call has a block_arg
        if call_block_arg = self.block_arg
          # Check input types
          call_block_arg_types = (call_block_arg.type as FunInstanceType).arg_types
          if yield_vars
            if yield_vars.length != call_block_arg_types.length
              raise "wrong number of block argument's arguments (#{call_block_arg_types.length} for #{yield_vars.length})"
            end

            i = 1
            yield_vars.zip(call_block_arg_types) do |yield_var, call_block_arg_type|
              if yield_var.type != call_block_arg_type
                raise "expected block argument's argument ##{i} to be #{yield_var.type}, not #{call_block_arg_type}"
              end
              i += 1
            end
          elsif call_block_arg_types.length != 0
            raise "wrong number of block argument's arguments (#{call_block_arg_types.length} for 0)"
          end

          fun_literal = call_block_arg
        else
          if block.args.length > fun_args.length
            raise "wrong number of block arguments (#{block.args.length} for #{fun_args.length})"
          end

          fun_def = Def.new("->", fun_args, block.body)
          fun_literal = FunLiteral.new(fun_def)

          unless block_arg.fun.output
            fun_literal.force_void = true
          end

          fun_literal.accept parent_visitor
        end

        block.fun_literal = fun_literal

        fun_literal_type = fun_literal.type?
        if fun_literal_type
          if output = block_arg.fun.output
            block_type = (fun_literal_type as FunInstanceType).return_type
            matched = MatchesLookup.match_arg(block_type, output, match.context)
            unless matched
              raise "expected block to return #{output}, not #{block_type}"
            end
          end
        else
          raise "cant' deduce type of block"
        end
      else
        block.accept parent_visitor

        if output = block_arg.fun.output
          raise "can't infer block type" unless block.body.type?

          block_type = block.body.type
          matched = MatchesLookup.match_arg(block_type, output, match.context)
          unless matched
            if output.is_a?(Self)
              raise "expected block to return #{match.context.owner}, not #{block_type}"
            else
              raise "expected block to return #{output}, not #{block_type}"
            end
          end
          block.body.freeze_type = block_type
        end
      end

      yield_vars
    end

    def lookup_node_type(visitor, node)
      node.accept visitor
      visitor.type
    end

    class MatchTypeLookup < TypeLookup
      def initialize(@context)
        super(@context.type_lookup)
      end

      def visit(node : Path)
        if node.names.length == 1 && @context.free_vars
          if type = @context.get_free_var(node.names.first)
            @type = type
            return
          end
        end

        super
      end

      def visit(node : Self)
        @type = @context.owner
        false
      end
    end

    def bubbling_exception
      begin
        yield
      rescue ex : Crystal::Exception
        if obj = @obj
          raise "instantiating '#{obj.type}##{name}(#{args.map(&.type).join ", "})'", ex
        else
          raise "instantiating '#{name}(#{args.map(&.type).join ", "})'", ex
        end
      end
    end

    def check_args_length_match(obj_type, untyped_def : External)
      call_args_count = args.length
      all_args_count = untyped_def.args.length

      if untyped_def.varargs && call_args_count >= all_args_count
        return
      end

      required_args_count = untyped_def.args.count { |arg| !arg.default_value }

      return if required_args_count <= call_args_count && call_args_count <= all_args_count

      raise "wrong number of arguments for '#{full_name(obj_type)}' (#{args.length} for #{untyped_def.args.length})"
    end

    def check_args_length_match(obj_type, untyped_def : Def)
      raise "Bug: shouldn't check args length for Def here"
    end

    def check_fun_args_types_match(obj_type, typed_def)
      typed_def.args.each_with_index do |typed_def_arg, i|
        expected_type = typed_def_arg.type
        self_arg = self.args[i]
        actual_type = self_arg.type
        actual_type = mod.pointer_of(actual_type) if self.args[i].is_a?(Out)
        unless actual_type.compatible_with?(expected_type) || actual_type.is_implicitly_converted_in_c_to?(expected_type)
          implicit_call = try_to_unsafe(self_arg) do |ex|
            if ex.message.not_nil!.includes?("undefined method 'to_unsafe'")
              arg_name = typed_def_arg.name.bytesize > 0 ? "'#{typed_def_arg.name}'" : "##{i + 1}"
              self_arg.raise "argument #{arg_name} of '#{full_name(obj_type)}' must be #{expected_type}, not #{actual_type}"
            else
              self_arg.raise ex.message, ex
            end
          end
          implicit_call_type = implicit_call.type?
          if implicit_call_type
            if implicit_call_type.compatible_with?(expected_type)
              self.args[i] = implicit_call
            else
              arg_name = typed_def_arg.name.bytesize > 0 ? "'#{typed_def_arg.name}'" : "##{i + 1}"
              self_arg.raise "argument #{arg_name} of '#{full_name(obj_type)}' must be #{expected_type}, not #{actual_type} (nor #{implicit_call_type} returned by '#{actual_type}#to_unsafe')"
            end
          else
            self_arg.raise "tried to convert #{actual_type} to #{expected_type} invoking to_unsafe, but can't deduce its type"
          end
        end
      end

      # Need to call to_unsafe on variadic args too
      if typed_def.varargs
        typed_def.args.length.upto(self.args.length - 1) do |i|
          self_arg = self.args[i]
          self_arg_type = self_arg.type?
          if self_arg_type
            unless self_arg_type.nil_type? || self_arg_type.primitive_like?
              implicit_call = try_to_unsafe(self_arg) do |ex|
                if ex.message.not_nil!.includes?("undefined method 'to_unsafe'")
                  self_arg.raise "argument ##{i + 1} of '#{full_name(obj_type)}' is not a primitive type and no #{self_arg_type}#to_unsafe method found"
                else
                  self_arg.raise ex.message, ex
                end
              end
              implicit_call_type = implicit_call.type?
              if implicit_call_type
                if implicit_call_type.primitive_like?
                  self.args[i] = implicit_call
                else
                  self_arg.raise "converted #{self_arg_type} invoking to_unsafe, but #{implicit_call_type} is not a primitive type"
                end
              else
                self_arg.raise "tried to convert #{self_arg_type} invoking to_unsafe, but can't deduce its type"
              end
            end
          else
            self_arg.raise "can't deduce argument type"
          end
        end
      end
    end

    def try_to_unsafe(self_arg)
      implicit_call = Call.new(self_arg.clone, "to_unsafe")
      begin
        implicit_call.accept parent_visitor
      rescue ex : TypeException
        yield ex
      end
      implicit_call
    end

    def obj_and_args_types_set?
      obj = @obj
      block_arg = @block_arg
      named_args = @named_args

      unless args.all? &.type?
        return false
      end

      if obj && !obj.type?
        return false
      end

      if block_arg && !block_arg.type?
        return false
      end

      if named_args && named_args.any? { |arg| !arg.value.type? }
        return false
      end

      true
    end

    def raise_matches_not_found(owner : CStructType, def_name, matches = nil)
      raise_struct_or_union_field_not_found owner, def_name
    end

    def raise_matches_not_found(owner : CUnionType, def_name, matches = nil)
      raise_struct_or_union_field_not_found owner, def_name
    end

    def raise_struct_or_union_field_not_found(owner, def_name)
      if def_name.ends_with?('=')
        def_name = def_name[0 .. -2]
      end

      var = owner.vars[def_name]?
      if var
        args[0].raise "field '#{def_name}' of #{owner.type_desc} #{owner} has type #{var.type}, not #{args[0].type}"
      else
        raise "#{owner.type_desc} #{owner} has no field '#{def_name}'"
      end
    end

    def raise_matches_not_found(owner, def_name, matches = nil)
      # Special case: Foo+:Class#new
      if owner.is_a?(VirtualMetaclassType) && def_name == "new"
        raise_matches_not_found_for_virtual_metaclass_new owner
      end

      defs = owner.lookup_defs(def_name)
      obj = @obj
      if defs.empty?
        check_macro_wrong_number_of_arguments(def_name)

        owner_trace = find_owner_trace(obj, owner) if obj
        similar_name = owner.lookup_similar_def_name(def_name, self.args.length, block)

        error_msg = String.build do |msg|
          if obj && owner != mod
            msg << "undefined method '#{def_name}' for #{owner}"
          elsif args.length > 0 || has_parenthesis
            msg << "undefined method '#{def_name}'"
          else
            similar_name = parent_visitor.lookup_similar_var_name(def_name) unless similar_name
            msg << "undefined local variable or method '#{def_name}'"
          end
          msg << " (did you mean '#{similar_name}'?)".colorize.yellow.bold if similar_name

          # Check if it's an instance variable that was never assigned a value
          if obj.is_a?(InstanceVar)
            scope = scope as InstanceVarContainer
            ivar = scope.lookup_instance_var(obj.name)
            deps = ivar.dependencies?
            if deps && deps.length == 1 && deps.first.same?(mod.nil_var)
              similar_name = scope.lookup_similar_instance_var_name(ivar.name)
              if similar_name
                msg << " (#{ivar.name} was never assigned a value, did you mean #{similar_name}?)".colorize.yellow.bold
              else
                msg << " (#{ivar.name} was never assigned a value)".colorize.yellow.bold
              end
            end
          end
        end
        raise error_msg, owner_trace
      end

      defs_matching_args_length = defs.select do |a_def|
        min_length, max_length = a_def.min_max_args_lengths
        min_length <= self.args.length <= max_length
      end

      if defs_matching_args_length.empty?
        all_arguments_lengths = [] of Int32
        min_splat = Int32::MAX
        defs.each do |a_def|
          min_length, max_length = a_def.min_max_args_lengths
          if max_length == Int32::MAX
            min_splat = Math.min(min_length, min_splat)
            all_arguments_lengths.push min_splat
          else
            min_length.upto(max_length) do |length|
              all_arguments_lengths.push length
            end
          end
        end
        all_arguments_lengths.uniq!.sort!

        raise String.build do |str|
          str << "wrong number of arguments for '"
          str << full_name(owner, def_name)
          str << "' ("
          str << args.length
          str << " for "
          all_arguments_lengths.join ", ", str
          if min_splat != Int32::MAX
            str << "+"
          end
          str << ")"
        end
      end

      if defs_matching_args_length.length > 0
        if block && defs_matching_args_length.all? { |a_def| !a_def.yields }
          raise "'#{full_name(owner, def_name)}' is not expected to be invoked with a block, but a block was given"
        elsif !block && defs_matching_args_length.all?(&.yields)
          raise "'#{full_name(owner, def_name)}' is expected to be invoked with a block, but no block was given"
        end

        if named_args = @named_args
          defs_matching_args_length.each do |a_def|
            check_named_args_mismatch named_args, a_def
          end
        end
      end

      if args.length == 1 && args.first.type.includes_type?(mod.nil)
        owner_trace = find_owner_trace(args.first, mod.nil)
      end

      arg_names = [] of Array(String)

      message = String.build do |msg|
        msg << "no overload matches '#{full_name(owner, def_name)}'"
        msg << " with types #{args.map(&.type).join ", "}" if args.length > 0
        msg << "\n"
        msg << "Overloads are:"
        defs.each do |a_def|
          arg_names.push a_def.args.map(&.name)

          msg << "\n - #{full_name(owner, def_name)}("
          a_def.args.each_with_index do |arg, i|
            msg << ", " if i > 0
            msg << arg.name
            if arg_type = arg.type?
              msg << " : "
              msg << arg_type
            elsif res = arg.restriction
              msg << " : "
              if owner.is_a?(GenericClassInstanceType) && res.is_a?(Path) && res.names.length == 1
                if type_var = owner.type_vars[res.names[0]]?
                  msg << type_var.type
                else
                  msg << res
                end
              else
                msg << res
              end
            end
          end

          msg << ", &block" if a_def.yields
          msg << ")"
        end

        if matches
          cover = matches.cover
          if cover.is_a?(Cover)
            missing = cover.missing
            uniq_arg_names = arg_names.uniq!
            uniq_arg_names = uniq_arg_names.length == 1 ? uniq_arg_names.first : nil
            unless missing.empty?
              msg << "\nCouldn't find overloads for these types:"
              missing.each_with_index do |missing_types|
                if uniq_arg_names
                  msg << "\n - #{full_name(owner, def_name)}(#{missing_types.map_with_index { |missing_type, i| "#{uniq_arg_names[i]} : #{missing_type}" }.join ", "}"
                else
                  msg << "\n - #{full_name(owner, def_name)}(#{missing_types.join ", "}"
                end
                msg << ", &block" if block
                msg << ")"
              end
            end
          end
        end
      end

      raise message, owner_trace
    end

    def check_named_args_mismatch(named_args, a_def)
      named_args.each do |named_arg|
        found_index = a_def.args.index { |arg| arg.name == named_arg.name }
        if found_index
          min_length, max_length = a_def.min_max_args_lengths
          if found_index < min_length
            named_arg.raise "argument '#{named_arg.name}' already specified"
          end
        else
          similar_name = SimilarName.find(named_arg.name, a_def.args.select(&.default_value).map(&.name))

          msg = String.build do |str|
            str << "no argument named '"
            str << named_arg.name
            str << "'"
            if similar_name
              str << " (did you mean '#{similar_name}'?)".colorize.yellow.bold
            end
          end
          named_arg.raise msg
        end
      end
    end

    def raise_matches_not_found_for_virtual_metaclass_new(owner)
      arg_types = args.map &.type

      owner.each_concrete_type do |concrete_type|
        defs = concrete_type.instance_type.lookup_defs_with_modules("initialize")
        defs = defs.select { |a_def| a_def.args.length != args.length }
        unless defs.empty?
          all_arguments_lengths = Set(Int32).new
          defs.each { |a_def| all_arguments_lengths << a_def.args.length }
          raise "wrong number of arguments for '#{concrete_type.instance_type}#initialize' (#{args.length} for #{all_arguments_lengths.join ", "})"
        end
      end
    end

    def check_macro_wrong_number_of_arguments(def_name)
      macros = in_macro_target &.lookup_macros(def_name)
      if macros
        all_arguments_lengths = Set(Int32).new
        macros.each do |macro|
          min_length = macro.args.index(&.default_value) || macro.args.length
          min_length.upto(macro.args.length) do |args_length|
            all_arguments_lengths << args_length
          end
        end

        raise "wrong number of arguments for macro '#{def_name}' (#{args.length} for #{all_arguments_lengths.join ", "})"
      end
    end

    def full_name(owner, def_name = name)
      owner.is_a?(Program) ? name : "#{owner}##{def_name}"
    end

    def define_new(scope, arg_types)
      instance_type = scope.instance_type

      if instance_type.is_a?(VirtualType)
        matches = define_new_recursive(instance_type.base_type, arg_types)
        return Matches.new(matches, scope)
      end

      # First check if this type has any initialize
      initializers = instance_type.lookup_defs_with_modules("initialize")

      signature = CallSignature.new("initialize", arg_types, block, named_args)

      if initializers.empty?
        # If there are no initialize at all, use parent's initialize
        matches = instance_type.lookup_matches signature
      else
        # Otherwise, use this type's initializers
        matches = instance_type.lookup_matches_with_modules signature
      end

      if matches.empty?
        # We first need to check if there aren't any "new" methods in the class
        defs = scope.lookup_defs("new")
        if defs.any? { |a_def| a_def.args.length > 0 }
          Matches.new(nil, false)
        else
          define_new_without_initialize(scope, arg_types)
        end
      elsif matches.cover_all?
        define_new_with_initialize(scope, arg_types, matches)
      else
        raise_matches_not_found instance_type, "initialize", matches
      end
    end

    def define_new_without_initialize(scope, arg_types)
      defs = scope.instance_type.lookup_defs("initialize")
      if defs.length > 0
        if scope.abstract
          raise "can't instantiate abstract class #{scope}"
        else
          raise_matches_not_found scope.instance_type, "initialize"
        end
      end

      if defs.length == 0 && arg_types.length > 0
        if scope.abstract
          raise "can't instantiate abstract class #{scope}"
        else
          raise "wrong number of arguments for '#{full_name(scope.instance_type)}' (#{self.args.length} for 0)"
        end
      end

      new_def = Def.argless_new(scope.instance_type)
      match = Match.new(new_def, arg_types, MatchContext.new(scope, scope))
      scope.add_def new_def

      Matches.new([match], true)
    end

    def define_new_with_initialize(scope, arg_types, matches)
      instance_type = scope.instance_type
      instance_type = instance_type.generic_class if instance_type.is_a?(GenericClassInstanceType)

      ms = matches.map do |match|
        # Check that this call doesn't have a named arg not mentioned in new
        if named_args = @named_args
          check_named_args_mismatch named_args, match.def
        end

        new_def = match.def.expand_new_from_initialize(instance_type)
        new_match = Match.new(new_def, match.arg_types, MatchContext.new(scope, scope, match.context.free_vars))
        scope.add_def new_def

        new_match
      end
      Matches.new(ms, true)
    end

    def define_new_recursive(owner, arg_types, matches = [] of Match)
      unless owner.abstract
        owner_matches = define_new(owner.metaclass, arg_types)
        owner_matches_matches = owner_matches.matches
        if owner_matches_matches
          matches.concat owner_matches_matches
        end
      end

      owner.subclasses.each do |subclass|
        subclass_matches = define_new_recursive(subclass, arg_types)
        matches.concat subclass_matches
      end

      matches
    end

    def prepare_typed_def_with_args(untyped_def, owner, self_type, arg_types)
      named_args = @named_args

      # If there's an argument count mismatch, or we have a splat, or there are
      # named arguments, we create another def that sets ups everything for the real call.
      if arg_types.length != untyped_def.args.length || untyped_def.splat_index || named_args
        named_args_names = named_args.try &.map &.name
        untyped_def = untyped_def.expand_default_arguments(arg_types.length, named_args_names)
      end

      args_start_index = 0

      typed_def = untyped_def.clone
      typed_def.owner = owner

      if body = typed_def.body
        typed_def.bind_to body
      end

      args = MetaVars.new

      if self_type.is_a?(Type)
        args["self"] = MetaVar.new("self", self_type)
      end

      self.args.each_index do |index|
        arg = typed_def.args[index]
        type = arg_types[args_start_index + index]
        var = MetaVar.new(arg.name, type)
        var.location = arg.location
        var.bind_to(var)
        args[arg.name] = var
        arg.type = type
      end

      named_args.try &.each do |named_arg|
        type = named_arg.value.type
        var = MetaVar.new(named_arg.name, type)
        var.location = named_arg.value.location
        var.bind_to(var)
        args[named_arg.name] = var
        arg = typed_def.args.find { |arg| arg.name == named_arg.name }.not_nil!
        arg.type = type
      end

      fun_literal = @block.try &.fun_literal
      if fun_literal
        block_arg = untyped_def.block_arg.not_nil!
        var = MetaVar.new(block_arg.name, fun_literal.type)
        args[block_arg.name] = var

        typed_def.block_arg.not_nil!.type = fun_literal.type
      end

      {typed_def, args}
    end
  end
end
