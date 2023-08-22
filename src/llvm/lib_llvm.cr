{% begin %}
lib LibLLVM
  LLVM_CONFIG = {{ env("LLVM_CONFIG") || `#{__DIR__}/ext/find-llvm-config`.stringify }}
end
{% end %}

{% begin %}
  {% unless flag?(:win32) %}
    @[Link("stdc++")]
  {% end %}
  @[Link(ldflags: {{"`#{LibLLVM::LLVM_CONFIG} --libs --system-libs --ldflags#{" --link-static".id if flag?(:static)}#{" 2> /dev/null".id unless flag?(:win32)}`"}})]
  lib LibLLVM
    VERSION = {{`#{LibLLVM::LLVM_CONFIG} --version`.chomp.stringify.gsub(/git/, "")}}
    BUILT_TARGETS = {{ (
                         env("LLVM_TARGETS") || `#{LibLLVM::LLVM_CONFIG} --targets-built`
                       ).strip.downcase.split(' ').map(&.id.symbolize) }}
  end
{% end %}

{% begin %}
  lib LibLLVM
    IS_170 = {{LibLLVM::VERSION.starts_with?("17.0")}}
    IS_160 = {{LibLLVM::VERSION.starts_with?("16.0")}}
    IS_150 = {{LibLLVM::VERSION.starts_with?("15.0")}}
    IS_140 = {{LibLLVM::VERSION.starts_with?("14.0")}}
    IS_130 = {{LibLLVM::VERSION.starts_with?("13.0")}}
    IS_120 = {{LibLLVM::VERSION.starts_with?("12.0")}}
    IS_111 = {{LibLLVM::VERSION.starts_with?("11.1")}}
    IS_110 = {{LibLLVM::VERSION.starts_with?("11.0")}}
    IS_100 = {{LibLLVM::VERSION.starts_with?("10.0")}}
    IS_90 = {{LibLLVM::VERSION.starts_with?("9.0")}}
    IS_80 = {{LibLLVM::VERSION.starts_with?("8.0")}}

    IS_LT_90 = {{compare_versions(LibLLVM::VERSION, "9.0.0") < 0}}
    IS_LT_100 = {{compare_versions(LibLLVM::VERSION, "10.0.0") < 0}}
    IS_LT_110 = {{compare_versions(LibLLVM::VERSION, "11.0.0") < 0}}
    IS_LT_120 = {{compare_versions(LibLLVM::VERSION, "12.0.0") < 0}}
    IS_LT_130 = {{compare_versions(LibLLVM::VERSION, "13.0.0") < 0}}
    IS_LT_140 = {{compare_versions(LibLLVM::VERSION, "14.0.0") < 0}}
    IS_LT_150 = {{compare_versions(LibLLVM::VERSION, "15.0.0") < 0}}
    IS_LT_160 = {{compare_versions(LibLLVM::VERSION, "16.0.0") < 0}}
    IS_LT_170 = {{compare_versions(LibLLVM::VERSION, "17.0.0") < 0}}
  end
{% end %}

lib LibLLVM
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias SizeT = LibC::SizeT

  type ContextRef = Void*
  type ModuleRef = Void*
  type MetadataRef = Void*
  type TypeRef = Void*
  type ValueRef = Void*
  type BasicBlockRef = Void*
  type BuilderRef = Void*
  type ExecutionEngineRef = Void*
  type GenericValueRef = Void*
  type TargetRef = Void*
  type TargetDataRef = Void*
  type TargetMachineRef = Void*
  type MemoryBufferRef = Void*
  type PassBuilderOptionsRef = Void*
  type ErrorRef = Void*
  type DIBuilderRef = Void*

  struct JITCompilerOptions
    opt_level : UInt32
    code_model : LLVM::CodeModel
    no_frame_pointer_elim : Int32
    enable_fast_isel : Int32
  end

  enum InlineAsmDialect
    ATT
    Intel
  end

  # NOTE: the following C enums usually have different values from their C++
  # counterparts (e.g. `LLVMModuleFlagBehavior` v.s. `LLVM::Module::ModFlagBehavior`)

  enum ModuleFlagBehavior
    Warning = 1
  end

  enum DWARFEmissionKind
    Full = 1
  end

  fun add_case = LLVMAddCase(switch : ValueRef, onval : ValueRef, dest : BasicBlockRef)
  fun add_clause = LLVMAddClause(lpad : ValueRef, clause_val : ValueRef)
  fun add_function = LLVMAddFunction(module : ModuleRef, name : UInt8*, type : TypeRef) : ValueRef
  fun add_global = LLVMAddGlobal(module : ModuleRef, type : TypeRef, name : UInt8*) : ValueRef
  fun add_handler = LLVMAddHandler(catch_switch : ValueRef, dest : BasicBlockRef)
  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef*, count : Int32)
  fun add_module_flag = LLVMAddModuleFlag(mod : ModuleRef, behavior : ModuleFlagBehavior, key : UInt8*, len : LibC::SizeT, val : MetadataRef)
  fun add_target_dependent_function_attr = LLVMAddTargetDependentFunctionAttr(fn : ValueRef, a : LibC::Char*, v : LibC::Char*)
  fun array_type = LLVMArrayType(element_type : TypeRef, count : UInt32) : TypeRef
  fun vector_type = LLVMVectorType(element_type : TypeRef, count : UInt32) : TypeRef
  fun build_va_arg = LLVMBuildVAArg(builder : BuilderRef, list : ValueRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_add = LLVMBuildAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(builder : BuilderRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_and = LLVMBuildAnd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_array_malloc = LLVMBuildArrayMalloc(builder : BuilderRef, type : TypeRef, val : ValueRef, name : UInt8*) : ValueRef
  fun build_ashr = LLVMBuildAShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_atomicrmw = LLVMBuildAtomicRMW(builder : BuilderRef, op : LLVM::AtomicRMWBinOp, ptr : ValueRef, val : ValueRef, ordering : LLVM::AtomicOrdering, singlethread : Int32) : ValueRef
  fun build_atomic_cmp_xchg = LLVMBuildAtomicCmpXchg(builder : BuilderRef, ptr : ValueRef, cmp : ValueRef, new : ValueRef, success_ordering : LLVM::AtomicOrdering, failure_ordering : LLVM::AtomicOrdering, single_thread : Int) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(builder : BuilderRef, value : ValueRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_br = LLVMBuildBr(builder : BuilderRef, block : BasicBlockRef) : ValueRef
  fun build_call2 = LLVMBuildCall2(builder : BuilderRef, type : TypeRef, fn : ValueRef, args : ValueRef*, num_args : Int32, name : UInt8*) : ValueRef
  fun build_catch_pad = LLVMBuildCatchPad(b : BuilderRef, parent_pad : ValueRef, args : ValueRef*, num_args : UInt, name : Char*) : ValueRef
  fun build_catch_ret = LLVMBuildCatchRet(b : BuilderRef, catch_pad : ValueRef, bb : BasicBlockRef) : ValueRef
  fun build_catch_switch = LLVMBuildCatchSwitch(b : BuilderRef, parent_pad : ValueRef, unwind_bb : BasicBlockRef, num_handlers : UInt, name : Char*) : ValueRef
  fun build_cond = LLVMBuildCondBr(builder : BuilderRef, if : ValueRef, then : BasicBlockRef, else : BasicBlockRef) : ValueRef
  fun build_exact_sdiv = LLVMBuildExactSDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_extract_value = LLVMBuildExtractValue(builder : BuilderRef, agg_val : ValueRef, index : UInt32, name : UInt8*) : ValueRef
  fun build_fadd = LLVMBuildFAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fcmp = LLVMBuildFCmp(builder : BuilderRef, op : LLVM::RealPredicate, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fdiv = LLVMBuildFDiv(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fence = LLVMBuildFence(builder : BuilderRef, ordering : LLVM::AtomicOrdering, singlethread : UInt32, name : UInt8*) : ValueRef
  fun build_fmul = LLVMBuildFMul(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_fp2si = LLVMBuildFPToSI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fp2ui = LLVMBuildFPToUI(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fpext = LLVMBuildFPExt(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fptrunc = LLVMBuildFPTrunc(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_fsub = LLVMBuildFSub(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_gep2 = LLVMBuildGEP2(builder : BuilderRef, ty : TypeRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt32, name : UInt8*) : ValueRef
  fun build_inbounds_gep2 = LLVMBuildInBoundsGEP2(builder : BuilderRef, ty : TypeRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt32, name : UInt8*) : ValueRef
  fun build_global_string_ptr = LLVMBuildGlobalStringPtr(builder : BuilderRef, str : UInt8*, name : UInt8*) : ValueRef
  fun build_icmp = LLVMBuildICmp(builder : BuilderRef, op : LLVM::IntPredicate, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_int2ptr = LLVMBuildIntToPtr(builder : BuilderRef, val : ValueRef, dest_ty : TypeRef, name : UInt8*) : ValueRef
  fun build_invoke2 = LLVMBuildInvoke2(builder : BuilderRef, ty : TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt32, then : BasicBlockRef, catch : BasicBlockRef, name : UInt8*) : ValueRef
  fun build_landing_pad = LLVMBuildLandingPad(builder : BuilderRef, ty : TypeRef, pers_fn : ValueRef, num_clauses : UInt32, name : UInt8*) : ValueRef
  fun build_load2 = LLVMBuildLoad2(builder : BuilderRef, ty : TypeRef, ptr : ValueRef, name : UInt8*) : ValueRef
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
  fun build_switch = LLVMBuildSwitch(builder : BuilderRef, value : ValueRef, otherwise : BasicBlockRef, num_cases : UInt32) : ValueRef
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
  fun const_int_of_arbitrary_precision = LLVMConstIntOfArbitraryPrecision(int_type : TypeRef, num_words : UInt32, words : UInt64*) : ValueRef
  fun const_null = LLVMConstNull(ty : TypeRef) : ValueRef
  fun const_pointer_null = LLVMConstPointerNull(ty : TypeRef) : ValueRef
  fun const_real = LLVMConstReal(real_ty : TypeRef, n : Float64) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_type : TypeRef, value : UInt8*) : ValueRef
  fun count_param_types = LLVMCountParamTypes(function_type : TypeRef) : UInt32
  fun create_generic_value_of_int = LLVMCreateGenericValueOfInt(ty : TypeRef, n : UInt64, is_signed : Int32) : GenericValueRef
  fun create_generic_value_of_pointer = LLVMCreateGenericValueOfPointer(p : Void*) : GenericValueRef
  fun create_jit_compiler_for_module = LLVMCreateJITCompilerForModule(jit : ExecutionEngineRef*, m : ModuleRef, opt_level : Int32, error : UInt8**) : Int32
  fun create_mc_jit_compiler_for_module = LLVMCreateMCJITCompilerForModule(jit : ExecutionEngineRef*, m : ModuleRef, options : JITCompilerOptions*, options_length : UInt32, error : UInt8**) : Int32
  fun create_target_machine = LLVMCreateTargetMachine(target : TargetRef, triple : UInt8*, cpu : UInt8*, features : UInt8*, level : LLVM::CodeGenOptLevel, reloc : LLVM::RelocMode, code_model : LLVM::CodeModel) : TargetMachineRef
  {% unless LibLLVM::IS_LT_120 %}
    fun create_type_attribute = LLVMCreateTypeAttribute(ctx : ContextRef, kind_id : UInt, ty : TypeRef) : AttributeRef
  {% end %}
  fun delete_basic_block = LLVMDeleteBasicBlock(block : BasicBlockRef)
  fun delete_function = LLVMDeleteFunction(fn : ValueRef)
  fun dispose_message = LLVMDisposeMessage(msg : UInt8*)
  fun dump_module = LLVMDumpModule(module : ModuleRef)
  fun dump_value = LLVMDumpValue(val : ValueRef)
  fun target_machine_emit_to_file = LLVMTargetMachineEmitToFile(t : TargetMachineRef, m : ModuleRef, filename : UInt8*, codegen : LLVM::CodeGenFileType, error_msg : UInt8**) : Int32
  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : UInt32, is_var_arg : Int32) : TypeRef
  fun generic_value_to_float = LLVMGenericValueToFloat(type : TypeRef, value : GenericValueRef) : Float64
  fun generic_value_to_int = LLVMGenericValueToInt(value : GenericValueRef, signed : Int32) : UInt64
  fun generic_value_to_pointer = LLVMGenericValueToPointer(value : GenericValueRef) : Void*
  fun get_basic_block_name = LLVMGetBasicBlockName(basic_block : BasicBlockRef) : Char*
  fun get_current_debug_location = LLVMGetCurrentDebugLocation(builder : BuilderRef) : ValueRef
  {% unless LibLLVM::IS_LT_90 %}
    fun get_current_debug_location2 = LLVMGetCurrentDebugLocation2(builder : BuilderRef) : MetadataRef
  {% end %}
  fun get_first_instruction = LLVMGetFirstInstruction(block : BasicBlockRef) : ValueRef
  fun get_first_target = LLVMGetFirstTarget : TargetRef
  fun get_first_basic_block = LLVMGetFirstBasicBlock(fn : ValueRef) : BasicBlockRef
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_named_global = LLVMGetNamedGlobal(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_count_params = LLVMCountParams(fn : ValueRef) : UInt
  fun get_host_cpu_name = LLVMGetHostCPUName : UInt8*
  fun get_param = LLVMGetParam(fn : ValueRef, index : Int32) : ValueRef
  fun get_param_types = LLVMGetParamTypes(function_type : TypeRef, dest : TypeRef*)
  fun get_params = LLVMGetParams(fn : ValueRef, params : ValueRef*)
  fun get_pointer_to_global = LLVMGetPointerToGlobal(ee : ExecutionEngineRef, global : ValueRef) : Void*
  fun get_return_type = LLVMGetReturnType(function_type : TypeRef) : TypeRef
  fun get_target_name = LLVMGetTargetName(target : TargetRef) : UInt8*
  fun get_target_description = LLVMGetTargetDescription(target : TargetRef) : UInt8*
  fun get_target_machine_triple = LLVMGetTargetMachineTriple(t : TargetMachineRef) : UInt8*
  fun get_target_from_triple = LLVMGetTargetFromTriple(triple : UInt8*, target : TargetRef*, error_message : UInt8**) : Int32
  fun normalize_target_triple = LLVMNormalizeTargetTriple(triple : Char*) : Char*
  fun get_type_kind = LLVMGetTypeKind(ty : TypeRef) : LLVM::Type::Kind
  fun get_undef = LLVMGetUndef(ty : TypeRef) : ValueRef
  fun get_value_name = LLVMGetValueName(value : ValueRef) : UInt8*
  fun get_value_kind = LLVMGetValueKind(value : ValueRef) : LLVM::Value::Kind
  fun initialize_x86_asm_printer = LLVMInitializeX86AsmPrinter
  fun initialize_x86_asm_parser = LLVMInitializeX86AsmParser
  fun initialize_x86_target = LLVMInitializeX86Target
  fun initialize_x86_target_info = LLVMInitializeX86TargetInfo
  fun initialize_x86_target_mc = LLVMInitializeX86TargetMC
  fun initialize_aarch64_asm_printer = LLVMInitializeAArch64AsmPrinter
  fun initialize_aarch64_asm_parser = LLVMInitializeAArch64AsmParser
  fun initialize_aarch64_target = LLVMInitializeAArch64Target
  fun initialize_aarch64_target_info = LLVMInitializeAArch64TargetInfo
  fun initialize_aarch64_target_mc = LLVMInitializeAArch64TargetMC
  fun initialize_arm_asm_printer = LLVMInitializeARMAsmPrinter
  fun initialize_arm_asm_parser = LLVMInitializeARMAsmParser
  fun initialize_arm_target = LLVMInitializeARMTarget
  fun initialize_arm_target_info = LLVMInitializeARMTargetInfo
  fun initialize_arm_target_mc = LLVMInitializeARMTargetMC
  fun initialize_webassembly_asm_printer = LLVMInitializeWebAssemblyAsmPrinter
  fun initialize_webassembly_asm_parser = LLVMInitializeWebAssemblyAsmParser
  fun initialize_webassembly_target = LLVMInitializeWebAssemblyTarget
  fun initialize_webassembly_target_info = LLVMInitializeWebAssemblyTargetInfo
  fun initialize_webassembly_target_mc = LLVMInitializeWebAssemblyTargetMC
  fun is_constant = LLVMIsConstant(val : ValueRef) : Int32
  fun is_function_var_arg = LLVMIsFunctionVarArg(ty : TypeRef) : Int32
  fun module_create_with_name_in_context = LLVMModuleCreateWithNameInContext(module_id : UInt8*, context : ContextRef) : ModuleRef
  fun offset_of_element = LLVMOffsetOfElement(td : TargetDataRef, struct_type : TypeRef, element : LibC::UInt) : UInt64
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt32) : TypeRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun print_module_to_file = LLVMPrintModuleToFile(m : ModuleRef, filename : UInt8*, error_msg : UInt8**) : Int32
  fun run_function = LLVMRunFunction(ee : ExecutionEngineRef, f : ValueRef, num_args : Int32, args : GenericValueRef*) : GenericValueRef
  fun set_cleanup = LLVMSetCleanup(lpad : ValueRef, val : Int32)
  fun set_global_constant = LLVMSetGlobalConstant(global : ValueRef, is_constant : Int32)
  fun is_global_constant = LLVMIsGlobalConstant(global : ValueRef) : Int32
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun get_initializer = LLVMGetInitializer(global_var : ValueRef) : ValueRef
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : LLVM::Linkage)
  fun get_linkage = LLVMGetLinkage(global : ValueRef) : LLVM::Linkage
  fun set_dll_storage_class = LLVMSetDLLStorageClass(global : ValueRef, storage_class : LLVM::DLLStorageClass)
  fun set_metadata = LLVMSetMetadata(value : ValueRef, kind_id : UInt32, node : ValueRef)
  fun set_target = LLVMSetTarget(mod : ModuleRef, triple : UInt8*)
  fun set_thread_local = LLVMSetThreadLocal(global_var : ValueRef, is_thread_local : Int32)
  fun is_thread_local = LLVMIsThreadLocal(global_var : ValueRef) : Int32
  fun set_value_name = LLVMSetValueName(val : ValueRef, name : UInt8*)
  fun set_personality_fn = LLVMSetPersonalityFn(fn : ValueRef, personality_fn : ValueRef)
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef
  fun size_of_type_in_bits = LLVMSizeOfTypeInBits(ref : TargetDataRef, ty : TypeRef) : UInt64
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : UInt8*) : TypeRef
  fun struct_set_body = LLVMStructSetBody(struct_type : TypeRef, element_types : TypeRef*, element_count : UInt32, packed : Int32)
  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : UInt8*) : Int32
  fun verify_module = LLVMVerifyModule(module : ModuleRef, action : LLVM::VerifierFailureAction, outmessage : UInt8**) : Int32
  fun link_in_mc_jit = LLVMLinkInMCJIT
  fun start_multithreaded = LLVMStartMultithreaded : Int32
  fun stop_multithreaded = LLVMStopMultithreaded
  fun is_multithreaded = LLVMIsMultithreaded : Int32
  fun get_first_function = LLVMGetFirstFunction(m : ModuleRef) : ValueRef
  fun get_next_function = LLVMGetNextFunction(f : ValueRef) : ValueRef
  fun get_next_basic_block = LLVMGetNextBasicBlock(bb : BasicBlockRef) : BasicBlockRef
  fun get_next_instruction = LLVMGetNextInstruction(inst : ValueRef) : ValueRef
  fun get_next_target = LLVMGetNextTarget(t : TargetRef) : TargetRef
  fun get_default_target_triple = LLVMGetDefaultTargetTriple : UInt8*
  fun print_module_to_string = LLVMPrintModuleToString(mod : ModuleRef) : UInt8*
  fun print_type_to_string = LLVMPrintTypeToString(ty : TypeRef) : UInt8*
  fun print_value_to_string = LLVMPrintValueToString(v : ValueRef) : UInt8*
  fun get_function_call_convention = LLVMGetFunctionCallConv(fn : ValueRef) : LLVM::CallConvention
  fun set_function_call_convention = LLVMSetFunctionCallConv(fn : ValueRef, cc : LLVM::CallConvention)
  fun set_instruction_call_convention = LLVMSetInstructionCallConv(instr : ValueRef, cc : LLVM::CallConvention)
  fun get_instruction_call_convention = LLVMGetInstructionCallConv(instr : ValueRef) : LLVM::CallConvention
  fun set_ordering = LLVMSetOrdering(memory_access_inst : ValueRef, ordering : LLVM::AtomicOrdering)
  fun get_int_type_width = LLVMGetIntTypeWidth(ty : TypeRef) : UInt32
  fun is_packed_struct = LLVMIsPackedStruct(ty : TypeRef) : Int32
  fun get_struct_name = LLVMGetStructName(ty : TypeRef) : UInt8*
  fun get_struct_element_types = LLVMGetStructElementTypes(ty : TypeRef, dest : TypeRef*)
  fun count_struct_element_types = LLVMCountStructElementTypes(ty : TypeRef) : UInt32
  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun get_array_length = LLVMGetArrayLength(ty : TypeRef) : UInt32
  fun get_vector_size = LLVMGetVectorSize(ty : TypeRef) : UInt32
  fun abi_size_of_type = LLVMABISizeOfType(td : TargetDataRef, ty : TypeRef) : UInt64
  fun abi_alignment_of_type = LLVMABIAlignmentOfType(td : TargetDataRef, ty : TypeRef) : UInt32
  fun get_target_machine_target = LLVMGetTargetMachineTarget(t : TargetMachineRef) : TargetRef
  {% if !LibLLVM::IS_LT_130 %}
    fun get_inline_asm = LLVMGetInlineAsm(t : TypeRef, asm_string : UInt8*, asm_string_len : LibC::SizeT, constraints : UInt8*, constraints_len : LibC::SizeT, has_side_effects : Int32, is_align_stack : Int32, dialect : InlineAsmDialect, can_throw : Int32) : ValueRef
  {% else %}
    fun get_inline_asm = LLVMGetInlineAsm(t : TypeRef, asm_string : UInt8*, asm_string_len : LibC::SizeT, constraints : UInt8*, constraints_len : LibC::SizeT, has_side_effects : Int32, is_align_stack : Int32, dialect : InlineAsmDialect) : ValueRef
  {% end %}
  fun create_context = LLVMContextCreate : ContextRef
  fun dispose_builder = LLVMDisposeBuilder(BuilderRef)
  fun dispose_target_machine = LLVMDisposeTargetMachine(TargetMachineRef)
  fun dispose_generic_value = LLVMDisposeGenericValue(GenericValueRef)
  fun dispose_execution_engine = LLVMDisposeExecutionEngine(ExecutionEngineRef)
  fun dispose_context = LLVMContextDispose(ContextRef)
  fun dispose_target_data = LLVMDisposeTargetData(TargetDataRef)
  fun set_volatile = LLVMSetVolatile(value : ValueRef, volatile : UInt32)
  fun set_alignment = LLVMSetAlignment(value : ValueRef, bytes : UInt32)
  fun get_return_type = LLVMGetReturnType(TypeRef) : TypeRef

  fun write_bitcode_to_memory_buffer = LLVMWriteBitcodeToMemoryBuffer(mod : ModuleRef) : MemoryBufferRef

  fun dispose_memory_buffer = LLVMDisposeMemoryBuffer(buf : MemoryBufferRef) : Void
  fun get_buffer_start = LLVMGetBufferStart(buf : MemoryBufferRef) : UInt8*
  fun get_buffer_size = LLVMGetBufferSize(buf : MemoryBufferRef) : LibC::SizeT

  fun write_bitcode_to_fd = LLVMWriteBitcodeToFD(mod : ModuleRef, fd : LibC::Int, should_close : LibC::Int, unbuffered : LibC::Int) : LibC::Int

  fun create_target_data_layout = LLVMCreateTargetDataLayout(t : TargetMachineRef) : TargetDataRef
  fun set_module_data_layout = LLVMSetModuleDataLayout(mod : ModuleRef, data : TargetDataRef)

  type AttributeRef = Void*
  alias AttributeIndex = UInt

  fun get_last_enum_attribute_kind = LLVMGetLastEnumAttributeKind : UInt
  fun get_enum_attribute_kind_for_name = LLVMGetEnumAttributeKindForName(name : Char*, s_len : LibC::SizeT) : UInt
  fun create_enum_attribute = LLVMCreateEnumAttribute(c : ContextRef, kind_id : UInt, val : UInt64) : AttributeRef
  fun add_attribute_at_index = LLVMAddAttributeAtIndex(f : ValueRef, idx : AttributeIndex, a : AttributeRef)
  fun get_enum_attribute_at_index = LLVMGetEnumAttributeAtIndex(f : ValueRef, idx : AttributeIndex, kind_id : UInt) : AttributeRef
  fun add_call_site_attribute = LLVMAddCallSiteAttribute(f : ValueRef, idx : AttributeIndex, value : AttributeRef)

  fun get_module_identifier = LLVMGetModuleIdentifier(m : ModuleRef, len : LibC::SizeT*) : UInt8*
  fun set_module_identifier = LLVMSetModuleIdentifier(m : ModuleRef, ident : UInt8*, len : LibC::SizeT)

  fun get_module_context = LLVMGetModuleContext(m : ModuleRef) : ContextRef
  fun get_global_parent = LLVMGetGlobalParent(global : ValueRef) : ModuleRef

  fun create_memory_buffer_with_contents_of_file = LLVMCreateMemoryBufferWithContentsOfFile(path : UInt8*, out_mem_buf : MemoryBufferRef*, out_message : UInt8**) : Int32
  fun parse_ir_in_context = LLVMParseIRInContext(context : ContextRef, mem_buf : MemoryBufferRef, out_m : ModuleRef*, out_message : UInt8**) : Int32
  fun context_dispose = LLVMContextDispose(ContextRef)

  fun void_type_in_context = LLVMVoidTypeInContext(ContextRef) : TypeRef
  fun int1_type_in_context = LLVMInt1TypeInContext(ContextRef) : TypeRef
  fun int8_type_in_context = LLVMInt8TypeInContext(ContextRef) : TypeRef
  fun int16_type_in_context = LLVMInt16TypeInContext(ContextRef) : TypeRef
  fun int32_type_in_context = LLVMInt32TypeInContext(ContextRef) : TypeRef
  fun int64_type_in_context = LLVMInt64TypeInContext(ContextRef) : TypeRef
  fun int128_type_in_context = LLVMInt128TypeInContext(ContextRef) : TypeRef
  fun int_type_in_context = LLVMIntTypeInContext(ContextRef, num_bits : UInt) : TypeRef
  fun float_type_in_context = LLVMFloatTypeInContext(ContextRef) : TypeRef
  fun double_type_in_context = LLVMDoubleTypeInContext(ContextRef) : TypeRef
  fun struct_type_in_context = LLVMStructTypeInContext(c : ContextRef, element_types : TypeRef*, element_count : UInt32, packed : Int32) : TypeRef
  {% unless LibLLVM::IS_LT_150 %}
    fun pointer_type_in_context = LLVMPointerTypeInContext(ContextRef, address_space : UInt) : TypeRef
  {% end %}

  fun const_string_in_context = LLVMConstStringInContext(c : ContextRef, str : UInt8*, length : UInt32, dont_null_terminate : Int32) : ValueRef
  fun const_struct_in_context = LLVMConstStructInContext(c : ContextRef, contant_vals : ValueRef*, count : UInt32, packed : Int32) : ValueRef

  fun get_md_kind_id_in_context = LLVMGetMDKindIDInContext(c : ContextRef, name : UInt8*, slen : UInt32) : UInt32
  fun md_node_in_context = LLVMMDNodeInContext(c : ContextRef, values : ValueRef*, count : Int32) : ValueRef
  fun md_string_in_context = LLVMMDStringInContext(c : ContextRef, str : UInt8*, length : Int32) : ValueRef

  fun value_as_metadata = LLVMValueAsMetadata(val : ValueRef) : MetadataRef
  fun metadata_as_value = LLVMMetadataAsValue(c : ContextRef, md : MetadataRef) : ValueRef

  fun append_basic_block_in_context = LLVMAppendBasicBlockInContext(ctx : ContextRef, fn : ValueRef, name : UInt8*) : BasicBlockRef
  fun create_builder_in_context = LLVMCreateBuilderInContext(c : ContextRef) : BuilderRef

  fun get_type_context = LLVMGetTypeContext(TypeRef) : ContextRef

  fun const_int_get_sext_value = LLVMConstIntGetSExtValue(ValueRef) : Int64
  fun const_int_get_zext_value = LLVMConstIntGetZExtValue(ValueRef) : UInt64

  fun get_num_operands = LLVMGetNumOperands(val : ValueRef) : Int32
  fun get_operand = LLVMGetOperand(val : ValueRef, index : UInt) : ValueRef

  fun get_num_arg_operands = LLVMGetNumArgOperands(instr : ValueRef) : UInt
  fun get_arg_operand = LLVMGetArgOperand(val : ValueRef, index : UInt) : ValueRef

  fun get_md_node_num_operands = LLVMGetMDNodeNumOperands(v : ValueRef) : UInt
  fun get_md_node_operands = LLVMGetMDNodeOperands(v : ValueRef, dest : ValueRef*)

  fun set_instr_param_alignment = LLVMSetInstrParamAlignment(instr : ValueRef, index : UInt, align : UInt)

  fun set_param_alignment = LLVMSetParamAlignment(arg : ValueRef, align : UInt)

  {% unless LibLLVM::IS_LT_130 %}
    fun run_passes = LLVMRunPasses(mod : ModuleRef, passes : UInt8*, tm : TargetMachineRef, options : PassBuilderOptionsRef) : ErrorRef
    fun create_pass_builder_options = LLVMCreatePassBuilderOptions : PassBuilderOptionsRef
    fun dispose_pass_builder_options = LLVMDisposePassBuilderOptions(options : PassBuilderOptionsRef)
  {% end %}

  fun create_di_builder = LLVMCreateDIBuilder(m : ModuleRef) : DIBuilderRef
  fun dispose_di_builder = LLVMDisposeDIBuilder(builder : DIBuilderRef)
  fun di_builder_finalize = LLVMDIBuilderFinalize(builder : DIBuilderRef)

  {% if LibLLVM::IS_LT_110 %}
    fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(
      builder : DIBuilderRef, lang : LLVM::DwarfSourceLanguage, file_ref : MetadataRef, producer : Char*,
      producer_len : SizeT, is_optimized : Int, flags : Char*, flags_len : SizeT, runtime_ver : UInt,
      split_name : Char*, split_name_len : SizeT, kind : DWARFEmissionKind, dwo_id : UInt,
      split_debug_inlining : Int, debug_info_for_profiling : Int
    ) : MetadataRef
  {% else %}
    fun di_builder_create_compile_unit = LLVMDIBuilderCreateCompileUnit(
      builder : DIBuilderRef, lang : LLVM::DwarfSourceLanguage, file_ref : MetadataRef, producer : Char*,
      producer_len : SizeT, is_optimized : Int, flags : Char*, flags_len : SizeT, runtime_ver : UInt,
      split_name : Char*, split_name_len : SizeT, kind : DWARFEmissionKind, dwo_id : UInt,
      split_debug_inlining : Int, debug_info_for_profiling : Int, sys_root : Char*,
      sys_root_len : SizeT, sdk : Char*, sdk_len : SizeT
    ) : MetadataRef
  {% end %}

  fun di_builder_create_file = LLVMDIBuilderCreateFile(
    builder : DIBuilderRef, filename : Char*, filename_len : SizeT,
    directory : Char*, directory_len : SizeT
  ) : MetadataRef

  fun di_builder_create_function = LLVMDIBuilderCreateFunction(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT,
    linkage_name : Char*, linkage_name_len : SizeT, file : MetadataRef, line_no : UInt,
    ty : MetadataRef, is_local_to_unit : Int, is_definition : Int, scope_line : UInt,
    flags : LLVM::DIFlags, is_optimized : Int
  ) : MetadataRef

  fun di_builder_create_lexical_block = LLVMDIBuilderCreateLexicalBlock(
    builder : DIBuilderRef, scope : MetadataRef, file : MetadataRef, line : UInt, column : UInt
  ) : MetadataRef
  fun di_builder_create_lexical_block_file = LLVMDIBuilderCreateLexicalBlockFile(
    builder : DIBuilderRef, scope : MetadataRef, file_scope : MetadataRef, discriminator : UInt
  ) : MetadataRef

  {% unless LibLLVM::IS_LT_90 %}
    fun di_builder_create_enumerator = LLVMDIBuilderCreateEnumerator(
      builder : DIBuilderRef, name : Char*, name_len : SizeT, value : Int64, is_unsigned : Int
    ) : MetadataRef
  {% end %}

  fun di_builder_create_subroutine_type = LLVMDIBuilderCreateSubroutineType(
    builder : DIBuilderRef, file : MetadataRef, parameter_types : MetadataRef*,
    num_parameter_types : UInt, flags : LLVM::DIFlags
  ) : MetadataRef
  fun di_builder_create_enumeration_type = LLVMDIBuilderCreateEnumerationType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
    elements : MetadataRef*, num_elements : UInt, class_ty : MetadataRef
  ) : MetadataRef
  fun di_builder_create_union_type = LLVMDIBuilderCreateUnionType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32, flags : LLVM::DIFlags,
    elements : MetadataRef*, num_elements : UInt, run_time_lang : UInt, unique_id : Char*, unique_id_len : SizeT
  ) : MetadataRef
  fun di_builder_create_array_type = LLVMDIBuilderCreateArrayType(
    builder : DIBuilderRef, size : UInt64, align_in_bits : UInt32,
    ty : MetadataRef, subscripts : MetadataRef*, num_subscripts : UInt
  ) : MetadataRef
  fun di_builder_create_unspecified_type = LLVMDIBuilderCreateUnspecifiedType(builder : DIBuilderRef, name : Char*, name_len : SizeT) : MetadataRef
  fun di_builder_create_basic_type = LLVMDIBuilderCreateBasicType(
    builder : DIBuilderRef, name : Char*, name_len : SizeT, size_in_bits : UInt64,
    encoding : UInt, flags : LLVM::DIFlags
  ) : MetadataRef
  fun di_builder_create_pointer_type = LLVMDIBuilderCreatePointerType(
    builder : DIBuilderRef, pointee_ty : MetadataRef, size_in_bits : UInt64, align_in_bits : UInt32,
    address_space : UInt, name : Char*, name_len : SizeT
  ) : MetadataRef
  fun di_builder_create_struct_type = LLVMDIBuilderCreateStructType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_number : UInt, size_in_bits : UInt64, align_in_bits : UInt32, flags : LLVM::DIFlags,
    derived_from : MetadataRef, elements : MetadataRef*, num_elements : UInt,
    run_time_lang : UInt, v_table_holder : MetadataRef, unique_id : Char*, unique_id_len : SizeT
  ) : MetadataRef
  fun di_builder_create_member_type = LLVMDIBuilderCreateMemberType(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_no : UInt, size_in_bits : UInt64, align_in_bits : UInt32, offset_in_bits : UInt64,
    flags : LLVM::DIFlags, ty : MetadataRef
  ) : MetadataRef
  fun di_builder_create_replaceable_composite_type = LLVMDIBuilderCreateReplaceableCompositeType(
    builder : DIBuilderRef, tag : UInt, name : Char*, name_len : SizeT, scope : MetadataRef,
    file : MetadataRef, line : UInt, runtime_lang : UInt, size_in_bits : UInt64, align_in_bits : UInt32,
    flags : LLVM::DIFlags, unique_identifier : Char*, unique_identifier_len : SizeT
  ) : MetadataRef

  fun di_builder_get_or_create_subrange = LLVMDIBuilderGetOrCreateSubrange(builder : DIBuilderRef, lo : Int64, count : Int64) : MetadataRef
  fun di_builder_get_or_create_array = LLVMDIBuilderGetOrCreateArray(builder : DIBuilderRef, data : MetadataRef*, length : SizeT) : MetadataRef
  fun di_builder_get_or_create_type_array = LLVMDIBuilderGetOrCreateTypeArray(builder : DIBuilderRef, types : MetadataRef*, length : SizeT) : MetadataRef

  {% if LibLLVM::IS_LT_140 %}
    fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilderRef, addr : Int64*, length : SizeT) : MetadataRef
  {% else %}
    fun di_builder_create_expression = LLVMDIBuilderCreateExpression(builder : DIBuilderRef, addr : UInt64*, length : SizeT) : MetadataRef
  {% end %}

  fun di_builder_insert_declare_at_end = LLVMDIBuilderInsertDeclareAtEnd(
    builder : DIBuilderRef, storage : ValueRef, var_info : MetadataRef,
    expr : MetadataRef, debug_loc : MetadataRef, block : BasicBlockRef
  ) : ValueRef

  fun di_builder_create_auto_variable = LLVMDIBuilderCreateAutoVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, file : MetadataRef,
    line_no : UInt, ty : MetadataRef, always_preserve : Int, flags : LLVM::DIFlags, align_in_bits : UInt32
  ) : MetadataRef
  fun di_builder_create_parameter_variable = LLVMDIBuilderCreateParameterVariable(
    builder : DIBuilderRef, scope : MetadataRef, name : Char*, name_len : SizeT, arg_no : UInt,
    file : MetadataRef, line_no : UInt, ty : MetadataRef, always_preserve : Int, flags : LLVM::DIFlags
  ) : MetadataRef

  fun set_subprogram = LLVMSetSubprogram(func : ValueRef, sp : MetadataRef)
  fun metadata_replace_all_uses_with = LLVMMetadataReplaceAllUsesWith(target_metadata : MetadataRef, replacement : MetadataRef)

  {% if LibLLVM::IS_LT_170 %}
    type PassManagerRef = Void*
    fun pass_manager_create = LLVMCreatePassManager : PassManagerRef
    fun create_function_pass_manager_for_module = LLVMCreateFunctionPassManagerForModule(mod : ModuleRef) : PassManagerRef
    fun run_pass_manager = LLVMRunPassManager(pm : PassManagerRef, m : ModuleRef) : Int32
    fun initialize_function_pass_manager = LLVMInitializeFunctionPassManager(fpm : PassManagerRef) : Int32
    fun run_function_pass_manager = LLVMRunFunctionPassManager(fpm : PassManagerRef, f : ValueRef) : Int32
    fun finalize_function_pass_manager = LLVMFinalizeFunctionPassManager(fpm : PassManagerRef) : Int32
    fun dispose_pass_manager = LLVMDisposePassManager(PassManagerRef)

    type PassRegistryRef = Void*
    fun get_global_pass_registry = LLVMGetGlobalPassRegistry : PassRegistryRef
    fun initialize_core = LLVMInitializeCore(r : PassRegistryRef)
    fun initialize_transform_utils = LLVMInitializeTransformUtils(r : PassRegistryRef)
    fun initialize_scalar_opts = LLVMInitializeScalarOpts(r : PassRegistryRef)
    fun initialize_obj_c_arc_opts = LLVMInitializeObjCARCOpts(r : PassRegistryRef)
    fun initialize_vectorization = LLVMInitializeVectorization(r : PassRegistryRef)
    fun initialize_inst_combine = LLVMInitializeInstCombine(r : PassRegistryRef)
    fun initialize_ipo = LLVMInitializeIPO(r : PassRegistryRef)
    fun initialize_instrumentation = LLVMInitializeInstrumentation(r : PassRegistryRef)
    fun initialize_analysis = LLVMInitializeAnalysis(r : PassRegistryRef)
    fun initialize_ipa = LLVMInitializeIPA(r : PassRegistryRef)
    fun initialize_code_gen = LLVMInitializeCodeGen(r : PassRegistryRef)
    fun initialize_target = LLVMInitializeTarget(r : PassRegistryRef)

    type PassManagerBuilderRef = Void*
    fun pass_manager_builder_create = LLVMPassManagerBuilderCreate : PassManagerBuilderRef
    fun pass_manager_builder_set_opt_level = LLVMPassManagerBuilderSetOptLevel(builder : PassManagerBuilderRef, opt_level : UInt32)
    fun pass_manager_builder_set_size_level = LLVMPassManagerBuilderSetSizeLevel(builder : PassManagerBuilderRef, size_level : UInt32)
    fun pass_manager_builder_set_disable_unroll_loops = LLVMPassManagerBuilderSetDisableUnrollLoops(builder : PassManagerBuilderRef, value : Int32)
    fun pass_manager_builder_set_disable_simplify_lib_calls = LLVMPassManagerBuilderSetDisableSimplifyLibCalls(builder : PassManagerBuilderRef, value : Int32)
    fun pass_manager_builder_use_inliner_with_threshold = LLVMPassManagerBuilderUseInlinerWithThreshold(builder : PassManagerBuilderRef, threshold : UInt32)
    fun pass_manager_builder_populate_function_pass_manager = LLVMPassManagerBuilderPopulateFunctionPassManager(builder : PassManagerBuilderRef, pm : PassManagerRef)
    fun pass_manager_builder_populate_module_pass_manager = LLVMPassManagerBuilderPopulateModulePassManager(builder : PassManagerBuilderRef, pm : PassManagerRef)
    fun dispose_pass_manager_builder = LLVMPassManagerBuilderDispose(PassManagerBuilderRef)
  {% end %}
end
