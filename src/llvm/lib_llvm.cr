require "./enums"

@[Link("stdc++")]
ifdef freebsd
  @[Link(ldflags: "`llvm-config36 --libs --system-libs --ldflags 2> /dev/null`")]
else
  @[Link(ldflags: "`(llvm-config-3.6 --libs --system-libs --ldflags 2> /dev/null) || (llvm-config-3.5 --libs --system-libs --ldflags 2> /dev/null) || (llvm-config --libs --system-libs --ldflags 2>/dev/null)`")]
end
lib LibLLVM
  type ContextRef = Void*
  type ModuleRef = Void*
  type TypeRef = Void*
  type ValueRef = Void*
  type BasicBlockRef = Void*
  type BuilderRef = Void*
  type ExecutionEngineRef = Void*
  type GenericValueRef = Void*
  type TargetRef = Void*
  type TargetDataRef = Void*
  type TargetMachineRef = Void*
  type PassManagerBuilderRef = Void*
  type PassManagerRef = Void*
  type PassRegistryRef = Void*

  struct JITCompilerOptions
    opt_level : UInt32
    code_model : LLVM::CodeModel
    no_frame_pointer_elim : Int32
    enable_fast_isel : Int32
  end

  fun add_attribute = LLVMAddAttribute(arg : ValueRef, attr : LLVM::Attribute)
  fun add_instr_attribute = LLVMAddInstrAttribute(instr : ValueRef, index : UInt32, attr : LLVM::Attribute)
  fun add_case = LLVMAddCase(switch : ValueRef, onval : ValueRef, dest : BasicBlockRef)
  fun add_clause = LLVMAddClause(lpad : ValueRef, clause_val : ValueRef)
  fun add_function = LLVMAddFunction(module : ModuleRef, name : UInt8*, type : TypeRef) : ValueRef
  fun add_function_attr = LLVMAddFunctionAttr(fn : ValueRef, pa : LLVM::Attribute)
  fun get_function_attr = LLVMGetFunctionAttr(fn : ValueRef) : LLVM::Attribute
  fun add_global = LLVMAddGlobal(module : ModuleRef, type : TypeRef, name : UInt8*) : ValueRef
  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef *, count : Int32)
  fun add_named_metadata_operand = LLVMAddNamedMetadataOperand(mod : ModuleRef, name : UInt8*, val : ValueRef)
  fun add_target_dependent_function_attr = LLVMAddTargetDependentFunctionAttr(fn : ValueRef, a : LibC::Char*, v : LibC::Char*)
  fun append_basic_block = LLVMAppendBasicBlock(fn : ValueRef, name : UInt8*) : BasicBlockRef
  fun array_type = LLVMArrayType(element_type : TypeRef, count : UInt32) : TypeRef
  fun vector_type = LLVMVectorType(element_type : TypeRef, count : UInt32) : TypeRef
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
  fun build_fcmp = LLVMBuildFCmp(builder : BuilderRef, op : LLVM::RealPredicate, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
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
  fun build_icmp = LLVMBuildICmp(builder : BuilderRef, op : LLVM::IntPredicate, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
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
  fun create_target_machine = LLVMCreateTargetMachine(target : TargetRef, triple : UInt8*, cpu : UInt8*, features : UInt8*, level : LLVM::CodeGenOptLevel, reloc : LLVM::RelocMode, code_model : LLVM::CodeModel) : TargetMachineRef
  fun delete_basic_block = LLVMDeleteBasicBlock(block : BasicBlockRef)
  fun dispose_message = LLVMDisposeMessage(msg : UInt8*)
  fun double_type = LLVMDoubleType : TypeRef
  fun dump_module = LLVMDumpModule(module : ModuleRef)
  fun dump_value = LLVMDumpValue(val : ValueRef)
  fun target_machine_emit_to_file = LLVMTargetMachineEmitToFile(t : TargetMachineRef, m : ModuleRef, filename : UInt8*, codegen : LLVM::CodeGenFileType, error_msg : UInt8**) : Int32
  fun float_type = LLVMFloatType : TypeRef
  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : UInt32, is_var_arg : Int32) : TypeRef
  fun generic_value_to_float = LLVMGenericValueToFloat(type : TypeRef, value : GenericValueRef) : Float64
  fun generic_value_to_int = LLVMGenericValueToInt(value : GenericValueRef, signed : Int32) : UInt64
  fun generic_value_to_pointer = LLVMGenericValueToPointer(value : GenericValueRef) : Void*
  fun get_attribute = LLVMGetAttribute(arg : ValueRef) : LLVM::Attribute
  fun get_current_debug_location = LLVMGetCurrentDebugLocation(builder : BuilderRef) : ValueRef
  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun get_first_instruction = LLVMGetFirstInstruction(block : BasicBlockRef) : ValueRef
  fun get_first_target = LLVMGetFirstTarget : TargetRef
  fun get_global_context = LLVMGetGlobalContext : ContextRef
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_named_global = LLVMGetNamedGlobal(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_param = LLVMGetParam(fn : ValueRef, index : Int32) : ValueRef
  fun get_param_types = LLVMGetParamTypes(function_type : TypeRef, dest : TypeRef*)
  fun get_params = LLVMGetParams(fn : ValueRef, params : ValueRef*)
  fun get_pointer_to_global = LLVMGetPointerToGlobal(ee : ExecutionEngineRef, global : ValueRef) : Void*
  fun get_return_type = LLVMGetReturnType(function_type : TypeRef) : TypeRef
  fun get_target_name = LLVMGetTargetName(target : TargetRef) : UInt8*
  fun get_target_description = LLVMGetTargetDescription(target : TargetRef) : UInt8*
  fun get_target_machine_data = LLVMGetTargetMachineData(t : TargetMachineRef) : TargetDataRef
  fun get_target_machine_triple = LLVMGetTargetMachineTriple(t : TargetMachineRef) : UInt8*
  fun get_target_from_triple = LLVMGetTargetFromTriple(triple : UInt8*, target : TargetRef*, error_message : UInt8**) : Int32
  fun get_type_kind = LLVMGetTypeKind(ty : TypeRef) : LLVM::Type::Kind
  fun get_undef = LLVMGetUndef(ty : TypeRef) : ValueRef
  fun get_value_name = LLVMGetValueName(value : ValueRef) : UInt8*
  fun initialize_native_target = LLVMInitializeNativeTarget
  fun int1_type = LLVMInt1Type : TypeRef
  fun int8_type = LLVMInt8Type : TypeRef
  fun int16_type = LLVMInt16Type : TypeRef
  fun int32_type = LLVMInt32Type : TypeRef
  fun int64_type = LLVMInt64Type : TypeRef
  fun int_type = LLVMIntType(bits : Int32) : TypeRef
  fun is_constant = LLVMIsConstant(val : ValueRef) : Int32
  fun is_function_var_arg = LLVMIsFunctionVarArg(ty : TypeRef) : Int32
  fun md_node = LLVMMDNode(values : ValueRef*, count : Int32) : ValueRef
  fun md_string = LLVMMDString(str : UInt8*, length : Int32) : ValueRef
  fun module_create_with_name = LLVMModuleCreateWithName(module_id : UInt8*) : ModuleRef
  fun module_create_with_name_in_context = LLVMModuleCreateWithNameInContext(module_id : UInt8*, context : ContextRef) : ModuleRef
  fun pass_manager_builder_create = LLVMPassManagerBuilderCreate : PassManagerBuilderRef
  fun pass_manager_builder_set_opt_level = LLVMPassManagerBuilderSetOptLevel(builder : PassManagerBuilderRef, opt_level : UInt32)
  fun pass_manager_builder_set_size_level = LLVMPassManagerBuilderSetSizeLevel(builder : PassManagerBuilderRef, size_level : UInt32)
  fun pass_manager_builder_set_disable_unroll_loops = LLVMPassManagerBuilderSetDisableUnrollLoops(builder : PassManagerBuilderRef, value : Int32)
  fun pass_manager_builder_set_disable_simplify_lib_calls = LLVMPassManagerBuilderSetDisableSimplifyLibCalls(builder : PassManagerBuilderRef, value : Int32)
  fun pass_manager_builder_use_inliner_with_threshold = LLVMPassManagerBuilderUseInlinerWithThreshold(builder : PassManagerBuilderRef, threshold : UInt32)
  fun pass_manager_builder_populate_function_pass_manager = LLVMPassManagerBuilderPopulateFunctionPassManager(builder : PassManagerBuilderRef, pm : PassManagerRef)
  fun pass_manager_builder_populate_module_pass_manager = LLVMPassManagerBuilderPopulateModulePassManager(builder : PassManagerBuilderRef, pm : PassManagerRef)
  fun pass_manager_create = LLVMCreatePassManager : PassManagerRef
  fun create_function_pass_manager_for_module = LLVMCreateFunctionPassManagerForModule(mod : ModuleRef) : PassManagerRef
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt32) : TypeRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun print_module_to_file = LLVMPrintModuleToFile(m : ModuleRef, filename : UInt8*, error_msg : UInt8**) : Int32
  fun run_function = LLVMRunFunction (ee : ExecutionEngineRef, f : ValueRef, num_args : Int32, args : GenericValueRef*) : GenericValueRef
  fun run_pass_manager = LLVMRunPassManager(pm : PassManagerRef, m : ModuleRef) : Int32
  fun initialize_function_pass_manager = LLVMInitializeFunctionPassManager(fpm : PassManagerRef) : Int32
  fun run_function_pass_manager = LLVMRunFunctionPassManager(fpm : PassManagerRef, f : ValueRef) : Int32
  fun finalize_function_pass_manager = LLVMFinalizeFunctionPassManager(fpm : PassManagerRef) : Int32
  fun set_cleanup = LLVMSetCleanup(lpad : ValueRef, val : Int32)
  fun set_data_layout = LLVMSetDataLayout(mod : ModuleRef, data : UInt8*)
  fun set_global_constant = LLVMSetGlobalConstant(global : ValueRef, is_constant : Int32)
  fun is_global_constant = LLVMIsGlobalConstant(global : ValueRef) : Int32
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun get_initializer = LLVMGetInitializer(global_var : ValueRef) : ValueRef
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : LLVM::Linkage)
  fun get_linkage = LLVMGetLinkage(global : ValueRef) : LLVM::Linkage
  fun set_metadata = LLVMSetMetadata(value : ValueRef, kind_id : UInt32, node : ValueRef)
  fun set_target = LLVMSetTarget(mod : ModuleRef, triple : UInt8*)
  fun set_thread_local = LLVMSetThreadLocal(global_var : ValueRef, is_thread_local : Int32)
  fun is_thread_local = LLVMIsThreadLocal(global_var : ValueRef) : Int32
  fun set_value_name = LLVMSetValueName(val : ValueRef, name : UInt8*)
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef
  fun size_of_type_in_bits = LLVMSizeOfTypeInBits(ref : TargetDataRef, ty : TypeRef) : UInt64
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : UInt8*) : TypeRef
  fun struct_set_body = LLVMStructSetBody(struct_type : TypeRef, element_types : TypeRef*, element_count : UInt32, packed : Int32)
  fun struct_type = LLVMStructType(element_types : TypeRef*, element_count : UInt32, packed : Int32) : TypeRef
  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun void_type = LLVMVoidType : TypeRef
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : UInt8*) : Int32
  fun verify_module = LLVMVerifyModule(module : ModuleRef, action : LLVM::VerifierFailureAction, outmessage : UInt8**) : Int32
  fun link_in_jit = LLVMLinkInJIT
  fun link_in_mc_jit = LLVMLinkInMCJIT
  fun start_multithreaded = LLVMStartMultithreaded : Int32
  fun stop_multithreaded = LLVMStopMultithreaded
  fun is_multithreaded = LLVMIsMultithreaded : Int32
  fun get_md_kind_id = LLVMGetMDKindID(name : UInt8*, slen : UInt32) : UInt32
  fun get_first_function = LLVMGetFirstFunction(m : ModuleRef) : ValueRef?
  fun get_next_function = LLVMGetNextFunction(f : ValueRef) : ValueRef?
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
  fun add_target_data = LLVMAddTargetData(td : TargetDataRef, pm : PassManagerRef)
  fun get_next_target = LLVMGetNextTarget(t : TargetRef) : TargetRef
  fun get_default_target_triple = LLVMGetDefaultTargetTriple : UInt8*
  fun print_module_to_string = LLVMPrintModuleToString(mod : ModuleRef) : UInt8*
  fun print_type_to_string = LLVMPrintTypeToString(ty : TypeRef) : UInt8*
  fun print_value_to_string = LLVMPrintValueToString(v : ValueRef) : UInt8*
  fun get_function_call_convention = LLVMGetFunctionCallConv(fn : ValueRef) : LLVM::CallConvention
  fun set_function_call_convention = LLVMSetFunctionCallConv(fn : ValueRef, cc : LLVM::CallConvention)
  fun set_instruction_call_convention = LLVMSetInstructionCallConv(instr : ValueRef, cc : LLVM::CallConvention)
  fun get_instruction_call_convention = LLVMGetInstructionCallConv(instr : ValueRef) : LLVM::CallConvention
  fun get_int_type_width = LLVMGetIntTypeWidth(ty : TypeRef) : UInt32
  fun is_packed_struct = LLVMIsPackedStruct(ty : TypeRef) : Int32
  fun get_struct_element_types = LLVMGetStructElementTypes(ty : TypeRef, dest : TypeRef*)
  fun count_struct_element_types = LLVMCountStructElementTypes(ty : TypeRef) : UInt32
  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun get_array_length = LLVMGetArrayLength(ty : TypeRef) : UInt32
  fun abi_size_of_type = LLVMABISizeOfType(td : TargetDataRef, ty : TypeRef) : UInt64
  fun abi_alignment_of_type = LLVMABIAlignmentOfType(td : TargetDataRef, ty : TypeRef) : UInt32
  fun get_target_machine_target = LLVMGetTargetMachineTarget(t : TargetMachineRef) : TargetRef
  fun const_inline_asm = LLVMConstInlineAsm(t : TypeRef, asm_string : UInt8*, constraints : UInt8*, has_side_effects : Int32, is_align_stack : Int32) : ValueRef
  fun create_context = LLVMContextCreate : ContextRef
  fun dispose_module = LLVMDisposeModule(ModuleRef)
  fun dispose_builder = LLVMDisposeBuilder(BuilderRef)
  fun dispose_target_machine = LLVMDisposeTargetMachine(TargetMachineRef)
  fun dispose_generic_value = LLVMDisposeGenericValue(GenericValueRef)
  fun dispose_execution_engine = LLVMDisposeExecutionEngine(ExecutionEngineRef)
  fun dispose_context = LLVMContextDispose(ContextRef)
  fun dispose_pass_manager = LLVMDisposePassManager(PassManagerRef)
  fun dispose_target_data = LLVMDisposeTargetData(TargetDataRef)
  fun dispose_pass_manager_builder = LLVMPassManagerBuilderDispose(PassManagerBuilderRef)
end

{%if true %}
lib LibLLVM
  {% for target in `(llvm-config-3.6 --targets-built 2>/dev/null) || (llvm-config-3.5 --targets-built 2>/dev/null) || (llvm-config --targets-built 2>/dev/null)`.chomp.split(" ") %}
    fun initialize_{{target.downcase.id}}_target = LLVMInitialize{{target.id}}Target
    fun initialize_{{target.downcase.id}}_target_info = LLVMInitialize{{target.id}}TargetInfo
    fun initialize_{{target.downcase.id}}_target_mc = LLVMInitialize{{target.id}}TargetMC

    {% unless ["XCore", "MSP430", "CppBackend", "NVPTX", "Hexagon"].find {|skip| target == skip } %}
      fun initialize_{{target.downcase.id}}_asm_parser = LLVMInitialize{{target.id}}AsmParser
    {% end %}

    {% unless ["CppBackend"].find {|skip| target == skip } %}
      fun initialize_{{target.downcase.id}}_asm_printer = LLVMInitialize{{target.id}}AsmPrinter
    {% end %}
  {% end %}
end
{% end %}
