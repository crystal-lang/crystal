require "./codegen"

class Crystal::CodeGenVisitor
  private SHADOW_STACK_HEAD_NAME = "__crystal_shadow_stack_head"

  # ABI shared with exception/call_stack/wasm.cr.
  #
  # Frames live on the stack; metadata and its Crystal strings live for the
  # entire module. Its head belongs to the single-threaded WASM runtime.
  # Future context switching must save and restore it.
  #
  # Only retain frames while generating their function bodies: deleted LLVM
  # functions can have their handles reused by functions without frames.
  @shadow_stack_frames = {} of LLVM::Function => {LLVM::Value, String}

  private def shadow_stack_enabled?
    @program.codegen_target.wasm? && @debug.wasm_line_numbers?
  end

  private def shadow_stack_frame_type
    llvm_context.struct([llvm_context.void_pointer, llvm_context.void_pointer])
  end

  private def shadow_stack_head
    unless @main_mod.globals[SHADOW_STACK_HEAD_NAME]?
      global = @main_mod.globals.add(@main_llvm_context.void_pointer, SHADOW_STACK_HEAD_NAME)
      global.initializer = @main_llvm_context.void_pointer.null
    end
    @llvm_mod.globals[SHADOW_STACK_HEAD_NAME]? || @llvm_mod.globals.add(llvm_context.void_pointer, SHADOW_STACK_HEAD_NAME)
  end

  private def shadow_stack_push(name, location)
    return unless shadow_stack_enabled?

    frame = alloca(shadow_stack_frame_type, "shadow_stack_frame")
    @shadow_stack_frames[context.fun] = {frame, name}
    store load(llvm_context.void_pointer, shadow_stack_head), gep(shadow_stack_frame_type, frame, 0, 0)
    shadow_stack_location(location || UNKNOWN_LOCATION)
    shadow_stack_restore
  end

  private def shadow_stack_location(location)
    return unless shadow_stack_enabled?
    return unless location = location.try &.expanded_location
    return unless info = @shadow_stack_frames[context.fun]?

    frame, name = info

    initializer = llvm_context.const_struct([
      build_string_constant(name),
      build_string_constant(location.original_filename || "??"),
      int32(location.line_number),
      int32(location.column_number),
    ])

    metadata = @llvm_mod.globals.add(initializer.type, "shadow_stack_metadata")
    metadata.linkage = LLVM::Linkage::Private
    metadata.global_constant = true
    metadata.initializer = initializer

    store cast_to_void_pointer(metadata), gep(shadow_stack_frame_type, frame, 0, 1)
  end

  private def shadow_stack_restore
    return unless shadow_stack_enabled?
    return unless info = @shadow_stack_frames[context.fun]?

    store cast_to_void_pointer(info[0]), shadow_stack_head
  end

  private def shadow_stack_pop
    return unless shadow_stack_enabled?
    return unless info = @shadow_stack_frames[context.fun]?

    store load(llvm_context.void_pointer, gep(shadow_stack_frame_type, info[0], 0, 0)), shadow_stack_head
  end
end
