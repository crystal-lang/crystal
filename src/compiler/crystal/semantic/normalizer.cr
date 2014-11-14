require "../program"
require "../syntax/transformer"
require "set"

module Crystal
  class Program
    def normalize(node)
      normalizer = Normalizer.new(self)
      node = normalizer.normalize(node)
      puts node if ENV["SSA"]? == "1"
      node
    end
  end

  class Normalizer < Transformer
    getter program

    def initialize(@program)
      @dead_code = false
      @current_def = nil
    end

    def normalize(node)
      node.transform(self)
    end

    def before_transform(node)
      @dead_code = false
    end

    def after_transform(node)
      case node
      when Return, Break, Next
        @dead_code = true
      when If, Case, Unless, And, Or, Expressions, Block
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
      case exps.length
      when 0
        Nop.new
      when 1
        exps[0]
      else
        node.expressions = exps
        node
      end
    end

    # Convert and to if:
    #
    # From:
    #
    #     a && b
    #
    # To:
    #
    #     if temp = a
    #       b
    #     else
    #       temp
    #     end
    def transform(node : And)
      left = node.left
      new_node = if left.is_a?(Var) || (left.is_a?(IsA) && left.obj.is_a?(Var))
               If.new(left, node.right, left.clone)
             elsif left.is_a?(Assign) && left.target.is_a?(Var)
               If.new(left, node.right, left.target.clone)
             else
               temp_var = new_temp_var
               If.new(Assign.new(temp_var.clone, left), node.right, temp_var.clone)
             end
      new_node.binary = :and
      new_node.location = node.location
      new_node.transform(self)
    end

    # Convert or to if
    #
    # From:
    #
    #     a || b
    #
    # To:
    #
    #     if temp = a
    #       temp
    #     else
    #       b
    #     end
    def transform(node : Or)
      left = node.left
      new_node = if left.is_a?(Var)
                   If.new(left, left.clone, node.right)
                 elsif left.is_a?(Assign) && left.target.is_a?(Var)
                   If.new(left, left.target.clone, node.right)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var.clone, left), temp_var.clone, node.right)
                 end
      new_node.binary = :or
      new_node.location = node.location
      new_node.transform(self)
    end

    # Convert an interpolation to a concatenation with a StringIO:
    #
    # From:
    #
    #     "foo#{bar}baz"
    #
    # To:
    #
    #     (StringIO.new << "foo" << bar << "baz").to_s
    def transform(node : StringInterpolation)
      super

      # Compute how long at least the string will be, so we
      # can allocate enough space.
      capacity = 0
      node.expressions.each do |piece|
        case piece
        when StringLiteral
          capacity += piece.value.length
        else
          capacity += 15
        end
      end

      if capacity <= 64
        call = Call.new(Path.global("StringIO"), "new")
      else
        call = Call.new(Path.global("StringIO"), "new", NumberLiteral.new(capacity))
      end

      node.expressions.each do |piece|
        call = Call.new(call, "<<", piece)
      end
      Call.new(call, "to_s").at(node)
    end

    # Transform a range literal into creating a Range object.
    #
    # From:
    #
    #    1 .. 3
    #
    # To:
    #
    #    Range.new(1, 3, true)
    #
    # From:
    #
    #    1 ... 3
    #
    # To:
    #
    #    Range.new(1, 3, false)
    def transform(node : RangeLiteral)
      super

      path = Path.global("Range").at(node)
      bool = BoolLiteral.new(node.exclusive).at(node)
      Call.new(path, "new", [node.from, node.to, bool]).at(node)
    end

    # Transform a multi assign into many assigns.
    def transform(node : MultiAssign)
      # From:
      #
      #     a, b = 1
      #
      #
      # To:
      #
      #     temp = 1
      #     a = temp[0]
      #     b = temp[1]
      if node.values.length == 1
        value = node.values[0]

        temp_var = new_temp_var

        assigns = Array(ASTNode).new(node.targets.length + 1)
        assigns << Assign.new(temp_var.clone, value).at(value)
        node.targets.each_with_index do |target, i|
          call = Call.new(temp_var.clone, "[]", NumberLiteral.new(i)).at(value)
          assigns << transform_multi_assign_target(target, call)
        end
        exps = Expressions.new(assigns)

      # From:
      #
      #     a = 1, 2, 3
      #
      # To:
      #
      #     a = [1, 2, 3]
      elsif node.targets.length == 1
        target = node.targets.first
        array = ArrayLiteral.new(node.values)
        exps = transform_multi_assign_target(target, array)

      # From:
      #
      #     a, b = c, d
      #
      # To:
      #
      #     temp1 = c
      #     temp2 = d
      #     a = temp1
      #     b = temp2
      else
        temp_vars = node.values.map { new_temp_var }

        assign_to_temps = [] of ASTNode
        assign_from_temps = [] of ASTNode

        temp_vars.each_with_index do |temp_var_2, i|
          assign_to_temps << Assign.new(temp_var_2.clone, node.values[i]).at(node)
          assign_from_temps << transform_multi_assign_target(node.targets[i], temp_var_2.clone)
        end

        exps = Expressions.new(assign_to_temps + assign_from_temps)
      end
      exps.location = node.location
      exps.transform(self)
    end

    def transform_multi_assign_target(target, value)
      if target.is_a?(Call)
        target.name = "#{target.name}="
        target.args << value
        target
      else
        Assign.new(target, value).at(target)
      end
    end

    def transform(node : Call)
      # Copy enclosing def's args to super/previous_def without parenthesis
      case node.name
      when "super", "previous_def"
        if node.args.empty? && !node.has_parenthesis
          if current_def = @current_def
            current_def.args.each do |arg|
              node.args.push Var.new(arg.name)
            end
          end
          node.has_parenthesis = true
        end
      end

      # Convert 'a <= b <= c' to 'a <= b && b <= c'
      if comparison?(node.name) && (obj = node.obj) && obj.is_a?(Call) && comparison?(obj.name)
        case middle = obj.args.first
        when NumberLiteral, Var, InstanceVar
          transform_many node.args
          left = obj
          right = Call.new(middle, node.name, node.args)
        else
          temp_var = new_temp_var
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
      if !node.uses_block_arg && block_arg
        block_arg_fun = block_arg.fun
        if block_arg_fun.is_a?(Fun) && !block_arg_fun.inputs && !block_arg_fun.output
          node.block_arg = nil
        end
      end

      node
    end

    def transform(node : Macro)
      node
    end

    # Convert a Case into a series of if ... elseif ... end:
    #
    # From:
    #
    #     case foo
    #     when bar, baz
    #       1
    #     when bun
    #       2
    #     else
    #       3
    #     end
    #
    # To:
    #
    #     temp = foo
    #     if bar === temp || baz === temp
    #       1
    #     elsif bun === temp
    #       2
    #     else
    #       3
    #     end
    #
    # But, when the "when" has a constant name, it's transformed to is_a?:
    #
    # From:
    #
    #     case foo
    #     when Bar
    #       1
    #     end
    #
    # To:
    #
    #     temp = foo
    #     if temp.is_a?(Bar)
    #       1
    #     end
    def transform(node : Case)
      node.cond = node.cond.try &.transform(self)

      node_cond = node.cond
      if node_cond
        case node_cond
        when Var, InstanceVar
          temp_var = node.cond
        when Assign
          temp_var = node_cond.target
          assign = node_cond
        else
          temp_var = new_temp_var
          assign = Assign.new(temp_var.clone, node_cond)
        end
      end

      a_if = nil
      final_if = nil
      node.whens.each do |wh|
        final_comp = nil
        wh.conds.each do |cond|
          if temp_var
            right_side = temp_var.clone
            if cond.is_a?(Path) || cond.is_a?(Generic)
              comp = IsA.new(right_side, cond)
            elsif cond.is_a?(Call) && cond.obj.is_a?(ImplicitObj)
              implicit_call = cond.clone as Call
              implicit_call.obj = temp_var.clone
              comp = implicit_call
            else
              comp = Call.new(cond, "===", right_side)
            end
          else
            comp = cond
          end

          comp.location = cond.location

          if final_comp
            final_comp = Or.new(final_comp, comp)
          else
            final_comp = comp
          end
        end

        wh_if = If.new(final_comp.not_nil!, wh.body)
        if a_if
          a_if.else = wh_if
        else
          final_if = wh_if
        end
        a_if = wh_if
      end

      if node_else = node.else
        a_if.not_nil!.else = node_else
      end

      final_if = final_if.not_nil!.transform(self)
      final_exp = if assign
                    Expressions.new([assign, final_if] of ASTNode)
                  else
                    final_if
                  end
      final_exp.location = node.location
      final_exp
    end

    def transform(node : If)
      node.cond = node.cond.transform(self)

      node.then = node.then.transform(self)
      then_dead_code = @dead_code

      node.else = node.else.transform(self)
      else_dead_code = @dead_code

      @dead_code = then_dead_code &&  else_dead_code
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

    # Convert unless to while:
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
      not_exp = Call.new(node.cond, "!").at(node.cond)
      While.new(not_exp, node.body, node.run_once).at(node)
    end

    # Evaluate the ifdef's flags.
    # If they hold, keep the "then" part.
    # If they don't, keep the "else" part.
    def transform(node : IfDef)
      cond_value = program.eval_flags(node.cond)
      if cond_value
        node.then.transform(self)
      else
        node.else.transform(self)
      end
    end

    # Transform require to its source code.
    # The source code can be a Nop if the file was already required.
    def transform(node : Require)
      location = node.location
      filenames = @program.find_in_path(node.string, location.try &.filename)
      if filenames
        nodes = Array(ASTNode).new(filenames.length)
        filenames.each do |filename|
          if @program.add_to_requires(filename)
            parser = Parser.new File.read(filename)
            parser.filename = filename
            nodes << parser.parse.transform(self)
          end
        end
        Expressions.from(nodes)
      else
        Nop.new
      end
    rescue ex : Crystal::Exception
      node.raise "while requiring \"#{node.string}\"", ex
    rescue ex
      node.raise "while requiring \"#{node.string}\": #{ex.message}"
    end

    def new_temp_var
      program.new_temp_var
    end
  end
end
