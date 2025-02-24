require "set"
require "../program"
require "../syntax/transformer"

module Crystal
  class Program
    def normalize(node, inside_exp = false, current_def = nil)
      normalizer = Normalizer.new(self)
      normalizer.current_def = current_def
      node.transform(normalizer)
    end
  end

  class Normalizer < Transformer
    getter program : Program

    # The current method where we are normalizing.
    # This is used to expand argless `super` and `previous_def`
    # to their version with arguments copied from the current method.
    property current_def : Def?

    @dead_code = false

    def initialize(@program)
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
      # Copy enclosing def's parameters to super/previous_def without parenthesis
      case node
      when .super?, .previous_def?
        named_args = node.named_args
        if node.args.empty? && (!named_args || named_args.empty?) && !node.has_parentheses?
          if current_def = @current_def
            splat_index = current_def.splat_index
            current_def.args.each_with_index do |arg, i|
              if splat_index && i > splat_index
                # Past the splat index we must pass arguments as named arguments
                named_args = node.named_args ||= Array(NamedArgument).new
                named_args.push NamedArgument.new(arg.external_name, Var.new(arg.name))
              elsif i == splat_index
                # At the splat index we must use a splat, except the bare splat
                # parameter will be skipped
                unless arg.external_name.empty?
                  node.args.push Splat.new(Var.new(arg.name))
                end
              else
                # Otherwise it's just a regular argument
                node.args.push Var.new(arg.name)
              end
            end

            # Copy also the double splat
            if arg = current_def.double_splat
              node.args.push DoubleSplat.new(Var.new(arg.name))
            end
          end
          node.has_parentheses = true
        end
      else
        # not a special call
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
          temp_assign = Assign.new(temp_var.clone, middle).at(middle)
          left = Call.new(obj.obj, obj.name, temp_assign).at(obj.obj)
          right = Call.new(temp_var.clone, node.name, node.args).at(node)
        end
        node = And.new(left, right).at(left)
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

    # Checks if the right hand side is dead code
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
      call.name_location = node.name_location

      case node.op
      when "||"
        # Special: tmp.exp || tmp.exp=(b)
        #
        # (3) = tmp.exp=(b)
        right = Call.new(tmp.clone, "#{target.name}=", node.value).at(node)
        right.name_location = node.name_location

        # (4) = (2) || (3)
        call = Or.new(call, right).at(node)
      when "&&"
        # Special: tmp.exp && tmp.exp=(b)
        #
        # (3) = tmp.exp=(b)
        right = Call.new(tmp.clone, "#{target.name}=", node.value).at(node)
        right.name_location = node.name_location

        # (4) = (2) && (3)
        call = And.new(call, right).at(node)
      else
        # (3) = (2) + b
        call = Call.new(call, node.op, node.value).at(node)
        call.name_location = node.name_location

        # (4) = tmp.exp=((3))
        call = Call.new(tmp.clone, "#{target.name}=", call).at(node)
        call.name_location = node.name_location
      end

      # (1); (4)
      if assign
        Expressions.new([assign, call] of ASTNode).at(node)
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
        call.name_location = node.name_location

        # (3) = tmp[tmp1, tmp2, ...] = b
        args = Array(ASTNode).new(tmp_args.size + 1)
        tmp_args.each { |arg| args << arg.clone }
        args << node.value
        right = Call.new(tmp.clone, "[]=", args).at(node)
        right.name_location = node.name_location

        # (3) = (2) || (4)
        call = Or.new(call, right).at(node)
      when "&&"
        # Special: tmp[tmp1, tmp2, ...]? && (tmp[tmp1, tmp2, ...] = b)
        #
        # (2) = tmp[tmp1, tmp2, ...]?
        call = Call.new(tmp.clone, "[]?", tmp_args).at(node)
        call.name_location = node.name_location

        # (3) = tmp[tmp1, tmp2, ...] = b
        args = Array(ASTNode).new(tmp_args.size + 1)
        tmp_args.each { |arg| args << arg.clone }
        args << node.value
        right = Call.new(tmp.clone, "[]=", args).at(node)
        right.name_location = node.name_location

        # (3) = (2) && (4)
        call = And.new(call, right).at(node)
      else
        # (2) = tmp[tmp1, tmp2, ...]
        call = Call.new(tmp.clone, "[]", tmp_args).at(node)
        call.name_location = node.name_location

        # (3) = (2) + b
        call = Call.new(call, node.op, node.value).at(node)
        call.name_location = node.name_location

        # (4) tmp.[]=(tmp1, tmp2, ..., (3))
        args = Array(ASTNode).new(tmp_args.size + 1)
        tmp_args.each { |arg| args << arg.clone }
        args << call
        call = Call.new(tmp.clone, "[]=", args).at(node)
        call.name_location = node.name_location
      end

      # (1); (4)
      if tmp_assigns.empty?
        call
      else
        exps = Array(ASTNode).new(tmp_assigns.size + 2)
        exps.concat(tmp_assigns)
        exps << call

        Expressions.new(exps).at(node)
      end
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
        call.name_location = node.name_location

        # a = (1)
        Assign.new(target.clone, call).at(node)
      end
    end

    def transform(node : StringInterpolation)
      # If the interpolation has just one string literal inside it,
      # return that instead of an interpolation
      if node.expressions.size == 1
        first = node.expressions.first
        return first if first.is_a?(StringLiteral)
      end

      super
    end

    # Turn block argument unpacking to multi assigns at the beginning
    # of a block.
    #
    # So this:
    #
    #    foo do |(x, y), z|
    #      x + y + z
    #    end
    #
    # is transformed to:
    #
    #    foo do |__temp_1, z|
    #      x, y = __temp_1
    #      x + y + z
    #    end
    def transform(node : Block)
      node = super

      unpacks = node.unpacks
      return node unless unpacks

      # as `node` is mutated in-place, ensure it can only be mutated once
      # we consider a block to be mutated if any unpack already has a
      # corresponding block parameter with a name (as the fictitious packed
      # parameters have empty names)
      return node if unpacks.any? { |index, _| !node.args[index].name.empty? }

      extra_expressions = [] of ASTNode
      next_unpacks = [] of {String, Expressions}

      unpacks.each do |index, expressions|
        temp_name = program.new_temp_var_name
        node.args[index] = Var.new(temp_name).at(node.args[index])

        extra_expressions << block_unpack_multiassign(temp_name, expressions, next_unpacks)
      end

      if next_unpacks
        while next_unpack = next_unpacks.shift?
          var_name, expressions = next_unpack

          extra_expressions << block_unpack_multiassign(var_name, expressions, next_unpacks)
        end
      end

      body = node.body
      case body
      when Nop
        node.body = Expressions.new(extra_expressions).at(node.body)
      when Expressions
        body.expressions = extra_expressions + body.expressions
      else
        extra_expressions << node.body
        node.body = Expressions.new(extra_expressions).at(node.body)
      end

      node
    end

    private def block_unpack_multiassign(var_name, expressions, next_unpacks)
      targets = expressions.expressions.map do |exp|
        case exp
        when Var
          exp
        when Underscore
          exp
        when Splat
          exp
        when Expressions
          next_temp_name = program.new_temp_var_name

          next_unpacks << {next_temp_name, exp}

          Var.new(next_temp_name).at(exp)
        else
          raise "BUG: unexpected block var #{exp} (#{exp.class})"
        end
      end
      values = [Var.new(var_name).at(expressions)] of ASTNode
      MultiAssign.new(targets, values).at(expressions)
    end
  end
end
