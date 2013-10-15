lib LibLLVM("LLVM-3.3")
  type ContextRef : Void*
  type ModuleRef : Void*
  type TypeRef : Void*
  type ValueRef : Void*
  type BasicBlockRef : Void*
  type BuilderRef : Void*
  type ExecutionEngineRef : Void*
  type GenericValueRef : Void*

  enum Linkage
    External,
    AvailableExternally,
    LinkOnceAny,
    LinkOnceODR,
    LinkOnceODRAutoHide,
    WeakAny,
    WeakODR,
    Appending,
    Internal,
    Private,
    DLLImport,
    DLLExport,
    ExternalWeak,
    Ghost,
    Common,
    LinkerPrivate,
    LinkerPrivateWeak
  end

  enum IntPredicate
    EQ = 32
    NE
    UGT
    UGE
    ULT
    ULE
    SGT
    SGE
    SLT
    SLE
  end

  enum RealPredicate
    PredicateFalse
    OEQ
    OGT
    OGE
    OLT
    OLE
    ONE
    ORD
    UNO
    UEQ
    UGT
    UGE
    ULT
    ULE
    UNE
    PredicateTrue
  end

  fun get_global_context = LLVMGetGlobalContext : ContextRef
  fun module_create_with_name = LLVMModuleCreateWithName(module_id : Char*) : ModuleRef
  fun dump_module = LLVMDumpModule(module : ModuleRef)
  fun void_type = LLVMVoidType() : TypeRef
  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : Int32, is_var_arg : Int32) : TypeRef
  fun add_function = LLVMAddFunction(module : ModuleRef, name : Char*, type : TypeRef) : ValueRef
  fun get_param = LLVMGetParam(fn : ValueRef, index : Int32) : ValueRef
  fun add_global = LLVMAddGlobal(module : ModuleRef, type : TypeRef, name : Char*) : ValueRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : Char*) : ValueRef
  fun append_basic_block = LLVMAppendBasicBlock(fn : ValueRef, name : Char*) : BasicBlockRef
  fun create_builder = LLVMCreateBuilder() : BuilderRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun build_ret_void = LLVMBuildRetVoid(builder : BuilderRef) : ValueRef
  fun build_ret = LLVMBuildRet(builder : BuilderRef, value : ValueRef) : ValueRef
  fun build_br = LLVMBuildBr(builder : BuilderRef, block : BasicBlockRef) : ValueRef
  fun build_call = LLVMBuildCall(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : Int32, name : Char*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(builder : BuilderRef, type : TypeRef, name : Char*) : ValueRef
  fun build_store = LLVMBuildStore(builder : BuilderRef, value : ValueRef, ptr : ValueRef)
  fun build_load = LLVMBuildLoad(builder : BuilderRef, ptr : ValueRef, name : Char*) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(builder : BuilderRef, value : ValueRef, type : TypeRef, name : Char*) : ValueRef
  fun build_add = LLVMBuildAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sub = LLVMBuildSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_mul = LLVMBuildMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sdiv = LLVMBuildSDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_udiv = LLVMBuildUDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_srem = LLVMBuildSRem(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_urem = LLVMBuildURem(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_shl = LLVMBuildShl(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_ashr = LLVMBuildAShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_lshr = LLVMBuildLShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_or = LLVMBuildOr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_and = LLVMBuildAnd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_xor = LLVMBuildXor(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fadd = LLVMBuildFAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fsub = LLVMBuildFSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fmul = LLVMBuildFMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fdiv = LLVMBuildFDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_icmp = LLVMBuildICmp(builder : BuilderRef, op : IntPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fcmp = LLVMBuildFCmp(builder : BuilderRef, op : RealPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ui2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_zext = LLVMBuildZExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_sext = LLVMBuildSExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_trunc = LLVMBuildTrunc(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_cond = LLVMBuildCondBr(builder : BuilderRef, if : ValueRef, then : BasicBlockRef, else : BasicBlockRef)
  fun build_fpext = LLVMBuildFPExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fptrunc = LLVMBuildFPTrunc(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fp2si = LLVMBuildFPToSI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fp2ui = LLVMBuildFPToUI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ui2fp = LLVMBuildUIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_int2ptr = LLVMBuildIntToPtr(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ptr2int = LLVMBuildPtrToInt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_malloc = LLVMBuildMalloc(builder : BuilderRef, type : TypeRef, name : Char*) : ValueRef
  fun build_array_malloc = LLVMBuildArrayMalloc(builder : BuilderRef, type : TypeRef, val : ValueRef, name : Char*) : ValueRef
  fun build_phi = LLVMBuildPhi(builder : BuilderRef, type : TypeRef, name : Char*) : ValueRef
  fun build_gep = LLVMBuildGEP(builder : BuilderRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt32, name : Char*) : ValueRef
  fun build_extract_value = LLVMBuildExtractValue(builder : BuilderRef, agg_val : ValueRef, index : UInt32, name : Char*) : ValueRef
  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef *, count : Int32)
  fun int_type = LLVMIntType(bits : Int32) : TypeRef
  fun float_type = LLVMFloatType() : TypeRef
  fun double_type = LLVMDoubleType() : TypeRef
  fun struct_type = LLVMStructType(element_types : TypeRef*, element_count : UInt32, packed : Int32) : TypeRef
  fun array_type = LLVMArrayType(element_type : TypeRef, count : UInt32) : TypeRef
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt32) : TypeRef
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : Char*) : TypeRef
  fun struct_set_body = LLVMStructSetBody(struct_type : TypeRef, element_types : TypeRef*, element_count : UInt32, packed : Int32)
  fun const_int = LLVMConstInt(int_type : TypeRef, value : UInt64, sign_extend : Int32) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_type : TypeRef, value : Char*) : ValueRef
  fun const_string = LLVMConstString(str : Char*, length : UInt32, dont_null_terminate : UInt32) : ValueRef
  fun const_array = LLVMConstArray(element_type : TypeRef, constant_vals : ValueRef*, length : UInt32) : ValueRef
  fun create_jit_compiler_for_module = LLVMCreateJITCompilerForModule (jit : ExecutionEngineRef*, m : ModuleRef, opt_level : Int32, error : Char**) : Int32
  fun run_function = LLVMRunFunction (ee : ExecutionEngineRef, f : ValueRef, num_args : Int32, args : Int32) : GenericValueRef
  fun initialize_x86_target_info = LLVMInitializeX86TargetInfo()
  fun initialize_x86_target = LLVMInitializeX86Target()
  fun initialize_x86_target_mc = LLVMInitializeX86TargetMC()
  fun generic_value_to_int = LLVMGenericValueToInt(value : GenericValueRef, signed : Int32) : Int32
  fun generic_value_to_float = LLVMGenericValueToFloat(type : TypeRef, value : GenericValueRef) : Float64
  fun generic_value_to_pointer = LLVMGenericValueToPointer(value : GenericValueRef) : Void*
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : Char*) : Int32
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : Linkage)
  fun set_global_constant = LLVMSetGlobalConstant(global : ValueRef, is_constant : Int32)
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun dump_value = LLVMDumpValue(val : ValueRef)
  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef
end

module LLVM
  def self.init_x86
    LibLLVM.initialize_x86_target_info
    LibLLVM.initialize_x86_target
    LibLLVM.initialize_x86_target_mc
  end

  def self.dump(value)
    LibLLVM.dump_value value
  end

  def self.type_of(value)
    LibLLVM.type_of(value)
  end

  def self.size_of(type)
    LibLLVM.size_of(type)
  end

  class Context
    def self.global
      LibLLVM.get_global_context
    end
  end

  class Module
    def initialize(name)
      @module = LibLLVM.module_create_with_name name
      @functions = FunctionCollection.new(self)
      @globals = GlobalCollection.new(self)
    end

    def dump
      LibLLVM.dump_module(@module)
    end

    def functions
      @functions
    end

    def globals
      @globals
    end

    def llvm_module
      @module
    end

    def write_bitcode(filename : String)
      LibLLVM.write_bitcode_to_file @module, filename
    end
  end

  class FunctionCollection
    def initialize(@mod)
    end

    def add(name, arg_types, ret_type, varargs = false)
      args = arg_types.map &.type
      fun_type = LibLLVM.function_type(ret_type.type, args.buffer.as(LibLLVM::TypeRef), arg_types.length, varargs ? 1 : 0)
      func = LibLLVM.add_function(@mod.llvm_module, name, fun_type)
      Function.new(func)
    end

    def [](name)
      func = LibLLVM.get_named_function(@mod.llvm_module, name)
      if func
        Function.new(func)
      else
        raise "Undefined function: #{name}"
      end
    end

    def []?(name)
      func = LibLLVM.get_named_function(@mod.llvm_module, name)
      func.nil? ? nil : Function.new(func)
    end
  end

  class Function
    def initialize(@fun)
    end

    def append_basic_block(name)
      LibLLVM.append_basic_block(@fun, name)
    end

    def llvm_function
      @fun
    end

    def get_param(index)
      LibLLVM.get_param(@fun, index)
    end

    def linkage=(linkage)
      LibLLVM.set_linkage(@fun, linkage)
    end
  end

  class GlobalCollection
    def initialize(@mod)
    end

    def add(type, name)
      GlobalVariable.new(LibLLVM.add_global(@mod.llvm_module, type.type, name))
    end
  end

  class Value
    getter :value

    def initialize(@value)
    end

    def self.const_string(value)
      new(LibLLVM.const_string(value.cstr, value.length.to_u32, 0_u32))
    end

    def self.const_array(type, values)
      new(LibLLVM.const_array(type.type, values.buffer, values.length.to_u32))
    end
  end

  class GlobalValue < Value
    def linkage=(linkage)
      LibLLVM.set_linkage(@value, linkage)
    end

    def global_constant=(flag : Bool)
      LibLLVM.set_global_constant(@value, flag ? 1 : 0)
    end
  end

  class GlobalVariable < GlobalValue
    def initializer=(value)
      LibLLVM.set_initializer(@value, value.value)
    end
  end

  class Builder
    def initialize
      @builder = LibLLVM.create_builder
    end

    def position_at_end(block)
      LibLLVM.position_builder_at_end(@builder, block)
    end

    def insert_block
      LibLLVM.get_insert_block(@builder)
    end

    def ret
      LibLLVM.build_ret_void(@builder)
    end

    def ret(value)
      LibLLVM.build_ret(@builder, value)
    end

    def br(block)
      LibLLVM.build_br(@builder, block)
    end

    def cond(cond, then_block, else_block)
      LibLLVM.build_cond(@builder, cond, then_block, else_block)
    end

    def phi(type, incoming_blocks, incoming_values, name = "")
      phi_node = LibLLVM.build_phi @builder, type.type, name
      LibLLVM.add_incoming phi_node, incoming_values.buffer, incoming_blocks.buffer, incoming_blocks.length
      phi_node
    end

    def call(func, args = [] of LibLLVM::ValueRef)
      LibLLVM.build_call(@builder, func.llvm_function, args.buffer, args.length, "")
    end

    def alloca(type, name = "")
      LibLLVM.build_alloca(@builder, type.type, name)
    end

    def store(value, ptr)
      LibLLVM.build_store(@builder, value, ptr)
    end

    def load(ptr, name = "")
      LibLLVM.build_load(@builder, ptr, name)
    end

    def malloc(type, name = "")
      LibLLVM.build_malloc(@builder, type.type, name)
    end

    def array_malloc(type, value, name = "")
      LibLLVM.build_array_malloc(@builder, type.type, value, name)
    end

    def gep(value, indices, name = "")
      LibLLVM.build_gep(@builder, value, indices.buffer, indices.length.to_u32, name)
    end

    def extract_value(value, index, name = "")
      LibLLVM.build_extract_value(@builder, value, index.to_u32, name)
    end

    macro self.define_cast(name)"
      def #{name}(value, type : Type, name = \"\" : String)
        #{name}(value, type.type, name)
      end

      def #{name}(value, type : LibvLLVM::TypeRef, name = \"\")
        LibLLVM.build_#{name}(@builder, value, type, name)
      end
    "end

    define_cast bit_cast
    define_cast si2fp
    define_cast ui2fp
    define_cast zext
    define_cast sext
    define_cast trunc
    define_cast fpext
    define_cast fptrunc
    define_cast fp2si
    define_cast fp2ui
    define_cast si2fp
    define_cast ui2fp
    define_cast int2ptr
    define_cast ptr2int

    macro self.define_binary(name)"
      def #{name}(lhs, rhs, name = \"\")
        LibLLVM.build_#{name}(@builder, lhs, rhs, name)
      end
    "end

    define_binary add
    define_binary sub
    define_binary mul
    define_binary sdiv
    define_binary udiv
    define_binary srem
    define_binary urem
    define_binary shl
    define_binary ashr
    define_binary lshr
    define_binary or
    define_binary and
    define_binary xor
    define_binary fadd
    define_binary fsub
    define_binary fmul
    define_binary fdiv

    macro self.define_cmp(name)"
      def #{name}(op, lhs, rhs, name = \"\")
        LibLLVM.build_#{name}(@builder, op, lhs, rhs, name)
      end
    "end

    define_cmp icmp
    define_cmp fcmp
  end

  abstract class Type
    getter :type

    def initialize(@type)
    end

    def size
      LLVM.size_of @type
    end
  end

  class IntType < Type
    def initialize(bits)
      super LibLLVM.int_type(bits)
    end

    def from_i(value)
      LibLLVM.const_int(@type, value.to_u64, 0)
    end
  end

  class FloatType < Type
    def initialize
      super LibLLVM.float_type
    end

    def from_s(value)
      LibLLVM.const_real_of_string(@type, value)
    end
  end

  class DoubleType < Type
    def initialize
      super LibLLVM.double_type
    end

    def from_s(value)
      LibLLVM.const_real_of_string(@type, value)
    end
  end

  class VoidType < Type
    def initialize
      super LibLLVM.void_type
    end
  end

  class ArrayType < Type
    def initialize(element_type : Type, count)
      super LibLLVM.array_type(element_type.type, count.to_u32)
    end
  end

  class StructType < Type
    def initialize(name)
      super LibLLVM.struct_create_named(Context.global, name)
    end

    def element_types=(element_types)
      LibLLVM.struct_set_body(@type, element_types.map(&.type).buffer, element_types.length.to_u32, 0)
    end
  end

  class PointerType < Type
    def initialize(element_type : Type)
      super LibLLVM.pointer_type(element_type.type, 0_u32)
    end
  end

  class GenericValue
    def initialize(value)
      @value = value
    end

    def to_i
      LibLLVM.generic_value_to_int(@value, 1)
    end

    def to_b
      to_i != 0
    end

    def to_f32
      LibLLVM.generic_value_to_float(LLVM::Float.type, @value)
    end

    def to_f64
      LibLLVM.generic_value_to_float(LLVM::Double.type, @value)
    end

    def to_string
      LibLLVM.generic_value_to_pointer(@value).as(String)
    end
  end

  class JITCompiler
    def initialize(mod)
      if LibLLVM.create_jit_compiler_for_module(out @jit, mod.llvm_module, 3, out error) != 0
        raise String.from_cstr(error)
      end
    end

    def run_function(func)
      ret = LibLLVM.run_function(@jit, func.llvm_function, 0, 0)
      GenericValue.new(ret)
    end
  end

  Void = VoidType.new
  Int1 = IntType.new(1)
  Int8 = IntType.new(8)
  Int16 = IntType.new(16)
  Int32 = IntType.new(32)
  Int64 = IntType.new(64)
  Float = FloatType.new
  Double = DoubleType.new
end
