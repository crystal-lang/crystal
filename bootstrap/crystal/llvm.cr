lib LibLLVM("LLVM-3.3")
  type ContextRef : Void*
  type ModuleRef : Void*
  type TypeRef : Void*
  type ValueRef : Void*
  type BasicBlockRef : Void*
  type BuilderRef : Void*
  type ExecutionEngineRef : Void*
  type GenericValueRef : Void*
  type TargetRef : Void*
  type TargetDataRef : Void*
  type TargetMachineRef : Void*

  enum Attribute
    ZExt       = 1
    SExt       = 2
    NoReturn   = 4
    InReg      = 8
    StructRet  = 16
    NoUnwind   = 32
    NoAlias    = 64
    ByVal      = 128
    Nest       = 256
    # ReadNone   = 1 << 9
    # ReadOnly   = 1 << 10
    # NoInline   = 1 << 11
    # AlwaysInline    = 1 << 12
    # OptimizeForSize = 1 << 13
    # StackProtect    = 1 << 14
    # StackProtectReq = 1 << 15
    # Alignment = 31 << 16
    # NoCapture  = 1 << 21
    # NoRedZone  = 1 << 22
    # NoImplicitFloat = 1 << 23
    # Naked      = 1 << 24
    # InlineHint = 1 << 25
    # StackAlignment = 7 << 26
    # ReturnsTwice = 1 << 29
    # UWTable = 1 << 30
    # NonLazyBind = 1 << 3
    # AddressSafety = 1_u64 << 32,
    # StackProtectStrong = 1_u64 << 33
  end

  enum Linkage
    External
    AvailableExternally
    LinkOnceAny
    LinkOnceODR
    LinkOnceODRAutoHide
    WeakAny
    WeakODR
    Appending
    Internal
    Private
    DLLImport
    DLLExport
    ExternalWeak
    Ghost
    Common
    LinkerPrivate
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

  enum TypeKind
    Void
    Half
    Float
    Double
    X86_FP80
    FP128
    PPC_FP128
    Label
    Integer
    Function
    Struct
    Array
    Pointer
    Vector
    Metadata
    X86_MMX
  end

  enum CodeGenOptLevel
    None
    Less
    Default
    Aggressive
  end

  enum RelocMode
    Default
    Static
    PIC
    DynamicNoPIC
  end

  enum CodeModel
    Default
    JITDefault
    Small
    Kernel
    Medium
    Large
  end

  fun add_attribute = LLVMAddAttribute(arg : ValueRef, attr : Int32)
  fun add_clause = LLVMAddClause(lpad : ValueRef, clause_val : ValueRef)
  fun add_function = LLVMAddFunction(module : ModuleRef, name : Char*, type : TypeRef) : ValueRef
  fun add_function_attr = LLVMAddFunctionAttr(fn : ValueRef, pa : Int32);
  fun add_global = LLVMAddGlobal(module : ModuleRef, type : TypeRef, name : Char*) : ValueRef
  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef *, count : Int32)
  fun append_basic_block = LLVMAppendBasicBlock(fn : ValueRef, name : Char*) : BasicBlockRef
  fun array_type = LLVMArrayType(element_type : TypeRef, count : UInt32) : TypeRef
  fun build_add = LLVMBuildAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(builder : BuilderRef, type : TypeRef, name : Char*) : ValueRef
  fun build_and = LLVMBuildAnd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_array_malloc = LLVMBuildArrayMalloc(builder : BuilderRef, type : TypeRef, val : ValueRef, name : Char*) : ValueRef
  fun build_ashr = LLVMBuildAShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(builder : BuilderRef, value : ValueRef, type : TypeRef, name : Char*) : ValueRef
  fun build_br = LLVMBuildBr(builder : BuilderRef, block : BasicBlockRef) : ValueRef
  fun build_call = LLVMBuildCall(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : Int32, name : Char*) : ValueRef
  fun build_cond = LLVMBuildCondBr(builder : BuilderRef, if : ValueRef, then : BasicBlockRef, else : BasicBlockRef)
  fun build_exact_sdiv = LLVMBuildExactSDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_extract_value = LLVMBuildExtractValue(builder : BuilderRef, agg_val : ValueRef, index : UInt32, name : Char*) : ValueRef
  fun build_fadd = LLVMBuildFAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fcmp = LLVMBuildFCmp(builder : BuilderRef, op : RealPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fdiv = LLVMBuildFDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fmul = LLVMBuildFMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fp2si = LLVMBuildFPToSI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fp2ui = LLVMBuildFPToUI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fpext = LLVMBuildFPExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fptrunc = LLVMBuildFPTrunc(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fsub = LLVMBuildFSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_gep = LLVMBuildGEP(builder : BuilderRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt32, name : Char*) : ValueRef
  fun build_global_string_ptr = LLVMBuildGlobalStringPtr(builder : BuilderRef, str : Char*, name : Char*) : ValueRef
  fun build_icmp = LLVMBuildICmp(builder : BuilderRef, op : IntPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_int2ptr = LLVMBuildIntToPtr(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_invoke = LLVMBuildInvoke(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : UInt32, then : BasicBlockRef, catch : BasicBlockRef, name : Char*) : ValueRef
  fun build_landing_pad = LLVMBuildLandingPad(builder : BuilderRef, ty : TypeRef, pers_fn : ValueRef, num_clauses : UInt32, name : Char*) : ValueRef
  fun build_load = LLVMBuildLoad(builder : BuilderRef, ptr : ValueRef, name : Char*) : ValueRef
  fun build_lshr = LLVMBuildLShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_malloc = LLVMBuildMalloc(builder : BuilderRef, type : TypeRef, name : Char*) : ValueRef
  fun build_mul = LLVMBuildMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_not = LLVMBuildNot(builder : BuilderRef, value : ValueRef, name : Char*) : ValueRef
  fun build_or = LLVMBuildOr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_phi = LLVMBuildPhi(builder : BuilderRef, type : TypeRef, name : Char*) : ValueRef
  fun build_ptr2int = LLVMBuildPtrToInt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ret = LLVMBuildRet(builder : BuilderRef, value : ValueRef) : ValueRef
  fun build_ret_void = LLVMBuildRetVoid(builder : BuilderRef) : ValueRef
  fun build_sdiv = LLVMBuildSDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_select = LLVMBuildSelect(builder : BuilderRef, if_value : ValueRef, then_value : ValueRef, else_value : ValueRef, name : Char*) : ValueRef
  fun build_sext = LLVMBuildSExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_shl = LLVMBuildShl(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_srem = LLVMBuildSRem(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_store = LLVMBuildStore(builder : BuilderRef, value : ValueRef, ptr : ValueRef)
  fun build_sub = LLVMBuildSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_trunc = LLVMBuildTrunc(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_udiv = LLVMBuildUDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_ui2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ui2fp = LLVMBuildUIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_unreachable = LLVMBuildUnreachable(builder : BuilderRef) : ValueRef
  fun build_urem = LLVMBuildURem(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_xor = LLVMBuildXor(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_zext = LLVMBuildZExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun const_array = LLVMConstArray(element_type : TypeRef, constant_vals : ValueRef*, length : UInt32) : ValueRef
  fun const_int = LLVMConstInt(int_type : TypeRef, value : UInt64, sign_extend : Int32) : ValueRef
  fun const_null = LLVMConstNull(ty : TypeRef) : ValueRef
  fun const_pointer_null = LLVMConstPointerNull(ty : TypeRef) : ValueRef
  fun const_real = LLVMConstReal(real_ty : TypeRef, n : Float64) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_type : TypeRef, value : Char*) : ValueRef
  fun const_string = LLVMConstString(str : Char*, length : UInt32, dont_null_terminate : UInt32) : ValueRef
  fun count_param_types = LLVMCountParamTypes(function_type : TypeRef) : UInt32
  fun create_builder = LLVMCreateBuilder() : BuilderRef
  fun create_generic_value_of_int = LLVMCreateGenericValueOfInt(ty : TypeRef, n : UInt64, is_signed : Int32) : GenericValueRef
  fun create_generic_value_of_pointer = LLVMCreateGenericValueOfPointer(p : Void*) : GenericValueRef
  fun create_jit_compiler_for_module = LLVMCreateJITCompilerForModule (jit : ExecutionEngineRef*, m : ModuleRef, opt_level : Int32, error : Char**) : Int32
  fun create_target_machine = LLVMCreateTargetMachine(target : TargetRef, triple : Char*, cpu : Char*, features : Char*, level : CodeGenOptLevel, reloc : RelocMode, code_model : CodeModel) : TargetMachineRef
  fun double_type = LLVMDoubleType() : TypeRef
  fun dump_module = LLVMDumpModule(module : ModuleRef)
  fun dump_value = LLVMDumpValue(val : ValueRef)
  fun float_type = LLVMFloatType() : TypeRef
  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : UInt32, is_var_arg : Int32) : TypeRef
  fun generic_value_to_float = LLVMGenericValueToFloat(type : TypeRef, value : GenericValueRef) : Float64
  fun generic_value_to_int = LLVMGenericValueToInt(value : GenericValueRef, signed : Int32) : Int32
  fun generic_value_to_pointer = LLVMGenericValueToPointer(value : GenericValueRef) : Void*
  fun get_attribute = LLVMGetAttribute(arg : ValueRef) : Attribute
  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun get_first_target = LLVMGetFirstTarget : TargetRef
  fun get_global_context = LLVMGetGlobalContext : ContextRef
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : Char*) : ValueRef
  fun get_named_global = LLVMGetNamedGlobal(mod : ModuleRef, name : Char*) : ValueRef
  fun get_param = LLVMGetParam(fn : ValueRef, index : Int32) : ValueRef
  fun get_param_types = LLVMGetParamTypes(function_type : TypeRef, dest : TypeRef*)
  fun get_return_type = LLVMGetReturnType(function_type : TypeRef) : TypeRef
  fun get_target_name = LLVMGetTargetName(target : TargetRef) : Char*
  fun get_target_description = LLVMGetTargetDescription(target : TargetRef) : Char*
  fun get_target_machine_data = LLVMGetTargetMachineData(t : TargetMachineRef) : TargetDataRef
  fun get_type_kind = LLVMGetTypeKind(ty : TypeRef) : TypeKind
  fun initialize_x86_target = LLVMInitializeX86Target()
  fun initialize_x86_target_info = LLVMInitializeX86TargetInfo()
  fun initialize_x86_target_mc = LLVMInitializeX86TargetMC()
  fun int_type = LLVMIntType(bits : Int32) : TypeRef
  fun is_constant = LLVMIsConstant(val : ValueRef) : Int32
  fun is_function_var_arg = LLVMIsFunctionVarArg(ty : TypeRef) : Int32
  fun module_create_with_name = LLVMModuleCreateWithName(module_id : Char*) : ModuleRef
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt32) : TypeRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun run_function = LLVMRunFunction (ee : ExecutionEngineRef, f : ValueRef, num_args : Int32, args : GenericValueRef*) : GenericValueRef
  fun set_cleanup = LLVMSetCleanup(lpad : ValueRef, val : Int32)
  fun set_global_constant = LLVMSetGlobalConstant(global : ValueRef, is_constant : Int32)
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : Linkage)
  fun set_thread_local = LLVMSetThreadLocal(global_var : ValueRef, is_thread_local : Int32)
  fun set_value_name = LLVMSetValueName(val : ValueRef, name : Char*)
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef
  fun size_of_type_in_bits = LLVMSizeOfTypeInBits(ref : TargetDataRef, ty : TypeRef) : UInt64
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : Char*) : TypeRef
  fun struct_set_body = LLVMStructSetBody(struct_type : TypeRef, element_types : TypeRef*, element_count : UInt32, packed : Int32)
  fun struct_type = LLVMStructType(element_types : TypeRef*, element_count : UInt32, packed : Int32) : TypeRef
  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun void_type = LLVMVoidType() : TypeRef
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : Char*) : Int32
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

  def self.type_kind_of(value)
    LibLLVM.get_type_kind(value)
  end

  def self.size_of(type)
    LibLLVM.size_of(type)
  end

  def self.constant?(value)
    LibLLVM.is_constant(value) != 0
  end

  def self.null(type)
    LibLLVM.const_null(type)
  end

  def self.pointer_null(type)
    LibLLVM.const_pointer_null(type)
  end

  def self.set_name(value, name)
    LibLLVM.set_value_name(value, name)
  end

  def self.add_attribute(value, attribute)
    LibLLVM.add_attribute value, attribute
  end

  def self.get_attribute(value)
    LibLLVM.get_attribute value
  end

  def self.set_thread_local(value, thread_local = true)
    LibLLVM.set_thread_local(value, thread_local ? 1 : 0)
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
      fun_type = LLVM.function_type(arg_types, ret_type, varargs)
      func = LibLLVM.add_function(@mod.llvm_module, name, fun_type)
      Function.new(func)
    end

    def add(name, arg_types, ret_type, varargs = false)
      func = add(name, arg_types, ret_type, varargs)
      yield func
      func
    end

    def [](name)
      self[name]?.not_nil!
    end

    def []?(name)
      func = LibLLVM.get_named_function(@mod.llvm_module, name)
      func ? Function.new(func) : nil
    end
  end

  class Function
    getter :fun

    def initialize(@fun)
    end

    def dump
      LLVM.dump @fun
    end

    def append_basic_block(name)
      LibLLVM.append_basic_block(@fun, name)
    end

    def append_basic_block(name)
      block = append_basic_block(name)
      builder = Builder.new
      builder.position_at_end block
      yield builder
      block
    end

    def dump
      LLVM.dump @fun
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

    def add_attribute(attribute)
      LibLLVM.add_function_attr @fun, attribute
    end

    def function_type
      LibLLVM.get_element_type(LLVM.type_of(@fun))
    end

    def return_type
      LibLLVM.get_return_type(function_type)
    end

    def param_count
      LibLLVM.count_param_types(function_type).to_i
    end

    def params
      Array(LibLLVM::ValueRef).new(param_count) { |i| get_param(i) }
    end

    def param_types
      type = function_type
      param_count = LibLLVM.count_param_types(type)
      param_types = Pointer(LibLLVM::TypeRef).malloc(param_count)
      LibLLVM.get_param_types(type, param_types)
      param_types.to_a(param_count.to_i)
    end

    def varargs?
      LibLLVM.is_function_var_arg(function_type) != 0
    end
  end

  class GlobalCollection
    def initialize(@mod)
    end

    def add(type, name)
      LibLLVM.add_global(@mod.llvm_module, type, name)
    end

    def []?(name)
      global = LibLLVM.get_named_global(@mod.llvm_module, name)
      global ? global : nil
    end

    def [](name)
      global = self[name]?
      if global
        global
      else
        raise "Global not found: #{name}"
      end
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
      phi_node = LibLLVM.build_phi @builder, type, name
      LibLLVM.add_incoming phi_node, incoming_values.buffer, incoming_blocks.buffer, incoming_blocks.length
      phi_node
    end

    def call(func : Function, args = [] of LibLLVM::ValueRef)
      call(func.llvm_function, args)
    end

    def call(func : LibLLVM::ValueRef, args = [] of LibLLVM::ValueRef)
      LibLLVM.build_call(@builder, func, args.buffer, args.length, "")
    end

    def alloca(type, name = "")
      LibLLVM.build_alloca(@builder, type, name)
    end

    def store(value, ptr)
      LibLLVM.build_store(@builder, value, ptr)
    end

    def load(ptr, name = "")
      LibLLVM.build_load(@builder, ptr, name)
    end

    def malloc(type, name = "")
      LibLLVM.build_malloc(@builder, type, name)
    end

    def array_malloc(type, value, name = "")
      LibLLVM.build_array_malloc(@builder, type, value, name)
    end

    def gep(value, indices, name = "")
      LibLLVM.build_gep(@builder, value, indices.buffer, indices.length.to_u32, name)
    end

    def extract_value(value, index, name = "")
      LibLLVM.build_extract_value(@builder, value, index.to_u32, name)
    end

    macro self.define_cast(name)"
      def #{name}(value, type, name = \"\")
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
    define_binary exact_sdiv
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

    def not(value, name = "")
      LibLLVM.build_not(@builder, value, name)
    end

    def unreachable
      LibLLVM.build_unreachable(@builder)
    end

    def select(cond, a_then, a_else, name = "")
      LibLLVM.build_select @builder, cond, a_then, a_else, name
    end

    def global_string_pointer(string, name = "")
      LibLLVM.build_global_string_ptr @builder, string, name
    end

    def landing_pad(type, personality, clauses, name = "")
      lpad = LibLLVM.build_landing_pad @builder, type, personality, clauses.length.to_u32, name
      LibLLVM.set_cleanup lpad, 1
      clauses.each do |clause|
        LibLLVM.add_clause lpad, clause
      end
      lpad
    end

    def invoke(fn, args, a_then, a_catch, name = "")
      LibLLVM.build_invoke @builder, fn.fun, args.buffer, args.length.to_u32, a_then, a_catch, name
    end
  end

  def self.pointer_type(element_type)
    LibLLVM.pointer_type(element_type, 0_u32)
  end

  def self.function_type(arg_types, return_type, varargs = false)
    LibLLVM.function_type(return_type, arg_types.buffer, arg_types.length.to_u32, varargs ? 1 : 0)
  end

  def self.struct_type(name, packed = false)
    struct = LibLLVM.struct_create_named(Context.global, name)
    element_types = yield struct
    LibLLVM.struct_set_body(struct, element_types.buffer, element_types.length.to_u32, packed ? 1 : 0)
    struct
  end

  def self.struct_type(name, element_types, packed = false)
    struct_type(name, packed) { element_types }
  end

  def self.array_type(element_type, count)
    LibLLVM.array_type(element_type, count.to_u32)
  end

  def self.int(type, value)
    LibLLVM.const_int(type, value.to_u64, 0)
  end

  def self.float(value : Float32)
    LibLLVM.const_real(LLVM::Float, value.to_f64)
  end

  def self.float(string : String)
    LibLLVM.const_real_of_string(LLVM::Float, string)
  end

  def self.double(value : Float64)
    LibLLVM.const_real(LLVM::Double, value)
  end

  def self.double(string : String)
    LibLLVM.const_real_of_string(LLVM::Double, string)
  end

  def self.set_linkage(value, linkage)
    LibLLVM.set_linkage(value, linkage)
  end

  def self.set_global_constant(value, flag)
    LibLLVM.set_global_constant(value, flag ? 1 : 0)
  end

  def self.array(type, values)
    LibLLVM.const_array(type, values.buffer, values.length.to_u32)
  end

  def self.set_initializer(value, initializer)
    LibLLVM.set_initializer(value, initializer)
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
      LibLLVM.generic_value_to_float(LLVM::Float, @value)
    end

    def to_f64
      LibLLVM.generic_value_to_float(LLVM::Double, @value)
    end

    def to_string
      to_pointer.as(String)
    end

    def to_pointer
      LibLLVM.generic_value_to_pointer(@value)
    end
  end

  class Target
    def self.first
      Target.new LibLLVM.get_first_target
    end

    def initialize(@target)
    end

    def name
      String.new LibLLVM.get_target_name(@target)
    end

    def description
      String.new LibLLVM.get_target_description(@target)
    end

    def create_target_machine(triple, cpu = "", features = "",
      opt_level = LibLLVM::CodeGenOptLevel::Default,
      reloc = LibLLVM::RelocMode::Default,
      code_model = LibLLVM::CodeModel::Default)
      target_machine = LibLLVM.create_target_machine(@target, triple, cpu, features, opt_level, reloc, code_model)
      target_machine ? TargetMachine.new(target_machine) : nil
    end

    def to_s
      "#{name} - #{description}"
    end
  end

  class TargetMachine
    def initialize(@target_machine)
    end

    def data_layout
      layout = LibLLVM.get_target_machine_data(@target_machine)
      layout ? TargetDataLayout.new(layout) : nil
    end
  end

  class TargetDataLayout
    def initialize(@target_data)
    end

    def size_in_bits(type)
      LibLLVM.size_of_type_in_bits(@target_data, type)
    end

    def size_in_bytes(type)
      size_in_bits(type) / 8
    end
  end

  class JITCompiler
    def initialize(mod)
      if LibLLVM.create_jit_compiler_for_module(out @jit, mod.llvm_module, 3, out error) != 0
        raise String.new(error)
      end
    end

    def run_function(func, args = [] of LibLLVM::GenericValueRef)
      ret = LibLLVM.run_function(@jit, func.llvm_function, args.length, args.buffer)
      GenericValue.new(ret)
    end
  end

  Void = LibLLVM.void_type
  Int1 = LibLLVM.int_type(1)
  Int8 = LibLLVM.int_type(8)
  Int16 = LibLLVM.int_type(16)
  Int32 = LibLLVM.int_type(32)
  Int64 = LibLLVM.int_type(64)
  Float = LibLLVM.float_type
  Double = LibLLVM.double_type
end
