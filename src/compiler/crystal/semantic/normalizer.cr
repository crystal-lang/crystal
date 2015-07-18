require "set"
require "../program"
require "../syntax/transformer"

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
      when If, Unless, Expressions, Block
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
          target = node.targets[i]
          value = node.values[i]
          if target.is_a?(Path)
            assign_from_temps << Assign.new(target, value).at(node)
          else
            assign_to_temps << Assign.new(temp_var_2.clone, value).at(node)
            assign_from_temps << transform_multi_assign_target(target, temp_var_2.clone)
          end
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
            current_def.args.each_with_index do |arg, i|
              arg = Var.new(arg.name)
              arg = Splat.new(arg) if i == current_def.splat_index
              node.args.push arg
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
            parser.wants_doc = @program.wants_doc?
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
