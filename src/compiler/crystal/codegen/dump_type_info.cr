module Crystal
  class CodeGenVisitor
    private def dump_type_info(path)
      ids = @program.llvm_id.@ids.to_a
      ids.sort_by! { |_, (_, id)| id }

      File.open(path, "w") do |f|
        JSON.build(f) do |j|
          j.object do
            j.field "types" do
              j.array do
                ids.each do |type, (min_subtype_id, id)|
                  dump_single_type(j, type, min_subtype_id, id)
                end
              end
            end
          end
        end
      end
    end

    private def dump_single_type(j : JSON::Builder, type, min_subtype_id, id)
      unless type.is_a?(GenericClassType)
        llvm_type = llvm_type(type)
        if type.is_a?(InstanceVarContainer)
          llvm_struct_type = llvm_struct_type(type)
        end
      end

      j.object do
        j.field "name" do
          j.string do |io|
            type.to_s_with_options(io, codegen: true, generic_args: true)
          end
        end
        j.field "id", id
        j.field "min_subtype_id", min_subtype_id
        if supertype = type.superclass
          j.field "supertype_id", @program.llvm_id.type_id(supertype)
        end
        if type.metaclass?
          j.field "instance_type_id", @program.llvm_id.type_id(type.instance_type)
        end

        has_inner_pointers =
          if type.struct?
            type.has_inner_pointers?
          else
            type.is_a?(InstanceVarContainer) && type.all_instance_vars.each_value.any? &.type.has_inner_pointers?
          end
        j.field "has_inner_pointers", has_inner_pointers

        if llvm_type
          j.field "size", @llvm_typer.size_of(llvm_type)
          j.field "align", @llvm_typer.align_of(llvm_type)
        end

        if llvm_struct_type
          unless type.struct?
            j.field "instance_size", @llvm_typer.size_of(llvm_struct_type)
            j.field "instance_align", @llvm_typer.align_of(llvm_struct_type)
          end

          if type.allows_instance_vars?
            j.field "instance_vars" do
              j.array do
                type.all_instance_vars.each do |name, ivar|
                  ivar_offset, ivar_size = ivar_offset_and_size(type, llvm_struct_type, name, ivar.type)
                  j.object do
                    j.field "name", name
                    j.field "type_name" do
                      j.string do |io|
                        ivar.type.to_s_with_options(io, codegen: true)
                      end
                    end
                    j.field "offset", ivar_offset
                    j.field "size", ivar_size
                  end
                end
              end
            end
          end
        end
      end
    end

    private def ivar_offset_and_size(type, llvm_type, ivar_name, ivar_type) : {UInt64, UInt64}
      if type.extern_union? || type.is_a?(StaticArrayInstanceType)
        return 0_u64, @llvm_typer.size_of(llvm_type)
      end

      element_index = type.index_of_instance_var(ivar_name).not_nil!
      element_index += 1 unless type.struct?

      ivar_llvm_type =
        if type.extern?
          @llvm_typer.llvm_embedded_c_type(ivar_type, wants_size: true)
        else
          @llvm_typer.llvm_embedded_type(ivar_type, wants_size: true)
        end

      {
        @llvm_typer.offset_of(llvm_type, element_index),
        @llvm_typer.size_of(ivar_llvm_type),
      }
    end

    private def dump_type_id
      ids = @program.llvm_id.@ids.to_a
      ids.sort_by! { |_, (min, max)| {min, -max} }

      puts "CRYSTAL_DUMP_TYPE_ID"
      parent_ids = [] of {Int32, Int32}
      ids.each do |type, (min, max)|
        while parent_id = parent_ids.last?
          break if min >= parent_id[0] && max <= parent_id[1]
          parent_ids.pop
        end
        indent = " " * (2 * parent_ids.size)

        show_generic_args = type.is_a?(GenericInstanceType) ||
                            type.is_a?(GenericClassInstanceMetaclassType) ||
                            type.is_a?(GenericModuleInstanceMetaclassType)
        puts "#{indent}{#{min} - #{max}}: #{type.to_s(generic_args: show_generic_args)}"
        parent_ids << {min, max}
      end
      puts
    end
  end
end
