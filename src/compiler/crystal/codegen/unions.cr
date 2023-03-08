# Here lies the logic of the representation of the MixedUnionType.
#
# Which structure is used to represent them is defined in `LLVMTyper#create_llvm_type`.
#
# The `#union_type_and_value_pointer` will allow to read the current value of the union.
# The `#store*_in_union` operations allow to write the value in a unions.
# The `#{assign|downcast|upcast}_distinct_union_types` operation matches the
# semantics described in `./casts.cr`
#
# Together these operations should encapsulate the binary representation of the MixedUnionType.
#
# Other unions like ReferenceUnionType that have a more trivial
# representation are not handled here.
#
module Crystal
  class LLVMTyper
    private def create_llvm_type(type : MixedUnionType, wants_size)
      llvm_name = llvm_name(type, wants_size)
      if s = @structs[llvm_name]?
        return s
      end

      @llvm_context.struct(llvm_name) do |a_struct|
        if wants_size
          @wants_size_cache[type] = a_struct
        else
          @cache[type] = a_struct
          @structs[llvm_name] = a_struct
        end

        max_size = 0
        type.expand_union_types.each do |subtype|
          unless subtype.void?
            size = size_of(llvm_type(subtype, wants_size: true))
            max_size = size if size > max_size
          end
        end

        max_size /= pointer_size.to_f
        max_size = max_size.ceil.to_i

        max_size = 1 if max_size == 0

        llvm_value_type = size_t.array(max_size)

        [@llvm_context.int32, llvm_value_type]
      end
    end

    def union_value_type(type : MixedUnionType)
      llvm_type(type).struct_element_types[1]
    end
  end

  class CodeGenVisitor
    def union_type_and_value_pointer(union_pointer, type : UnionType)
      raise "BUG: trying to access union_type_and_value_pointer of a #{type} from #{union_pointer}"
    end

    def union_type_and_value_pointer(union_pointer, type : MixedUnionType)
      struct_type = llvm_type(type)
      {
        load(llvm_context.int32, union_type_id(struct_type, union_pointer)),
        union_value(struct_type, union_pointer),
      }
    end

    def union_type_id(struct_type, union_pointer)
      aggregate_index struct_type, union_pointer, 0
    end

    def union_value(struct_type, union_pointer)
      aggregate_index struct_type, union_pointer, 1
    end

    def store_in_union(union_type, union_pointer, value_type, value)
      struct_type = llvm_type(union_type)
      store type_id(value, value_type), union_type_id(struct_type, union_pointer)
      casted_value_ptr = cast_to_pointer(union_value(struct_type, union_pointer), value_type)
      store value, casted_value_ptr
    end

    def store_bool_in_union(target_type, union_pointer, value)
      struct_type = llvm_type(target_type)
      store type_id(value, @program.bool), union_type_id(struct_type, union_pointer)

      # To store a boolean in a union
      # we sign-extend it to the size in bits of the union
      union_size = @llvm_typer.size_of(struct_type.struct_element_types[1])
      int_type = llvm_context.int((union_size * 8).to_i32)

      bool_as_extended_int = builder.zext(value, int_type)
      casted_value_ptr = pointer_cast(union_value(struct_type, union_pointer), int_type.pointer)
      store bool_as_extended_int, casted_value_ptr
    end

    def store_nil_in_union(target_type, union_pointer)
      struct_type = llvm_type(target_type)
      union_value_type = struct_type.struct_element_types[1]
      value = union_value_type.null

      store type_id(value, @program.nil), union_type_id(struct_type, union_pointer)
      casted_value_ptr = pointer_cast union_value(struct_type, union_pointer), union_value_type.pointer
      store value, casted_value_ptr
    end

    def store_void_in_union(target_type, union_pointer)
      struct_type = llvm_type(target_type)
      store type_id(@program.void), union_type_id(struct_type, union_pointer)
    end

    def assign_distinct_union_types(target_pointer, target_type, value_type, value)
      # If we have:
      # - target_pointer: Pointer(A | B | C)
      # - target_type: A | B | C
      # - value_type: A | B
      # - value: Pointer(A | B)
      #
      # Then we:
      # - load the value, we get A | B
      # - cast the target pointer to Pointer(A | B)
      # - store the A | B from the first pointer into the casted target pointer
      casted_target_pointer = cast_to_pointer target_pointer, value_type
      store load(llvm_type(value_type), value), casted_target_pointer
    end

    def downcast_distinct_union_types(value, to_type : MixedUnionType, from_type : MixedUnionType)
      cast_to_pointer value, to_type
    end

    def upcast_distinct_union_types(value, to_type : MixedUnionType, from_type : MixedUnionType)
      # Because we are casting a union to a bigger union, we need new space
      # for that, hence the alloca. Then we simply reuse `assign_distinct_union_types`.
      target_pointer = alloca llvm_type(to_type)
      assign_distinct_union_types target_pointer, to_type, from_type, value
      target_pointer
    end

    private def type_id_impl(value, type : MixedUnionType)
      union_type_and_value_pointer(value, type)[0]
    end
  end
end
