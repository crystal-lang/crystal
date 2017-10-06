module Crystal
  class MacroInterpreter < Visitor
    getter last : ASTNode
    property free_vars : Hash(String, TypeVar)?

    def self.new(program, scope : Type, path_lookup : Type, a_macro : Macro, call, a_def : Def? = nil)
      vars = {} of String => ASTNode
      splat_index = a_macro.splat_index
      double_splat = a_macro.double_splat

      # Process regular args
      # (skip the splat index because we need to create an array for it)
      a_macro.match(call.args) do |macro_arg, macro_arg_index, call_arg, call_arg_index|
        vars[macro_arg.name] = call_arg if macro_arg_index != splat_index
      end

      # Gather splat args into an array
      if splat_index
        splat_arg = a_macro.args[splat_index]
        unless splat_arg.name.empty?
          splat_elements = if splat_index < call.args.size
                             splat_size = Splat.size(a_macro, call.args)
                             call.args[splat_index, splat_size]
                           else
                             [] of ASTNode
                           end
          vars[splat_arg.name] = TupleLiteral.new(splat_elements)
        end
      end

      # The double splat argument
      if double_splat
        named_tuple_elems = [] of NamedTupleLiteral::Entry
        if named_args = call.named_args
          named_args.each do |named_arg|
            # Skip an argument that's already there as a positional argument
            next if a_macro.args.any? &.external_name.==(named_arg.name)

            named_tuple_elems << NamedTupleLiteral::Entry.new(named_arg.name, named_arg.value)
          end
        end

        vars[double_splat.name] = NamedTupleLiteral.new(named_tuple_elems)
      end

      # Process default values
      a_macro.args.each do |macro_arg|
        default_value = macro_arg.default_value
        next unless default_value

        next if vars.has_key?(macro_arg.name)

        default_value = default_value.expand_node(call.location, call.end_location) if default_value.is_a?(MagicConstant)
        vars[macro_arg.name] = default_value
      end

      # The named arguments
      call.named_args.try &.each do |named_arg|
        arg = a_macro.args.find { |arg| arg.external_name == named_arg.name }
        arg_name = arg.try(&.name) || named_arg.name
        vars[arg_name] = named_arg.value
      end

      # The block arg
      call_block = call.block
      macro_block_arg = a_macro.block_arg
      if macro_block_arg
        vars[macro_block_arg.name] = call_block || Nop.new
      end

      new(program, scope, path_lookup, a_macro.location, vars, call.block, a_def)
    end

    record MacroVarKey, name : String, exps : Array(ASTNode)?

    def initialize(@program : Program,
                   @scope : Type, @path_lookup : Type, @location : Location?,
                   @vars = {} of String => ASTNode, @block : Block? = nil, @def : Def? = nil)
      @str = IO::Memory.new(512) # Can't be String::Builder because of `{{debug()}}
      @last = Nop.new
    end

    def define_var(name, value)
      @vars[name] = value
    end

    def accept(node)
      node.accept self
      @last
    end

    def visit(node : Expressions)
      node.expressions.each &.accept self
      false
    end

    def visit(node : MacroExpression)
      node.exp.accept self

      if node.output?
        # In the caseof {{yield}}, we want to paste the block's body
        # retaining the original node's location, so error messages
        # are shown in the block instead of in the generated macro source
        is_yield = node.exp.is_a?(Yield) && !@last.is_a?(Nop)
        @str << " #<loc:push>begin " if is_yield
        @last.to_s(@str, emit_loc_pragma: is_yield, emit_doc: is_yield)
        @str << " end#<loc:pop> " if is_yield
      end

      false
    end

    def visit(node : MacroLiteral)
      @str << node.value
    end

    def visit(node : Var)
      var = @vars[node.name]?
      if var
        return @last = var
      end

      # Try to consider the var as a top-level macro call.
      #
      # Note: this should really be done at the parser level. However,
      # currently macro calls with blocks are possible, for example:
      #
      # some_macro_call do |arg|
      #   {{arg}}
      # end
      #
      # and in this case the parser has no idea about this, so the only
      # solution is to do it now.
      if value = interpret_top_level_call?(Call.new(nil, node.name))
        return @last = value
      end

      node.raise "undefined macro variable '#{node.name}'"
    end

    def visit(node : StringInterpolation)
      @last = StringLiteral.new(String.build do |str|
        node.expressions.each do |exp|
          if exp.is_a?(StringLiteral)
            str << exp.value
          else
            exp.accept self
            @last.to_s(str)
          end
        end
      end)
      false
    end

    def visit(node : MacroIf)
      node.cond.accept self

      body = @last.truthy? ? node.then : node.else
      body.accept self

      false
    end

    def visit(node : MacroFor)
      node.exp.accept self

      exp = @last
      case exp
      when ArrayLiteral
        visit_macro_for_array_like node, exp
      when TupleLiteral
        visit_macro_for_array_like node, exp
      when HashLiteral
        visit_macro_for_hash_like(node, exp, exp.entries) do |entry|
          {entry.key, entry.value}
        end
      when NamedTupleLiteral
        visit_macro_for_hash_like(node, exp, exp.entries) do |entry|
          {MacroId.new(entry.key), entry.value}
        end
      when RangeLiteral
        exp.from.accept self
        from = @last

        unless from.is_a?(NumberLiteral)
          node.raise "range begin #{exp.from} must evaluate to a NumberLiteral"
        end

        from = from.to_number.to_i

        exp.to.accept self
        to = @last

        unless to.is_a?(NumberLiteral)
          node.raise "range end #{exp.to} must evaluate to a NumberLiteral"
        end

        to = to.to_number.to_i

        element_var = node.vars[0]
        index_var = node.vars[1]?

        range = Range.new(from, to, exp.exclusive?)
        range.each_with_index do |element, index|
          @vars[element_var.name] = NumberLiteral.new(element)
          if index_var
            @vars[index_var.name] = NumberLiteral.new(index)
          end
          node.body.accept self
        end

        @vars.delete element_var.name
        @vars.delete index_var.name if index_var
      when TypeNode
        type = exp.type

        case type
        when TupleInstanceType
          visit_macro_for_array_like(node, exp, type.tuple_types) do |type|
            TypeNode.new(type)
          end
        when NamedTupleInstanceType
          visit_macro_for_hash_like(node, exp, type.entries) do |entry|
            {MacroId.new(entry.name), TypeNode.new(entry.type)}
          end
        else
          exp.raise "can't interate TypeNode of type #{type}, only tuple or named tuple types"
        end
      else
        node.exp.raise "for expression must be an array, hash or tuple literal, not #{exp.class_desc}:\n\n#{exp}"
      end

      false
    end

    def visit_macro_for_array_like(node, exp)
      visit_macro_for_array_like node, exp, exp.elements, &.itself
    end

    def visit_macro_for_array_like(node, exp, entries)
      element_var = node.vars[0]
      index_var = node.vars[1]?

      entries.each_with_index do |element, index|
        @vars[element_var.name] = yield element
        if index_var
          @vars[index_var.name] = NumberLiteral.new(index)
        end
        node.body.accept self
      end

      @vars.delete element_var.name
      @vars.delete index_var.name if index_var
    end

    def visit_macro_for_hash_like(node, exp, entries)
      key_var = node.vars[0]
      value_var = node.vars[1]?
      index_var = node.vars[2]?

      entries.each_with_index do |entry, i|
        key, value = yield entry, value_var

        @vars[key_var.name] = key
        @vars[value_var.name] = value if value_var
        @vars[index_var.name] = NumberLiteral.new(i) if index_var

        node.body.accept self
      end

      @vars.delete key_var.name
      @vars.delete value_var.name if value_var
      @vars.delete index_var.name if index_var
    end

    def visit(node : MacroVar)
      if exps = node.exps
        exps = exps.map { |exp| accept exp }
      else
        exps = nil
      end

      key = MacroVarKey.new(node.name, exps)

      macro_vars = @macro_vars ||= {} of MacroVarKey => String
      macro_var = macro_vars[key] ||= @program.new_temp_var_name
      @str << macro_var
      false
    end

    def visit(node : Assign)
      case target = node.target
      when Var
        node.value.accept self
        @vars[target.name] = @last
      else
        node.raise "can only assign to variables, not #{target.class_desc}"
      end

      false
    end

    def visit(node : And)
      node.left.accept self
      if @last.truthy?
        node.right.accept self
      end
      false
    end

    def visit(node : Or)
      node.left.accept self
      unless @last.truthy?
        node.right.accept self
      end
      false
    end

    def visit(node : Not)
      node.exp.accept self
      @last = BoolLiteral.new(!@last.truthy?)
      false
    end

    def visit(node : If)
      node.cond.accept self
      (@last.truthy? ? node.then : node.else).accept self
      false
    end

    def visit(node : Unless)
      node.cond.accept self
      (@last.truthy? ? node.else : node.then).accept self
      false
    end

    def visit(node : Call)
      obj = node.obj
      if obj
        if obj.is_a?(Var) && (existing_var = @vars[obj.name]?)
          receiver = existing_var
        else
          obj.accept self
          receiver = @last
        end

        args = node.args.map { |arg| accept arg }

        begin
          @last = receiver.interpret(node.name, args, node.block, self)
        rescue ex : Crystal::Exception
          node.raise ex.message, inner: ex
        rescue ex
          node.raise ex.message
        end
      else
        # no receiver: special calls
        interpret_top_level_call node
      end

      false
    end

    def visit(node : Yield)
      if block = @block
        if node.exps.empty?
          @last = block.body.clone
        else
          block_vars = {} of String => ASTNode
          node.exps.each_with_index do |exp, i|
            if block_arg = block.args[i]?
              block_vars[block_arg.name] = exp.clone
            end
          end
          @last = replace_block_vars block.body.clone, block_vars
        end
      else
        @last = Nop.new
      end
      false
    end

    def visit(node : Path)
      @last = resolve(node)
      false
    end

    def resolve(node : Path)
      resolve?(node) || node.raise_undefined_constant(@path_lookup)
    end

    def resolve?(node : Path)
      if node.names.size == 1 && (match = @free_vars.try &.[node.names.first]?)
        matched_type = match
      else
        matched_type = @path_lookup.lookup_path(node)
      end

      return unless matched_type

      case matched_type
      when Const
        matched_type.value
      when Type
        matched_type = matched_type.remove_alias

        # If it's the T of a variadic generic type, produce tuple literals
        # or named tuple literals. The compiler has them as a type
        # (a tuple type, or a named tuple type) but the user should see
        # them as literals, and having them as a type doesn't add
        # any useful information.
        path_lookup = @path_lookup.instance_type
        if node.names.size == 1
          case path_lookup
          when UnionType
            produce_tuple = node.names.first == "T"
          when GenericInstanceType
            produce_tuple = ((splat_index = path_lookup.splat_index) &&
                             path_lookup.type_vars.keys.index(node.names.first) == splat_index) ||
                            (path_lookup.double_variadic? && path_lookup.type_vars.first_key == node.names.first)
          else
            produce_tuple = false
          end
          if produce_tuple
            case matched_type
            when TupleInstanceType
              return TupleLiteral.map(matched_type.tuple_types) { |t| TypeNode.new(t) }
            when NamedTupleInstanceType
              entries = matched_type.entries.map do |entry|
                NamedTupleLiteral::Entry.new(entry.name, TypeNode.new(entry.type))
              end
              return NamedTupleLiteral.new(entries)
            when UnionType
              return TupleLiteral.map(matched_type.union_types) { |t| TypeNode.new(t) }
            end
          end
        end

        TypeNode.new(matched_type)
      when Self
        target = @scope == @program.class_type ? @scope : @scope.instance_type
        TypeNode.new(target)
      when ASTNode
        matched_type
      else
        node.raise "can't interpret #{node}"
      end
    end

    def visit(node : Splat)
      node.exp.accept self
      @last = @last.interpret("splat", [] of ASTNode, nil, self)
      false
    end

    def visit(node : DoubleSplat)
      node.exp.accept self
      @last = @last.interpret("double_splat", [] of ASTNode, nil, self)
      false
    end

    def visit(node : IsA)
      node.obj.accept self
      const_name = node.const.to_s
      obj_class_desc = @last.class_desc
      @last = BoolLiteral.new(@last.class_desc == const_name)
      false
    end

    def visit(node : InstanceVar)
      case node.name
      when "@type"
        target = @scope == @program.class_type ? @scope : @scope.instance_type
        return @last = TypeNode.new(target)
      when "@def"
        return @last = @def || NilLiteral.new
      end

      node.raise "unknown macro instance var: '#{node.name}'"
    end

    def visit(node : TupleLiteral)
      @last = TupleLiteral.map(node.elements) { |element| accept element }.at(node)
      false
    end

    def visit(node : ArrayLiteral)
      @last = ArrayLiteral.map(node.elements) { |element| accept element }.at(node)
      false
    end

    def visit(node : HashLiteral)
      @last =
        HashLiteral.new(node.entries.map do |entry|
          HashLiteral::Entry.new(accept(entry.key), accept(entry.value))
        end).at(node)
      false
    end

    def visit(node : NamedTupleLiteral)
      @last =
        NamedTupleLiteral.new(node.entries.map do |entry|
          NamedTupleLiteral::Entry.new(entry.key, accept(entry.value))
        end).at(node)
      false
    end

    def visit(node : Nop | NilLiteral | BoolLiteral | NumberLiteral | CharLiteral | StringLiteral | SymbolLiteral | RangeLiteral | RegexLiteral | MacroId | TypeNode | Def)
      @last = node
      false
    end

    def visit(node : ASTNode)
      node.raise "can't execute #{node.class_desc} in a macro"
    end

    def to_s
      @str.to_s
    end

    def replace_block_vars(body, vars)
      transformer = ReplaceBlockVarsTransformer.new(vars)
      body.transform transformer
    end

    class ReplaceBlockVarsTransformer < Transformer
      @vars : Hash(String, ASTNode)

      def initialize(@vars)
      end

      def transform(node : MacroExpression)
        if (exp = node.exp).is_a?(Var)
          replacement = @vars[exp.name]?
          return replacement if replacement
        end
        node
      end
    end
  end
end
