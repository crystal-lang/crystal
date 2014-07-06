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

      owner = target_def.owner.not_nil!

      begin
        generated_source = @program.expand_macro owner, target_def.body
      rescue ex : Crystal::Exception
        target_def.raise "expanding macro", ex
      end

      vars = MetaVars.new
      target_def.args.each do |arg|
        vars[arg.name] = MetaVar.new(arg.name, arg.type)
      end
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
        parser = Parser.new(generated_source, [vars])
        parser.filename = VirtualFile.new(the_macro, generated_source, node.location)
        normalize(yield parser)
      rescue ex : Crystal::SyntaxException
        node.raise "macro didn't expand to a valid program, it expanded to:\n\n#{"=" * 80}\n#{"-" * 80}\n#{generated_source.lines.to_s_with_line_numbers}\n#{"-" * 80}\n#{ex.to_s(generated_source)}\n#{"=" * 80}"
      end
    end
  end

  class MacroExpander
    make_named_tuple CompiledFile, [name, handle]

    def initialize(@mod)
      @cache = {} of String => CompiledFile
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
        str << compiled_file.name
        args.each do |arg|
          str << " "
          str << arg.inspect
        end
      end

      result = system2(command).join "\n"
      {$exit == 0, result}
    end

    def compile(filename)
      source = File.read(filename)

      output_filename = "#{ENV["TMPDIR"] || "/tmp"}/.crystal-run.XXXXXX"
      tmp_fd = C.mkstemp output_filename
      raise "Error creating temp file #{output_filename}" if tmp_fd == -1
      C.close tmp_fd

      compiler = Compiler.new
      compiler.output_filename = output_filename

      # Although release takes longer, once the bc is cached in .crystal
      # the subsequent times will make program execution faster.
      compiler.release = true

      compiler.compile(filename, source)

      CompiledFile.new(output_filename, tmp_fd)
    end

    class MacroVisitor < Visitor
      getter last

      def self.new(expander, mod, scope, a_macro : Macro, call)
        vars = {} of String => ASTNode

        a_macro.args.each_with_index do |macro_arg, index|
          call_arg = call.args[index]? || macro_arg.default_value.not_nil!
          vars[macro_arg.name] = call_arg.to_macro_var
        end

        new(expander, mod, scope, a_macro.location, vars, call.block)
      end

      def initialize(@expander, @mod, @scope, @location, @vars = {} of String => ASTNode, @block = nil)
        @str = StringBuilder.new
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
          @str << @last.to_s
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
              str << @last.to_s
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
        when ArrayLiteral, TupleLiteral
          element_var = node.vars[0]
          index_var = node.vars[1]?

          exp.elements.each_with_index do |element, index|
            @vars[element_var.name] = element
            if index_var
              @vars[index_var.name] = NumberLiteral.new(index, :i32)
            end
            node.body.accept self
          end

          @vars.delete element_var.name
          @vars.delete index_var.name if index_var
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
              @vars[index_var.name] = NumberLiteral.new(i, :i32)
            end

            node.body.accept self

            i += 1
          end

          @vars.delete key_var.name
          @vars.delete value_var.name if value_var
          @vars.delete index_var.name if index_var
        else
          node.exp.raise "for expression must be an array, hash or tuple literal, not #{exp.class_desc}:\n\n#{exp}"
        end

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
        when "puts", "p"
          execute_puts(node)
        when "system"
          execute_system(node)
        when "raise"
          execute_raise(node)
        when "run"
          execute_run(node)
        else
          node.raise "unknown special macro call: '#{node.name}'"
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

        result = system2(cmd).join "\n"
        if $exit == 0
          @last = MacroId.new(result)
        else
          node.raise "error executing command: #{cmd}\n\nGot:\n\n#{result}\n"
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
        when "@name", "@class_name"
          @last = StringLiteral.new(@scope.to_s)
        when "@instance_vars"
          @last = MacroType.instance_vars(@scope)
        when "@superclass"
          @last = MacroType.superclass(@scope)
        else
          node.raise "unknown macro instance var: '#{node.name}'"
        end
      end

      def visit(node : MetaVar)
        @last = node
      end

      {% for name in %w(Bool Number Char String Symbol Nil Array Range Tuple Hash) %}
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
    end
  end

  class ASTNode
    def to_macro_id
      to_s
    end

    def to_macro_var
      self
    end

    def truthy?
      true
    end

    def interpret(method, args, block, interpreter)
      case method
      when "id"
        interpret_argless_method("id", args) { MacroId.new(to_macro_id) }
      when "stringify"
        interpret_argless_method("stringify", args) { stringify }
      when "=="
        BoolLiteral.new(self == args.first)
      when "!="
        BoolLiteral.new(self != args.first)
      when "!"
        BoolLiteral.new(!truthy?)
      else
        raise "undefined macro method #{class_desc}##{method}'"
      end
    end

    def interpret_argless_method(method, args)
      interpret_check_args_length method, args, 0
      yield
    end

    def interpret_one_arg_method(method, args)
      interpret_check_args_length method, args, 1
      yield args.first
    end

    def interpret_check_args_length(method, args, length)
      unless args.length == length
        raise "wrong number of arguments for #{method} (#{args.length} for #{length})"
      end
    end

    def stringify
      StringLiteral.new(to_s)
    end

    def to_macro_id
      to_s
    end
  end

  class Nop
    def truthy?
      false
    end
  end

  class NilLiteral
    def to_macro_id
      "nil"
    end

    def truthy?
      false
    end
  end

  class BoolLiteral
    def to_macro_id
      @value ? "true" : "false"
    end

    def truthy?
      @value
    end
  end

  class NumberLiteral
    def interpret(method, args, block, interpreter)
      case method
      when ">"
        compare_to(args.first) { |me, other| me > other }
      when ">="
        compare_to(args.first) { |me, other| me >= other }
      when "<"
        compare_to(args.first) { |me, other| me < other }
      when "<="
        compare_to(args.first) { |me, other| me <= other }
      else
        super
      end
    end

    def compare_to(other)
      unless other.is_a?(NumberLiteral)
        raise "can't compare number to #{other}"
      end

      BoolLiteral.new(yield to_number, other.to_number)
    end

    def to_number
      @value.to_f64
    end
  end

  class StringLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "[]"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when RangeLiteral
            from, to = arg.from, arg.to
            unless from.is_a?(NumberLiteral)
              raise "range from in StringLiteral#[] must be a number, not #{from.class_desc}: #{from}"
            end

            unless to.is_a?(NumberLiteral)
              raise "range to in StringLiteral#[] must be a number, not #{to.class_desc}: #{from}"
            end

            from, to = from.to_number.to_i, to = to.to_number.to_i
            range = Range.new(from, to, arg.exclusive)
            StringLiteral.new(@value[range])
          else
            raise "wrong argument for StringLiteral#[] (#{arg.class_desc}): #{arg}"
          end
        end
      when "capitalize"
        interpret_argless_method(method, args) { StringLiteral.new(@value.capitalize) }
      when "downcase"
        interpret_argless_method(method, args) { StringLiteral.new(@value.downcase) }
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(@value.empty?) }
      when "identify"
        interpret_argless_method(method, args) { StringLiteral.new(@value.tr(":", "_")) }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(@value.length, :i32) }
      when "lines"
        interpret_argless_method(method, args) { create_array_literal_from_values(@value.lines) }
      when "split"
        case args.length
        when 0
          create_array_literal_from_values(@value.split)
        when 1
          first_arg = args.first
          case first_arg
          when CharLiteral
            splitter = first_arg.value
          when StringLiteral
            splitter = first_arg.value
          else
            splitter = first_arg.to_s
          end

          create_array_literal_from_values(@value.split(splitter))
        else
          raise "wrong number of arguments for split (#{args.length} for 0, 1)"
        end
      when "strip"
        interpret_argless_method(method, args) { StringLiteral.new(@value.strip) }
      when "upcase"
        interpret_argless_method(method, args) { StringLiteral.new(@value.upcase) }
      else
        super
      end
    end

    def create_array_literal_from_values(values)
      ArrayLiteral.new(Array(ASTNode).new(values.length) { |i| StringLiteral.new(values[i]) })
    end

    def to_macro_id
      @value
    end
  end

  class ArrayLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "any?"
        interpret_argless_method(method, args) do
          raise "any? expects a block" unless block

          block_arg = block.args.first?

          BoolLiteral.new(elements.any? do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept(block.body).truthy?
          end)
        end
      when "all?"
        interpret_argless_method(method, args) do
          raise "all? expects a block" unless block

          block_arg = block.args.first?

          BoolLiteral.new(elements.all? do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept(block.body).truthy?
          end)
        end
      when "argify"
        interpret_argless_method(method, args) do
          MacroId.new(elements.map(&.to_macro_id).join ", ")
        end
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(elements.empty?) }
      when "first"
        interpret_argless_method(method, args) { elements.first? || NilLiteral.new }
      when "join"
        interpret_one_arg_method(method, args) do |arg|
          StringLiteral.new(elements.map(&.to_macro_id).join arg.to_macro_id)
        end
      when "last"
        interpret_argless_method(method, args) { elements.last? || NilLiteral.new }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(elements.length, :i32) }
      when "map"
        interpret_argless_method(method, args) do
          raise "map expects a block" unless block

          block_arg = block.args.first?

          ArrayLiteral.new(elements.map do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept block.body
          end)
        end
      when "select"
        interpret_argless_method(method, args) do
          raise "select expects a block" unless block

          block_arg = block.args.first?

          ArrayLiteral.new(elements.select do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept(block.body).truthy?
          end)
        end
      when "[]"
        case args.length
        when 1
          arg = args.first
          unless arg.is_a?(NumberLiteral)
            arg.raise "argument to [] must be a number, not #{arg.class_desc}:\n\n#{arg}"
          end

          index = arg.to_number.to_i
          value = elements[index]?
          if value
            value
          else
            NilLiteral.new
          end
        else
          raise "wrong number of arguments for [] (#{args.length} for 1)"
        end
      else
        super
      end
    end
  end

  class HashLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(keys.empty?) }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(keys.length, :i32) }
      when "[]"
        case args.length
        when 1
          arg = args.first

          index = keys.index(arg)
          if index
            values[index]
          else
            NilLiteral.new
          end
        else
          raise "wrong number of arguments for [] (#{args.length} for 1)"
        end
      else
        super
      end
    end
  end

  class TupleLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(elements.empty?) }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(elements.length, :i32) }
      when "[]"
        case args.length
        when 1
          arg = args.first
          unless arg.is_a?(NumberLiteral)
            arg.raise "argument to [] must be a number, not #{arg.class_desc}:\n\n#{arg}"
          end

          index = arg.to_number.to_i
          value = elements[index]?
          if value
            value
          else
            raise "tuple index out of bounds: #{index} in #{self}"
          end
        else
          raise "wrong number of arguments for [] (#{args.length} for 1)"
        end
      else
        super
      end
    end
  end

  class MetaVar
    def to_macro_id
      @name
    end

    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { StringLiteral.new(@name) }
      when "type"
        interpret_argless_method(method, args) do
          if type = @type
            MacroType.new(type)
          else
            NilLiteral.new
          end
        end
      else
        super
      end
    end
  end

  class MacroType
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { StringLiteral.new(type.to_s) }
      when "instance_vars"
        interpret_argless_method(method, args) { MacroType.instance_vars(type) }
      when "superclass"
        interpret_argless_method(method, args) { MacroType.superclass(type) }
      else
        super
      end
    end

    def self.instance_vars(type)
      unless type.is_a?(InstanceVarContainer)
        return ArrayLiteral.new
      end

      all_ivars = type.all_instance_vars

      ivars = Array(ASTNode).new(all_ivars.length)
      all_ivars.each do |name, ivar|
        ivars.push MetaVar.new(name, ivar.type)
      end

      ArrayLiteral.new(ivars)
    end

    def self.superclass(type)
      superclass = type.superclass
      superclass ? MacroType.new(superclass) : NilLiteral.new
    rescue
      NilLiteral.new
    end
  end

  class SymbolLiteral
    def to_macro_id
      @value
    end
  end

  class Var
    def to_macro_id
      @name
    end
  end

  class Call
    def to_macro_id
      if !obj && !block && args.empty?
        @name
      else
        to_s
      end
    end

    def to_macro_var
      MacroId.new(to_macro_id)
    end
  end

  class InstanceVar
    def to_macro_id
      @name
    end
  end

  class Path
    def to_macro_id
      @names.join "::"
    end
  end
end
