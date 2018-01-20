require "./codegen"

class Crystal::CodeGenVisitor
  @node_ensure_exception_handlers = {} of UInt64 => Handler

  def visit(node : ExceptionHandler)
    if @program.has_flag?("windows")
      windows_runtime_exception_handling(node)
    else
      landing_pad(node)
    end
  end

  private def windows_runtime_exception_handling(node : ExceptionHandler)
    context.fun.personality_function = @llvm_mod.functions[@personality_name]

    # http://llvm.org/docs/ExceptionHandling.html#overview
    rescue_block = new_block "rescue"

    node_rescues = node.rescues
    node_ensure = node.ensure
    node_else = node.else
    rescue_ensure_block = nil

    Phi.open(self, node, @needs_value) do |phi|
      phi.force_exit_block = !!node_ensure

      # 1)
      old_rescue_block = @rescue_block
      @rescue_block = rescue_block
      accept node.body
      @rescue_block = old_rescue_block

      # 2)
      # If there's an else, we take the value from it.
      # Otherwise, the value is taken from the body.
      if node_else
        accept node_else
        phi.add @last, node_else.type?
      else
        phi.add @last, node.body.type?
      end

      position_at_end rescue_block

      catch_body = new_block "catch.body"
      # if @catch_pad is not nil then this rescue block is inner
      # http://llvm.org/docs/ExceptionHandling.html#funclet-parent-tokens
      if c = @catch_pad
        cs = builder.catch_switch(c, old_rescue_block || LLVM::BasicBlock.null, 1)
      else
        cs = builder.catch_switch(nil, old_rescue_block || LLVM::BasicBlock.null, 1)
      end
      builder.add_handler cs, catch_body
      position_at_end catch_body

      image_base = external_constant(llvm_context.int8, "__ImageBase")
      base_type_descriptor = external_constant(llvm_context.void_pointer, "\u{1}??_7type_info@@6B@")

      # .PEAX is void*
      void_ptr_type_descriptor = @llvm_mod.globals.add(
        llvm_context.struct([
          llvm_context.void_pointer.pointer,
          llvm_context.void_pointer,
          llvm_context.int8.array(6),
        ]), "\u{1}??_R0PEAX@8")
      void_ptr_type_descriptor.initializer = llvm_context.const_struct [
        base_type_descriptor,
        llvm_context.void_pointer.null,
        llvm_context.const_string(".PEAX"),
      ]

      catchable_type = llvm_context.struct([llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32])
      void_ptr_catchable_type = @llvm_mod.globals.add(
        catchable_type, "_CT??_R0PEAX@88")
      void_ptr_catchable_type.initializer = llvm_context.const_struct [
        int32(1),
        sub_image_base(void_ptr_type_descriptor),
        int32(0),
        int32(-1),
        int32(0),
        int32(8),
        int32(0),
      ]

      catchable_type_array = llvm_context.struct([llvm_context.int32, llvm_context.int32.array(1)])
      catchable_void_ptr = @llvm_mod.globals.add(
        catchable_type_array, "_CTA1PEAX")
      catchable_void_ptr.initializer = llvm_context.const_struct [
        int32(1),
        llvm_context.int32.const_array([sub_image_base(void_ptr_catchable_type)]),
      ]

      eh_throwinfo = llvm_context.struct([llvm_context.int32, llvm_context.int32, llvm_context.int32, llvm_context.int32])
      void_ptr_throwinfo = @llvm_mod.globals.add(
        eh_throwinfo, "_TI1PEAX")
      void_ptr_throwinfo.initializer = llvm_context.const_struct [
        int32(0),
        int32(0),
        int32(0),
        sub_image_base(catchable_void_ptr),
      ]

      if node_rescues
        # 3)
        # Make sure the rescue knows about the current ensure
        # and the previous catch block
        old_rescue_block = @rescue_block
        @rescue_block = rescue_ensure_block || @rescue_block

        a_rescue = node_rescues[0]
        var = context.vars[a_rescue.name]
        old_catch_pad = @catch_pad
        @catch_pad = catch_pad = builder.catch_pad cs, [void_ptr_type_descriptor, int32(0), var.pointer]
        caught = new_block "caught"
        accept a_rescue.body
        builder.build_catch_ret catch_pad, caught
        @catch_pad = old_catch_pad

        position_at_end caught

        phi.add @last, a_rescue.body.type?
      end
    end

    old_last = @last
    builder_end = @builder.end

    @last = old_last

    false
  end

  private def landing_pad(node : ExceptionHandler)
    rescue_block = new_block "rescue"

    node_rescues = node.rescues
    node_ensure = node.ensure
    node_else = node.else
    rescue_ensure_block = nil

    # Here we transform this:
    #
    # ```
    # begin
    #   body
    # rescue ex : Ex1
    #   rescue_1_body
    # rescue ex : Ex2
    #   rescue_2_body
    # rescue
    #   rescue_3_body
    # ensure
    #   ensure_body
    # end
    # ```
    #
    # Into something like this:
    #
    # ```
    # # 1) Any exception raised in the body will end up in `rescue_block`
    # setup_rescue_block
    #
    # # 2) Codegen body, and `else` if available
    # body/else
    # goto exit
    #
    # # 3) Any exception raised in a rescue block will end up in `rescue_ensure_block`
    # setup_rescue_ensure_block
    #
    # # 4) rescue_block:
    # if ex.is_a?(Ex1)
    #   rescue_1_body
    #   goto exit
    # end
    #
    # if ex.is_a?(Ex2)
    #   rescue_2_body
    #   goto exit
    # end
    #
    # if ex
    #   rescue_3_body
    #   goto exit
    # end
    #
    # # 5) No raise clause matched, so we execute the ensure body and re-raise
    # # (can happen if there's no general `raise` or `raise ex` clause)
    # ensure_body
    # raise ex
    #
    # # 6) rescue_ensure_block:
    # ensure_body
    # raise ex
    #
    # # 7) exit:
    # ensure_body
    # ```
    #
    # Note that we generate the ensure body multiple times.
    # We could probably avoid this, but ensure bodies are usually small so
    # the code duplication is not so terrible.
    Phi.open(self, node, @needs_value) do |phi|
      # If there's an ensure block, even if the body/else
      # and all rescues are NoReturn we must still generate the
      # ensure part, which is done in the exit block.
      phi.force_exit_block = !!node_ensure

      ensure_exception_handlers = (@ensure_exception_handlers ||= [] of Handler)
      ensure_exception_handlers.push Handler.new(node, context)

      # 1)
      old_rescue_block = @rescue_block
      @rescue_block = rescue_block
      accept node.body
      @rescue_block = old_rescue_block

      # 2)
      # If there's an else, we take the value from it.
      # Otherwise, the value is taken from the body.
      if node_else
        accept node_else
        phi.add @last, node_else.type?
      else
        phi.add @last, node.body.type?
      end

      position_at_end rescue_block
      lp_ret_type = llvm_typer.landing_pad_type
      lp = builder.landing_pad lp_ret_type, main_fun(self.personality_name), [] of LLVM::Value
      unwind_ex_obj = extract_value lp, 0
      ex_type_id = extract_value lp, 1

      if node_rescues
        if node_ensure
          rescue_ensure_block = new_block "rescue_ensure"
        end

        # 3)
        # Make sure the rescue knows about the current ensure
        # and the previous catch block
        old_rescue_block = @rescue_block
        @rescue_block = rescue_ensure_block || @rescue_block

        node_rescues.each do |a_rescue|
          # 4)
          this_rescue_block, next_rescue_block = new_blocks "this_rescue", "next_rescue"
          if a_rescue_types = a_rescue.types
            cond = nil
            a_rescue_types.each do |type|
              rescue_type = type.type.instance_type.virtual_type
              rescue_type_cond = match_any_type_id(rescue_type, ex_type_id)
              cond = cond ? or(cond, rescue_type_cond) : rescue_type_cond
            end
            cond cond.not_nil!, this_rescue_block, next_rescue_block
          else
            br this_rescue_block
          end
          position_at_end this_rescue_block

          with_cloned_context do
            if a_rescue_name = a_rescue.name
              context.vars = context.vars.dup
              get_exception_fun = main_fun(GET_EXCEPTION_NAME)
              set_current_debug_location node if @debug.line_numbers?
              exception_ptr = call get_exception_fun, [bit_cast(unwind_ex_obj, get_exception_fun.params.first.type)]
              exception = int2ptr exception_ptr, llvm_typer.type_id_pointer
              unless a_rescue.type.virtual?
                exception = cast_to exception, a_rescue.type
              end
              var = context.vars[a_rescue_name]
              assign var.pointer, var.type, a_rescue.type, exception
            end

            accept a_rescue.body
          end
          phi.add @last, a_rescue.body.type?

          position_at_end next_rescue_block
        end

        @rescue_block = old_rescue_block
      end

      ensure_exception_handlers.pop

      # 5) No raise clause matched, so we execute the ensure body (if any) and re-raise
      accept node_ensure if node_ensure

      raise_fun = main_fun(RAISE_NAME)
      codegen_call_or_invoke(node, nil, nil, raise_fun, [bit_cast(unwind_ex_obj, raise_fun.params.first.type)], true, @program.no_return)
    end

    old_last = @last
    builder_end = @builder.end

    # 7)
    if node_ensure && !builder_end
      accept node_ensure
      builder_end = @builder.end
    end

    if node_ensure && rescue_ensure_block
      # 6)
      old_block = insert_block
      position_at_end rescue_ensure_block
      lp_ret_type = llvm_typer.landing_pad_type
      lp = builder.landing_pad lp_ret_type, main_fun(self.personality_name), [] of LLVM::Value
      unwind_ex_obj = extract_value lp, 0

      accept node_ensure
      raise_fun = main_fun(RAISE_NAME)
      codegen_call_or_invoke(node, nil, nil, raise_fun, [bit_cast(unwind_ex_obj, raise_fun.params.first.type)], true, @program.no_return)

      position_at_end old_block

      # Since we went to another block, we must restore the 'end' state
      @builder.end = builder_end
    end

    @last = old_last

    false
  end

  def execute_ensures_until(node)
    stop_exception_handler = @node_ensure_exception_handlers[node.object_id]?.try &.node

    @ensure_exception_handlers.try &.reverse_each do |exception_handler|
      break if exception_handler.node.same?(stop_exception_handler)

      target_ensure = exception_handler.node.ensure
      next unless target_ensure

      with_context(exception_handler.context) do
        accept target_ensure
      end
    end
  end

  def set_ensure_exception_handler(node)
    if eh = @ensure_exception_handlers.try &.last?
      @node_ensure_exception_handlers[node.object_id] = eh
    end
  end

  def external_constant(type, name)
    @llvm_mod.globals[name]? || begin
      c = @llvm_mod.globals.add(type, name)
      c.global_constant = true
      c
    end
  end

  def sub_image_base(value)
    image_base = external_constant(llvm_context.int8, "__ImageBase")

    @builder.trunc(
      @builder.sub(
        @builder.ptr2int(value, llvm_context.int64),
        @builder.ptr2int(image_base, llvm_context.int64)),
      llvm_context.int32)
  end
end
