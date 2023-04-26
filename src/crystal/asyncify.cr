{% skip_file unless flag?(:wasm32) %}

# :nodoc:
@[Link(wasm_import_module: "asyncify")]
lib LibAsyncify
  struct Data
    current_location : Void*
    end_location : Void*
  end

  fun start_unwind(data : Data*)
  fun stop_unwind
  fun start_rewind(data : Data*)
  fun stop_rewind
end

# :nodoc:
module Crystal::Asyncify
  enum State
    Normal
    Unwinding
    Rewinding
  end

  @@state = State::Normal
  class_getter! main_func, current_func

  # Reads the stack pointer global.
  def self.stack_pointer
    stack_pointer = uninitialized Void*
    asm("
      .globaltype __stack_pointer, i32
      global.get __stack_pointer
      local.set $0
    " : "=r"(stack_pointer))

    stack_pointer
  end

  # Sets the stack pointer global. Use this in conjuction with unwinding the stack.
  def self.stack_pointer=(stack_pointer : Void*)
    asm("
      .globaltype __stack_pointer, i32
      local.get $0
      global.set __stack_pointer
    " :: "r"(stack_pointer))
  end

  # Wraps the entrypoint to capture and stop stack unwindings and trigger a rewind
  # into the right point.
  @[NoInline]
  def self.wrap_main(&block)
    @@main_func = block
    @@current_func = block
    block.call

    until @@state.normal?
      @@state = State::Normal
      LibAsyncify.stop_unwind

      if before_rewind = @@before_rewind
        before_rewind.call
      end

      if rewind_data = @@rewind_data
        @@state = State::Rewinding
        LibAsyncify.start_rewind(rewind_data)
      end

      func = @@rewind_func.not_nil!
      @@current_func = func
      func.call
    end
  end

  # Performs a stack unwind. All stack local variables will be stored in the `unwind_data` buffer.
  # If a `rewind_data` buffer is provided, the stack will be rewinded into that position after unwinding.
  # `rewind_func` controls the execution target to invoke after unwinding. It can be a new function, the
  # main function or the currently executing function. Finally, the `before_rewind` callback can be used
  # to specify some action to do after unwinding and before rewinding.
  def self.unwind(
    *,
    unwind_data : LibAsyncify::Data*,
    rewind_data : LibAsyncify::Data*?,
    rewind_func : Proc(Void),
    before_rewind : Proc(Void)? = nil
  )
    @@rewind_data = rewind_data
    @@rewind_func = rewind_func
    @@before_rewind = before_rewind

    real_unwind(unwind_data)
  end

  @[NoInline]
  private def self.real_unwind(unwind_data : LibAsyncify::Data*)
    if @@state.rewinding?
      @@state = State::Normal
      LibAsyncify.stop_rewind
      return
    end

    @@state = State::Unwinding
    LibAsyncify.start_unwind(unwind_data)
  end
end
