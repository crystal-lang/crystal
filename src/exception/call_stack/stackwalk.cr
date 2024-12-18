require "c/dbghelp"

# :nodoc:
struct Exception::CallStack
  skip(__FILE__)

  @@sym_loaded = false

  def self.load_debug_info : Nil
    return if ENV["CRYSTAL_LOAD_DEBUG_INFO"]? == "0"

    unless @@sym_loaded
      @@sym_loaded = true
      begin
        load_debug_info_impl
      rescue ex
        Crystal::System.print_exception "Unable to load debug information", ex
      end
    end
  end

  private def self.load_debug_info_impl : Nil
    # TODO: figure out if and when to call SymCleanup (it cannot be done in
    # `at_exit` because unhandled exceptions in `main_user_code` are printed
    # after those handlers)
    executable_path = Process.executable_path
    executable_path_ptr = executable_path ? Crystal::System.to_wstr(File.dirname(executable_path)) : Pointer(LibC::WCHAR).null
    if LibC.SymInitializeW(LibC.GetCurrentProcess, executable_path_ptr, 1) == 0
      raise RuntimeError.from_winerror("SymInitializeW")
    end
    LibC.SymSetOptions(LibC.SymGetOptions | LibC::SYMOPT_UNDNAME | LibC::SYMOPT_LOAD_LINES | LibC::SYMOPT_FAIL_CRITICAL_ERRORS | LibC::SYMOPT_NO_PROMPTS)
  end

  def self.setup_crash_handler
    Crystal::System::Signal.setup_seh_handler
  end

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_call_stack_unwind)] {% end %}
  protected def self.unwind : Array(Void*)
    # TODO: use stack if possible (must be 16-byte aligned)
    context = Pointer(LibC::CONTEXT).malloc(1)
    context.value.contextFlags = LibC::CONTEXT_FULL
    LibC.RtlCaptureContext(context)

    stack = [] of Void*
    each_frame(context) do |frame|
      (frame.count + 1).times do
        stack << frame.ip
      end
    end
    stack
  end

  private def self.each_frame(context, &)
    # unlike DWARF, this is required on Windows to even be able to produce
    # correct stack traces, so we do it here but not in `libunwind.cr`
    load_debug_info

    machine_type = {% if flag?(:x86_64) %}
                     LibC::IMAGE_FILE_MACHINE_AMD64
                   {% elsif flag?(:i386) %}
                     # TODO: use WOW64_CONTEXT in place of CONTEXT
                     {% raise "x86 not supported" %}
                   {% elsif flag?(:aarch64) %}
                     LibC::IMAGE_FILE_MACHINE_ARM64
                   {% else %}
                     {% raise "Architecture not supported" %}
                   {% end %}

    stack_frame = LibC::STACKFRAME64.new
    stack_frame.addrPC.mode = LibC::ADDRESS_MODE::AddrModeFlat
    stack_frame.addrFrame.mode = LibC::ADDRESS_MODE::AddrModeFlat
    stack_frame.addrStack.mode = LibC::ADDRESS_MODE::AddrModeFlat

    {% if flag?(:x86_64) %}
      stack_frame.addrPC.offset = context.value.rip
      stack_frame.addrFrame.offset = context.value.rbp
      stack_frame.addrStack.offset = context.value.rsp
    {% elsif flag?(:aarch64) %}
      stack_frame.addrPC.offset = context.value.pc
      stack_frame.addrFrame.offset = context.value.x[29]
      stack_frame.addrStack.offset = context.value.sp
    {% end %}

    last_frame = nil
    cur_proc = LibC.GetCurrentProcess
    cur_thread = LibC.GetCurrentThread

    while true
      ret = LibC.StackWalk64(
        machine_type,
        cur_proc,
        cur_thread,
        pointerof(stack_frame),
        context,
        nil,
        nil, # ->LibC.SymFunctionTableAccess64,
        nil, # ->LibC.SymGetModuleBase64,
        nil
      )
      break if ret == 0

      ip = Pointer(Void).new(stack_frame.addrPC.offset)
      if last_frame
        if ip != last_frame.ip
          yield last_frame
          last_frame = RepeatedFrame.new(ip)
        else
          last_frame.incr
        end
      else
        last_frame = RepeatedFrame.new(ip)
      end
    end

    yield last_frame if last_frame
  end

  struct RepeatedFrame
    getter ip : Void*, count : Int32

    def initialize(@ip : Void*)
      @count = 0
    end

    def incr
      @count += 1
    end
  end

  private record StackContext, context : LibC::CONTEXT*, thread : LibC::HANDLE

  def self.print_backtrace(exception_info) : Nil
    each_frame(exception_info.value.contextRecord) do |frame|
      print_frame(frame)
    end
  end

  private def self.print_frame(repeated_frame)
    Crystal::System.print_error "[%p] ", repeated_frame.ip
    print_frame_location(repeated_frame)
    Crystal::System.print_error " (%d times)", repeated_frame.count + 1 unless repeated_frame.count == 0
    Crystal::System.print_error "\n"
  end

  private def self.print_frame_location(repeated_frame)
    if name = decode_function_name(repeated_frame.ip.address)
      file, line, _ = decode_line_number(repeated_frame.ip.address)
      if file != "??" && line != 0
        Crystal::System.print_error "%s at %s:%d", name, file, line
        return
      end
    end

    if frame = decode_frame(repeated_frame.ip)
      offset, sname, fname = frame
      Crystal::System.print_error "%s +%lld in %s", sname, offset.to_i64, fname
    else
      Crystal::System.print_error "???"
    end
  end

  protected def self.decode_line_number(pc)
    load_debug_info

    line_info = uninitialized LibC::IMAGEHLP_LINEW64
    line_info.sizeOfStruct = sizeof(LibC::IMAGEHLP_LINEW64)

    if LibC.SymGetLineFromAddrW64(LibC.GetCurrentProcess, pc, out displacement, pointerof(line_info)) != 0
      file_name = String.from_utf16(line_info.fileName)[0]
      line_number = line_info.lineNumber.to_i32
    else
      line_number = 0
    end

    unless file_name
      if m_info = sym_get_module_info(pc)
        offset, image_name = m_info
        file_name = "#{image_name} +#{offset}"
      else
        file_name = "??"
      end
    end

    {file_name, line_number, 0}
  end

  protected def self.decode_function_name(pc)
    if sym = sym_from_addr(pc)
      _, sname = sym
      sname
    end
  end

  protected def self.decode_frame(ip)
    pc = decode_address(ip)
    if sym = sym_from_addr(pc)
      if m_info = sym_get_module_info(pc)
        offset, sname = sym
        _, fname = m_info
        {offset, sname, fname}
      end
    end
  end

  private def self.sym_get_module_info(pc)
    load_debug_info

    module_info = Pointer(LibC::IMAGEHLP_MODULEW64).malloc(1)
    module_info.value.sizeOfStruct = sizeof(LibC::IMAGEHLP_MODULEW64)

    if LibC.SymGetModuleInfoW64(LibC.GetCurrentProcess, pc, module_info) != 0
      mod_displacement = pc - LibC.SymGetModuleBase64(LibC.GetCurrentProcess, pc)
      image_name = String.from_utf16(module_info.value.loadedImageName.to_unsafe)[0]
      {mod_displacement, image_name}
    end
  end

  private def self.sym_from_addr(pc)
    load_debug_info

    symbol_size = sizeof(LibC::SYMBOL_INFOW) + (LibC::MAX_SYM_NAME - 1) * sizeof(LibC::WCHAR)
    symbol = Pointer(UInt8).malloc(symbol_size).as(LibC::SYMBOL_INFOW*)
    symbol.value.sizeOfStruct = sizeof(LibC::SYMBOL_INFOW)
    symbol.value.maxNameLen = LibC::MAX_SYM_NAME

    sym_displacement = LibC::DWORD64.zero
    if LibC.SymFromAddrW(LibC.GetCurrentProcess, pc, pointerof(sym_displacement), symbol) != 0
      symbol_str = String.from_utf16(symbol.value.name.to_unsafe.to_slice(symbol.value.nameLen))
      {sym_displacement, symbol_str}
    end
  end

  protected def self.decode_address(ip)
    ip.address
  end
end
