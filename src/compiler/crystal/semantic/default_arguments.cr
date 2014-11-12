require "../syntax/ast"

class Crystal::Def
  def expand_default_arguments(args_length, named_args = nil)
    # If the named arguments cover all arguments with a default value and
    # they come in the same order, we can safely return this def without
    # needing a useless indirection.
    if named_args && args_length + named_args.length == args.length
      all_match = true
      named_args.each_with_index do |named_arg, i|
        arg = args[args_length + i]
        unless arg.name == named_arg
          all_match = false
          break
        end
      end
      if all_match
        return self
      end
    end

    # If there are no named args and all unspecified default arguments are magic
    # constants we can return outself (magic constants will be filled later)
    if !named_args && !splat_index
      all_magic = true
      args_length.upto(args.length - 1) do |index|
        unless args[index].default_value.is_a?(MagicConstant)
          all_magic = false
          break
        end
      end
      if all_magic
        return self
      end
    end

    retain_body = yields || args.any? { |arg| arg.default_value && arg.restriction } || splat_index

    splat_index = splat_index() || -1

    new_args = [] of Arg

    # Args before splat index
    0.upto(Math.min(args_length, splat_index) - 1) do |index|
      new_args << args[index].clone
    end

    # Splat arg
    if splat_index == -1
      splat_length = 0
      offset = 0
    else
      splat_length = args_length - (args.length - 1)
      offset = splat_index + splat_length
    end

    splat_length.times do |index|
      new_args << Arg.new("_arg#{index}")
    end

    # Args after splat index
    base = splat_index + 1
    min_length = Math.min(args_length, args.length)
    base.upto(min_length - 1) do |index|
      new_args << args[index].clone
    end

    if named_args
      new_name = String.build do |str|
        str << name
        named_args.each do |named_arg|
          str << ':'
          str << named_arg
          new_args << Arg.new(named_arg)
        end
      end
    else
      new_name = name
    end

    expansion = Def.new(new_name, new_args, nil, receiver.clone, block_arg.clone, return_type.clone, yields)
    expansion.instance_vars = instance_vars
    expansion.args.each { |arg| arg.default_value = nil }
    expansion.calls_super = calls_super
    expansion.calls_initialize = calls_initialize
    expansion.uses_block_arg = uses_block_arg
    expansion.yields = yields
    expansion.location = location
    expansion.owner = owner?

    if retain_body
      new_body = [] of ASTNode

      # Default values
      if splat_index == -1
        end_index = args.length - 1
      else
        end_index = Math.min(args_length, splat_index - 1)
      end

      # Declare variables that are not covered
      args_length.upto(end_index) do |index|
        arg = args[index]

        # But first check if we already have it in the named arguments
        unless named_args.try &.index(arg.name)
          default_value = arg.default_value.not_nil!

          # If the default value is a magic constant we add it to the expanded
          # def and don't declare it (since it's already an argument)
          if default_value.is_a?(MagicConstant)
            expansion.args.push arg.clone
          else
            new_body << Assign.new(Var.new(arg.name), default_value)
          end
        end
      end

      # Splat argument
      if splat_index != -1
        tuple_args = [] of ASTNode
        splat_length.times do |index|
          tuple_args << Var.new("_arg#{index}")
        end
        tuple = TupleLiteral.new(tuple_args)
        new_body << Assign.new(Var.new(args[splat_index].name), tuple)
      end

      new_body.push body.clone
      expansion.body = Expressions.new(new_body)
    else
      new_args = [] of ASTNode

      # Append variables that are already covered
      0.upto(args_length - 1) do |index|
        arg = args[index]
        new_args.push Var.new(arg.name)
      end

      # Append default values for those not covered
      args_length.upto(args.length - 1) do |index|
        arg = args[index]

        # But first check if we already have it in the named arguments
        if named_args.try &.index(arg.name)
          new_args.push Var.new(arg.name)
        else
          default_value = arg.default_value.not_nil!

          # If the default value is a magic constant we add it to the expanded
          # def, and use that on the forwarded call
          if default_value.is_a?(MagicConstant)
            new_args.push Var.new(arg.name)
            expansion.args.push arg.clone
          else
            new_args.push default_value
          end
        end
      end

      expansion.body = Call.new(nil, name, new_args)
    end

    expansion
  end
end
