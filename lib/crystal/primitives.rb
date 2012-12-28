require_relative 'program'

module Crystal
  class Program
    def define_primitives
      define_object_primitives
      define_bool_primitives
      define_char_primitives
      define_int_primitives
      define_long_primitives
      define_float_primitives
      define_symbol_primitives
      define_pointer_primitives

      define_numeric_operations
    end

    def define_object_primitives
      no_args_primitive(object, 'nil?', bool) { |b, f| LLVM::Int1.from_i(0) }
      no_args_primitive(object, 'object_id', long) do |b, f, llvm_mod, self_type|
        b.ptr2int(f.params[0], LLVM::Int64)
      end
      no_args_primitive(object, 'to_cstr', char_pointer) do |b, f, llvm_mod, self_type|
        buffer = b.array_malloc(LLVM::Int8, LLVM::Int(self_type.name.length + 23))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("#<#{self_type.name}:0x%016lx>"), f.params[0]
        buffer
      end
    end

    def define_bool_primitives
      self_primitive(bool, 'to_b')
      singleton(bool, :==, {'other' => bool}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(bool, :'!@', {}, bool) { |b, f| b.not(f.params[0]) }
      singleton(bool, :'&&', {'other' => bool}, bool) { |b, f| b.and(f.params[0], f.params[1]) }
      singleton(bool, :'||', {'other' => bool}, bool) { |b, f| b.or(f.params[0], f.params[1]) }
    end

    def define_char_primitives
      no_args_primitive(char, 'to_cstr', char_pointer) do |b, f, llvm_mod|
        buffer = b.array_malloc(LLVM::Int8, LLVM::Int(2))
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

    CALC_OP_MAP = {
      'Int' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'Long' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'Float' => { :+ => :fadd, :- => :fsub, :* => :fmul, :/ => :fdiv },
    }

    COMP_OP_FUN_MAP = {
      'Int' => :icmp, 'Long' => :icmp, 'Float' => :fcmp
    }

    COMP_OP_ARG_MAP = {
      'Int' => { :== => :eq, :> => :sgt, :>= => :sge, :< => :slt, :<= => :sle, :'!=' => :ne },
      'Long' => { :== => :eq, :> => :sgt, :>= => :sge, :< => :slt, :<= => :sle, :'!=' => :ne },
      'Float' => { :== => :oeq, :> => :ogt, :>= => :oge, :< => :olt, :<= => :ole, :'!=' => :one }
    }

    def build_calc_op(b, ret_type, op, arg1, arg2)
      b.send CALC_OP_MAP[ret_type.name][op], arg1, arg2
    end

    def build_comp_op(b, comp_type, op, arg1, arg2)
      b.send COMP_OP_FUN_MAP[comp_type.name], COMP_OP_ARG_MAP[comp_type.name][op], arg1, arg2
    end

    def greatest_type(type1, type2)
      return float if type1 == float || type2 == float
      return long if type1 == long || type2 == long
      return int
    end

    def adjust_calc_type(b, ret_type, type, arg)
      return arg if ret_type == type
      return b.si2fp(arg, float.llvm_type) if ret_type == float
      return b.zext(arg, long.llvm_type) if ret_type == long
    end

    def define_numeric_operations
      [int, long, float].repeated_permutation(2) do |type1, type2|
        [:+, :-, :*, :/].each do |op|
          ret_type = greatest_type(type1, type2)
          singleton(type1, op, {'other' => type2}, ret_type) do |b, f|
            arg1 = adjust_calc_type(b, ret_type, type1, f.params[0])
            arg2 = adjust_calc_type(b, ret_type, type2, f.params[1])
            build_calc_op(b, ret_type, op, arg1, arg2)
          end
        end

        [:==, :>, :>=, :<, :<=, :!=].each do |op|
          comp_type = greatest_type(type1, type2)
          singleton(type1, op, {'other' => type2}, bool) do |b, f|
            arg1 = adjust_calc_type(b, comp_type, type1, f.params[0])
            arg2 = adjust_calc_type(b, comp_type, type2, f.params[1])
            build_comp_op(b, comp_type, op, arg1, arg2)
          end
        end
      end
    end

    def define_int_primitives
      no_args_primitive(int, 'to_cstr', char_pointer) do |b, f, llvm_mod|
        buffer = b.array_malloc(LLVM::Int8, LLVM::Int(12))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("%d"), f.params[0]
        buffer
      end

      self_primitive(int, 'to_i')
      no_args_primitive(int, 'to_f', float) { |b, f| b.si2fp(f.params[0], float.llvm_type) }

      singleton(int, :%, {'other' => int}, int) { |b, f| b.srem(f.params[0], f.params[1]) }
      singleton(int, :<<, {'other' => int}, int) { |b, f| b.shl(f.params[0], f.params[1]) }
      singleton(int, :|, {'other' => int}, int) { |b, f| b.or(f.params[0], f.params[1]) }
      singleton(int, :&, {'other' => int}, int) { |b, f| b.and(f.params[0], f.params[1]) }

      no_args_primitive(int, 'chr', char) { |b, f| b.trunc(f.params[0], char.llvm_type) }
    end

    def define_long_primitives
      no_args_primitive(long, 'to_i', int) { |b, f| b.trunc(f.params[0], int.llvm_type) }
      no_args_primitive(long, 'to_cstr', char_pointer) do |b, f, llvm_mod|
        buffer = b.array_malloc(LLVM::Int8, LLVM::Int(22))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("%ld"), f.params[0]
        buffer
      end

      no_args_primitive(long, :-@, long) { |b, f| b.sub(LLVM::Int64.from_i(0), f.params[0]) }
      no_args_primitive(long, :+@, long) { |b, f| f.params[0] }
    end

    def define_float_primitives
      no_args_primitive(float, 'to_cstr', char_pointer) do |b, f, llvm_mod|
        buffer = b.array_malloc(LLVM::Int8, LLVM::Int(12))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("%g"), b.fp_ext(f.params[0], LLVM::Double)
        buffer
      end

      no_args_primitive(float, 'to_i', int) { |b, f| b.fp2si(f.params[0], int.llvm_type) }
      self_primitive(float, 'to_f')
    end

    def define_symbol_primitives
      singleton(symbol, :==, {'other' => symbol}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(symbol, 'hash', {}, int) { |b, f| f.params[0] }
      no_args_primitive(symbol, 'to_s', string) do |b, f, llvm_mod|
        b.load(b.gep llvm_mod.globals['symbol_table'], [LLVM::Int(0), f.params[0]])
      end
    end

    def define_pointer_primitives
      pointer.metaclass.add_def Def.new('malloc', [Arg.new_with_type('size', int)], PointerMalloc.new)
      pointer.metaclass.add_def Def.new('malloc', [Arg.new_with_type('size', long)], PointerMalloc.new)
      pointer.add_def Def.new('value', [], PointerGetValue.new)
      pointer.add_def Def.new('value=', [Arg.new('value')], PointerSetValue.new)
      pointer.add_def Def.new('realloc', [Arg.new_with_type('size', int)], PointerRealloc.new)
      pointer.add_def Def.new('realloc', [Arg.new_with_type('size', long)], PointerRealloc.new)
      pointer.add_def Def.new(:+, [Arg.new_with_type('offset', int)], PointerAdd.new)
      pointer.add_def Def.new(:+, [Arg.new_with_type('offset', long)], PointerAdd.new)
      pointer.add_def Def.new('as', [Arg.new('type')], PointerCast.new)
      no_args_primitive(object, 'address', long) do |b, f, llvm_mod, self_type|
        b.ptr2int(f.params[0], LLVM::Int64)
      end
    end

    def primitive(owner, name, arg_names)
      p = owner.add_def Def.new(name, arg_names.map { |x| Arg.new(x) })
      p.owner = owner
      yield p
    end

    def no_args_primitive(owner, name, return_type, &block)
      primitive(owner, name, []) { |p| p.overload([], return_type, &block) }
    end

    def self_primitive(owner, name)
      no_args_primitive(owner, name, owner) { |b, f| f.params[0] }
    end

    def singleton(owner, name, args, return_type, &block)
      p = owner.add_def Def.new(name, args.map { |name, type| Arg.new_with_type(name, type) })
      p.owner = owner
      p.overload(args.values, return_type, &block)
    end

    def sprintf(llvm_mod)
      llvm_mod.functions['sprintf'] || llvm_mod.functions.add('sprintf', [LLVM::Pointer(LLVM::Int8)], int.llvm_type, varargs: true)
    end

    def realloc(llvm_mod)
      llvm_mod.functions['realloc'] || llvm_mod.functions.add('realloc', [LLVM::Pointer(LLVM::Int8), LLVM::Int], LLVM::Pointer(LLVM::Int8))
    end

    def memset(llvm_mod)
      llvm_mod.functions['llvm.memset.p0i8.i32'] || llvm_mod.functions.add('llvm.memset.p0i8.i32', [LLVM::Pointer(LLVM::Int8), LLVM::Int8, LLVM::Int, LLVM::Int32, LLVM::Int1], LLVM.Void)
    end
  end

  class Def
    def overload(arg_types, return_type, &block)
      instance = clone
      instance.owner = owner
      arg_types.each_with_index do |arg_type, i|
        instance.args[i].set_type(arg_type)
      end
      instance.body = PrimitiveBody.new(block)
      instance.type = return_type
      add_instance(instance)
    end
  end

  class External < Def
  end

  class Primitive < ASTNode
  end

  class PrimitiveBody < Primitive
    attr_accessor :block

    def initialize(block)
      @block = block
    end
  end

  class PointerMalloc < Primitive
  end

  class PointerMallocWithValue < Primitive
  end

  class PointerGetValue < Primitive
  end

  class PointerSetValue < Primitive
  end

  class PointerAdd < Primitive
  end

  class PointerRealloc < Primitive
  end

  class PointerCast < Primitive
  end

  class Alloc < Primitive
    def initialize(type)
      @type = type
    end

    def clone_from(other)
      @type = other.type.clone
    end
  end

  class StructAlloc < Primitive
    attr_reader :type

    def initialize(type)
      @type = type
    end

    def clone_from(other)
      @type = other.type
    end
  end

  class StructSet < Primitive
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def clone_from(other)
      @name = other.name
    end
  end

  class StructGet < Primitive
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def clone_from(other)
      @name = other.name
    end
  end

  class ARGC < Primitive
    def initialize(type)
      @type = type
    end

    def clone_from(other)
      @type = other.type
    end
  end

  class ARGV < Primitive
    def initialize(type)
      @type = type
    end

    def clone_from(other)
      @type = other.type
    end
  end
end

