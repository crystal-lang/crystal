lib StdCpp("stdc++")
end

lib LibLLVM("`llvm-config --libs --ldflags`")
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
    ZExt            =  1 << 0
    SExt            =  1 << 1
    NoReturn        =  1 << 2
    InReg           =  1 << 3
    StructRet       =  1 << 4
    NoUnwind        =  1 << 5
    NoAlias         =  1 << 6
    ByVal           =  1 << 7
    Nest            =  1 << 8
    ReadNone        =  1 << 9
    ReadOnly        =  1 << 10
    NoInline        =  1 << 11
    AlwaysInline    =  1 << 12
    OptimizeForSize =  1 << 13
    StackProtect    =  1 << 14
    StackProtectReq =  1 << 15
    Alignment       = 31 << 16
    NoCapture       =  1 << 21
    NoRedZone       =  1 << 22
    NoImplicitFloat =  1 << 23
    Naked           =  1 << 24
    InlineHint      =  1 << 25
    StackAlignment  =  7 << 26
    ReturnsTwice    =  1 << 29
    UWTable         =  1 << 30
    NonLazyBind     =  1 << 31
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

  enum VerifierFailureAction
    AbortProcessAction   # verifier will print to stderr and abort()
    PrintMessageAction   # verifier will print to stderr and return 1
    ReturnStatusAction   # verifier will just return 1
  end

  struct JITCompilerOptions
    opt_level : UInt32
    code_model : CodeModel
    no_frame_pointer_elim : Int32
    enable_fast_isel : Int32
  end

  fun add_attribute = LLVMAddAttribute(arg : ValueRef, attr : Int32)
  fun add_instr_attribute = LLVMAddInstrAttribute(instr : ValueRef, index : UInt32, attr : Attribute)
  fun add_clause = LLVMAddClause(lpad : ValueRef, clause_val : ValueRef)
  fun add_function = LLVMAddFunction(module : ModuleRef, name : UInt8*, type : TypeRef) : ValueRef
  fun add_function_attr = LLVMAddFunctionAttr(fn : ValueRef, pa : Int32);
  fun add_global = LLVMAddGlobal(module : ModuleRef, type : TypeRef, name : UInt8*) : ValueRef
  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef *, count : Int32)
  fun add_named_metadata_operand = LLVMAddNamedMetadataOperand(mod : ModuleRef, name : UInt8*, val : ValueRef)
  fun append_basic_block = LLVMAppendBasicBlock(fn : ValueRef, name : UInt8*) : BasicBlockRef
  fun array_type = LLVMArrayType(element_type : TypeRef, count : UInt32) : TypeRef
  fun build_add = LLVMBuildAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(builder : BuilderRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_and = LLVMBuildAnd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_array_malloc = LLVMBuildArrayMalloc(builder : BuilderRef, type : TypeRef, val : ValueRef, name : UInt8*) : ValueRef
  fun build_ashr = LLVMBuildAShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(builder : BuilderRef, value : ValueRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_br = LLVMBuildBr(builder : BuilderRef, block : BasicBlockRef) : ValueRef
  fun build_call = LLVMBuildCall(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : Int32, name : UInt8*) : ValueRef
  fun build_cond = LLVMBuildCondBr(builder : BuilderRef, if : ValueRef, then : BasicBlockRef, else : BasicBlockRef) : ValueRef
  fun build_exact_sdiv = LLVMBuildExactSDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_extract_value = LLVMBuildExtractValue(builder : BuilderRef, agg_val : ValueRef, index : UInt32, name : UInt8*) : ValueRef
  fun build_fadd = LLVMBuildFAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fcmp = LLVMBuildFCmp(builder : BuilderRef, op : RealPredicate, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fdiv = LLVMBuildFDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fmul = LLVMBuildFMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fp2si = LLVMBuildFPToSI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fp2ui = LLVMBuildFPToUI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fpext = LLVMBuildFPExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fptrunc = LLVMBuildFPTrunc(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fsub = LLVMBuildFSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_gep = LLVMBuildGEP(builder : BuilderRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt32, name : UInt8*) : ValueRef
  fun build_inbounds_gep = LLVMBuildInBoundsGEP(builder : BuilderRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt32, name : UInt8*) : ValueRef
  fun build_global_string_ptr = LLVMBuildGlobalStringPtr(builder : BuilderRef, str : UInt8*, name : UInt8*) : ValueRef
  fun build_icmp = LLVMBuildICmp(builder : BuilderRef, op : IntPredicate, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_int2ptr = LLVMBuildIntToPtr(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_invoke = LLVMBuildInvoke(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : UInt32, then : BasicBlockRef, catch : BasicBlockRef, name : UInt8*) : ValueRef
  fun build_landing_pad = LLVMBuildLandingPad(builder : BuilderRef, ty : TypeRef, pers_fn : ValueRef, num_clauses : UInt32, name : UInt8*) : ValueRef
  fun build_load = LLVMBuildLoad(builder : BuilderRef, ptr : ValueRef, name : UInt8*) : ValueRef
  fun build_lshr = LLVMBuildLShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_malloc = LLVMBuildMalloc(builder : BuilderRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_mul = LLVMBuildMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_not = LLVMBuildNot(builder : BuilderRef, value : ValueRef, name : UInt8*) : ValueRef
  fun build_or = LLVMBuildOr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_phi = LLVMBuildPhi(builder : BuilderRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_ptr2int = LLVMBuildPtrToInt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_ret = LLVMBuildRet(builder : BuilderRef, value : ValueRef) : ValueRef
  fun build_ret_void = LLVMBuildRetVoid(builder : BuilderRef) : ValueRef
  fun build_sdiv = LLVMBuildSDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_select = LLVMBuildSelect(builder : BuilderRef, if_value : ValueRef, then_value : ValueRef, else_value : ValueRef, name : UInt8*) : ValueRef
  fun build_sext = LLVMBuildSExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_shl = LLVMBuildShl(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_srem = LLVMBuildSRem(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_store = LLVMBuildStore(builder : BuilderRef, value : ValueRef, ptr : ValueRef) : ValueRef
  fun build_sub = LLVMBuildSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_trunc = LLVMBuildTrunc(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_udiv = LLVMBuildUDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_ui2fp = LLVMBuildSIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_ui2fp = LLVMBuildUIToFP(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_unreachable = LLVMBuildUnreachable(builder : BuilderRef) : ValueRef
  fun build_urem = LLVMBuildURem(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_xor = LLVMBuildXor(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_zext = LLVMBuildZExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun const_array = LLVMConstArray(element_type : TypeRef, constant_vals : ValueRef*, length : UInt32) : ValueRef
  fun const_int = LLVMConstInt(int_type : TypeRef, value : UInt64, sign_extend : Int32) : ValueRef
  fun const_null = LLVMConstNull(ty : TypeRef) : ValueRef
  fun const_pointer_null = LLVMConstPointerNull(ty : TypeRef) : ValueRef
  fun const_real = LLVMConstReal(real_ty : TypeRef, n : Float64) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_type : TypeRef, value : UInt8*) : ValueRef
  fun const_string = LLVMConstString(str : UInt8*, length : UInt32, dont_null_terminate : Int32) : ValueRef
  fun const_struct = LLVMConstStruct(contant_vals : ValueRef*, count : UInt32, packed : Int32) : ValueRef
  fun count_param_types = LLVMCountParamTypes(function_type : TypeRef) : UInt32
  fun create_builder = LLVMCreateBuilder : BuilderRef
  fun create_generic_value_of_int = LLVMCreateGenericValueOfInt(ty : TypeRef, n : UInt64, is_signed : Int32) : GenericValueRef
  fun create_generic_value_of_pointer = LLVMCreateGenericValueOfPointer(p : Void*) : GenericValueRef
  fun create_jit_compiler_for_module = LLVMCreateJITCompilerForModule (jit : ExecutionEngineRef*, m : ModuleRef, opt_level : Int32, error : UInt8**) : Int32
  fun create_mc_jit_compiler_for_module = LLVMCreateMCJITCompilerForModule(jit : ExecutionEngineRef*, m : ModuleRef, options : JITCompilerOptions*, options_length : UInt32, error : UInt8**) : Int32
  fun create_target_machine = LLVMCreateTargetMachine(target : TargetRef, triple : UInt8*, cpu : UInt8*, features : UInt8*, level : CodeGenOptLevel, reloc : RelocMode, code_model : CodeModel) : TargetMachineRef
  fun delete_basic_block = LLVMDeleteBasicBlock(block : BasicBlockRef)
  fun double_type = LLVMDoubleType : TypeRef
  fun dump_module = LLVMDumpModule(module : ModuleRef)
  fun dump_value = LLVMDumpValue(val : ValueRef)
  fun float_type = LLVMFloatType : TypeRef
  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : UInt32, is_var_arg : Int32) : TypeRef
  fun generic_value_to_float = LLVMGenericValueToFloat(type : TypeRef, value : GenericValueRef) : Float64
  fun generic_value_to_int = LLVMGenericValueToInt(value : GenericValueRef, signed : Int32) : Int32
  fun generic_value_to_pointer = LLVMGenericValueToPointer(value : GenericValueRef) : Void*
  fun get_attribute = LLVMGetAttribute(arg : ValueRef) : Attribute
  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun get_first_instruction = LLVMGetFirstInstruction(block : BasicBlockRef) : ValueRef
  fun get_first_target = LLVMGetFirstTarget : TargetRef
  fun get_global_context = LLVMGetGlobalContext : ContextRef
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_named_global = LLVMGetNamedGlobal(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_param = LLVMGetParam(fn : ValueRef, index : Int32) : ValueRef
  fun get_param_types = LLVMGetParamTypes(function_type : TypeRef, dest : TypeRef*)
  fun get_pointer_to_global = LLVMGetPointerToGlobal(ee : ExecutionEngineRef, global : ValueRef) : Void*
  fun get_return_type = LLVMGetReturnType(function_type : TypeRef) : TypeRef
  fun get_target_name = LLVMGetTargetName(target : TargetRef) : UInt8*
  fun get_target_description = LLVMGetTargetDescription(target : TargetRef) : UInt8*
  fun get_target_machine_data = LLVMGetTargetMachineData(t : TargetMachineRef) : TargetDataRef
  fun get_type_kind = LLVMGetTypeKind(ty : TypeRef) : TypeKind
  fun get_undef = LLVMGetUndef(ty : TypeRef) : ValueRef
  fun get_value_name = LLVMGetValueName(value : ValueRef) : UInt8*
  fun initialize_x86_asm_printer = LLVMInitializeX86AsmPrinter
  fun initialize_x86_target = LLVMInitializeX86Target
  fun initialize_x86_target_info = LLVMInitializeX86TargetInfo
  fun initialize_x86_target_mc = LLVMInitializeX86TargetMC
  fun initialize_native_target = LLVMInitializeNativeTarget
  fun int_type = LLVMIntType(bits : Int32) : TypeRef
  fun is_constant = LLVMIsConstant(val : ValueRef) : Int32
  fun is_function_var_arg = LLVMIsFunctionVarArg(ty : TypeRef) : Int32
  fun md_node = LLVMMDNode(values : ValueRef*, count : Int32) : ValueRef
  fun md_string = LLVMMDString(str : UInt8*, length : Int32) : ValueRef
  fun module_create_with_name = LLVMModuleCreateWithName(module_id : UInt8*) : ModuleRef
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt32) : TypeRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun run_function = LLVMRunFunction (ee : ExecutionEngineRef, f : ValueRef, num_args : Int32, args : GenericValueRef*) : GenericValueRef
  fun set_cleanup = LLVMSetCleanup(lpad : ValueRef, val : Int32)
  fun set_data_layout = LLVMSetDataLayout(mod : ModuleRef, data : UInt8*)
  fun set_global_constant = LLVMSetGlobalConstant(global : ValueRef, is_constant : Int32)
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : Linkage)
  fun set_metadata = LLVMSetMetadata(value : ValueRef, kind_id : UInt32, node : ValueRef)
  fun set_target = LLVMSetTarget(mod : ModuleRef, triple : UInt8*)
  fun set_thread_local = LLVMSetThreadLocal(global_var : ValueRef, is_thread_local : Int32)
  fun set_value_name = LLVMSetValueName(val : ValueRef, name : UInt8*)
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef
  fun size_of_type_in_bits = LLVMSizeOfTypeInBits(ref : TargetDataRef, ty : TypeRef) : UInt64
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : UInt8*) : TypeRef
  fun struct_set_body = LLVMStructSetBody(struct_type : TypeRef, element_types : TypeRef*, element_count : UInt32, packed : Int32)
  fun struct_type = LLVMStructType(element_types : TypeRef*, element_count : UInt32, packed : Int32) : TypeRef
  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun void_type = LLVMVoidType : TypeRef
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : UInt8*) : Int32
  fun verify_module = LLVMVerifyModule(module : ModuleRef, action : VerifierFailureAction, outmessage : UInt8**) : Int32
  fun link_in_jit = LLVMLinkInJIT
  fun link_in_mc_jit = LLVMLinkInMCJIT
  fun start_multithreaded = LLVMStartMultithreaded : Int32
  fun stop_multithreaded = LLVMStopMultithreaded
  fun is_multithreaded = LLVMIsMultithreaded : Int32
  fun get_md_kind_id = LLVMGetMDKindID(name : UInt8*, slen : UInt32) : UInt32
end
