lib LibLLVM
  # LLVMBool
  alias Bool = LibC::Int

  type MemoryBufferRef = Void*
  type ContextRef = Void*
  type ModuleRef = Void*
  type TypeRef = Void*
  type ValueRef = Void*
  type BasicBlockRef = Void*
  type MetadataRef = Void*
  type BuilderRef = Void*
  type DIBuilderRef = Void*
  type PassManagerRef = Void*
  {% if LibLLVM::IS_LT_170 %}
    type PassRegistryRef = Void*
  {% end %}
  type OperandBundleRef = Void*
  type AttributeRef = Void*
end
