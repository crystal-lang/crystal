module Crystal
  class Program
    def expand_macro(a_macro : Macro, call : Call, scope : Type, type_lookup : Type?)
      macro_expander.expand a_macro, call, scope, type_lookup || scope
    end

    def expand_macro(node : ASTNode, scope : Type, type_lookup : Type?, free_vars = nil)
      macro_expander.expand node, scope, type_lookup || scope, free_vars
    end

    def parse_macro_source(expanded_macro, the_macro, node, vars, inside_def = false, inside_type = false, inside_exp = false)
      parse_macro_source expanded_macro, the_macro, node, vars, inside_def, inside_type, inside_exp, &.parse
    end

    def parse_macro_source(expanded_macro, the_macro, node, vars, inside_def = false, inside_type = false, inside_exp = false)
      generated_source = expanded_macro.source
      begin
        parser = Parser.new(generated_source, @program.string_pool, [vars.dup])
        parser.filename = VirtualFile.new(the_macro, generated_source, node.location)
        parser.visibility = node.visibility
        parser.def_nest = 1 if inside_def
        parser.type_nest = 1 if inside_type
        parser.wants_doc = @program.wants_doc?
        generated_node = yield parser
        if yields = expanded_macro.yields
          generated_node = generated_node.transform(YieldsTransformer.new(yields))
        end
        normalize(generated_node, inside_exp: inside_exp)
      rescue ex : Crystal::SyntaxException
        node.raise "macro didn't expand to a valid program, it expanded to:\n\n#{"=" * 80}\n#{"-" * 80}\n#{generated_source.lines.to_s_with_line_numbers}\n#{"-" * 80}\n#{ex.to_s_with_source(generated_source)}\n#{"=" * 80}"
      end
    end
  end

  class MacroExpander
    # When a macro is expanded the result is a source code to be parsed.
    # When a macro contains `{{yield}}`, instead of transforming the yielded
    # node to a String, which would cause loss of location information (which could
    # be added with a loc pragma, but it would be slow) a placeholder is created
    # and later must be replaced. The mapping of placeholders is the `yields` property
    # of this record. What must be replaced are argless calls whose name appear in this
    # `yields` hash.
    record ExpandedMacro, source : String, yields : Hash(String, ASTNode)?

    def initialize(@mod : Program)
      @cache = {} of String => String
    end

    def expand(a_macro : Macro, call : Call, scope : Type, type_lookup : Type)
      visitor = MacroVisitor.new self, @mod, scope, type_lookup, a_macro, call
      a_macro.body.accept visitor
      source = visitor.to_s
      ExpandedMacro.new source, visitor.yields
    end

    def expand(node : ASTNode, scope : Type, type_lookup : Type, free_vars = nil)
      visitor = MacroVisitor.new self, @mod, scope, type_lookup, node.location
      visitor.free_vars = free_vars
      node.accept visitor
      source = visitor.to_s
      ExpandedMacro.new source, visitor.yields
    end

    def run(filename, args)
      compiled_file = @cache[filename] ||= compile(filename)

      command = String.build do |str|
        str << compiled_file.inspect
        args.each do |arg|
          str << " "
          str << arg.inspect
        end
      end

      result = `#{command}`
      {$?.success?, result}
    end

    def compile(filename)
      source = File.read(filename)

      compiler = Compiler.new

      # Although release takes longer, once the bc is cached in .crystal
      # the subsequent times will make program execution faster.
      compiler.release = true

      # Don't cleanup old directories after compiling: it might happen
      # that in doing so we remove the directory associated with the current
      # compilation (for example if we have more than 10 macro runs, the current
      # directory will be the oldest).
      compiler.cleanup = false

      safe_filename = filename.gsub(/[^a-zA-Z\_\-\.]/, "_")

      tempfile_path = @mod.new_tempfile("macro-run-#{safe_filename}")

      compiler.compile Compiler::Source.new(filename, source), tempfile_path

      tempfile_path
    end

    class MacroVisitor < Visitor
      getter last : ASTNode
      getter yields : Hash(String, ASTNode)?
      property free_vars : Hash(String, TypeVar)?

      def self.new(expander, mod, scope : Type, type_lookup : Type, a_macro : Macro, call)
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

          default_value = default_value.expand_node(call.location) if default_value.is_a?(MagicConstant)
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

        new(expander, mod, scope, type_lookup, a_macro.location, vars, call.block)
      end

      record MacroVarKey, name : String, exps : Array(ASTNode)?

      def initialize(@expander : MacroExpander, @mod : Program,
                     @scope : Type, @type_lookup : Type, @location : Location?,
                     @vars = {} of String => ASTNode, @block : Block? = nil)
        @str = MemoryIO.new(512)
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

        if node.output
          if node.exp.is_a?(Yield) && !@last.is_a?(Nop)
            var_name = @mod.new_temp_var_name
            yields = @yields ||= {} of String => ASTNode
            yields[var_name] = @last
            @last = Var.new(var_name)
          end
          @last.to_s(@str)
        end

        false
      end

      def visit(node : MacroLiteral)
        @str << node.value
      end

      def visit(node : Var)
        var = @vars[node.name]?
        if var
          @last = var
        else
          node.raise "undefined macro variable '#{node.name}'"
        end
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

          exclusive = exp.exclusive

          element_var = node.vars[0]
          index_var = node.vars[1]?

          range = Range.new(from, to, exclusive)
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
          unless type.is_a?(NamedTupleInstanceType)
            exp.raise "can't interate TypeNode of type #{type}, only named tuple types"
          end

          visit_macro_for_hash_like(node, exp, type.names_and_types) do |name_and_type|
            {MacroId.new(name_and_type[0]), TypeNode.new(name_and_type[1])}
          end
        else
          node.exp.raise "for expression must be an array, hash or tuple literal, not #{exp.class_desc}:\n\n#{exp}"
        end

        false
      end

      def visit_macro_for_array_like(node, exp)
        element_var = node.vars[0]
        index_var = node.vars[1]?

        exp.elements.each_with_index do |element, index|
          @vars[element_var.name] = element
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
        macro_var = macro_vars[key] ||= @mod.new_temp_var_name
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
          execute_special_call node
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
        if node.names.size == 1 && (match = @free_vars.try &.[node.names.first]?)
          matched_type = match
        else
          matched_type = @type_lookup.lookup_type(node)
        end

        unless matched_type
          node.raise "undefined constant #{node}"
        end

        case matched_type
        when Const
          matched_type.value
        when Type
          TypeNode.new(matched_type)
        when ASTNode
          matched_type
        else
          node.raise "can't interpret #{node}"
        end
      end

      def visit(node : Splat)
        node.exp.accept self
        @last = @last.interpret("argify", [] of ASTNode, nil, self)
        false
      end

      def visit(node : IsA)
        node.obj.accept self
        const_name = node.const.to_s
        obj_class_desc = @last.class_desc
        @last = BoolLiteral.new(@last.class_desc == const_name)
        false
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

      def replace_block_vars(body, vars)
        transformer = ReplaceBlockVarsTransformer.new(vars)
        body.transform transformer
      end

      def execute_special_call(node)
        case node.name
        when "debug"
          execute_debug
        when "env"
          execute_env(node)
        when "now"
          execute_now(node)
        when "puts", "p"
          execute_puts(node)
        when "pp"
          execute_pp(node)
        when "system", "`"
          execute_system(node)
        when "raise"
          execute_raise(node)
        when "run"
          execute_run(node)
        else
          node.raise "unknown special macro call: '#{node.name}'"
        end
      end

      def execute_debug
        puts @str
        @last = Nop.new
      end

      def execute_env(node)
        if node.args.size == 1
          node.args[0].accept self
          cmd = @last.to_macro_id
          env_value = ENV[cmd]?
          @last = env_value ? StringLiteral.new(env_value) : NilLiteral.new
        else
          node.wrong_number_of_arguments "macro call 'env'", node.args.size, 1
        end
      end

      def execute_now(node)
        case node.args.size
        when 1
          node.args[0].accept self
          format = @last.to_macro_id
          utc = false

          if named_args = node.named_args
            utc_arg = named_args.find &.name.==("utc")
            if utc_arg
              utc_arg.value.accept self
              utc = @last.truthy?
            end
          end
        when 2
          node.args[0].accept self
          format = @last.to_macro_id
          node.args[1].accept self
          utc = @last.truthy?
        else
          node.wrong_number_of_arguments "macro call 'now'", node.args.size, 1
        end

        begin
          time = utc ? Time.utc_now : Time.now
          @last = StringLiteral.new(time.to_s(format))
        rescue ex
          node.raise ex.message
        end
      end

      def execute_puts(node)
        node.args.each do |arg|
          arg.accept self
          puts @last
        end

        @last = Nop.new
      end

      def execute_pp(node)
        node.args.each do |arg|
          arg.accept self
          print arg
          print " = "
          puts @last
        end

        @last = Nop.new
      end

      def execute_system(node)
        cmd = node.args.map do |arg|
          arg.accept self
          @last.to_macro_id
        end
        cmd = cmd.join " "

        result = `#{cmd}`
        if $?.success?
          @last = MacroId.new(result)
        elsif result.empty?
          node.raise "error executing command: #{cmd}, got exit status #{$?.exit_code}"
        else
          node.raise "error executing command: #{cmd}, got exit status #{$?.exit_code}:\n\n#{result}\n"
        end
      end

      def execute_raise(node)
        msg = node.args.map do |arg|
          arg.accept self
          @last.to_macro_id
        end
        msg = msg.join " "

        node.raise "can't expand macro: #{msg}"
      end

      def execute_run(node)
        if node.args.size == 0
          node.wrong_number_of_arguments "macro call 'run'", 0, "1+"
        end

        node.args.first.accept self
        filename = @last.to_macro_id
        original_filanme = filename

        # Support absolute paths
        if filename.starts_with?("/")
          filename = "#{filename}.cr" unless filename.ends_with?(".cr")

          if File.exists?(filename)
            unless File.file?(filename)
              node.raise "error executing macro run: '#{filename}' is not a file"
            end
          else
            node.raise "error executing macro run: can't find file '#{filename}'"
          end
        else
          begin
            relative_to = @location.try &.original_filename
            found_filenames = @mod.find_in_path(filename, relative_to)
          rescue ex
            node.raise "error executing macro run: #{ex.message}"
          end

          unless found_filenames
            node.raise "error executing macro run: can't find file '#{filename}'"
          end

          if found_filenames.size > 1
            node.raise "error executing macro run: '#{filename}' is a directory"
          end

          filename = found_filenames.first
        end

        run_args = [] of String
        node.args.each_with_index do |arg, i|
          next if i == 0

          arg.accept self
          run_args << @last.to_macro_id
        end

        success, result = @expander.run(filename, run_args)
        if success
          @last = MacroId.new(result)
        else
          node.raise "Error executing run: #{original_filanme} #{run_args.map(&.inspect).join " "}\n\nGot:\n\n#{result}\n"
        end
      end

      def visit(node : InstanceVar)
        case node.name
        when "@type"
          target = @scope == @mod.class_type ? @scope : @scope.instance_type
          return @last = TypeNode.new(target)
        end

        node.raise "unknown macro instance var: '#{node.name}'"
      end

      def visit(node : MetaVar)
        @last = node
      end

      {% for name in %w(Bool Number Char String Symbol Nil Range Regex) %}
        def visit(node : {{name.id}}Literal)
          @last = node
          false
        end
      {% end %}

      def visit(node : TupleLiteral)
        @last =
          TupleLiteral.new(node.elements.map do |element|
            accept element
          end).at(node)
        false
      end

      def visit(node : ArrayLiteral)
        @last =
          ArrayLiteral.new(node.elements.map do |element|
            accept element
          end).at(node)
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

      def visit(node : Nop)
        @last = node
      end

      def visit(node : MacroId)
        @last = node
      end

      def visit(node : TypeNode)
        @last = node
      end

      def visit(node : Def)
        @last = node
        false
      end

      def visit(node : ASTNode)
        node.raise "can't execute #{node.class_desc} in a macro"
      end

      def to_s
        @str.to_s
      end

      def to_s(io)
        @str.to_s(io)
      end
    end
  end

  class YieldsTransformer < Transformer
    @yields : Hash(String, Crystal::ASTNode)

    def initialize(@yields)
    end

    def transform(node : Call)
      @yields[node.name]? || super
    end

    def transform(node : MacroLiteral)
      # For the very rare case where a macro generates a macro,
      # the macro's body won't be an AST node (won't be parsed).
      # So, we use gsub to replace the yield values.
      value = node.value

      @yields.each do |name, node|
        value = value.gsub(name) { node.to_s }
      end

      node.value = value

      node
    end
  end
end
