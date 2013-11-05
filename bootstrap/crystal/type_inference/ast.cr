require "../ast"

module Crystal
  class ASTNode
    def needs_const_block?
      true
    end
  end

  class Def
    property :owner

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

  class Macro
    make_tuple InstanceKey, types

    def add_instance(a_fun, arg_types)
      @instances ||= {} of InstanceKey => LLVM::Function
      @instances[InstanceKey.new(arg_types)] = a_fun
    end

    def lookup_instance(arg_types)
      @instances ? @instances[InstanceKey.new(arg_types)]? : nil
    end
  end

  class ClassVar
    property! owner
    property! var
    property! class_scope
  end

  class Ident
    property target_const
  end

  class Arg
    def self.new_with_type(name, type)
      arg = new(name)
      arg.type = type
      arg
    end

    def self.new_with_restriction(name, restriction)
      arg = Arg.new(name)
      arg.type_restriction = restriction
      arg
    end
  end

  class Block
    property :visited
  end

  macro self.doesnt_need_const_block(klass)"
    class #{klass}
      def needs_const_block?
        false
      end
    end
  "end

  doesnt_need_const_block NilLiteral
  doesnt_need_const_block BoolLiteral
  doesnt_need_const_block NumberLiteral
  doesnt_need_const_block CharLiteral
  doesnt_need_const_block StringLiteral
  doesnt_need_const_block SymbolLiteral

  class Primitive
    def needs_const_block?
      case name
      when :float32_infinity, :flaot64_infinity
        false
      else
        true
      end
    end
  end
end
