require "set"
require "../program"
require "../syntax/transformer"

module Crystal
  class Program
    def normalize(node, inside_exp = false)
      node.transform Normalizer.new(self)
    end
  end

  class Normalizer < Transformer
    getter program : Program

    @dead_code : Bool
    @current_def : Def?

    def initialize(@program)
      @dead_code = false
      @current_def = nil
    end

    def before_transform(node)
      @dead_code = false
    end

    def after_transform(node)
      case node
      when Return, Break, Next
        @dead_code = true
      when If, Unless, Expressions, Block, Assign
        # Skip
      else
        @dead_code = false
      end
    end

    def transform(node : Expressions)
      exps = [] of ASTNode
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end
        end
        break if @dead_code
      end
      case exps.size
      when 0
        Nop.new
      when 1
        exps[0]
      else
        node.expressions = exps
        node
      end
    end

    def transform(node : Call)
      # Copy enclosing def's args to super/previous_def without parenthesis
      case node.name
      when "super", "previous_def"
        if node.args.empty? && !node.has_parentheses?
          if current_def = @current_def
            current_def.args.each_with_index do |arg, i|
              arg = Var.new(arg.name)
              arg = Splat.new(arg) if i == current_def.splat_index
              node.args.push arg
            end
          end
          node.has_parentheses = true
        end
      end

      # Convert 'a <= b <= c' to 'a <= b && b <= c'
      if comparison?(node.name) && (obj = node.obj) && obj.is_a?(Call) && comparison?(obj.name)
        case middle = obj.args.first
        when NumberLiteral, Var, InstanceVar
          transform_many node.args
          left = obj
          right = Call.new(middle.clone, node.name, node.args)
        else
          temp_var = program.new_temp_var
          temp_assign = Assign.new(temp_var.clone, middle)
          left = Call.new(obj.obj, obj.name, temp_assign)
          right = Call.new(temp_var.clone, node.name, node.args)
        end
        node = And.new(left, right)
        node = node.transform self
      else
        node = super
      end

      node
    end

    def comparison?(name)
      case name
      when "<=", "<", "!=", "==", "===", ">", ">="
        true
      else
        false
      end
    end

    def transform(node : Def)
      @current_def = node
      node = super
      @current_def = nil

      # If the def has a block argument without a specification
      # and it doesn't use it, we remove it because it's useless
      # and the semantic code won't have to bother checking it
      block_arg = node.block_arg
      if !node.uses_block_arg? && block_arg
        block_arg_restriction = block_arg.restriction
        if block_arg_restriction.is_a?(ProcNotation) && !block_arg_restriction.inputs && !block_arg_restriction.output
          node.block_arg = nil
        elsif !block_arg_restriction
          node.block_arg = nil
        end
      end

      node
    end

    def transform(node : Macro)
      node
    end

    def transform(node : If)
      node.cond = node.cond.transform(self)

      node.then = node.then.transform(self)
      then_dead_code = @dead_code

      node.else = node.else.transform(self)
      else_dead_code = @dead_code

      @dead_code = then_dead_code && else_dead_code
      node
    end

    # Convert unless to if:
    #
    # From:
    #
    #     unless foo
    #       bar
    #     else
    #       baz
    #     end
    #
    # To:
    #
    #     if foo
    #       baz
    #     else
    #       bar
    #     end
    def transform(node : Unless)
      If.new(node.cond, node.else, node.then).transform(self).at(node)
    end

    # Convert until to while:
    #
    # From:
    #
    #    until foo
    #      bar
    #    end
    #
    # To:
    #
    #    while !foo
    #      bar
    #    end
    def transform(node : Until)
      node = super
      not_exp = Not.new(node.cond).at(node.cond)
      While.new(not_exp, node.body).at(node)
    end

    # Evaluate the ifdef's flags.
    # If they hold, keep the "then" part.
    # If they don't, keep the "else" part.
    def transform(node : IfDef)
      cond_value = eval_flags(node.cond)
      if cond_value
        node.then.transform(self)
      else
        node.else.transform(self)
      end
    end

    # Check if the right hand side is dead code
    def transform(node : Assign)
      super

      if @dead_code
        node.value
      else
        node
      end
    end

    def eval_flags(node)
      evaluator = FlagsEvaluator.new(program)
      node.accept evaluator
      evaluator.value
    end

    class FlagsEvaluator < Visitor
      getter value : Bool

      def initialize(@program : Program)
        @value = false
      end

      def visit(node : Var)
        @value = @program.has_flag?(node.name)
      end

      def visit(node : Not)
        node.exp.accept self
        @value = !@value
        false
      end

      def visit(node : And)
        node.left.accept self
        left_value = @value
        node.right.accept self
        @value = left_value && @value
        false
      end

      def visit(node : Or)
        node.left.accept self
        left_value = @value
        node.right.accept self
        @value = left_value || @value
        false
      end

      def visit(node : ASTNode)
        raise "Bug: shouldn't visit #{node} in FlagsEvaluator"
      end
    end
  end
end
