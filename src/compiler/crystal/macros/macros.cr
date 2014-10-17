require "tempfile"

module Crystal
  class Program
    def push_def_macro(def)
      @def_macros << def
    end

    def expand_macro(scope : Type, a_macro : Macro, call)
      @macro_expander.expand scope, a_macro, call
    end

    def expand_macro(scope : Type, node)
      @macro_expander.expand scope, node
    end

    def expand_def_macros
      until @def_macros.empty?
        def_macro = @def_macros.pop
        expand_def_macro def_macro
      end
    end

    def expand_def_macro(target_def)
      the_macro = Macro.new("macro_#{target_def.object_id}", [] of Arg, target_def.body)
      the_macro.location = target_def.location

      owner = target_def.owner

      case owner
      when VirtualType
        owner = owner.base_type
      when VirtualMetaclassType
        owner = owner.instance_type.base_type.metaclass
      end

      begin
        generated_source = @program.expand_macro owner, target_def.body
      rescue ex : Crystal::Exception
        target_def.raise "expanding macro", ex
      end

      vars = MetaVars.new
      target_def.args.each do |arg|
        vars[arg.name] = MetaVar.new(arg.name, arg.type)
      end
      vars["self"] = MetaVar.new("self", owner) unless owner.is_a?(Program)
      target_def.vars = vars

      arg_names = target_def.args.map(&.name)

      generated_nodes = parse_macro_source(generated_source, the_macro, target_def, arg_names.to_set) do |parser|
        parser.parse_to_def(target_def)
      end

      type_visitor = TypeVisitor.new(@program, vars, target_def)
      type_visitor.scope = owner
      generated_nodes.accept type_visitor

      if generated_nodes.type != target_def.type
        target_def.raise "expected '#{target_def.name}' to return #{target_def.type}, not #{generated_nodes.type}"
      end

      target_def.body = generated_nodes
    end

    def parse_macro_source(generated_source, the_macro, node, vars)
      parse_macro_source generated_source, the_macro, node, vars, &.parse
    end

    def parse_macro_source(generated_source, the_macro, node, vars)
      begin
        parser = Parser.new(generated_source, [vars.dup])
        parser.filename = VirtualFile.new(the_macro, generated_source, node.location)
        parser.visibility = node.visibility
        normalize(yield parser)
      rescue ex : Crystal::SyntaxException
        node.raise "macro didn't expand to a valid program, it expanded to:\n\n#{"=" * 80}\n#{"-" * 80}\n#{generated_source.lines.to_s_with_line_numbers}\n#{"-" * 80}\n#{ex.to_s_with_source(generated_source)}\n#{"=" * 80}"
      end
    end
  end

  class MacroExpander
    def initialize(@mod)
      @cache = {} of String => String
    end

    def expand(scope : Type, a_macro, call)
      visitor = MacroVisitor.new self, @mod, scope, a_macro, call
      a_macro.body.accept visitor
      visitor.to_s
    end

    def expand(scope : Type, node)
      visitor = MacroVisitor.new self, @mod, scope, node.location
      node.accept visitor
      visitor.to_s
    end

    def run(filename, args)
      compiled_file = @cache[filename] ||= compile(filename)

      command = String.build do |str|
        str << compiled_file
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

      tempfile = Tempfile.new "crystal-run"
      tempfile.close

      compiler = Compiler.new

      # Although release takes longer, once the bc is cached in .crystal
      # the subsequent times will make program execution faster.
      compiler.release = true

      compiler.compile Compiler::Source.new(filename, source), tempfile.path

      tempfile.path
    end

    class MacroVisitor < Visitor
      getter last

      def self.new(expander, mod, scope, a_macro : Macro, call)
        vars = {} of String => ASTNode

        macro_args_length = a_macro.args.length
        call_args_length = call.args.length
        splat_index = a_macro.splat_index || -1

        # Args before the splat argument
        0.upto(splat_index - 1) do |index|
          macro_arg = a_macro.args[index]
          call_arg = call.args[index]? || macro_arg.default_value.not_nil!
          vars[macro_arg.name] = call_arg.to_macro_var
        end

        # The splat argument
        if splat_index == -1
          splat_length = 0
          offset = 0
        else
          splat_length = call_args_length - (macro_args_length - 1)
          offset = splat_index + splat_length
          splat_arg = a_macro.args[splat_index]
          vars[splat_arg.name] = ArrayLiteral.new(call.args[splat_index, splat_length])
        end

        # Args after the splat argument
        base = splat_index + 1
        base.upto(macro_args_length - 1) do |index|
          macro_arg = a_macro.args[index]
          call_arg = call.args[offset + index - base]? || macro_arg.default_value.not_nil!
          vars[macro_arg.name] = call_arg.to_macro_var
        end

        # The named arguments
        call.named_args.try &.each do |named_arg|
          vars[named_arg.name] = named_arg.value
        end

        # The block arg
        call_block = call.block
        macro_block_arg = a_macro.block_arg
        if macro_block_arg
          vars[macro_block_arg.name] = call_block || Nop.new
        end

        new(expander, mod, scope, a_macro.location, vars, call.block)
      end

      def initialize(@expander, @mod, @scope, @location, @vars = {} of String => ASTNode, @block = nil)
        @str = StringIO.new(512)
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

        unless node.exp.is_a?(Assign)
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

        if @last.truthy?
          node.then.accept self
        else
          node.else.accept self
        end

        false
      end

      def visit(node : MacroFor)
        node.exp.accept self

        exp = @last
        case exp
        when ArrayLiteral
          visit_macro_for_single_iterable node, exp
        when TupleLiteral
          visit_macro_for_single_iterable node, exp
        when HashLiteral
          key_var = node.vars[0]
          value_var = node.vars[1]?
          index_var = node.vars[2]?

          i = 0
          exp.keys.zip(exp.values) do |key, value|
            @vars[key_var.name] = key
            if value_var
              @vars[value_var.name] = value
            end
            if index_var
              @vars[index_var.name] = NumberLiteral.new(i)
            end

            node.body.accept self

            i += 1
          end

          @vars.delete key_var.name
          @vars.delete value_var.name if value_var
          @vars.delete index_var.name if index_var
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
        else
          node.exp.raise "for expression must be an array, hash or tuple literal, not #{exp.class_desc}:\n\n#{exp}"
        end

        false
      end

      def visit_macro_for_single_iterable(node, exp)
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

      def visit(node : Call)
        obj = node.obj
        if obj
          obj.accept self
          receiver = @last

          args = node.args.map do |arg|
            arg.accept self
            @last
          end

          begin
            @last = receiver.interpret(node.name, args, node.block, self)
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
            @last = block.body
          else
            block_vars = {} of String => ASTNode
            node.exps.each_with_index do |exp, i|
              if block_arg = block.args[i]?
                block_vars[block_arg.name] = exp
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
        matched_type = @scope.lookup_type(node)
        unless matched_type
          node.raise "undefined constant #{node}"
        end

        case matched_type
        when Const
          @last = matched_type.value
        when Type
          @last = MacroType.new(matched_type)
        when ASTNode
          @last = matched_type
        else
          node.raise "can't interpret #{node}"
        end

        false
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
        when "env"
          execute_env(node)
        when "puts", "p"
          execute_puts(node)
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

      def execute_env(node)
        if node.args.length == 1
          node.args[0].accept self
          cmd = @last.to_macro_id
          env_value = ENV[cmd]?
          @last = env_value ? StringLiteral.new(env_value) : NilLiteral.new
        else
          node.raise "wrong number of arguments for macro call 'env' (#{node.args.length} for 1)"
        end
      end

      def execute_puts(node)
        node.args.each do |arg|
          arg.accept self
          puts @last
        end

        @last = NilLiteral.new
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
          node.raise "error executing command: #{cmd}, got exit status #{$?.exit}"
        else
          node.raise "error executing command: #{cmd}, got exit status #{$?.exit}:\n\n#{result}\n"
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
        if node.args.length == 0
          node.raise "wrong number of arguments for macro run (0 for 1..)"
        end

        node.args.first.accept self
        filename = @last.to_macro_id
        original_filanme = filename

        begin
          relative_to = @location.try &.filename
          if relative_to.is_a?(VirtualFile)
            relative_to = relative_to.expanded_location.try(&.filename)
          end

          found_filenames = @mod.find_in_path(filename, relative_to)
        rescue ex
          node.raise "error executing macro run: #{ex.message}"
        end

        unless found_filenames
          node.raise "error executing macro run: can't find file '#{filename}'"
        end

        if found_filenames.length > 1
          node.raise "error executing macro run: '#{filename}' is a directory"
        end

        filename = found_filenames.first

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
        when "@class_name"
          return @last = StringLiteral.new(@scope.to_s)
        when "@instance_vars"
          return @last = MacroType.instance_vars(@scope)
        when "@length"
          if (scope = @scope).is_a?(TupleInstanceType)
            return @last = NumberLiteral.new(scope.tuple_types.length)
          end
        when "@superclass"
          return @last = MacroType.superclass(@scope)
        when "@type"
          return @last = MacroType.new(@scope)
        end

        node.raise "unknown macro instance var: '#{node.name}'"
      end

      def visit(node : MetaVar)
        @last = node
      end

      {% for name in %w(Bool Number Char String Symbol Nil Array Range Tuple Hash Regex) %}
        def visit(node : {{name.id}}Literal)
          @last = node
          false
        end
      {% end %}

      def visit(node : Nop)
        @last = node
      end

      def visit(node : MacroId)
        @last = node
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
end
