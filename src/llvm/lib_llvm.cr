{% begin %}
lib LibLLVM
  LLVM_CONFIG = {{
                  `[ -n "$LLVM_CONFIG" ] && command -v "$LLVM_CONFIG" || \
                   command -v llvm-config-8 || command -v llvm-config-8.0 || command -v llvm-config80 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 8.0*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config-7 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 7.1*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config-7.0 || command -v llvm-config70 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 7.0*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config-6.0 || command -v llvm-config60 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 6.0*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config-5.0 || command -v llvm-config50 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 5.0*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config-4.0 || command -v llvm-config40 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 4.0*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config-3.9 || command -v llvm-config39 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 3.9*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config-3.8 || command -v llvm-config38 || \
                   (command -v llvm-config > /dev/null && (case "$(llvm-config --version)" in 3.8*) command -v llvm-config;; *) false;; esac)) || \
                   command -v llvm-config
                  `.chomp.stringify
                }}
end
{% end %}

{% begin %}
  @[Link("stdc++")]
  {% if flag?(:static) %}
    @[Link(ldflags: "`{{LibLLVM::LLVM_CONFIG.id}} --libs --system-libs --ldflags --link-static 2> /dev/null`")]
  {% else %}
    @[Link(ldflags: "`{{LibLLVM::LLVM_CONFIG.id}} --libs --system-libs --ldflags 2> /dev/null`")]
  {% end %}
  lib LibLLVM
    VERSION = {{`#{LibLLVM::LLVM_CONFIG} --version`.chomp.stringify}}
    BUILT_TARGETS = {{ `#{LibLLVM::LLVM_CONFIG} --targets-built`.strip.downcase.split(' ').map(&.id.symbolize) }}
  end
{% end %}

{% begin %}
  lib LibLLVM
    IS_80 = {{LibLLVM::VERSION.starts_with?("8.0")}}
    IS_71 = {{LibLLVM::VERSION.starts_with?("7.1")}}
    IS_70 = {{LibLLVM::VERSION.starts_with?("7.0")}}
    IS_60 = {{LibLLVM::VERSION.starts_with?("6.0")}}
    IS_50 = {{LibLLVM::VERSION.starts_with?("5.0")}}
    IS_40 = {{LibLLVM::VERSION.starts_with?("4.0")}}
    IS_39 = {{LibLLVM::VERSION.starts_with?("3.9")}}
    IS_38 = {{LibLLVM::VERSION.starts_with?("3.8")}}

    IS_LT_70 = IS_38 || IS_39 || IS_40 || IS_50 || IS_60
  end
{% end %}

lib LibLLVM
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt

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
  type MemoryBufferRef = Void*

  struct JITCompilerOptions
    opt_level : UInt32
    code_model : LLVM::CodeModel
    no_frame_pointer_elim : Int32
    enable_fast_isel : Int32
  end

  fun add_case = LLVMAddCase(switch : ValueRef, onval : ValueRef, dest : BasicBlockRef)
  fun add_clause = LLVMAddClause(lpad : ValueRef, clause_val : ValueRef)
  fun add_function = LLVMAddFunction(module : ModuleRef, name : UInt8*, type : TypeRef) : ValueRef
  fun add_global = LLVMAddGlobal(module : ModuleRef, type : TypeRef, name : UInt8*) : ValueRef
  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef*, count : Int32)
  fun add_named_metadata_operand = LLVMAddNamedMetadataOperand(mod : ModuleRef, name : UInt8*, val : ValueRef)
  fun add_target_dependent_function_attr = LLVMAddTargetDependentFunctionAttr(fn : ValueRef, a : LibC::Char*, v : LibC::Char*)
  fun array_type = LLVMArrayType(element_type : TypeRef, count : UInt32) : TypeRef
  fun vector_type = LLVMVectorType(element_type : TypeRef, count : UInt32) : TypeRef
  fun build_add = LLVMBuildAdd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(builder : BuilderRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_and = LLVMBuildAnd(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_array_malloc = LLVMBuildArrayMalloc(builder : BuilderRef, type : TypeRef, val : ValueRef, name : UInt8*) : ValueRef
  fun build_ashr = LLVMBuildAShr(builder : BuilderRef, lhs : ValueRef, rhs : ValueRef, name : UInt8*) : ValueRef
  fun build_atomicrmw = LLVMBuildAtomicRMW(builder : BuilderRef, op : LLVM::AtomicRMWBinOp, ptr : ValueRef, val : ValueRef, ordering : LLVM::AtomicOrdering, singlethread : Int32) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(builder : BuilderRef, value : ValueRef, type : TypeRef, name : UInt8*) : ValueRef
  fun build_br = LLVMBuildBr(builder : BuilderRef, block : BasicBlockRef) : ValueRef
  fun build_call = LLVMBuildCall(builder : BuilderRef, fn : ValueRef, args : ValueRef*, num_args : Int32, name : UInt8*) : ValueRef
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
  fun get_current_debug_location = LLVMGetCurrentDebugLocation(builder : BuilderRef) : ValueRef
  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun get_first_instruction = LLVMGetFirstInstruction(block : BasicBlockRef) : ValueRef
  fun get_first_target = LLVMGetFirstTarget : TargetRef
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun get_named_function = LLVMGetNamedFunction(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_named_global = LLVMGetNamedGlobal(mod : ModuleRef, name : UInt8*) : ValueRef
  fun get_count_params = LLVMCountParams(fn : ValueRef) : UInt
  fun get_param = LLVMGetParam(fn : ValueRef, index : Int32) : ValueRef
  fun get_param_types = LLVMGetParamTypes(function_type : TypeRef, dest : TypeRef*)
  fun get_params = LLVMGetParams(fn : ValueRef, params : ValueRef*)
  fun get_pointer_to_global = LLVMGetPointerToGlobal(ee : ExecutionEngineRef, global : ValueRef) : Void*
  fun get_return_type = LLVMGetReturnType(function_type : TypeRef) : TypeRef
  fun get_target_name = LLVMGetTargetName(target : TargetRef) : UInt8*
  fun get_target_description = LLVMGetTargetDescription(target : TargetRef) : UInt8*
  fun get_target_machine_triple = LLVMGetTargetMachineTriple(t : TargetMachineRef) : UInt8*
  fun get_target_from_triple = LLVMGetTargetFromTriple(triple : UInt8*, target : TargetRef*, error_message : UInt8**) : Int32
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
  fun initialize_native_target = LLVMInitializeNativeTarget
  fun is_constant = LLVMIsConstant(val : ValueRef) : Int32
  fun is_function_var_arg = LLVMIsFunctionVarArg(ty : TypeRef) : Int32
  fun module_create_with_name_in_context = LLVMModuleCreateWithNameInContext(module_id : UInt8*, context : ContextRef) : ModuleRef
  fun offset_of_element = LLVMOffsetOfElement(td : TargetDataRef, struct_type : TypeRef, element : LibC::UInt) : UInt64
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
  fun run_function = LLVMRunFunction(ee : ExecutionEngineRef, f : ValueRef, num_args : Int32, args : GenericValueRef*) : GenericValueRef
  fun run_pass_manager = LLVMRunPassManager(pm : PassManagerRef, m : ModuleRef) : Int32
  fun initialize_function_pass_manager = LLVMInitializeFunctionPassManager(fpm : PassManagerRef) : Int32
  fun run_function_pass_manager = LLVMRunFunctionPassManager(fpm : PassManagerRef, f : ValueRef) : Int32
  fun finalize_function_pass_manager = LLVMFinalizeFunctionPassManager(fpm : PassManagerRef) : Int32
  fun set_cleanup = LLVMSetCleanup(lpad : ValueRef, val : Int32)
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
  fun set_personality_fn = LLVMSetPersonalityFn(fn : ValueRef, personality_fn : ValueRef)
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef
  fun size_of_type_in_bits = LLVMSizeOfTypeInBits(ref : TargetDataRef, ty : TypeRef) : UInt64
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : UInt8*) : TypeRef
  fun struct_set_body = LLVMStructSetBody(struct_type : TypeRef, element_types : TypeRef*, element_count : UInt32, packed : Int32)
  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun write_bitcode_to_file = LLVMWriteBitcodeToFile(module : ModuleRef, path : UInt8*) : Int32
  fun verify_module = LLVMVerifyModule(module : ModuleRef, action : LLVM::VerifierFailureAction, outmessage : UInt8**) : Int32
  fun link_in_jit = LLVMLinkInJIT
  fun link_in_mc_jit = LLVMLinkInMCJIT
  fun start_multithreaded = LLVMStartMultithreaded : Int32
  fun stop_multithreaded = LLVMStopMultithreaded
  fun is_multithreaded = LLVMIsMultithreaded : Int32
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
  fun get_struct_name = LLVMGetStructName(ty : TypeRef) : UInt8*
  fun get_struct_element_types = LLVMGetStructElementTypes(ty : TypeRef, dest : TypeRef*)
  fun count_struct_element_types = LLVMCountStructElementTypes(ty : TypeRef) : UInt32
  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun get_array_length = LLVMGetArrayLength(ty : TypeRef) : UInt32
  fun get_vector_size = LLVMGetVectorSize(ty : TypeRef) : UInt32
  fun abi_size_of_type = LLVMABISizeOfType(td : TargetDataRef, ty : TypeRef) : UInt64
  fun abi_alignment_of_type = LLVMABIAlignmentOfType(td : TargetDataRef, ty : TypeRef) : UInt32
  fun get_target_machine_target = LLVMGetTargetMachineTarget(t : TargetMachineRef) : TargetRef
  fun const_inline_asm = LLVMConstInlineAsm(t : TypeRef, asm_string : UInt8*, constraints : UInt8*, has_side_effects : Int32, is_align_stack : Int32) : ValueRef
  fun create_context = LLVMContextCreate : ContextRef
  fun dispose_builder = LLVMDisposeBuilder(BuilderRef)
  fun dispose_target_machine = LLVMDisposeTargetMachine(TargetMachineRef)
  fun dispose_generic_value = LLVMDisposeGenericValue(GenericValueRef)
  fun dispose_execution_engine = LLVMDisposeExecutionEngine(ExecutionEngineRef)
  fun dispose_context = LLVMContextDispose(ContextRef)
  fun dispose_pass_manager = LLVMDisposePassManager(PassManagerRef)
  fun dispose_target_data = LLVMDisposeTargetData(TargetDataRef)
  fun dispose_pass_manager_builder = LLVMPassManagerBuilderDispose(PassManagerBuilderRef)
  fun set_volatile = LLVMSetVolatile(value : ValueRef, volatile : UInt32)
  fun set_alignment = LLVMSetAlignment(value : ValueRef, bytes : UInt32)
  fun get_return_type = LLVMGetReturnType(TypeRef) : TypeRef

  fun write_bitcode_to_memory_buffer = LLVMWriteBitcodeToMemoryBuffer(mod : ModuleRef) : MemoryBufferRef

  fun dispose_memory_buffer = LLVMDisposeMemoryBuffer(buf : MemoryBufferRef) : Void
  fun get_buffer_start = LLVMGetBufferStart(buf : MemoryBufferRef) : UInt8*
  fun get_buffer_size = LLVMGetBufferSize(buf : MemoryBufferRef) : LibC::SizeT

  fun write_bitcode_to_fd = LLVMWriteBitcodeToFD(mod : ModuleRef, fd : LibC::Int, should_close : LibC::Int, unbuffered : LibC::Int) : LibC::Int

  {% if LibLLVM::IS_38 %}
    fun copy_string_rep_of_target_data = LLVMCopyStringRepOfTargetData(data : TargetDataRef) : UInt8*
    fun get_target_machine_data = LLVMGetTargetMachineData(t : TargetMachineRef) : TargetDataRef
    fun set_data_layout = LLVMSetDataLayout(mod : ModuleRef, data : UInt8*)
  {% else %}
    # LLVM >= 3.9
    fun create_target_data_layout = LLVMCreateTargetDataLayout(t : TargetMachineRef) : TargetDataRef
    fun set_module_data_layout = LLVMSetModuleDataLayout(mod : ModuleRef, data : TargetDataRef)
  {% end %}

  {% if LibLLVM::IS_38 %}
    fun add_attribute = LLVMAddAttribute(arg : ValueRef, attr : LLVM::Attribute)
    fun add_instr_attribute = LLVMAddInstrAttribute(instr : ValueRef, index : UInt32, attr : LLVM::Attribute)
    fun add_function_attr = LLVMAddFunctionAttr(fn : ValueRef, pa : LLVM::Attribute)
    fun get_function_attr = LLVMGetFunctionAttr(fn : ValueRef) : LLVM::Attribute
    fun get_attribute = LLVMGetAttribute(arg : ValueRef) : LLVM::Attribute
  {% else %}
    # LLVM >= 3.9
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
  {% end %}

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

  fun const_string_in_context = LLVMConstStringInContext(c : ContextRef, str : UInt8*, length : UInt32, dont_null_terminate : Int32) : ValueRef
  fun const_struct_in_context = LLVMConstStructInContext(c : ContextRef, contant_vals : ValueRef*, count : UInt32, packed : Int32) : ValueRef

  fun get_md_kind_id_in_context = LLVMGetMDKindIDInContext(c : ContextRef, name : UInt8*, slen : UInt32) : UInt32
  fun md_node_in_context = LLVMMDNodeInContext(c : ContextRef, values : ValueRef*, count : Int32) : ValueRef
  fun md_string_in_context = LLVMMDStringInContext(c : ContextRef, str : UInt8*, length : Int32) : ValueRef

  fun append_basic_block_in_context = LLVMAppendBasicBlockInContext(ctx : ContextRef, fn : ValueRef, name : UInt8*) : BasicBlockRef
  fun create_builder_in_context = LLVMCreateBuilderInContext(c : ContextRef) : BuilderRef

  fun get_type_context = LLVMGetTypeContext(TypeRef) : ContextRef

  fun const_int_get_sext_value = LLVMConstIntGetSExtValue(ValueRef) : Int64
  fun const_int_get_zext_value = LLVMConstIntGetZExtValue(ValueRef) : UInt64

  fun get_num_operands = LLVMGetNumOperands(val : ValueRef) : Int32
  fun get_operand = LLVMGetOperand(val : ValueRef, index : UInt) : ValueRef

  fun get_num_arg_operands = LLVMGetNumArgOperands(instr : ValueRef) : UInt
  fun get_arg_operand = LLVMGetArgOperand(val : ValueRef, index : UInt) : ValueRef

  fun set_instr_param_alignment = LLVMSetInstrParamAlignment(instr : ValueRef, index : UInt, align : UInt)

  fun set_param_alignment = LLVMSetParamAlignment(arg : ValueRef, align : UInt)
end
