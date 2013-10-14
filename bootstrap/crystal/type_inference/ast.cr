require "../ast"

module Crystal
  class Def
    property :owner
    property :instances

    def has_default_arguments?
      args.length > 0 && args.last.default_value
    end

    def expand_default_arguments
      self_def = clone
      self_def.instance_vars = instance_vars
      self_def.args.each { |arg| arg.default_value = nil }

      retain_body = yields || args.any? { |arg| arg.default_value && arg.type_restriction }

      expansions = [self_def]

      i = args.length - 1
      while i >= 0 && (arg_default_value = (arg = args[i]).default_value)
        expansion = Def.new(name, self_def.args[0 ... i].map(&.clone), nil, receiver.clone, self_def.block_arg.clone, self_def.yields)
        expansion.instance_vars = instance_vars
        # TODO expansion.calls_super = calls_super
        # TODO expansion.uses_block_arg = uses_block_arg
        expansion.yields = yields

        if retain_body
          new_body = [] of ASTNode
          args[i .. -1].each do |arg2|
            arg2_default_value = arg2.default_value
            raise "Bug: arg2_default_value should not have been nil" unless arg2_default_value

            new_body << Assign.new(Var.new(arg2.name), arg2_default_value)
          end
          new_body.push body.clone
          expansion.body = Expressions.new(new_body)
        else
          new_args = [] of ASTNode
          self_def.args[0 ... i].each do |arg2|
            new_args.push Var.new(arg2.name)
          end
          raise "Bug: #{arg_default_value} should not have been nil" unless arg_default_value

          new_args.push arg_default_value

          expansion.body = Call.new(nil, name, new_args)
        end

        expansions << expansion
        i -= 1
      end

      expansions
    end
  end

  class Arg
    def self.new_with_type(name, type)
      arg = new(name)
      arg.type = type
      arg
    end
  end
end
