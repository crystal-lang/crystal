module Crystal
  abstract class BaseTypeVisitor < Visitor
    getter mod
    property types

    def initialize(@mod, @vars = MetaVars.new)
      @types = [@mod] of Type
      @exp_nest = 0
      @attributes = nil
      @lib_def_pass = 0
      @in_type_args = 0
      @block_nest = 0
    end

    def visit(node : Attribute)
      attributes = @attributes ||= [] of Attribute
      attributes << node
      false
    end

    def visit(node : Path)
      type = resolve_ident(node)
      case type
      when Const
        if !type.value.type? && !type.visited?
          type.visited = true

          meta_vars = MetaVars.new
          const_def = Def.new("const", [] of Arg)
          type_visitor = TypeVisitor.new(@mod, meta_vars, const_def)
          type_visitor.types = type.scope_types
          type_visitor.scope = type.scope

          type.value.accept type_visitor
          type.vars = const_def.vars
          type.visitor = self
        end
        node.target_const = type
        node.bind_to type.value
        type.used = true
      when Type
        if type.is_a?(AliasType) && @in_type_args == 0 && !type.aliased_type?
          if type.value_processed?
            node.raise "infinite recursive definition of alias #{type}"
          else
            type.process_value
          end
        end

        node.type = check_type_in_type_args(type.remove_alias_if_simple)
      when ASTNode
        type.accept self unless type.type?
        node.syntax_replacement = type
        node.bind_to type
      end
    end

    def end_visit(node : Fun)
      if inputs = node.inputs
        types = inputs.map &.type.instance_type.virtual_type
      else
        types = [] of Type
      end

      if output = node.output
        types << output.type.instance_type.virtual_type
      else
        types << mod.void
      end

      node.type = mod.fun_of(types)
    end

    def end_visit(node : Union)
      old_in_is_a, @in_is_a = @in_is_a, false

      types = node.types.map do |subtype|
        instance_type = subtype.type.instance_type
        unless instance_type.allowed_in_generics?
          subtype.raise "can't use #{instance_type} in unions yet, use a more specific type"
        end
        instance_type.virtual_type
      end

      @in_is_a = old_in_is_a

      if @in_is_a
        node.type = @mod.type_merge_union_of(types)
      else
        node.type = @mod.type_merge(types)
      end
    end

    def end_visit(node : Virtual)
      node.type = check_type_in_type_args node.name.type.instance_type.virtual_type
    end

    def end_visit(node : Metaclass)
      node.type = node.name.type.virtual_type!.metaclass
    end

    def visit(node : Generic)
      node.in_type_args = @in_type_args > 0
      node.scope = @scope

      node.name.accept self

      @in_type_args += 1
      node.type_vars.each &.accept self
      @in_type_args -= 1

      return false if node.type?

      instance_type = node.name.type.instance_type
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.variadic
        min_needed = instance_type.type_vars.size - 1
        if node.type_vars.size < min_needed
          node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.size} for #{min_needed}..)"
        end
      else
        if instance_type.type_vars.size != node.type_vars.size
          node.raise "wrong number of type vars for #{instance_type} (#{node.type_vars.size} for #{instance_type.type_vars.size})"
        end
      end

      node.instance_type = instance_type
      node.type_vars.each &.add_observer(node)
      node.update

      false
    end

    def visit_fun_def(node : FunDef)
      check_outside_block_or_exp node, "declare fun"

      if node.body && !current_type.is_a?(Program)
        node.raise "can only declare fun at lib or global scope"
      end

      call_convention = check_call_convention_attributes node
      check_valid_attributes node, ValidFunDefAttributes, "fun"
      node.doc ||= attributes_doc()

      args = node.args.map do |arg|
        restriction = arg.restriction.not_nil!
        processing_types do
          restriction.accept self
        end

        arg_type = check_arg_primitive_like(restriction)

        Arg.new(arg.name, type: arg_type).at(arg.location)
      end

      node_return_type = node.return_type
      if node_return_type
        processing_types do
          node_return_type.accept self
        end
        return_type = check_primitive_like(node_return_type)
      else
        return_type = @mod.void
      end

      external = External.for_fun(node.name, node.real_name, args, return_type, node.varargs, node.body, node)
      external.doc = node.doc
      check_ditto external

      external.call_convention = call_convention

      if node_body = node.body
        vars = MetaVars.new
        args.each do |arg|
          var = MetaVar.new(arg.name, arg.type)
          var.bind_to var
          vars[arg.name] = var
        end
        external.set_type(nil)

        visitor = TypeVisitor.new(@mod, vars, external)
        visitor.untyped_def = external
        visitor.scope = @mod
        visitor.block_nest = @block_nest

        begin
          node_body.accept visitor
        rescue ex : Crystal::Exception
          node.raise ex.message, ex
        end

        inferred_return_type = @mod.type_merge([node_body.type?, external.type?])

        if return_type && return_type != @mod.void && inferred_return_type != return_type
          node.raise "expected fun to return #{return_type} but it returned #{inferred_return_type}"
        end

        external.set_type(return_type)
      end

      external.raises = true if node.has_attribute?("Raises")

      begin
        old_external = current_type.add_def external
      rescue ex : Crystal::Exception
        node.raise ex.message
      end

      if old_external.is_a?(External)
        old_external.dead = true
      end

      if node.body
        key = DefInstanceKey.new external.object_id, external.args.map(&.type), nil, nil
        current_type.add_def_instance key, external
      end

      node.type = @mod.nil

      false
    end

    def processing_types
      yield
    end

    def visit(node : ASTNode)
      true
    end

    def visit_any(node)
      @exp_nest += 1 if nesting_exp?(node)

      true
    end

    def end_visit_any(node)
      @exp_nest -= 1 if nesting_exp?(node)

      if @attributes
        case node
        when Expressions
          # Nothing, will be taken care in individual expressions
        when Attribute
          # Nothing
        when Nop
          # Nothing (might happen as a result of an evaulated ifdef)
        when Call
          # Don't clear attributes if these were generated by a macro
          unless node.expanded
            @attributes = nil
          end
        else
          @attributes = nil
        end
      end
    end

    def nesting_exp?(node)
      case node
      when Expressions, LibDef, ClassDef, ModuleDef, FunDef, Def, Macro,
           Alias, Include, Extend, EnumDef, VisibilityModifier, MacroFor, MacroIf, MacroExpression,
           FileNode
        false
      else
        true
      end
    end

    def check_type_in_type_args(type)
      if @in_type_args > 0
        type
      else
        type.metaclass
      end
    end

    def lookup_path_type(node : Self, create_modules_if_missing = false)
      current_type
    end

    def lookup_path_type(node : Path, create_modules_if_missing = false)
      target_type = resolve_ident(node, create_modules_if_missing)
      if target_type.is_a?(Type)
        target_type.remove_alias_if_simple
      else
        node.raise "#{node} must be a type here, not #{target_type}"
      end
    end

    def lookup_path_type(node : Generic, create_modules_if_missing = false)
      lookup_path_type node.name, create_modules_if_missing
    end

    def lookup_path_type(node, create_modules_if_missing = false)
      raise "lookup_path_type not implemented for #{node}"
    end

    def resolve_ident(node : Path, create_modules_if_missing = false)
      target_type, similar_name = resolve_ident?(node, create_modules_if_missing)

      unless target_type
        TypeLookup.check_cant_infer_generic_type_parameter(@scope, node)

        error_msg = String.build do |msg|
          msg << "undefined constant #{node}"
          msg << @mod.colorize(" (did you mean '#{similar_name}'?)").yellow.bold if similar_name
        end
        node.raise error_msg
      end

      target_type
    end

    def resolve_ident?(node : Path, create_modules_if_missing = false)
      free_vars = @free_vars
      if free_vars && !node.global && (type = free_vars[node.names.first]?)
        target_type = type
        if node.names.size > 1
          target_type = lookup_type target_type, node.names[1..-1], node
        end
      else
        base_lookup = node.global ? mod : (@type_lookup || @scope || @types.last)
        target_type = lookup_type base_lookup, node, node

        unless target_type
          if create_modules_if_missing
            next_type = base_lookup
            node.names.each do |name|
              next_type = lookup_type base_lookup, [name], node
              if next_type
                if next_type.is_a?(ASTNode)
                  node.raise "execpted #{name} to be a type"
                end
              else
                next_type = NonGenericModuleType.new(@mod, base_lookup, name)

                if (location = node.location)
                  next_type.locations << location
                end

                base_lookup.types[name] = next_type
              end
              base_lookup = next_type
            end
            target_type = next_type
          else
            similar_name = base_lookup.lookup_similar_type_name(node)
          end
        end
      end

      {target_type, similar_name}
    end

    def lookup_type(base_type, names, node)
      base_type.lookup_type names
    rescue ex
      node.raise ex.message
    end

    def process_type_name(node_name)
      if node_name.names.size == 1 && !node_name.global
        scope = current_type
        name = node_name.names.first
      else
        name = node_name.names.pop
        scope = lookup_path_type node_name, create_modules_if_missing: true
      end
      {scope, name}
    end

    def attach_doc(type, node)
      if @mod.wants_doc?
        type.doc ||= node.doc
      end

      if node_location = node.location
        type.locations << node_location
      end
    end

    def check_ditto(node)
      stripped_doc = node.doc.try &.strip
      if stripped_doc == ":ditto:" || stripped_doc == "ditto"
        node.doc = @last_doc
      end

      @last_doc = node.doc
    end

    def check_outside_block_or_exp(node, op)
      if inside_block?
        node.raise "can't #{op} inside block"
      end

      if inside_exp?
        node.raise "can't #{op} dynamically"
      end
    end

    def run_hooks(type_with_hooks, current_type, kind, node, call = nil)
      hooks = type_with_hooks.hooks
      if hooks
        hooks.each do |hook|
          next if hook.kind != kind

          expanded = expand_macro(hook.macro, node) do
            if call
              @mod.expand_macro hook.macro, call, current_type.instance_type
            else
              @mod.expand_macro hook.macro.body, current_type.instance_type
            end
          end

          node.add_runtime_initializer(expanded)
        end
      end

      if kind == :inherited && (superclass = type_with_hooks.instance_type.superclass)
        run_hooks(superclass.metaclass, current_type, kind, node)
      end
    end

    def expand_macro(node, raise_on_missing_const = true)
      if expanded = node.expanded
        @exp_nest -= 1
        expanded.accept self
        @exp_nest += 1
        return true
      end

      obj = node.obj
      case obj
      when Path
        if raise_on_missing_const
          macro_scope = resolve_ident(obj)
        else
          macro_scope, similar_name = resolve_ident?(obj)
        end
        return false unless macro_scope.is_a?(Type)

        the_macro = macro_scope.metaclass.lookup_macro(node.name, node.args.size, node.named_args)
      when Nil
        return false if node.name == "super" || node.name == "previous_def"
        the_macro = node.lookup_macro
      else
        return false
      end

      return false unless the_macro

      @exp_nest -= 1

      generated_nodes = expand_macro(the_macro, node) do
        @mod.expand_macro the_macro, node, (macro_scope || @scope || current_type)
      end

      @exp_nest += 1

      node.expanded = generated_nodes
      node.bind_to generated_nodes

      true
    end

    def expand_macro(the_macro, node)
      begin
        expanded_macro = yield
      rescue ex : Crystal::Exception
        node.raise "expanding macro", ex
      end

      generated_nodes = @mod.parse_macro_source(expanded_macro, the_macro, node, Set.new(@vars.keys),
        inside_def: !!@typed_def,
        inside_type: !current_type.is_a?(Program),
        inside_exp: @exp_nest > 0,
      )

      if node_doc = node.doc
        generated_nodes.accept PropagateDocVisitor.new(node_doc)
      end

      generated_nodes.accept self
      generated_nodes
    end

    def visit(node : MacroExpression)
      expand_inline_macro node
    end

    def visit(node : MacroIf)
      expand_inline_macro node
    end

    def visit(node : MacroFor)
      expand_inline_macro node
    end

    def expand_inline_macro(node)
      if expanded = node.expanded
        expanded.accept self
        return false
      end

      the_macro = Macro.new("macro_#{node.object_id}", [] of Arg, node).at(node.location)

      generated_nodes = expand_macro(the_macro, node) do
        @mod.expand_macro node, (@scope || current_type), @free_vars
      end

      node.expanded = generated_nodes
      node.bind_to generated_nodes

      false
    end

    def check_valid_attributes(node, valid_attributes, desc)
      if attributes = @attributes
        attributes.each do |attr|
          unless valid_attributes.includes?(attr.name)
            attr.raise "illegal attribute for #{desc}, valid attributes are: #{valid_attributes.join ", "}"
          end

          if !attr.args.empty? || attr.named_args
            attr.raise "#{attr.name} attribute can't receive arguments"
          end
        end
        node.attributes = attributes
      end
    end

    def attributes_doc
      @attributes.try(&.first?).try &.doc
    end

    def check_arg_primitive_like(node)
      type = check_primitive_like(node)

      real_type = type.remove_typedef
      if real_type.void?
        node.raise "can't use Void as argument type"
      end

      type
    end

    def check_primitive_like(node)
      type = node.type.instance_type

      unless type.primitive_like?
        msg = String.build do |msg|
          msg << "only primitive types, pointers, structs, unions, enums and tuples are allowed in lib declarations"
          msg << " (did you mean Int32?)" if type == @mod.int
          msg << " (did you mean Float32?)" if type == @mod.float
        end
        node.raise msg
      end

      if type.is_a?(TypeDefType) && type.typedef.fun?
        type = type.typedef
      end

      type
    end

    def interpret_enum_value(node : NumberLiteral, target_type)
      case node.kind
      when :i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64, :i64
        case target_type.kind
        when :i8  then node.value.to_i8? || node.raise "invalid Int8: #{node.value}"
        when :u8  then node.value.to_u8? || node.raise "invalid UInt8: #{node.value}"
        when :i16 then node.value.to_i16? || node.raise "invalid Int16: #{node.value}"
        when :u16 then node.value.to_u16? || node.raise "invalid UInt16: #{node.value}"
        when :i32 then node.value.to_i32? || node.raise "invalid Int32: #{node.value}"
        when :u32 then node.value.to_u32? || node.raise "invalid UInt32: #{node.value}"
        when :i64 then node.value.to_i64? || node.raise "invalid Int64: #{node.value}"
        when :u64 then node.value.to_u64? || node.raise "invalid UInt64: #{node.value}"
        else
          node.raise "enum type must be an integer, not #{target_type.kind}"
        end
      else
        node.raise "constant value must be an integer, not #{node.kind}"
      end
    end

    def interpret_enum_value(node : Call, target_type)
      obj = node.obj
      unless obj
        node.raise "invalid constant value"
      end

      case node.args.size
      when 0
        left = interpret_enum_value(obj, target_type)

        case node.name
        when "+" then +left
        when "-"
          case left
          when Int8  then -left
          when Int16 then -left
          when Int32 then -left
          when Int64 then -left
          else
            node.raise "invalid constant value"
          end
        when "~" then ~left
        else
          node.raise "invalid constant value"
        end
      when 1
        left = interpret_enum_value(obj, target_type)
        right = interpret_enum_value(node.args.first, target_type)

        case node.name
        when "+"  then left + right
        when "-"  then left - right
        when "*"  then left * right
        when "/"  then left / right
        when "&"  then left & right
        when "|"  then left | right
        when "<<" then left << right
        when ">>" then left >> right
        when "%"  then left % right
        else
          node.raise "invalid constant value"
        end
      else
        node.raise "invalid constant value"
      end
    end

    def interpret_enum_value(node : Path, target_type)
      type = resolve_ident(node)
      case type
      when Const
        interpret_enum_value(type.value, target_type)
      else
        node.raise "invalid constant value"
      end
    end

    def interpret_enum_value(node : ASTNode, target_type)
      node.raise "invalid constant value"
    end

    def visit(node : ExternalVar)
      false
    end

    def check_call_convention_attributes(node)
      attributes = @attributes
      return unless attributes

      call_convention = nil

      attributes.reject! do |attr|
        next false unless attr.name == "CallConvention"

        if call_convention
          attr.raise "call convention already specified"
        end

        if attr.args.size != 1
          attr.raise "wrong number of arguments for attribute CallConvention (#{attr.args.size} for 1)"
        end

        call_convention_node = attr.args.first
        unless call_convention_node.is_a?(StringLiteral)
          call_convention_node.raise "argument to CallConvention must be a string"
        end

        value = call_convention_node.value
        call_convention = LLVM::CallConvention.parse?(value)
        unless call_convention
          call_convention_node.raise "invalid call convention. Valid values are #{LLVM::CallConvention.values.join ", "}"
        end

        true
      end

      call_convention
    end

    def inside_exp?
      @exp_nest > 0
    end

    def pushing_type(type)
      @types.push type
      yield
      @types.pop
    end

    def current_type
      @types.last
    end
  end
end
