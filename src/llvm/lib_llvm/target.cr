require "./types"

lib LibLLVM
  type TargetDataRef = Void*

  {% for target in ALL_TARGETS %}
    {% name = target.downcase.id %}
    fun initialize_{{ name }}_target_info = LLVMInitialize{{ target.id }}TargetInfo
    fun initialize_{{ name }}_target = LLVMInitialize{{ target.id }}Target
    fun initialize_{{ name }}_target_mc = LLVMInitialize{{ target.id }}TargetMC
    fun initialize_{{ name }}_asm_printer = LLVMInitialize{{ target.id }}AsmPrinter
    fun initialize_{{ name }}_asm_parser = LLVMInitialize{{ target.id }}AsmParser
  {% end %}

  fun set_module_data_layout = LLVMSetModuleDataLayout(m : ModuleRef, dl : TargetDataRef)

  fun dispose_target_data = LLVMDisposeTargetData(td : TargetDataRef)
  fun size_of_type_in_bits = LLVMSizeOfTypeInBits(td : TargetDataRef, ty : TypeRef) : ULongLong
  fun abi_size_of_type = LLVMABISizeOfType(td : TargetDataRef, ty : TypeRef) : ULongLong
  fun abi_alignment_of_type = LLVMABIAlignmentOfType(td : TargetDataRef, ty : TypeRef) : UInt
  fun offset_of_element = LLVMOffsetOfElement(td : TargetDataRef, struct_ty : TypeRef, element : UInt) : ULongLong
  fun copy_string_rep_of_target_data = LLVMCopyStringRepOfTargetData(td : TargetDataRef) : Char*
end
