require_relative 'program'

module Crystal
  class Program
    def define_primitives
      define_object_primitives
      define_reference_primitives

      define_value_primitives
      define_bool_primitives
      define_char_primitives
      define_int32_primitives
      define_int64_primitives
      define_float32_primitives
      define_float64_primitives
      define_symbol_primitives
      define_pointer_primitives

      define_numeric_operations
      define_math_primitives
    end

    def define_object_primitives
      object.add_def Def.new(:class, [], ClassMethod.new)
    end

    def define_reference_primitives
      a_def = no_args_primitive(reference, 'nil?', bool) do |b, f|
        b.icmp(:eq, b.ptr2int(f.params[0], LLVM::Int), LLVM::Int(0))
      end
      instance = a_def.overload [], bool do |b, f|
        obj = b.load(b.gep(f.params[0], [LLVM::Int(0), LLVM::Int(1)]))
        b.icmp(:eq, b.ptr2int(obj, LLVM::Int), LLVM::Int(0))
      end
      instance.owner = reference.hierarchy_type
      reference.hierarchy_type.add_def_instance(a_def.object_id, [], nil, instance)

      a_def = no_args_primitive(reference, 'object_id', int64) do |b, f, llvm_mod, self_type|
        b.ptr2int(f.params[0], LLVM::Int64)
      end

      instance = a_def.overload [], int64 do |b, f, llvm_mod, self_type|
        obj = b.load(b.gep(f.params[0], [LLVM::Int(0), LLVM::Int(1)]))
        b.ptr2int(obj, LLVM::Int64)
      end
      instance.owner = reference.hierarchy_type
      reference.hierarchy_type.add_def_instance(a_def.object_id, [], nil, instance)

      a_def = no_args_primitive(reference, 'to_cstr', char_pointer) do |b, f, llvm_mod, self_type|
        buffer = b.array_malloc(LLVM::Int8, LLVM::Int(self_type.name.length + 23))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("#<#{self_type.name}:0x%016lx>"), f.params[0]
        buffer
      end

      instance = a_def.overload [], char_pointer do |b, f, llvm_mod, self_type|
        obj = b.load(b.gep(f.params[0], [LLVM::Int(0), LLVM::Int(1)]))
        buffer = b.array_malloc(LLVM::Int8, LLVM::Int(self_type.name.length + 23))
        b.call sprintf(llvm_mod), buffer, b.global_string_pointer("#<#{self_type.name}:0x%016lx>"), obj
        buffer
      end

      instance.owner = reference.hierarchy_type
      reference.hierarchy_type.add_def_instance(a_def.object_id, [], nil, instance)
    end

    def define_value_primitives
      [value, bool, char, int32, int64, float32, float64, symbol].each do |klass|
        no_args_primitive(klass, 'nil?', bool) { |b, f| LLVM::Int1.from_i(0) }
      end
    end

    def define_bool_primitives
      singleton(bool, :==, {'other' => bool}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(bool, :'!@', {}, bool) { |b, f| b.not(f.params[0]) }
    end

    def define_char_primitives
      no_args_primitive(char, 'ord', int32) { |b, f| b.zext(f.params[0], int32.llvm_type) }
      singleton(char, :==, {'other' => char}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(char, :'!=', {'other' => char}, bool) { |b, f| b.icmp(:ne, f.params[0], f.params[1]) }
      singleton(char, :<, {'other' => char}, bool) { |b, f| b.icmp(:ult, f.params[0], f.params[1]) }
      singleton(char, :<=, {'other' => char}, bool) { |b, f| b.icmp(:ule, f.params[0], f.params[1]) }
      singleton(char, :>, {'other' => char}, bool) { |b, f| b.icmp(:ugt, f.params[0], f.params[1]) }
      singleton(char, :>=, {'other' => char}, bool) { |b, f| b.icmp(:uge, f.params[0], f.params[1]) }
    end

    def define_math_primitives
      math = types['Math'].metaclass
      singleton(math, 'sqrt', {'other' => float32}, float32) { |b, f, llvm_mod| b.call(sqrtf(llvm_mod), f.params[1]) }
      singleton(math, 'sqrt', {'other' => float64}, float64) { |b, f, llvm_mod| b.call(sqrt(llvm_mod), f.params[1]) }
    end

    CALC_OP_MAP = {
      'UInt8' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'UInt16' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'UInt32' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'UInt64' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'Int8' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'Int16' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'Int32' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'Int64' => { :+ => :add, :- => :sub, :* => :mul, :/ => :sdiv },
      'Float32' => { :+ => :fadd, :- => :fsub, :* => :fmul, :/ => :fdiv },
      'Float64' => { :+ => :fadd, :- => :fsub, :* => :fmul, :/ => :fdiv },
    }

    COMP_OP_FUN_MAP = {
      'UInt8' => :icmp,
      'UInt16' => :icmp,
      'UInt32' => :icmp,
      'UInt64' => :icmp,
      'Int8' => :icmp,
      'Int16' => :icmp,
      'Int32' => :icmp,
      'Int64' => :icmp,
      'Float32' => :fcmp,
      'Float64' => :fcmp,
    }

    COMP_OP_ARG_MAP = {
      'UInt8' => { :== => :eq, :> => :ugt, :>= => :uge, :< => :ult, :<= => :ule, :'!=' => :ne },
      'UInt16' => { :== => :eq, :> => :ugt, :>= => :uge, :< => :ult, :<= => :ule, :'!=' => :ne },
      'UInt32' => { :== => :eq, :> => :ugt, :>= => :uge, :< => :ult, :<= => :ule, :'!=' => :ne },
      'UInt64' => { :== => :eq, :> => :ugt, :>= => :uge, :< => :ult, :<= => :ule, :'!=' => :ne },
      'Int8' => { :== => :eq, :> => :sgt, :>= => :sge, :< => :slt, :<= => :sle, :'!=' => :ne },
      'Int16' => { :== => :eq, :> => :sgt, :>= => :sge, :< => :slt, :<= => :sle, :'!=' => :ne },
      'Int32' => { :== => :eq, :> => :sgt, :>= => :sge, :< => :slt, :<= => :sle, :'!=' => :ne },
      'Int64' => { :== => :eq, :> => :sgt, :>= => :sge, :< => :slt, :<= => :sle, :'!=' => :ne },
      'Float32' => { :== => :oeq, :> => :ogt, :>= => :oge, :< => :olt, :<= => :ole, :'!=' => :one },
      'Float64' => { :== => :oeq, :> => :ogt, :>= => :oge, :< => :olt, :<= => :ole, :'!=' => :one },
    }

    def build_calc_op(b, ret_type, op, arg1, arg2)
      b.send CALC_OP_MAP[ret_type.name][op], arg1, arg2
    end

    def build_comp_op(b, comp_type, op, arg1, arg2)
      b.send COMP_OP_FUN_MAP[comp_type.name], COMP_OP_ARG_MAP[comp_type.name][op], arg1, arg2
    end

    def greatest_type(type1, type2)
      return float64 if type1 == float64 || type2 == float64
      return float32 if type1 == float32 || type2 == float32
      return uint64 if type1 == uint64 || type2 == uint64
      return int64 if type1 == int64 || type2 == int64
      return uint32 if type1 == uint32 || type2 == uint32
      return int32 if type1 == int32 || type2 == int32
      return uint16 if type1 == uint16 || type2 == uint16
      return int16 if type1 == int16 || type2 == int16
      return uint8 if type1 == uint8 || type2 == uint8
      return int8
    end

    def adjust_calc_type(b, ret_type, type, arg)
      return arg if ret_type == type
      if ret_type == float64
        if type == float32
          return b.fp_ext(arg, float64.llvm_type)
        elsif type.unsigned?
          return b.ui2fp(arg, float64.llvm_type)
        else
          return b.si2fp(arg, float64.llvm_type)
        end
      elsif ret_type == float32
        if type.unsigned?
          return b.ui2fp(arg, float32.llvm_type)
        else
          return b.si2fp(arg, float32.llvm_type)
        end
      end

      return b.zext(arg, int64.llvm_type) if ret_type == int64 || ret_type == uint64
      return b.zext(arg, int32.llvm_type) if ret_type == int32 || ret_type == uint32
      return b.zext(arg, int16.llvm_type) if ret_type == int16 || ret_type == uint16
      return arg
    end

    def cast_back(b, ret_type, type, arg)
      if ret_type.rank > type.rank
        b.zext(arg, ret_type.llvm_type)
      elsif ret_type.rank < type.rank
        b.trunc(arg, ret_type.llvm_type)
      else
        arg
      end
    end

    def define_numeric_operations
      [uint8, uint16, uint32, uint64, int8, int16, int32, int64, float32, float64].repeated_permutation(2) do |type1, type2|
        [:+, :-, :*, :/].each do |op|
          ret_type = greatest_type(type1, type2)
          if ret_type.equal?(float32) || ret_type.equal?(float64)
            singleton(type1, op, {'other' => type2}, ret_type) do |b, f|
              arg1 = adjust_calc_type(b, ret_type, type1, f.params[0])
              arg2 = adjust_calc_type(b, ret_type, type2, f.params[1])
              build_calc_op(b, ret_type, op, arg1, arg2)
            end
          else
            singleton(type1, op, {'other' => type2}, type1) do |b, f|
              arg1 = adjust_calc_type(b, ret_type, type1, f.params[0])
              arg2 = adjust_calc_type(b, ret_type, type2, f.params[1])
              ret = build_calc_op(b, ret_type, op, arg1, arg2)
              cast_back(b, type1, ret_type, ret)
            end
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

    def define_int32_primitives
      self_primitive(int32, 'to_i')
      no_args_primitive(int32, 'to_f', float32) { |b, f| b.si2fp(f.params[0], float32.llvm_type) }
      no_args_primitive(int32, 'to_d', float64) { |b, f| b.si2fp(f.params[0], float64.llvm_type) }

      singleton(int32, :%, {'other' => int32}, int32) { |b, f| b.srem(f.params[0], f.params[1]) }
      singleton(int32, :<<, {'other' => int32}, int32) { |b, f| b.shl(f.params[0], f.params[1]) }
      singleton(int32, :|, {'other' => int32}, int32) { |b, f| b.or(f.params[0], f.params[1]) }
      singleton(int32, :&, {'other' => int32}, int32) { |b, f| b.and(f.params[0], f.params[1]) }
      singleton(int32, :"^", {'other' => int32}, int32) { |b, f| b.xor(f.params[0], f.params[1]) }

      no_args_primitive(int32, 'chr', char) { |b, f| b.trunc(f.params[0], char.llvm_type) }
    end

    def define_int64_primitives
      no_args_primitive(int64, 'to_i', int32) { |b, f| b.trunc(f.params[0], int32.llvm_type) }
      no_args_primitive(int64, 'to_f', float32) { |b, f| b.si2fp(f.params[0], float32.llvm_type) }
      no_args_primitive(int64, 'to_d', float64) { |b, f| b.si2fp(f.params[0], float64.llvm_type) }

      no_args_primitive(int64, :-@, int64) { |b, f| b.sub(LLVM::Int64.from_i(0), f.params[0]) }
      no_args_primitive(int64, :+@, int64) { |b, f| f.params[0] }
    end

    def define_float32_primitives
      no_args_primitive(float32, 'to_i', int32) { |b, f| b.fp2si(f.params[0], int32.llvm_type) }
      self_primitive(float32, 'to_f')
      no_args_primitive(float32, 'to_d', float64) { |b, f| b.fp_ext(f.params[0], float64.llvm_type) }
      singleton(float32, :**, {'other' => float32}, float32) { |b, f, llvm_mod| b.call(powf(llvm_mod), f.params[0], f.params[1]) }
    end

    def define_float64_primitives
      no_args_primitive(float64, 'to_i', int32) { |b, f| b.fp2si(f.params[0], int32.llvm_type) }
      no_args_primitive(float64, 'to_f', float32) { |b, f| b.fp_trunc(f.params[0], float32.llvm_type) }
      self_primitive(float64, 'to_d')
      singleton(float64, :**, {'other' => float64}, float64) { |b, f, llvm_mod| b.call(pow(llvm_mod), f.params[0], f.params[1]) }
    end

    def define_symbol_primitives
      singleton(symbol, :==, {'other' => symbol}, bool) { |b, f| b.icmp(:eq, f.params[0], f.params[1]) }
      singleton(symbol, 'hash', {}, int32) { |b, f| f.params[0] }
      no_args_primitive(symbol, 'to_s', string) do |b, f, llvm_mod|
        b.load(b.gep llvm_mod.globals['symbol_table'], [LLVM::Int(0), f.params[0]])
      end
    end

    def define_pointer_primitives
      pointer.metaclass.add_def Def.new('malloc', [Arg.new_with_restriction('size', int32)], PointerMalloc.new)
      pointer.metaclass.add_def Def.new('malloc', [Arg.new_with_restriction('size', int64)], PointerMalloc.new)
      pointer.add_def Def.new('value', [], PointerGetValue.new)
      pointer.add_def Def.new('value=', [Arg.new_with_restriction('value', Ident.new(["T"]))], PointerSetValue.new)
      pointer.add_def Def.new('realloc', [Arg.new_with_restriction('size', int32)], PointerRealloc.new)
      pointer.add_def Def.new('realloc', [Arg.new_with_restriction('size', int64)], PointerRealloc.new)
      pointer.add_def Def.new(:+, [Arg.new_with_restriction('offset', int32)], PointerAdd.new)
      pointer.add_def Def.new(:+, [Arg.new_with_restriction('offset', int64)], PointerAdd.new)
      pointer.add_def Def.new('as', [Arg.new('type')], PointerCast.new)
      shared_singleton(pointer, 'address', int64) do |b, f, llvm_mod, self_type|
        b.ptr2int(f.params[0], LLVM::Int64)
      end
    end

    def primitive(owner, name, arg_names)
      a_def = owner.add_def Def.new(name, arg_names.map { |x| Arg.new(x) })
      a_def.owner = owner
      yield a_def
      a_def
    end

    def no_args_primitive(owner, name, return_type, &block)
      primitive(owner, name, []) do |a_def|
        instance = a_def.overload([], return_type, &block)
        owner.add_def_instance(a_def.object_id, [], nil, instance)
      end
    end

    def self_primitive(owner, name)
      no_args_primitive(owner, name, owner) { |b, f| f.params[0] }
    end

    def singleton(owner, name, args, return_type, &block)
      a_def = owner.add_def Def.new(name, args.map { |name, type| Arg.new_with_restriction(name, type) })
      a_def.owner = owner
      instance = a_def.overload(args.values, return_type, &block)
      owner.add_def_instance(a_def.object_id, args.values, nil, instance)
    end

    def shared_singleton(owner, name, return_type, &block)
      body = PrimitiveBody.new(&block)
      body.type = return_type
      owner.add_def Def.new(name, [], body)
    end

    def sprintf(llvm_mod)
      llvm_mod.functions['sprintf'] || llvm_mod.functions.add('sprintf', [LLVM::Pointer(LLVM::Int8)], int32.llvm_type, varargs: true)
    end

    def realloc(llvm_mod)
      llvm_mod.functions['realloc'] || llvm_mod.functions.add('realloc', [LLVM::Pointer(LLVM::Int8), LLVM::Int], LLVM::Pointer(LLVM::Int8))
    end

    def memset(llvm_mod)
      llvm_mod.functions['llvm.memset.p0i8.i32'] || llvm_mod.functions.add('llvm.memset.p0i8.i32', [LLVM::Pointer(LLVM::Int8), LLVM::Int8, LLVM::Int, LLVM::Int32, LLVM::Int1], LLVM.Void)
    end

    def pow(llvm_mod)
      llvm_mod.functions['llvm.pow.f64'] || llvm_mod.functions.add('llvm.pow.f64', [LLVM::Double, LLVM::Double], LLVM::Double)
    end

    def powf(llvm_mod)
      llvm_mod.functions['llvm.pow.f32'] || llvm_mod.functions.add('llvm.pow.f32', [LLVM::Float, LLVM::Float], LLVM::Float)
    end

    def sqrt(llvm_mod)
      llvm_mod.functions['llvm.sqrt.f64'] || llvm_mod.functions.add('llvm.sqrt.f64', [LLVM::Double], LLVM::Double)
    end

    def sqrtf(llvm_mod)
      llvm_mod.functions['llvm.sqrt.f32'] || llvm_mod.functions.add('llvm.sqrt.f32', [LLVM::Float], LLVM::Float)
    end

    def llvm_puts(llvm_mod)
      llvm_mod.functions['puts'] || llvm_mod.functions.add('puts', [LLVM::Pointer(LLVM::Int8)], LLVM::Int)
    end
  end

  class Def
    def overload(arg_types, return_type, &block)
      instance = clone
      instance.owner = owner
      arg_types.each_with_index do |arg_type, i|
        instance.args[i].set_type(arg_type)
      end
      instance.body = PrimitiveBody.new(&block)
      instance.set_type(return_type)
      instance
    end
  end

  class External < Def
  end

  class Primitive < ASTNode
  end

  class PrimitiveBody < Primitive
    attr_accessor :block

    def initialize(&block)
      @block = block
    end

    def clone
      self
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

  class Allocate < Primitive
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

  class NilPointer < Primitive
    def initialize(type)
      @type = type
    end

    def clone_from(other)
      @type = other.type
    end
  end

  class ClassMethod < Primitive
  end
end

