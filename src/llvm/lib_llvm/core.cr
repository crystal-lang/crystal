require "./types"

lib LibLLVM
  # NOTE: the following C enums usually have different values from their C++
  # counterparts (e.g. `LLVMModuleFlagBehavior` v.s. `LLVM::Module::ModFlagBehavior`)

  enum ModuleFlagBehavior
    Error        = 0
    Warning      = 1
    Require      = 2
    Override     = 3
    Append       = 4
    AppendUnique = 5
  end

  alias AttributeIndex = UInt

  fun dispose_message = LLVMDisposeMessage(message : Char*)

  fun create_context = LLVMContextCreate : ContextRef
  fun dispose_context = LLVMContextDispose(c : ContextRef)

  fun get_md_kind_id_in_context = LLVMGetMDKindIDInContext(c : ContextRef, name : Char*, s_len : UInt) : UInt

  fun get_enum_attribute_kind_for_name = LLVMGetEnumAttributeKindForName(name : Char*, s_len : SizeT) : UInt
  fun get_last_enum_attribute_kind = LLVMGetLastEnumAttributeKind : UInt
  fun create_enum_attribute = LLVMCreateEnumAttribute(c : ContextRef, kind_id : UInt, val : UInt64) : AttributeRef
  fun create_string_attribute = LLVMCreateStringAttribute(c : ContextRef, k : Char*, k_length : UInt, v : Char*, v_length : UInt) : AttributeRef
  {% unless LibLLVM::IS_LT_120 %}
    fun create_type_attribute = LLVMCreateTypeAttribute(c : ContextRef, kind_id : UInt, type_ref : TypeRef) : AttributeRef
  {% end %}

  fun module_create_with_name_in_context = LLVMModuleCreateWithNameInContext(module_id : Char*, c : ContextRef) : ModuleRef
  fun get_module_identifier = LLVMGetModuleIdentifier(m : ModuleRef, len : SizeT*) : Char*
  fun set_module_identifier = LLVMSetModuleIdentifier(m : ModuleRef, ident : Char*, len : SizeT)
  fun set_target = LLVMSetTarget(m : ModuleRef, triple : Char*)
  fun add_module_flag = LLVMAddModuleFlag(m : ModuleRef, behavior : ModuleFlagBehavior, key : Char*, key_len : SizeT, val : MetadataRef)
  fun dump_module = LLVMDumpModule(m : ModuleRef)
  fun print_module_to_file = LLVMPrintModuleToFile(m : ModuleRef, filename : Char*, error_message : Char**) : Bool
  fun print_module_to_string = LLVMPrintModuleToString(m : ModuleRef) : Char*
  {% if !LibLLVM::IS_LT_130 %}
    fun get_inline_asm = LLVMGetInlineAsm(ty : TypeRef, asm_string : Char*, asm_string_size : SizeT, constraints : Char*, constraints_size : SizeT, has_side_effects : Bool, is_align_stack : Bool, dialect : LLVM::InlineAsmDialect, can_throw : Bool) : ValueRef
  {% else %}
    fun get_inline_asm = LLVMGetInlineAsm(t : TypeRef, asm_string : Char*, asm_string_size : SizeT, constraints : Char*, constraints_size : SizeT, has_side_effects : Bool, is_align_stack : Bool, dialect : LLVM::InlineAsmDialect) : ValueRef
  {% end %}
  fun get_module_context = LLVMGetModuleContext(m : ModuleRef) : ContextRef

  fun add_function = LLVMAddFunction(m : ModuleRef, name : Char*, function_ty : TypeRef) : ValueRef
  fun get_named_function = LLVMGetNamedFunction(m : ModuleRef, name : Char*) : ValueRef
  fun get_first_function = LLVMGetFirstFunction(m : ModuleRef) : ValueRef
  fun get_next_function = LLVMGetNextFunction(fn : ValueRef) : ValueRef

  fun get_type_kind = LLVMGetTypeKind(ty : TypeRef) : LLVM::Type::Kind
  fun get_type_context = LLVMGetTypeContext(ty : TypeRef) : ContextRef
  fun print_type_to_string = LLVMPrintTypeToString(ty : TypeRef) : Char*

  fun int1_type_in_context = LLVMInt1TypeInContext(c : ContextRef) : TypeRef
  fun int8_type_in_context = LLVMInt8TypeInContext(c : ContextRef) : TypeRef
  fun int16_type_in_context = LLVMInt16TypeInContext(c : ContextRef) : TypeRef
  fun int32_type_in_context = LLVMInt32TypeInContext(c : ContextRef) : TypeRef
  fun int64_type_in_context = LLVMInt64TypeInContext(c : ContextRef) : TypeRef
  fun int128_type_in_context = LLVMInt128TypeInContext(c : ContextRef) : TypeRef
  fun int_type_in_context = LLVMIntTypeInContext(c : ContextRef, num_bits : UInt) : TypeRef
  fun get_int_type_width = LLVMGetIntTypeWidth(integer_ty : TypeRef) : UInt

  fun half_type_in_context = LLVMHalfTypeInContext(c : ContextRef) : TypeRef
  fun float_type_in_context = LLVMFloatTypeInContext(c : ContextRef) : TypeRef
  fun double_type_in_context = LLVMDoubleTypeInContext(c : ContextRef) : TypeRef
  fun x86_fp80_type_in_context = LLVMX86FP80TypeInContext(c : ContextRef) : TypeRef
  fun fp128_type_in_context = LLVMFP128TypeInContext(c : ContextRef) : TypeRef
  fun ppc_fp128_type_in_context = LLVMPPCFP128TypeInContext(c : ContextRef) : TypeRef

  fun function_type = LLVMFunctionType(return_type : TypeRef, param_types : TypeRef*, param_count : UInt, is_var_arg : Bool) : TypeRef
  fun is_function_var_arg = LLVMIsFunctionVarArg(function_ty : TypeRef) : Bool
  fun get_return_type = LLVMGetReturnType(function_ty : TypeRef) : TypeRef
  fun count_param_types = LLVMCountParamTypes(function_ty : TypeRef) : UInt
  fun get_param_types = LLVMGetParamTypes(function_ty : TypeRef, dest : TypeRef*)

  fun struct_type_in_context = LLVMStructTypeInContext(c : ContextRef, element_types : TypeRef*, element_count : UInt, packed : Bool) : TypeRef
  fun struct_create_named = LLVMStructCreateNamed(c : ContextRef, name : Char*) : TypeRef
  fun get_struct_name = LLVMGetStructName(ty : TypeRef) : Char*
  fun struct_set_body = LLVMStructSetBody(struct_ty : TypeRef, element_types : TypeRef*, element_count : UInt, packed : Bool)
  fun count_struct_element_types = LLVMCountStructElementTypes(struct_ty : TypeRef) : UInt
  fun get_struct_element_types = LLVMGetStructElementTypes(struct_ty : TypeRef, dest : TypeRef*)
  fun is_packed_struct = LLVMIsPackedStruct(struct_ty : TypeRef) : Bool

  fun get_element_type = LLVMGetElementType(ty : TypeRef) : TypeRef
  fun array_type = LLVMArrayType(element_type : TypeRef, element_count : UInt) : TypeRef
  fun get_array_length = LLVMGetArrayLength(array_ty : TypeRef) : UInt
  fun pointer_type = LLVMPointerType(element_type : TypeRef, address_space : UInt) : TypeRef
  {% unless LibLLVM::IS_LT_150 %}
    fun pointer_type_in_context = LLVMPointerTypeInContext(c : ContextRef, address_space : UInt) : TypeRef
  {% end %}
  fun vector_type = LLVMVectorType(element_type : TypeRef, element_count : UInt) : TypeRef
  fun get_vector_size = LLVMGetVectorSize(vector_ty : TypeRef) : UInt

  fun void_type_in_context = LLVMVoidTypeInContext(c : ContextRef) : TypeRef

  fun type_of = LLVMTypeOf(val : ValueRef) : TypeRef
  fun get_value_kind = LLVMGetValueKind(val : ValueRef) : LLVM::Value::Kind
  fun get_value_name2 = LLVMGetValueName2(val : ValueRef, length : SizeT*) : Char*
  fun set_value_name2 = LLVMSetValueName2(val : ValueRef, name : Char*, name_len : SizeT)
  fun dump_value = LLVMDumpValue(val : ValueRef)
  fun print_value_to_string = LLVMPrintValueToString(val : ValueRef) : Char*
  fun is_constant = LLVMIsConstant(val : ValueRef) : Bool
  fun get_value_name = LLVMGetValueName(val : ValueRef) : Char*
  fun set_value_name = LLVMSetValueName(val : ValueRef, name : Char*)

  fun get_operand = LLVMGetOperand(val : ValueRef, index : UInt) : ValueRef
  fun get_num_operands = LLVMGetNumOperands(val : ValueRef) : Int

  fun const_null = LLVMConstNull(ty : TypeRef) : ValueRef
  fun get_undef = LLVMGetUndef(ty : TypeRef) : ValueRef
  fun const_pointer_null = LLVMConstPointerNull(ty : TypeRef) : ValueRef

  fun const_int = LLVMConstInt(int_ty : TypeRef, n : ULongLong, sign_extend : Bool) : ValueRef
  fun const_int_of_arbitrary_precision = LLVMConstIntOfArbitraryPrecision(int_ty : TypeRef, num_words : UInt, words : UInt64*) : ValueRef
  fun const_real = LLVMConstReal(real_ty : TypeRef, n : Double) : ValueRef
  fun const_real_of_string = LLVMConstRealOfString(real_ty : TypeRef, text : Char*) : ValueRef
  fun const_real_of_string_and_size = LLVMConstRealOfStringAndSize(real_ty : TypeRef, text : Char*, s_len : UInt) : ValueRef
  fun const_int_get_zext_value = LLVMConstIntGetZExtValue(constant_val : ValueRef) : ULongLong
  fun const_int_get_sext_value = LLVMConstIntGetSExtValue(constant_val : ValueRef) : LongLong

  {% if LibLLVM::IS_LT_190 %}
    fun const_string_in_context = LLVMConstStringInContext(c : ContextRef, str : Char*, length : UInt, dont_null_terminate : Bool) : ValueRef
  {% else %}
    fun const_string_in_context2 = LLVMConstStringInContext2(c : ContextRef, str : Char*, length : SizeT, dont_null_terminate : Bool) : ValueRef
  {% end %}
  fun const_struct_in_context = LLVMConstStructInContext(c : ContextRef, constant_vals : ValueRef*, count : UInt, packed : Bool) : ValueRef
  fun const_array = LLVMConstArray(element_ty : TypeRef, constant_vals : ValueRef*, length : UInt) : ValueRef

  fun align_of = LLVMAlignOf(ty : TypeRef) : ValueRef
  fun size_of = LLVMSizeOf(ty : TypeRef) : ValueRef

  fun get_global_parent = LLVMGetGlobalParent(global : ValueRef) : ModuleRef
  fun get_linkage = LLVMGetLinkage(global : ValueRef) : LLVM::Linkage
  fun set_linkage = LLVMSetLinkage(global : ValueRef, linkage : LLVM::Linkage)
  fun set_dll_storage_class = LLVMSetDLLStorageClass(global : ValueRef, class : LLVM::DLLStorageClass)

  fun set_alignment = LLVMSetAlignment(v : ValueRef, bytes : UInt)

  fun add_global = LLVMAddGlobal(m : ModuleRef, ty : TypeRef, name : Char*) : ValueRef
  fun get_named_global = LLVMGetNamedGlobal(m : ModuleRef, name : Char*) : ValueRef
  fun get_initializer = LLVMGetInitializer(global_var : ValueRef) : ValueRef
  fun set_initializer = LLVMSetInitializer(global_var : ValueRef, constant_val : ValueRef)
  fun is_thread_local = LLVMIsThreadLocal(global_var : ValueRef) : Bool
  fun set_thread_local = LLVMSetThreadLocal(global_var : ValueRef, is_thread_local : Bool)
  fun is_global_constant = LLVMIsGlobalConstant(global_var : ValueRef) : Bool
  fun set_global_constant = LLVMSetGlobalConstant(global_var : ValueRef, is_constant : Bool)

  fun delete_function = LLVMDeleteFunction(fn : ValueRef)
  fun set_personality_fn = LLVMSetPersonalityFn(fn : ValueRef, personality_fn : ValueRef)
  fun get_function_call_convention = LLVMGetFunctionCallConv(fn : ValueRef) : LLVM::CallConvention
  fun set_function_call_convention = LLVMSetFunctionCallConv(fn : ValueRef, cc : LLVM::CallConvention)
  fun add_attribute_at_index = LLVMAddAttributeAtIndex(f : ValueRef, idx : AttributeIndex, a : AttributeRef)
  fun get_enum_attribute_at_index = LLVMGetEnumAttributeAtIndex(f : ValueRef, idx : AttributeIndex, kind_id : UInt) : AttributeRef
  fun add_target_dependent_function_attr = LLVMAddTargetDependentFunctionAttr(fn : ValueRef, a : Char*, v : Char*)

  fun get_count_params = LLVMCountParams(fn : ValueRef) : UInt
  fun get_params = LLVMGetParams(fn : ValueRef, params : ValueRef*)
  fun get_param = LLVMGetParam(fn : ValueRef, index : UInt) : ValueRef
  fun set_param_alignment = LLVMSetParamAlignment(arg : ValueRef, align : UInt)

  fun md_string_in_context2 = LLVMMDStringInContext2(c : ContextRef, str : Char*, s_len : SizeT) : ValueRef
  fun md_node_in_context2 = LLVMMDNodeInContext2(c : ContextRef, mds : ValueRef*, count : SizeT) : ValueRef
  fun metadata_as_value = LLVMMetadataAsValue(c : ContextRef, md : MetadataRef) : ValueRef
  fun value_as_metadata = LLVMValueAsMetadata(val : ValueRef) : MetadataRef
  fun get_md_node_num_operands = LLVMGetMDNodeNumOperands(v : ValueRef) : UInt
  fun get_md_node_operands = LLVMGetMDNodeOperands(v : ValueRef, dest : ValueRef*)
  fun md_string_in_context = LLVMMDStringInContext(c : ContextRef, str : Char*, s_len : UInt) : ValueRef
  fun md_node_in_context = LLVMMDNodeInContext(c : ContextRef, vals : ValueRef*, count : UInt) : ValueRef

  {% unless LibLLVM::IS_LT_180 %}
    fun create_operand_bundle = LLVMCreateOperandBundle(tag : Char*, tag_len : SizeT, args : ValueRef*, num_args : UInt) : OperandBundleRef
    fun dispose_operand_bundle = LLVMDisposeOperandBundle(bundle : OperandBundleRef)
  {% end %}

  fun get_basic_block_name = LLVMGetBasicBlockName(bb : BasicBlockRef) : Char*
  fun get_first_basic_block = LLVMGetFirstBasicBlock(fn : ValueRef) : BasicBlockRef
  fun get_next_basic_block = LLVMGetNextBasicBlock(bb : BasicBlockRef) : BasicBlockRef
  fun append_basic_block_in_context = LLVMAppendBasicBlockInContext(c : ContextRef, fn : ValueRef, name : Char*) : BasicBlockRef
  fun delete_basic_block = LLVMDeleteBasicBlock(bb : BasicBlockRef)
  fun get_first_instruction = LLVMGetFirstInstruction(bb : BasicBlockRef) : ValueRef

  fun set_metadata = LLVMSetMetadata(val : ValueRef, kind_id : UInt, node : ValueRef)
  fun get_next_instruction = LLVMGetNextInstruction(inst : ValueRef) : ValueRef

  fun get_num_arg_operands = LLVMGetNumArgOperands(instr : ValueRef) : UInt
  fun set_instruction_call_convention = LLVMSetInstructionCallConv(instr : ValueRef, cc : LLVM::CallConvention)
  fun get_instruction_call_convention = LLVMGetInstructionCallConv(instr : ValueRef) : LLVM::CallConvention
  fun set_instr_param_alignment = LLVMSetInstrParamAlignment(instr : ValueRef, idx : AttributeIndex, align : UInt)
  fun add_call_site_attribute = LLVMAddCallSiteAttribute(c : ValueRef, idx : AttributeIndex, a : AttributeRef)

  fun add_incoming = LLVMAddIncoming(phi_node : ValueRef, incoming_values : ValueRef*, incoming_blocks : BasicBlockRef*, count : UInt)

  fun create_builder_in_context = LLVMCreateBuilderInContext(c : ContextRef) : BuilderRef
  fun position_builder_at_end = LLVMPositionBuilderAtEnd(builder : BuilderRef, block : BasicBlockRef)
  fun get_insert_block = LLVMGetInsertBlock(builder : BuilderRef) : BasicBlockRef
  fun dispose_builder = LLVMDisposeBuilder(builder : BuilderRef)

  {% if LibLLVM::IS_LT_90 %}
    fun set_current_debug_location = LLVMSetCurrentDebugLocation(builder : BuilderRef, l : ValueRef)
  {% else %}
    fun get_current_debug_location2 = LLVMGetCurrentDebugLocation2(builder : BuilderRef) : MetadataRef
    fun set_current_debug_location2 = LLVMSetCurrentDebugLocation2(builder : BuilderRef, loc : MetadataRef)
  {% end %}
  fun get_current_debug_location = LLVMGetCurrentDebugLocation(builder : BuilderRef) : ValueRef

  fun build_ret_void = LLVMBuildRetVoid(BuilderRef) : ValueRef
  fun build_ret = LLVMBuildRet(BuilderRef, v : ValueRef) : ValueRef
  fun build_br = LLVMBuildBr(BuilderRef, dest : BasicBlockRef) : ValueRef
  fun build_cond = LLVMBuildCondBr(BuilderRef, if : ValueRef, then : BasicBlockRef, else : BasicBlockRef) : ValueRef
  fun build_switch = LLVMBuildSwitch(BuilderRef, v : ValueRef, else : BasicBlockRef, num_cases : UInt) : ValueRef
  fun build_invoke2 = LLVMBuildInvoke2(BuilderRef, ty : TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, then : BasicBlockRef, catch : BasicBlockRef, name : Char*) : ValueRef
  {% unless LibLLVM::IS_LT_180 %}
    fun build_invoke_with_operand_bundles = LLVMBuildInvokeWithOperandBundles(BuilderRef, ty : TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, then : BasicBlockRef, catch : BasicBlockRef, bundles : OperandBundleRef*, num_bundles : UInt, name : Char*) : ValueRef
  {% end %}
  fun build_unreachable = LLVMBuildUnreachable(BuilderRef) : ValueRef

  fun build_landing_pad = LLVMBuildLandingPad(b : BuilderRef, ty : TypeRef, pers_fn : ValueRef, num_clauses : UInt, name : Char*) : ValueRef
  fun build_catch_ret = LLVMBuildCatchRet(b : BuilderRef, catch_pad : ValueRef, bb : BasicBlockRef) : ValueRef
  fun build_catch_pad = LLVMBuildCatchPad(b : BuilderRef, parent_pad : ValueRef, args : ValueRef*, num_args : UInt, name : Char*) : ValueRef
  fun build_catch_switch = LLVMBuildCatchSwitch(b : BuilderRef, parent_pad : ValueRef, unwind_bb : BasicBlockRef, num_handlers : UInt, name : Char*) : ValueRef

  fun add_case = LLVMAddCase(switch : ValueRef, on_val : ValueRef, dest : BasicBlockRef)
  fun add_clause = LLVMAddClause(landing_pad : ValueRef, clause_val : ValueRef)
  fun set_cleanup = LLVMSetCleanup(landing_pad : ValueRef, val : Bool)
  fun add_handler = LLVMAddHandler(catch_switch : ValueRef, dest : BasicBlockRef)

  fun get_arg_operand = LLVMGetArgOperand(funclet : ValueRef, i : UInt) : ValueRef

  fun build_add = LLVMBuildAdd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fadd = LLVMBuildFAdd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sub = LLVMBuildSub(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fsub = LLVMBuildFSub(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_mul = LLVMBuildMul(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fmul = LLVMBuildFMul(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_udiv = LLVMBuildUDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_sdiv = LLVMBuildSDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_exact_sdiv = LLVMBuildExactSDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fdiv = LLVMBuildFDiv(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_urem = LLVMBuildURem(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_srem = LLVMBuildSRem(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_shl = LLVMBuildShl(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_lshr = LLVMBuildLShr(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_ashr = LLVMBuildAShr(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_and = LLVMBuildAnd(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_or = LLVMBuildOr(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_xor = LLVMBuildXor(BuilderRef, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_not = LLVMBuildNot(BuilderRef, value : ValueRef, name : Char*) : ValueRef
  fun build_neg = LLVMBuildNeg(BuilderRef, value : ValueRef, name : Char*) : ValueRef
  fun build_fneg = LLVMBuildFNeg(BuilderRef, value : ValueRef, name : Char*) : ValueRef

  fun build_malloc = LLVMBuildMalloc(BuilderRef, ty : TypeRef, name : Char*) : ValueRef
  fun build_array_malloc = LLVMBuildArrayMalloc(BuilderRef, ty : TypeRef, val : ValueRef, name : Char*) : ValueRef
  fun build_alloca = LLVMBuildAlloca(BuilderRef, ty : TypeRef, name : Char*) : ValueRef
  fun build_load2 = LLVMBuildLoad2(BuilderRef, ty : TypeRef, pointer_val : ValueRef, name : Char*) : ValueRef
  fun build_store = LLVMBuildStore(BuilderRef, val : ValueRef, ptr : ValueRef) : ValueRef
  fun build_gep2 = LLVMBuildGEP2(b : BuilderRef, ty : TypeRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt, name : Char*) : ValueRef
  fun build_inbounds_gep2 = LLVMBuildInBoundsGEP2(b : BuilderRef, ty : TypeRef, pointer : ValueRef, indices : ValueRef*, num_indices : UInt, name : Char*) : ValueRef
  fun build_global_string_ptr = LLVMBuildGlobalStringPtr(b : BuilderRef, str : Char*, name : Char*) : ValueRef
  fun set_volatile = LLVMSetVolatile(memory_access_inst : ValueRef, is_volatile : Bool)
  fun set_ordering = LLVMSetOrdering(memory_access_inst : ValueRef, ordering : LLVM::AtomicOrdering)

  fun build_trunc = LLVMBuildTrunc(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_zext = LLVMBuildZExt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_sext = LLVMBuildSExt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fp2ui = LLVMBuildFPToUI(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fp2si = LLVMBuildFPToSI(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ui2fp = LLVMBuildUIToFP(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_si2fp = LLVMBuildSIToFP(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fptrunc = LLVMBuildFPTrunc(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_fpext = LLVMBuildFPExt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_ptr2int = LLVMBuildPtrToInt(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_int2ptr = LLVMBuildIntToPtr(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef
  fun build_bit_cast = LLVMBuildBitCast(BuilderRef, val : ValueRef, dest_ty : TypeRef, name : Char*) : ValueRef

  fun build_icmp = LLVMBuildICmp(BuilderRef, op : LLVM::IntPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef
  fun build_fcmp = LLVMBuildFCmp(BuilderRef, op : LLVM::RealPredicate, lhs : ValueRef, rhs : ValueRef, name : Char*) : ValueRef

  fun build_phi = LLVMBuildPhi(BuilderRef, ty : TypeRef, name : Char*) : ValueRef
  fun build_call2 = LLVMBuildCall2(BuilderRef, TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, name : Char*) : ValueRef
  {% unless LibLLVM::IS_LT_180 %}
    fun build_call_with_operand_bundles = LLVMBuildCallWithOperandBundles(BuilderRef, TypeRef, fn : ValueRef, args : ValueRef*, num_args : UInt, bundles : OperandBundleRef*, num_bundles : UInt, name : Char*) : ValueRef
  {% end %}
  fun build_select = LLVMBuildSelect(BuilderRef, if : ValueRef, then : ValueRef, else : ValueRef, name : Char*) : ValueRef
  fun build_va_arg = LLVMBuildVAArg(BuilderRef, list : ValueRef, ty : TypeRef, name : Char*) : ValueRef
  fun build_extract_value = LLVMBuildExtractValue(BuilderRef, agg_val : ValueRef, index : UInt, name : Char*) : ValueRef
  fun build_fence = LLVMBuildFence(b : BuilderRef, ordering : LLVM::AtomicOrdering, single_thread : Bool, name : Char*) : ValueRef
  fun build_atomicrmw = LLVMBuildAtomicRMW(b : BuilderRef, op : LLVM::AtomicRMWBinOp, ptr : ValueRef, val : ValueRef, ordering : LLVM::AtomicOrdering, single_thread : Bool) : ValueRef
  fun build_atomic_cmp_xchg = LLVMBuildAtomicCmpXchg(b : BuilderRef, ptr : ValueRef, cmp : ValueRef, new : ValueRef, success_ordering : LLVM::AtomicOrdering, failure_ordering : LLVM::AtomicOrdering, single_thread : Bool) : ValueRef

  fun create_memory_buffer_with_contents_of_file = LLVMCreateMemoryBufferWithContentsOfFile(path : Char*, out_mem_buf : MemoryBufferRef*, out_message : Char**) : Bool
  fun get_buffer_start = LLVMGetBufferStart(mem_buf : MemoryBufferRef) : Char*
  fun get_buffer_size = LLVMGetBufferSize(mem_buf : MemoryBufferRef) : SizeT
  fun dispose_memory_buffer = LLVMDisposeMemoryBuffer(mem_buf : MemoryBufferRef)

  {% if LibLLVM::IS_LT_170 %}
    fun get_global_pass_registry = LLVMGetGlobalPassRegistry : PassRegistryRef

    fun pass_manager_create = LLVMCreatePassManager : PassManagerRef
    fun create_function_pass_manager_for_module = LLVMCreateFunctionPassManagerForModule(m : ModuleRef) : PassManagerRef
    fun run_pass_manager = LLVMRunPassManager(pm : PassManagerRef, m : ModuleRef) : Bool
    fun initialize_function_pass_manager = LLVMInitializeFunctionPassManager(fpm : PassManagerRef) : Bool
    fun run_function_pass_manager = LLVMRunFunctionPassManager(fpm : PassManagerRef, f : ValueRef) : Bool
    fun finalize_function_pass_manager = LLVMFinalizeFunctionPassManager(fpm : PassManagerRef) : Bool
    fun dispose_pass_manager = LLVMDisposePassManager(pm : PassManagerRef)
  {% end %}

  fun start_multithreaded = LLVMStartMultithreaded : Bool
  fun stop_multithreaded = LLVMStopMultithreaded
  fun is_multithreaded = LLVMIsMultithreaded : Bool
end
