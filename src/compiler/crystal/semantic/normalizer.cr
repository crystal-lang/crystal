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
          right = Call.new(middle.clone, node.name, node.args).at(middle)
        else
          temp_var = program.new_temp_var
          temp_assign = Assign.new(temp_var.clone, middle)
          left = Call.new(obj.obj, obj.name, temp_assign).at(obj.obj)
          right = Call.new(temp_var.clone, node.name, node.args).at(node)
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

    # Check if the right hand side is dead code
    def transform(node : Assign)
      super

      if @dead_code
        node.value
      else
        node
      end
    end

    # Convert `a += b` to `a = a + b`
    def transform(node : OpAssign)
      super

      target = node.target
      if target.is_a?(Call)
        if target.name == "[]"
          transform_op_assign_index(node, target)
        else
          transform_op_assign_call(node, target)
        end
      else
        transform_op_assign_simple(node, target)
      end
    end

    def transform_op_assign_call(node, target)
      obj = target.obj.not_nil!

      # Convert
      #
      #     a.exp += b
      #
      # To
      #
      #     tmp = a
      #     tmp.exp=(tmp.exp + b)
      case obj
      when Var, InstanceVar, ClassVar, .simple_literal?
        tmp = obj
      else
        tmp = program.new_temp_var

        # (1) = tmp = a
        assign = Assign.new(tmp, obj).at(node)
      end

      # (2) = tmp.exp
      call = Call.new(tmp.clone, target.name).at(node)

      case node.op
      when "||"
        # Special: tmp.exp || tmp.exp=(b)
        #
        # (3) = tmp.exp=(b)
        right = Call.new(tmp.clone, "#{target.name}=", node.value).at(node)

        # (4) = (2) || (3)
        call = Or.new(call, right).at(node)
      when "&&"
        # Special: tmp.exp && tmp.exp=(b)
        #
        # (3) = tmp.exp=(b)
        right = Call.new(tmp.clone, "#{target.name}=", node.value).at(node)

        # (4) = (2) && (3)
        call = And.new(call, right).at(node)
      else
        # (3) = (2) + b
        call = Call.new(call, node.op, node.value).at(node)

        # (4) = tmp.exp=((3))
        call = Call.new(tmp.clone, "#{target.name}=", call).at(node)
      end

      # (1); (4)
      if assign
        Expressions.new([assign, call]).at(node)
      else
        call
      end
    end

    def transform_op_assign_index(node, target)
      obj = target.obj.not_nil!

      # Convert
      #
      #     a[exp1, exp2, ...] += b
      #
      # To
      #
      #     tmp = a
      #     tmp1 = exp1
      #     tmp2 = exp2
      #     ...
      #     tmp.[]=(tmp1, tmp2, ..., tmp[tmp1, tmp2, ...] + b)
      tmp_args = target.args.map { program.new_temp_var.as(ASTNode) }
      tmp = program.new_temp_var

      # (1) = tmp1 = exp1; tmp2 = exp2; ...; tmp = a
      tmp_assigns = Array(ASTNode).new(tmp_args.size + 1)
      tmp_args.each_with_index do |var, i|
        # For simple literals we don't need a temp variable
        arg = target.args[i]
        if arg.simple_literal?
          tmp_args[i] = arg
        else
          tmp_assigns << Assign.new(var.clone, arg).at(node)
        end
      end

      case obj
      when Var, InstanceVar, ClassVar, .simple_literal?
        # Nothing
        tmp = obj
      else
        tmp_assigns << Assign.new(tmp, obj).at(node)
      end

      case node.op
      when "||"
        # Special: tmp[tmp1, tmp2, ...]? || (tmp[tmp1, tmp2, ...] = b)
        #
        # (2) = tmp[tmp1, tmp2, ...]?
        call = Call.new(tmp.clone, "[]?", tmp_args).at(node)

        # (3) = tmp[tmp1, tmp2, ...] = b
        args = Array(ASTNode).new(tmp_args.size + 1)
        tmp_args.each { |arg| args << arg.clone }
        args << node.value
        right = Call.new(tmp.clone, "[]=", args).at(node)

        # (3) = (2) || (4)
        call = Or.new(call, right).at(node)
      when "&&"
        # Special: tmp[tmp1, tmp2, ...]? && (tmp[tmp1, tmp2, ...] = b)
        #
        # (2) = tmp[tmp1, tmp2, ...]?
        call = Call.new(tmp.clone, "[]?", tmp_args).at(node)

        # (3) = tmp[tmp1, tmp2, ...] = b
        args = Array(ASTNode).new(tmp_args.size + 1)
        tmp_args.each { |arg| args << arg.clone }
        args << node.value
        right = Call.new(tmp.clone, "[]=", args).at(node)

        # (3) = (2) && (4)
        call = And.new(call, right).at(node)
      else
        # (2) = tmp[tmp1, tmp2, ...]
        call = Call.new(tmp.clone, "[]", tmp_args).at(node)

        # (3) = (2) + b
        call = Call.new(call, node.op, node.value).at(node)

        # (4) tmp.[]=(tmp1, tmp2, ..., (3))
        args = Array(ASTNode).new(tmp_args.size + 1)
        tmp_args.each { |arg| args << arg.clone }
        args << call
        call = Call.new(tmp.clone, "[]=", args).at(node)
      end

      # (1); (4)
      exps = Array(ASTNode).new(tmp_assigns.size + 2)
      exps.concat(tmp_assigns)
      exps << call
      Expressions.new(exps).at(node)
    end

    def transform_op_assign_simple(node, target)
      case node.op
      when "&&"
        # (1) a = b
        assign = Assign.new(target, node.value).at(node)

        # a && (1)
        And.new(target.clone, assign).at(node)
      when "||"
        # (1) a = b
        assign = Assign.new(target, node.value).at(node)

        # a || (1)
        Or.new(target.clone, assign).at(node)
      else
        # (1) = a + b
        call = Call.new(target, node.op, node.value).at(node)

        # a = (1)
        Assign.new(target.clone, call).at(node)
      end
    end
  end
end
