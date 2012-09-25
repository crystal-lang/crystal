module Crystal
	class Module
		private 

		def define_primitives
			define_bool_primitives
      define_char_primitives
			define_int_primitives
			define_float_primitives
			define_externals
		end

		def define_bool_primitives
      singleton(bool, :'!@', {}, bool) { |b, f| b.not(f.params[0]) }
      singleton(bool, :'&&', {'other' => bool}, bool) { |b, f| b.and(f.params[0], f.params[1]) }
      singleton(bool, :'||', {'other' => bool}, bool) { |b, f| b.or(f.params[0], f.params[1]) }
		end

    def define_char_primitives
      no_args_primitive(char, 'ord', int) { |b, f| b.zext(f.params[0], int.llvm_type) }
      singleton(char, :==, {'other' => char}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(char, :'!=', {'other' => char}, bool) { |b, f| b.icmp(:ne, f.params[0], f.params[1]) }
      singleton(char, :<, {'other' => char}, bool) { |b, f| b.icmp(:ult, f.params[0], f.params[1]) }
      singleton(char, :<=, {'other' => char}, bool) { |b, f| b.icmp(:ule, f.params[0], f.params[1]) }
      singleton(char, :>, {'other' => char}, bool) { |b, f| b.icmp(:ugt, f.params[0], f.params[1]) }
      singleton(char, :>=, {'other' => char}, bool) { |b, f| b.icmp(:uge, f.params[0], f.params[1]) }
    end

		def define_int_primitives
      no_args_primitive(int, 'to_i', int) { |b, f| f.params[0] }
      no_args_primitive(int, 'to_f', float) { |b, f| b.si2fp(f.params[0], float.llvm_type) }

      primitive(int, :+, ['other']) do |p|
        p.overload([int], int) { |b, f| b.add(f.params[0], f.params[1]) }
        p.overload([float], float) { |b, f| b.fadd(b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :-, ['other']) do |p|
        p.overload([int], int) { |b, f| b.sub(f.params[0], f.params[1]) }
        p.overload([float], float) { |b, f| b.fsub(b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :*, ['other']) do |p|
        p.overload([int], int) { |b, f| b.mul(f.params[0], f.params[1]) }
        p.overload([float], float) { |b, f| b.fmul(b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :/, ['other']) do |p|
        p.overload([int], int) { |b, f| b.sdiv(f.params[0], f.params[1]) }
        p.overload([float], float) { |b, f| b.fdiv(b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :==, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
        p.overload([float], bool) { |b, f| b.fcmp(:oeq, b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :'!=', ['other']) do |p|
        p.overload([int], bool) { |b, f| b.icmp(:ne, f.params[0], f.params[1]) }
        p.overload([float], bool) { |b, f| b.fcmp(:one, b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :<, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.icmp(:slt, f.params[0], f.params[1]) }
        p.overload([float], bool) { |b, f| b.fcmp(:olt, b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :<=, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.icmp(:sle, f.params[0], f.params[1]) }
        p.overload([float], bool) { |b, f| b.fcmp(:ole, b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :>, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.icmp(:sgt, f.params[0], f.params[1]) }
        p.overload([float], bool) { |b, f| b.fcmp(:ogt, b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      primitive(int, :>=, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.icmp(:sge, f.params[0], f.params[1]) }
        p.overload([float], bool) { |b, f| b.fcmp(:oge, b.si2fp(f.params[0], float.llvm_type), f.params[1]) }
      end

      no_args_primitive(int, 'chr', char) { |b, f| b.trunc(f.params[0], char.llvm_type) }
		end

		def define_float_primitives
      no_args_primitive(float, 'to_i', int) { |b, f| b.fp2si(f.params[0], int.llvm_type) }
      no_args_primitive(float, 'to_f', float) { |b, f| f.params[0] }

      primitive(float, :+, ['other']) do |p|
        p.overload([int], float) { |b, f| b.fadd(f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], float) { |b, f| b.fadd(f.params[0], f.params[1]) }
      end

      primitive(float, :-, ['other']) do |p|
        p.overload([int], float) { |b, f| b.fsub(f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], float) { |b, f| b.fsub(f.params[0], f.params[1]) }
      end

      primitive(float, :*, ['other']) do |p|
        p.overload([int], float) { |b, f| b.fmul(f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], float) { |b, f| b.fmul(f.params[0], f.params[1]) }
      end

      primitive(float, :/, ['other']) do |p|
        p.overload([int], float) { |b, f| b.fdiv(f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], float) { |b, f| b.fdiv(f.params[0], f.params[1]) }
      end

      primitive(float, :==, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.fcmp(:oeq, f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], bool) { |b, f| b.fcmp(:oeq, f.params[0], f.params[1]) }
      end

      primitive(float, :'!=', ['other']) do |p|
        p.overload([int], bool) { |b, f| b.fcmp(:one, f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], bool) { |b, f| b.fcmp(:one, f.params[0], f.params[1]) }
      end

      primitive(float, :<, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.fcmp(:olt, f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], bool) { |b, f| b.fcmp(:olt, f.params[0], f.params[1]) }
      end

      primitive(float, :<=, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.fcmp(:ole, f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], bool) { |b, f| b.fcmp(:ole, f.params[0], f.params[1]) }
      end

      primitive(float, :>, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.fcmp(:ogt, f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], bool) { |b, f| b.fcmp(:ogt, f.params[0], f.params[1]) }
      end

      primitive(float, :>=, ['other']) do |p|
        p.overload([int], bool) { |b, f| b.fcmp(:oge, f.params[0], b.si2fp(f.params[1], float.llvm_type)) }
        p.overload([float], bool) { |b, f| b.fcmp(:oge, f.params[0], f.params[1]) }
      end
		end

		def define_externals
      external('putchar', {'c' => char}, char)
      external('getchar', {}, char)
     end

	  def primitive(owner, name, arg_names)
	    p = owner.defs[name] = FrozenDef.new(name, arg_names.map { |x| Var.new(x) })
	    p.owner = owner
	    yield p
	  end

    def no_args_primitive(owner, name, return_type, &block)
      primitive(owner, name, []) { |p| p.overload([], return_type, &block) }
    end

    def singleton(owner, name, args, return_type, &block)
      p = owner.defs[name] = FrozenDef.new(name, args.keys.map { |x| Var.new(x) })
      p.owner = owner
      p.overload(args.values, return_type, &block)
    end

	  def external(name, args, return_type)
	    args = args.map do |name, type|
	      var = Var.new(name)
	      var.type = type
	      var
	    end

	    instance = defs[name] = External.new(name, args)
	    instance.body = Expressions.new
	    instance.body.type = return_type
	    instance.add_instance instance
	  end
	end

  class Def
    def overload(arg_types, return_type, &block)
      instance = clone
      instance.owner = owner
      arg_types.each_with_index do |arg_type, i|
        instance.args[i].type = arg_type
      end
      instance.body = PrimitiveBody.new(return_type, block)
      add_instance(instance)
    end
  end

  class PrimitiveBody < ASTNode
    attr_accessor :block

    def initialize(type, block)
      @type = type
      @block = block
    end
  end

  class FrozenDef < Def
  end

  class External < FrozenDef
    def mangled_name
      name
    end
  end
end

