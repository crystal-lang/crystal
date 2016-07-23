module Crystal
  abstract class BaseTypeVisitor < Visitor
    getter program : Program
    property types : Array(Type)
    property in_type_args

    @free_vars : Hash(String, TypeVar)?
    @type_lookup : Type?
    @scope : Type?
    @typed_def : Def?
    @last_doc : String?
    @block : Block?

    def initialize(@program, @vars = MetaVars.new)
      @types = [@program] of Type
      @exp_nest = 0
      @attributes = nil
      @lib_def_pass = 0
      @in_type_args = 0
      @in_generic_args = 0
      @block_nest = 0
      @in_is_a = false
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
          type_visitor = MainVisitor.new(@program, meta_vars, const_def)
          type_visitor.types = type.scope_types
          type_visitor.scope = type.scope

          type.value.accept type_visitor

          type.vars = const_def.vars
          type.visitor = self
          type.used = true

          program.class_var_and_const_initializers << type
        end

        node.target_const = type
        node.bind_to type.value
      when Type
        if type.is_a?(AliasType) && @in_generic_args == 0 && !type.aliased_type?
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

    private def const_or_class_var_name(const_or_class_var)
      if const_or_class_var.is_a?(Const)
        const_or_class_var.to_s
      else
        "#{const_or_class_var.owner}::#{const_or_class_var.name}"
      end
    end

    def visit(node : ProcNotation)
      @in_type_args += 1
      @in_generic_args += 1
      node.inputs.try &.each &.accept(self)
      node.output.try &.accept(self)
      @in_generic_args -= 1
      @in_type_args -= 1

      if inputs = node.inputs
        types = inputs.map &.type.instance_type.virtual_type
      else
        types = [] of Type
      end

      if output = node.output
        types << output.type.instance_type.virtual_type
      else
        types << program.void
      end

      node.type = program.proc_of(types)

      false
    end

    def visit(node : Union)
      @in_type_args += 1
      node.types.each &.accept self
      @in_type_args -= 1

      old_in_is_a, @in_is_a = @in_is_a, false

      types = node.types.map do |subtype|
        instance_type = subtype.type
        unless instance_type.allowed_in_generics?
          subtype.raise "can't use #{instance_type} in unions yet, use a more specific type"
        end
        instance_type.virtual_type
      end

      @in_is_a = old_in_is_a

      if @in_is_a
        node.type = @program.type_merge_union_of(types)
      else
        node.type = @program.type_merge(types)
      end

      false
    end

    def visit(node : Metaclass)
      node.name.accept self
      node.type = node.name.type.virtual_type.metaclass
      false
    end

    def visit(node : Self)
      the_self = (@scope || current_type)
      if the_self.is_a?(Program)
        node.raise "there's no self in this scope"
      end

      node.type = the_self.instance_type
    end

    def visit(node : Generic)
      node.in_type_args = @in_type_args > 0
      node.scope = @scope

      node.name.accept self

      @in_type_args += 1
      @in_generic_args += 1
      node.type_vars.each &.accept self
      node.named_args.try &.each &.value.accept self
      @in_generic_args -= 1
      @in_type_args -= 1

      return false if node.type?

      instance_type = node.name.type.instance_type
      unless instance_type.is_a?(GenericClassType)
        node.raise "#{instance_type} is not a generic class, it's a #{instance_type.type_desc}"
      end

      if instance_type.double_variadic?
        unless node.named_args
          node.raise "can only instantiate NamedTuple with named arguments"
        end
      elsif instance_type.splat_index
        if node.named_args
          node.raise "can only use named arguments with NamedTuple"
        end

        min_needed = instance_type.type_vars.size - 1
        if node.type_vars.size < min_needed
          node.wrong_number_of "type vars", instance_type, node.type_vars.size, "#{min_needed}+"
        end
      else
        if node.named_args
          node.raise "can only use named arguments with NamedTuple"
        end

        # Need to count type vars because there might be splats
        type_vars_count = 0
        knows_count = true
        node.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            if type_var.type?
              type_vars_count += type_var.type.as(TupleInstanceType).size
            else
              knows_count = false
              break
            end
          else
            type_vars_count += 1
          end
        end

        if knows_count && instance_type.type_vars.size != type_vars_count
          node.wrong_number_of "type vars", instance_type, type_vars_count, instance_type.type_vars.size
        end
      end

      node.instance_type = instance_type
      node.type_vars.each &.add_observer(node)
      node.named_args.try &.each &.value.add_observer(node)
      node.update

      false
    end

    def visit_fun_def(node : FunDef)
      check_outside_block_or_exp node, "declare fun"

      if node.body && !current_type.is_a?(Program)
        node.raise "can only declare fun at lib or global scope"
      end

      call_convention = check_call_convention_attributes node
      attributes = check_valid_attributes node, ValidFunDefAttributes, "fun"
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
        return_type = check_return_type_primitive_like(node_return_type)
        return_type = @program.nil if return_type.void?
      else
        return_type = @program.nil
      end

      external = node.external?
      had_external = external
      if external && (body = node.body)
        # This is the case where there's a body and we already have an external
        # because we declared it in TopLevelVisitor
        external.body = body
      else
        external = External.new(node.name, args, node.body, node.real_name).at(node)
        external.set_type(return_type)
        external.varargs = node.varargs?
        external.fun_def = node
        external.call_convention = call_convention
        external.doc = node.doc
        check_ditto external
        node.external = external
      end

      if node_body = node.body
        vars = MetaVars.new
        args.each do |arg|
          var = MetaVar.new(arg.name, arg.type)
          var.bind_to var
          vars[arg.name] = var
        end
        external.set_type(nil)

        visitor = MainVisitor.new(@program, vars, external)
        visitor.untyped_def = external
        visitor.scope = @program
        visitor.block_nest = @block_nest

        begin
          node_body.accept visitor
        rescue ex : Crystal::Exception
          node.raise ex.message, ex
        end

        inferred_return_type = @program.type_merge([node_body.type?, external.type?])

        if return_type && return_type != @program.nil && inferred_return_type != return_type
          node.raise "expected fun to return #{return_type} but it returned #{inferred_return_type}"
        end

        external.set_type(return_type)
      end

      unless had_external
        process_def_attributes(external, attributes)

        begin
          old_external = current_type.add_def external
        rescue ex : Crystal::Exception
          node.raise ex.message
        end

        if old_external.is_a?(External)
          old_external.dead = true
        end

        if current_type.is_a?(Program)
          key = DefInstanceKey.new external.object_id, external.args.map(&.type), nil, nil
          current_type.add_def_instance key, external
        end
      end

      node.type = @program.nil

      false
    end

    private def process_def_attributes(node, attributes)
      attributes.try &.each do |attribute|
        case attribute.name
        when "NoInline"     then node.no_inline = true
        when "AlwaysInline" then node.always_inline = true
        when "Naked"        then node.naked = true
        when "ReturnsTwice" then node.returns_twice = true
        when "Raises"       then node.raises = true
        end
      end
    end

    def processing_types
      yield
    end

    def visit(node : ASTNode)
      true
    end

    def visit_any(node)
      if nesting_exp?(node)
        @exp_nest += 1
      end

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
        when MacroExpression, MacroIf, MacroFor
          # Don't clear attributes that were generating with macros
        else
          @attributes = nil
        end
      end
    end

    def nesting_exp?(node)
      case node
      when Expressions, LibDef, ClassDef, ModuleDef, FunDef, Def, Macro,
           Alias, Include, Extend, EnumDef, VisibilityModifier, MacroFor, MacroIf, MacroExpression,
           FileNode, TypeDeclaration, Require
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
          msg << @program.colorize(" (did you mean '#{similar_name}'?)").yellow.bold if similar_name
        end
        node.raise error_msg
      end

      target_type
    end

    def resolve_ident?(node : Path, create_modules_if_missing = false)
      free_vars = @free_vars
      if free_vars && !node.global? && (type_var = free_vars[node.names.first]?)
        if type_var.is_a?(Type)
          target_type = type_var
          if node.names.size > 1
            target_type = lookup_type target_type, node.names[1..-1], node
          end
        else
          target_type = type_var
        end
      else
        base_lookup = node.global? ? program : (@type_lookup || @scope || @types.last)
        target_type = lookup_type base_lookup, node, node

        unless target_type
          if create_modules_if_missing
            next_type = base_lookup
            node.names.each do |name|
              next_type = lookup_type base_lookup, [name], node, lookup_in_container: false
              if next_type
                if next_type.is_a?(ASTNode)
                  node.raise "execpted #{name} to be a type"
                end
              else
                next_type = NonGenericModuleType.new(@program, base_lookup, name)

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

    def lookup_type(base_type, names, node, lookup_in_container = true)
      base_type.lookup_type names, lookup_in_container: lookup_in_container
    rescue ex : Crystal::Exception
      raise ex
    rescue ex
      node.raise ex.message
    end

    def process_type_name(node_name)
      if node_name.names.size == 1 && !node_name.global?
        scope = current_type
        name = node_name.names.first
      else
        name = node_name.names.pop
        scope = lookup_path_type node_name, create_modules_if_missing: true
      end
      {scope, name}
    end

    def attach_doc(type, node)
      if @program.wants_doc?
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
              @program.expand_macro hook.macro, call, current_type.instance_type, @type_lookup
            else
              @program.expand_macro hook.macro.body, current_type.instance_type, @type_lookup
            end
          end

          node.add_runtime_initializer(expanded)
        end
      end

      if kind == :inherited && (superclass = type_with_hooks.instance_type.superclass)
        run_hooks(superclass.metaclass, current_type, kind, node)
      end
    end

    def expand_macro(node, raise_on_missing_const = true, first_pass = false)
      if expanded = node.expanded
        @exp_nest -= 1
        begin
          expanded.accept self
        rescue ex : Crystal::Exception
          node.raise "expanding macro", ex
        end
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

        macro_scope = macro_scope.remove_alias

        the_macro = macro_scope.metaclass.lookup_macro(node.name, node.args, node.named_args)
      when Nil
        return false if node.name == "super" || node.name == "previous_def"
        the_macro = node.lookup_macro
      else
        return false
      end

      return false unless the_macro

      # If we find a macro outside a def/block and this is not the first pass it means that the
      # macro was defined before we first found this call, so it's an error
      # (we must analyze the macro expansion in all passes)
      if !@typed_def && !@block && !first_pass
        node.raise "macro '#{node.name}' must be defined before this point but is defined later"
      end

      expansion_scope = (macro_scope || @scope || current_type)

      args = expand_macro_arguments(node, expansion_scope)

      @exp_nest -= 1
      generated_nodes = expand_macro(the_macro, node) do
        old_args = node.args
        node.args = args
        expanded = @program.expand_macro the_macro, node, expansion_scope, @type_lookup
        node.args = old_args
        expanded
      end
      @exp_nest += 1

      node.expanded = generated_nodes
      node.bind_to generated_nodes

      true
    end

    def expand_macro(the_macro, node, mode = nil)
      begin
        expanded_macro = yield
      rescue ex : Crystal::Exception
        node.raise "expanding macro", ex
      end

      mode ||= if @lib_def_pass > 0
                 MacroExpansionMode::Lib
               else
                 MacroExpansionMode::Normal
               end

      generated_nodes = @program.parse_macro_source(expanded_macro, the_macro, node, Set.new(@vars.keys),
        inside_def: !!@typed_def,
        inside_type: !current_type.is_a?(Program),
        inside_exp: @exp_nest > 0,
        mode: mode,
      )

      if node_doc = node.doc
        generated_nodes.accept PropagateDocVisitor.new(node_doc)
      end

      generated_nodes.accept self
      generated_nodes
    end

    class PropagateDocVisitor < Visitor
      @doc : String

      def initialize(@doc)
      end

      def visit(node : Expressions)
        true
      end

      def visit(node : ClassDef | ModuleDef | EnumDef | Def | FunDef | Alias | Assign)
        node.doc ||= @doc
        false
      end

      def visit(node : ASTNode)
        true
      end
    end

    def expand_macro_arguments(node, expansion_scope)
      # If any argument is a MacroExpression, solve it first and
      # replace Path with Const/TypeNode if it denotes such thing
      args = node.args
      if args.any? &.is_a?(MacroExpression)
        @exp_nest -= 1
        args = args.map do |arg|
          if arg.is_a?(MacroExpression)
            arg.accept self
            expanded = arg.expanded.not_nil!
            if expanded.is_a?(Path)
              expanded_type = expansion_scope.lookup_type(expanded)
              case expanded_type
              when Const
                expanded = expanded_type.value
              when Type
                expanded = TypeNode.new(expanded_type)
              end
            end
            expanded
          else
            arg
          end
        end
        @exp_nest += 1
      end
      args
    end

    def visit(node : MacroExpression)
      expand_inline_macro node
      false
    end

    def visit(node : MacroIf)
      expand_inline_macro node
      false
    end

    def visit(node : MacroFor)
      expand_inline_macro node
      false
    end

    def expand_inline_macro(node, mode = nil)
      if expanded = node.expanded
        begin
          expanded.accept self
        rescue ex : Crystal::Exception
          node.raise "expanding macro", ex
        end
        return expanded
      end

      the_macro = Macro.new("macro_#{node.object_id}", [] of Arg, node).at(node.location)

      generated_nodes = expand_macro(the_macro, node, mode: mode) do
        @program.expand_macro node, (@scope || current_type), @type_lookup, @free_vars
      end

      node.expanded = generated_nodes
      node.bind_to generated_nodes

      generated_nodes
    end

    def check_valid_attributes(node, valid_attributes, desc)
      attributes = @attributes
      return unless attributes

      attributes.each do |attr|
        unless valid_attributes.includes?(attr.name)
          attr.raise "illegal attribute for #{desc}, valid attributes are: #{valid_attributes.join ", "}"
        end

        if attr.name != "Primitive"
          if !attr.args.empty? || attr.named_args
            attr.raise "#{attr.name} attribute can't receive arguments"
          end
        end
      end

      attributes
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

    def check_return_type_primitive_like(node)
      type = node.type.instance_type
      return type if type.nil_type?

      check_primitive_like(node)
    end

    def check_primitive_like(node)
      type = node.type.instance_type

      unless type.primitive_like?
        msg = String.build do |msg|
          msg << "only primitive types, pointers, structs, unions, enums and tuples are allowed in lib declarations"
          msg << " (did you mean Int32?)" if type == @program.int
          msg << " (did you mean Float32?)" if type == @program.float
        end
        node.raise msg
      end

      if type.is_a?(TypeDefType) && type.typedef.proc?
        type = type.typedef
      end

      type
    end

    def interpret_enum_value(node : NumberLiteral, target_type = nil)
      case node.kind
      when :i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64, :i64
        target_kind = target_type.try(&.kind) || node.kind
        case target_kind
        when :i8  then node.value.to_i8? || node.raise "invalid Int8: #{node.value}"
        when :u8  then node.value.to_u8? || node.raise "invalid UInt8: #{node.value}"
        when :i16 then node.value.to_i16? || node.raise "invalid Int16: #{node.value}"
        when :u16 then node.value.to_u16? || node.raise "invalid UInt16: #{node.value}"
        when :i32 then node.value.to_i32? || node.raise "invalid Int32: #{node.value}"
        when :u32 then node.value.to_u32? || node.raise "invalid UInt32: #{node.value}"
        when :i64 then node.value.to_i64? || node.raise "invalid Int64: #{node.value}"
        when :u64 then node.value.to_u64? || node.raise "invalid UInt64: #{node.value}"
        else
          node.raise "enum type must be an integer, not #{target_kind}"
        end
      else
        node.raise "constant value must be an integer, not #{node.kind}"
      end
    end

    def interpret_enum_value(node : Call, target_type = nil)
      obj = node.obj
      if obj
        if obj.is_a?(Path)
          value = interpret_enum_value_call_macro?(node, target_type)
          return value if value
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
              interpret_enum_value_call_macro(node, target_type)
            end
          when "~" then ~left
          else
            interpret_enum_value_call_macro(node, target_type)
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
            interpret_enum_value_call_macro(node, target_type)
          end
        else
          node.raise "invalid constant value"
        end
      else
        interpret_enum_value_call_macro(node, target_type)
      end
    end

    def interpret_enum_value_call_macro(node : Call, target_type = nil)
      interpret_enum_value_call_macro?(node, target_type) ||
        node.raise("invalid constant value")
    end

    def interpret_enum_value_call_macro?(node : Call, target_type = nil)
      if node.global?
        node.scope = @program
      else
        node.scope = @scope || current_type.metaclass
      end

      if expand_macro(node, raise_on_missing_const: false, first_pass: true)
        return interpret_enum_value(node.expanded.not_nil!, target_type)
      end

      nil
    end

    def interpret_enum_value(node : Path, target_type = nil)
      type = resolve_ident(node)
      case type
      when Const
        interpret_enum_value(type.value, target_type)
      else
        node.raise "invalid constant value"
      end
    end

    def interpret_enum_value(node : Expressions, target_type = nil)
      if node.expressions.size == 1
        interpret_enum_value(node.expressions.first)
      else
        node.raise "invalid constant value"
      end
    end

    def interpret_enum_value(node : ASTNode, target_type = nil)
      node.raise "invalid constant value"
    end

    def visit(node : ExternalVar)
      false
    end

    # Transform require to its source code.
    # The source code can be a Nop if the file was already required.
    def visit(node : Require)
      if expanded = node.expanded
        expanded.accept self
        return false
      end

      if inside_exp?
        node.raise "can't require dynamically"
      end

      location = node.location
      filenames = @program.find_in_path(node.string, location.try &.original_filename)
      if filenames
        nodes = Array(ASTNode).new(filenames.size)
        filenames.each do |filename|
          if @program.add_to_requires(filename)
            parser = Parser.new File.read(filename), @program.string_pool
            parser.filename = filename
            parser.wants_doc = @program.wants_doc?
            parsed_nodes = parser.parse
            parsed_nodes = @program.normalize(parsed_nodes, inside_exp: inside_exp?)
            # We must type the node immediately, in case a file requires another
            # *before* one of the files in `filenames`
            parsed_nodes.accept self
            nodes << FileNode.new(parsed_nodes, filename)
          end
        end
        expanded = Expressions.from(nodes)
        expanded.bind_to(nodes)
      else
        expanded = Nop.new
      end

      node.expanded = expanded
      node.bind_to(expanded)
      false
    rescue ex : Crystal::Exception
      node.raise "while requiring \"#{node.string}\"", ex
    rescue ex
      node.raise "while requiring \"#{node.string}\": #{ex.message}"
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
          attr.wrong_number_of_arguments "attribute CallConvention", attr.args.size, 1
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

    def check_declare_var_type(node, declared_type, variable_kind)
      type = declared_type.instance_type

      if type.is_a?(GenericClassType)
        node.raise "can't declare variable of generic non-instantiated type #{type}"
      end

      Crystal.check_type_allowed_in_generics(node, type, "can't use #{type} as the type of #{variable_kind}")

      declared_type
    end

    def class_var_owner(node)
      scope = (@scope || current_type).class_var_owner
      if scope.is_a?(Program)
        node.raise "can't use class variables at the top level"
      end

      if scope.is_a?(GenericClassType) || scope.is_a?(GenericModuleType)
        node.raise "can't use class variables in generic types"
      end

      scope.as(ClassVarContainer)
    end

    def lookup_class_var(node)
      class_var_owner = class_var_owner(node)
      var = class_var_owner.lookup_class_var?(node.name)
      unless var
        undefined_class_variable(node, class_var_owner)
      end
      var
    end

    def undefined_class_variable(node, owner)
      similar_name = lookup_similar_class_variable_name(node, owner)
      @program.undefined_class_variable(node, owner, similar_name)
    end

    def lookup_similar_class_variable_name(node, owner)
      Levenshtein.find(node.name) do |finder|
        owner.class_vars.each_key do |name|
          finder.test(name)
        end
      end
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
