module Crystal
  class Program
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

      begin
        arg_names = target_def.args.map(&.name)

        parser = Parser.new(generated_source, [Set.new(arg_names)])
        parser.filename = VirtualFile.new(the_macro, generated_source)
        generated_nodes = parser.parse
      rescue ex : Crystal::SyntaxException
        target_def.raise "def macro didn't expand to a valid program, it expanded to:\n\n#{"=" * 80}\n#{"-" * 80}\n#{generated_source.lines.to_s_with_line_numbers}\n#{"-" * 80}\n#{ex.to_s(generated_source)}\n#{"=" * 80}"
      end

      generated_nodes = @program.normalize(generated_nodes)

      type_visitor = TypeVisitor.new(@program, vars, target_def)
      type_visitor.scope = owner
      generated_nodes.accept type_visitor

      if generated_nodes.type != target_def.type
        target_def.raise "expected '#{target_def.name}' to return #{target_def.type}, not #{generated_nodes.type}"
      end

      target_def.body = generated_nodes
    end
  end

  class MacroExpander
    def initialize(@mod)
    end

    def expand(scope : Type, a_macro, call)
      visitor = MacroVisitor.new @mod, scope, a_macro, call
      a_macro.body.accept visitor
      visitor.to_s
    end

    def expand(scope : Type, node)
      visitor = MacroVisitor.new @mod, scope
      node.accept visitor
      visitor.to_s
    end

    class MacroVisitor < Visitor
      getter last

      def self.new(mod, scope, a_macro : Macro, call)
        vars = {} of String => ASTNode
        a_macro.args.zip(call.args) do |macro_arg, call_arg|
          vars[macro_arg.name] = call_arg.to_macro_var
        end

        new(mod, scope, vars, call.block)
      end

      def initialize(@mod, @scope, @vars = {} of String => ASTNode, @block = nil)
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

        @str << @last.to_macro_id

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
              str << @last.to_macro_id
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
          node.exp.raise "for expression must be an array, hash or tuple literal, not:\n\n#{exp}"
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

          @last = receiver.interpret(node.name, args, node.block, self)
        else
          # no receiver: special calls
          execute_special_call node
        end

        false
      end

      def visit(node : Yield)
        if block = @block
          @last = block.body
        else
          @last = Nop.new
        end
        false
      end

      def execute_special_call(node)
        case node.name
        when "puts", "p"
          execute_puts(node)
        when "system"
          execute_system(node)
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
          @last = StringLiteral.new(result)
        else
          node.raise "Error executing command: #{cmd}\n\nGot:\n\n#{result}\n"
        end
      end

      def visit(node : InstanceVar)
        case node.name
        when "@name"
          @last = StringLiteral.new(@scope.to_s)
        when "@instance_vars"
          scope = @scope
          unless scope.is_a?(InstanceVarContainer)
            node.raise "#{scope} can't have instance vars"
          end

          all_ivars = scope.all_instance_vars

          ivars = Array(ASTNode).new(all_ivars.length)
          all_ivars.each do |name, ivar|
            ivars.push MetaVar.new(name, ivar.type)
          end

          @last = ArrayLiteral.new(ivars)
        else
          node.raise "unknown macro instance var: '#{node.name}'"
        end
      end

      def visit(node : MetaVar)
        @last = node
      end

      def visit(node : BoolLiteral)
        @last = node
      end

      def visit(node : NumberLiteral)
        @last = node
      end

      def visit(node : CharLiteral)
        @last = node
      end

      def visit(node : StringLiteral)
        @last = node
      end

      def visit(node : SymbolLiteral)
        @last = node
      end

      def visit(node : NilLiteral)
        @last = node
      end

      def visit(node : ArrayLiteral)
        @last = node
        false
      end

      def visit(node : TupleLiteral)
        @last = node
        false
      end

      def visit(node : HashLiteral)
        @last = node
        false
      end

      def visit(node : Nop)
        @last = node
      end

      def visit(node : MacroCallWrapper)
        @last = node
      end

      def visit(node : ASTNode)
        node.raise "can't execute this in a macro"
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
      when "stringify"
        unless args.length == 0
          raise "wrong number of arguments for stringify (#{args.length} for 0)"
        end

        stringify
      when "=="
        BoolLiteral.new(self == args.first)
      when "!="
        BoolLiteral.new(self != args.first)
      else
        raise "undefined macro method: '#{method}'"
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
      StringLiteral.new(to_macro_id)
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
    def to_macro_id
      @value
    end

    def stringify
      StringLiteral.new("\"#{@value.dump}\"")
    end

    def interpret(method, args, block, interpreter)
      case method
      when "downcase"
        interpret_argless_method(method, args) { StringLiteral.new(@value.downcase) }
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(@value.empty?) }
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
          if first_arg.is_a?(CharLiteral)
            create_array_literal_from_values(@value.split(first_arg.value))
          else
            create_array_literal_from_values(@value.split(first_arg.to_macro_id))
          end
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
            arg.raise "argument to [] must be a number, not #{arg}"
          end

          index = arg.to_number.to_i
          value = elements[index]?
          if value
            value
          else
            raise "array index out of bounds: #{index} in #{self}"
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
            arg.raise "argument to [] must be a number, not #{arg}"
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

    def stringify
      StringLiteral.new("\"#{@name}\"")
    end
  end

  class SymbolLiteral
    def to_macro_id
      @value
    end

    def stringify
      StringLiteral.new("\":#{@value.dump}\"")
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
      MacroCallWrapper.new(self)
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
