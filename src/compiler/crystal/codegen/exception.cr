require "./codegen"

class Crystal::CodeGenVisitor
  @node_ensure_exception_handlers : Hash(ASTNode, Handler) = ({} of ASTNode => Handler).compare_by_identity

  def visit(node : ExceptionHandler)
    # In this codegen, we assume that LLVM only provides us with a basic try/catch abstraction with no
    # type restrictions on the exception caught. The basic strategy is to codegen this
    #
    # ```
    # begin
    #   body
    # else
    #   else_body
    # rescue ex : Ex1
    #   rescue_1_body
    # rescue ex : Ex2
    #   rescue_2_body
    # rescue ex
    #   rescue_3_body
    # ensure
    #   ensure_body
    # end
    # ```
    #
    # Into something like (assuming goto is implemented in crystal):
    #
    # ```
    # begin
    #   body
    # rescue ex
    #   begin
    #     if ex.is_a? Ex1
    #       rescue_1_body
    #     elsif ex.is_a? Ex2
    #       rescue_2_body
    #     else
    #       if rescue_3_body
    #         rescue_3_body
    #       else
    #         # If no handlers match and there is no generic handler, re-raise
    #         ensure_body
    #         raise ex
    #       end
    #     end
    #
    #     # Skip else_body if we ran an exception handler
    #     goto exit
    #   rescue ex2
    #    ensure_body
    #    raise ex2
    #   end
    # end
    #
    # else_body
    #
    # exit:
    # ensure_body
    # ```
    #
    # Note we codegen the ensure body three times! In practice this isn't a big deal, since ensure bodies are typically small.

    windows = @program.has_flag? "windows"

    context.fun.personality_function = windows_personality_fun.func if windows

    # This is the block which is entered when the body raises an exception
    rescue_block = new_block "rescue"

    node_rescues = node.rescues
    node_ensure = node.ensure
    node_else = node.else
    rescue_ensure_block = nil

    Phi.open(self, node, @needs_value) do |phi|
      # If there's an ensure block, even if the body/else
      # and all rescues are NoReturn we must still generate the
      # ensure part, which is done in the exit block.
      phi.force_exit_block = !!node_ensure

      # Keep track of the stack of ensure blocks inside the current function
      # This is used in codegenning returns to run the ensure blocks before returning
      ensure_exception_handlers = (@ensure_exception_handlers ||= [] of Handler)
      ensure_exception_handlers.push Handler.new(node, context)

      # Codegen the body of the exception handler
      # All exceptions raised in here will enter rescue_block. We tell the codegen to make this happen
      # by setting `@rescue_block`.
      old_rescue_block = @rescue_block
      @rescue_block = rescue_block
      accept node.body
      @rescue_block = old_rescue_block

      # Codegen the `else` block directly after the body of the rescue, except without
      # the rescue block set.
      # If there's an else, we take the value from it. Otherwise, the value is taken from the body.
      if node_else
        accept node_else
        phi.add @last, node_else.type?
      else
        phi.add @last, node.body.type?
      end

      # Here we start codegenning what happens once an exception is raised.
      # This code is responsible for finding the type of the exception, and
      # deciding which `rescue` block is entered (if any).
      # If no rescue block is entered, the ensure block is ran then the exception is re-raised.
      position_at_end rescue_block

      old_catch_pad = @catch_pad

      if windows
        # Windows structured exception handling must enter a catch_switch instruction
        # which decides which catch body block to enter. Crystal only ever generates one catch body
        # which is used for all exceptions. For more information on how structured exception handling works in LLVM,
        # see https://llvm.org/docs/ExceptionHandling.html#exception-handling-using-the-windows-runtime
        catch_body = new_block "catch_body"
        catch_switch = builder.catch_switch(@catch_pad || LLVM::Value.null, @rescue_block || LLVM::BasicBlock.null, 1)
        builder.add_handler catch_switch, catch_body

        # We're now generating the catch body, which must begin with a catchpad instruction
        position_at_end catch_body

        # Allocate space for the caught exception
        exception_type = @program.exception.virtual_type
        exception_llvm_type = llvm_type(exception_type)
        caught_exception_ptr = alloca exception_llvm_type

        # The catchpad instruction dictates which types of exceptions this block handles,
        # we want all of them, so we rescue all void* by passing the void_ptr_type_descriptor.
        # We also need to record the catch pad instruction in `@catch_pad` to refer to the parent catch
        # pad in nested rescue blocks, and to generate funclet information for function calls which are
        # "inside" this catchpad. More information on this is available in the link above.
        @catch_pad = builder.catch_pad catch_switch, [void_ptr_type_descriptor, int32(0), caught_exception_ptr]

        # builder.printf("catchpad entered #{node.location}\n", catch_pad: @catch_pad)

        caught_exception = load exception_llvm_type, caught_exception_ptr
        exception_type_id = type_id(caught_exception, exception_type)
      else
        # Unwind exception handling code - used on non-windows platforms - is a lot simpler.
        # First we generate the landing pad instruction, this returns a tuple of the libunwind
        # exception object and the type ID of the exception. This tuple is set up in the crystal
        # personality function in raise.cr
        lp_ret_type = llvm_typer.landing_pad_type
        lp = builder.landing_pad lp_ret_type, main_fun(personality_name).func, [] of LLVM::Value
        unwind_ex_obj = extract_value lp, 0
        exception_type_id = extract_value lp, 1

        # We call __crystal_get_exception to get the actual crystal `Exception` object.
        get_exception_fun = main_fun(GET_EXCEPTION_NAME)
        get_exception_arg_type = get_exception_fun.type.params_types.first # Void* or LibUnwind::Exception*
        get_exception_arg = pointer_cast(unwind_ex_obj, get_exception_arg_type)

        set_current_debug_location node if @debug.line_numbers?
        caught_exception_ptr = call get_exception_fun, [get_exception_arg]
        caught_exception = int2ptr caught_exception_ptr, llvm_typer.type_id_pointer
      end

      if node_rescues
        old_rescue_block = @rescue_block

        # Exceptions raised in a `rescue` block must be caught so that the `ensure` block can be ran.
        # Here we set up the rescue block for that purpose.
        if node_ensure
          rescue_ensure_block = new_block "rescue_ensure"
        else
          rescue_ensure_block = @rescue_block
        end

        node_rescues.each do |a_rescue|
          # For every rescue block, we generate a type ID check which branches to
          # `this_rescue_block` if the exception type is covered by the type restriction, or
          # branches to `next_rescue_block` if the restriction doesn't match.
          this_rescue_block, next_rescue_block = new_blocks "this_rescue", "next_rescue"
          if a_rescue_types = a_rescue.types
            cond = nil
            a_rescue_types.each do |type|
              rescue_type = type.type.instance_type.virtual_type
              rescue_type_cond = match_any_type_id(rescue_type, exception_type_id)
              cond = cond ? or(cond, rescue_type_cond) : rescue_type_cond
            end
            cond cond.not_nil!, this_rescue_block, next_rescue_block
          else
            br this_rescue_block
          end

          # If the rescue restriction matches, codegen the rescue block.
          position_at_end this_rescue_block

          # On windows, we are "inside" the catchpad block. It's difficult to track when to catch_ret when
          # codegenning the entire rescue body, so we catch_ret early and execute the rescue bodies "outside" the
          # rescue block.
          if catch_pad = @catch_pad
            catch_ret_target_block = new_block "this_rescue_target"
            builder.build_catch_ret catch_pad, catch_ret_target_block
            position_at_end catch_ret_target_block
          end

          saved_catch_pad = @catch_pad
          @catch_pad = old_catch_pad

          # We are generating code for rescues, so set up the rescue block.
          @rescue_block = rescue_ensure_block

          with_cloned_context do
            if a_rescue_name = a_rescue.name
              context.vars = context.vars.dup

              # Cast the caught exception to the type restriction, then assign it
              cast_caught_exception = cast_to caught_exception, a_rescue.type
              var = context.vars[a_rescue_name]
              assign var.pointer, var.type, a_rescue.type, cast_caught_exception
            end

            accept a_rescue.body
          end
          phi.add @last, a_rescue.body.type?

          @rescue_block = old_rescue_block

          # If the rescue restriction doesn't match, program flow falls through to the next
          # iteration of the loop, i.e. the next rescue block (or ensure block if this is the last iteration)
          position_at_end next_rescue_block
          @catch_pad = saved_catch_pad
        end
      end

      # Codegen the ensure block. We are currently inside the last `next_rescue_block`,
      # and none of the `rescue` blocks have matched.

      # We are generating the ensure block, so returns should no longer go via the ensure block,
      # or it would execute twice (and segfault).
      ensure_exception_handlers.pop

      # We codegen the ensure block, unlike the rescue blocks, inside the catchpad block.
      # This means we can re-raise efficiently, and is safe, since ensures cannot use return, next,
      # break or any other construct to jump outside of the ensure block.
      accept node_ensure if node_ensure

      # ensure finished, re-raise the current exception.
      codegen_re_raise(node, unwind_ex_obj)

      # This is the block in which all exceptions raised in any `rescue` block end up.
      # We want to run the ensure and re-raise.
      if node_ensure && rescue_ensure_block
        position_at_end rescue_ensure_block

        # Codegen catchswitch+pad or landing pad as described above.
        # This code is simpler because we never need to extract the exception type
        if windows
          rescue_ensure_body = new_block "rescue_ensure_body"
          catch_switch = builder.catch_switch(old_catch_pad || LLVM::Value.null, @rescue_block || LLVM::BasicBlock.null, 1)
          builder.add_handler catch_switch, rescue_ensure_body

          position_at_end rescue_ensure_body

          @catch_pad = builder.catch_pad catch_switch, [void_ptr_type_descriptor, int32(0), llvm_context.void_pointer.null]
        else
          lp_ret_type = llvm_typer.landing_pad_type
          lp = builder.landing_pad lp_ret_type, main_fun(personality_name).func, [] of LLVM::Value
          unwind_ex_obj = extract_value lp, 0
        end

        # Codegen ensure, then make sure we re-raise the exception.
        accept node_ensure
        codegen_re_raise(node, unwind_ex_obj)
      end

      # We are no longer inside the catch pad
      @catch_pad = old_catch_pad
    end

    # This is where codegen ends up if either no exception was raised or the exception was caught by a
    # `rescue` and the rescue didn't raise. In this case, we need to run the ensure block if any.
    # However, ensure blocks do not affect the return type of an exception handler, so we need to
    # save and restore @last to preserve the correct return value.
    old_last = @last
    accept node_ensure if node_ensure
    @last = old_last

    false
  end

  def codegen_re_raise(node, unwind_ex_obj)
    if @program.has_flag? "windows"
      # On windows we can re-raise by calling _CxxThrowException with two null arguments
      call windows_throw_fun, [llvm_context.void_pointer.null, llvm_context.void_pointer.null]
      unreachable
    else
      raise_fun = main_fun(RAISE_NAME)
      raise_fun_arg_type = raise_fun.func.params.first.type # Void* or LibUnwind::Exception*
      raise_fun_arg = pointer_cast(unwind_ex_obj.not_nil!, raise_fun_arg_type)
      codegen_call_or_invoke(node, nil, nil, raise_fun, [raise_fun_arg], true, @program.no_return)
    end
  end

  def execute_ensures_until(node)
    stop_exception_handler = @node_ensure_exception_handlers[node]?.try &.node

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
      @node_ensure_exception_handlers[node] = eh
    end
  end

  private def windows_throw_fun
    fetch_typed_fun(@llvm_mod, "_CxxThrowException") do
      LLVM::Type.function([@llvm_context.void_pointer, @llvm_context.void_pointer], @llvm_context.void, false)
    end
  end

  private def windows_personality_fun
    fetch_typed_fun(@llvm_mod, "__CxxFrameHandler3") do
      LLVM::Type.function([] of LLVM::Type, @llvm_context.int32, true)
    end
  end
end
