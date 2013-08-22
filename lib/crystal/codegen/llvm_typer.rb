module Crystal
  class LLVMTyper
    HIERARCHY_LLVM_TYPE = LLVM::Type.struct([LLVM::Int, LLVM::Pointer(LLVM::Int8)], true, "Object+")
    HIERARCHY_LLVM_ARG_TYPE = LLVM::Pointer(HIERARCHY_LLVM_TYPE)

    def initialize
      @cache = {}
      @struct_cache = {}
      @embedded_cache = {}
      @arg_cache = {}
    end

    def llvm_type(type)
      unless llvm_type = @cache[type.type_id]
        llvm_type = case type
                    when PrimitiveType
                      type.llvm_type
                    when NoReturnType
                      LLVM.Void
                    when PointerInstanceType
                      LLVM::Pointer(llvm_embedded_type(type.var.type))
                    when InstanceVarContainer
                      LLVM::Pointer(llvm_struct_type(type))
                    when UnionType
                      if type.nilable?
                        llvm_type(type.nilable_type)
                      else
                        llvm_value_type = LLVM::Type.array(LLVM::Int, type.llvm_value_size.fdiv(LLVM::Int.type.width / 8).ceil)
                        LLVM::Type.struct([LLVM::Int, llvm_value_type], true, type.llvm_name)
                      end
                    when Metaclass, GenericClassInstanceMetaclass, HierarchyTypeMetaclass
                      LLVM::Int
                    when CStructType
                      LLVM::Pointer(llvm_struct_type(type))
                    when CUnionType
                      LLVM::Pointer(llvm_struct_type(type))
                    when TypeDefType
                      llvm_type(type.type)
                    when HierarchyType
                      HIERARCHY_LLVM_TYPE
                    else
                      raise "Unexepcted type #{type} in llvm_type"
                    end

        @cache[type.type_id] = llvm_type
      end
      llvm_type
    end

    def llvm_struct_type(type)
      unless llvm_type = @struct_cache[type.type_id]
        llvm_type = case type
                    when InstanceVarContainer
                      @struct_cache[type.type_id] = llvm_struct_type = LLVM::Struct(type.llvm_name)
                      llvm_struct_type.element_types = type.all_instance_vars.values.map { |var| llvm_embedded_type(var.type) }
                      return llvm_struct_type
                    when CStructType
                      @struct_cache[type.type_id] = llvm_struct_type = LLVM::Struct(type.llvm_name)
                      llvm_struct_type.element_types = type.vars.values.map { |var| llvm_embedded_type(var.type) }
                      return llvm_struct_type
                    when CUnionType
                      max_union_var = type.vars.values.max_by { |var| var.type.llvm_size }

                      llvm_struct_type = LLVM::Struct(type.llvm_name)
                      llvm_struct_type.element_types = [llvm_embedded_type(max_union_var.type)]
                      llvm_struct_type
                    else
                      raise "Unexepcted type #{type} in llvm_struct_type"
                    end

        @struct_cache[type.type_id] = llvm_type
      end
      llvm_type
    end

    def llvm_embedded_type(type)
      unless llvm_type = @embedded_cache[type.type_id]
        llvm_type = case type
                    when CStructType
                      llvm_struct_type(type)
                    when CUnionType
                      llvm_struct_type(type)
                    else
                      llvm_type(type)
                    end

        @embedded_cache[type.type_id] = llvm_type
      end
      llvm_type
    end

    def llvm_arg_type(type)
      unless llvm_type = @arg_cache[type.type_id]
        llvm_type = case type
                    when UnionType
                      type.union? ? LLVM::Pointer(llvm_type(type)) : llvm_type(type)
                    when HierarchyType
                      HIERARCHY_LLVM_ARG_TYPE
                    else
                      llvm_type(type)
                    end

        @arg_cache[type.type_id] = llvm_type
      end
      llvm_type
    end
  end
end