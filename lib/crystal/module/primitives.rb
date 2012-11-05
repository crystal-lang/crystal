module Crystal
  class Module
    def define_primitives
      define_object_primitives
      define_value_primitives
      define_bool_primitives
      define_char_primitives
      define_int_primitives
      define_long_primitives
      define_float_primitives
      define_symbol_primitives
      define_array_primitives
      define_externals
      define_builtins
    end

    def define_object_primitives
      no_args_primitive(object, 'nil?', bool) { |b, f| b.icmp(:eq, b.ptr2int(f.params[0], LLVM::Int), LLVM::Int(0)) }
      no_args_primitive(object, 'object_id', long) do |b, f, llvm_mod, self_type|
        b.ptr2int(f.params[0], LLVM::Int64)
      end
      no_args_primitive(object, 'to_s', string) do |b, f, llvm_mod, self_type|
        buffer = b.array_malloc(char.llvm_type, LLVM::Int(self_type.name.length + 23))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("#<#{self_type.name}:0x%016lx>"), f.params[0]
        buffer
      end
    end

    def define_value_primitives
      no_args_primitive(value, 'nil?', bool) { |b, f| LLVM::Int1.from_i(0) }
    end

    def define_bool_primitives
      no_args_primitive(bool, 'to_s', string) do |b, f, llvm_mod|
        false_string = b.global_string_pointer("false")
        true_string = b.global_string_pointer("true")
        b.select f.params[0], true_string, false_string
      end

      singleton(bool, :'!@', {}, bool) { |b, f| b.not(f.params[0]) }
      singleton(bool, :'&&', {'other' => bool}, bool) { |b, f| b.and(f.params[0], f.params[1]) }
      singleton(bool, :'||', {'other' => bool}, bool) { |b, f| b.or(f.params[0], f.params[1]) }
    end

    def define_char_primitives
      no_args_primitive(char, 'to_s', string) do |b, f, llvm_mod|
        buffer = b.array_malloc(char.llvm_type, LLVM::Int(2))
        b.store f.params[0], b.gep(buffer, LLVM::Int(0))
        b.store LLVM::Int8.from_i(0), b.gep(buffer, LLVM::Int(1))
        buffer
      end

      no_args_primitive(char, 'ord', int) { |b, f| b.zext(f.params[0], int.llvm_type) }
      singleton(char, :==, {'other' => char}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(char, :'!=', {'other' => char}, bool) { |b, f| b.icmp(:ne, f.params[0], f.params[1]) }
      singleton(char, :<, {'other' => char}, bool) { |b, f| b.icmp(:ult, f.params[0], f.params[1]) }
      singleton(char, :<=, {'other' => char}, bool) { |b, f| b.icmp(:ule, f.params[0], f.params[1]) }
      singleton(char, :>, {'other' => char}, bool) { |b, f| b.icmp(:ugt, f.params[0], f.params[1]) }
      singleton(char, :>=, {'other' => char}, bool) { |b, f| b.icmp(:uge, f.params[0], f.params[1]) }
    end

    def define_int_primitives
      no_args_primitive(int, 'to_s', string) do |b, f, llvm_mod|
        buffer = b.array_malloc(char.llvm_type, LLVM::Int(12))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("%d"), f.params[0]
        buffer
      end

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

      singleton(int, :%, {'other' => int}, int) { |b, f| b.srem(f.params[0], f.params[1]) }

      no_args_primitive(int, 'chr', char) { |b, f| b.trunc(f.params[0], char.llvm_type) }
    end

    def define_long_primitives
      no_args_primitive(long, 'to_s', string) do |b, f, llvm_mod|
        buffer = b.array_malloc(char.llvm_type, LLVM::Int(22))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("%ld"), f.params[0]
        buffer
      end
    end

    def define_float_primitives
      no_args_primitive(float, 'to_s', string) do |b, f, llvm_mod|
        buffer = b.array_malloc(char.llvm_type, LLVM::Int(12))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("%g"), b.fp_ext(f.params[0], LLVM::Double)
        buffer
      end

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

    def define_symbol_primitives
      singleton(symbol, :==, {'other' => symbol}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(symbol, :'!=', {'other' => symbol}, bool) { |b, f| b.icmp(:ne, f.params[0], f.params[1]) }
      no_args_primitive(symbol, 'to_s', string) do |b, f, llvm_mod|
        b.load(b.gep llvm_mod.globals['symbol_table'], [LLVM::Int(0), f.params[0]])
      end
    end

    def define_array_primitives
      array.metaclass.defs['new'] = Def.new('new', [Var.new('size'), Var.new('obj')], ArrayNew.new)

      array.defs['length'] = Def.new('length', [], ArrayLength.new)
      array.defs['push'] = Def.new('push', [Var.new('value')], ArrayPush.new)
      array.defs[:<<] = Def.new(:<<, [Var.new('value')], ArrayPush.new)
      array.defs[:[]=] = Def.new(:[]=, [Var.new('index'), Var.new('value')], ArraySet.new)
      array.defs[:[]] = Def.new(:[], [Var.new('index')], ArrayGet.new)
    end

    def define_externals
      external('putchar', {'c' => char}, char)
      external('getchar', {}, char)
      external('strlen', {'str' => string}, int)
      external('puts', {'str' => string}, int)
      external('atoi', {'str' => string}, int)
    end

    def define_builtins
      Dir[File.expand_path("../../../../std/**/*.cr",  __FILE__)].each do |file|
        node = Parser.parse(File.read(file))
        node.accept TypeVisitor.new(self)
      end
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
      args = args.map { |name, type| Var.new(name, type) }

      instance = defs[name] = External.new(name, args)
      instance.body = Expressions.new
      instance.body.set_type(return_type)
      instance.add_instance instance
    end

    def sprintf(llvm_mod)
      llvm_mod.functions['sprintf'] || llvm_mod.functions.add('sprintf', [string.llvm_type], int.llvm_type, varargs: true)
    end

    def realloc(llvm_mod)
      llvm_mod.functions['realloc'] || llvm_mod.functions.add('realloc', [LLVM::Pointer(LLVM::Int8), LLVM::Int], LLVM::Pointer(LLVM::Int8))
    end

    def memset(llvm_mod)
      llvm_mod.functions['memset'] || llvm_mod.functions.add('memset', [LLVM::Pointer(LLVM::Int8), LLVM::Int, LLVM::Int], LLVM::Pointer(LLVM::Int8))
    end
  end

  class Def
    def overload(arg_types, return_type, &block)
      instance = clone
      instance.owner = owner
      arg_types.each_with_index do |arg_type, i|
        instance.args[i].set_type(arg_type)
      end
      instance.body = PrimitiveBody.new(return_type, block)
      add_instance(instance)
    end
  end

  class FrozenDef < Def
    def clone0(&block)
      frozen_def = FrozenDef.new name, args.map { |arg| arg.clone(&block) }, (body ? body.clone(&block) : nil), receiver ? receiver.clone(&block) : nil
      frozen_def.instances = instances
      frozen_def
    end
  end

  class External < FrozenDef
    def mangled_name(obj_type)
      name
    end
  end

  class Primitive < ASTNode
  end

  class PrimitiveBody < Primitive
    attr_accessor :block

    def initialize(type, block)
      @type = type
      @block = block
    end
  end

  class ArrayNew < Primitive
  end

  class ArraySet < Primitive
  end

  class ArrayGet < Primitive
  end

  class ArrayPush < Primitive
  end

  class ArrayLength < Primitive
  end
end

