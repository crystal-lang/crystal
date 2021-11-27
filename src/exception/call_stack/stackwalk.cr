require "c/dbghelp"

# :nodoc:
struct Exception::CallStack
  skip(__FILE__)

  @@sym_loaded = false

  def self.load_debug_info
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

  private def self.load_debug_info_impl
    # TODO: figure out if and when to call SymCleanup (it cannot be done in
    # `at_exit` because unhandled exceptions in `main_user_code` are printed
    # after those handlers)
    executable_path = Process.executable_path
    executable_path_ptr = executable_path ? File.dirname(executable_path).to_utf16.to_unsafe : Pointer(LibC::WCHAR).null
    if LibC.SymInitializeW(LibC.GetCurrentProcess, executable_path_ptr, 1) == 0
      raise RuntimeError.from_winerror("SymInitializeW")
    end
    LibC.SymSetOptions(LibC.SymGetOptions | LibC::SYMOPT_UNDNAME | LibC::SYMOPT_LOAD_LINES | LibC::SYMOPT_FAIL_CRITICAL_ERRORS | LibC::SYMOPT_NO_PROMPTS)
  end

  def self.unwind
    load_debug_info

    machine_type = {% if flag?(:x86_64) %}
                     LibC::IMAGE_FILE_MACHINE_AMD64
                   {% elsif flag?(:i386) %}
                     # TODO: use WOW64_CONTEXT in place of CONTEXT
                     {% raise "x86 not supported" %}
                   {% else %}
                     {% raise "architecture not supported" %}
                   {% end %}

    # TODO: use stack if possible (must be 16-byte aligned)
    context = Pointer(LibC::CONTEXT).malloc(1)
    context.value.contextFlags = LibC::CONTEXT_FULL
    LibC.RtlCaptureContext(context)

    stack_frame = LibC::STACKFRAME64.new
    stack_frame.addrPC.mode = LibC::ADDRESS_MODE::AddrModeFlat
    stack_frame.addrFrame.mode = LibC::ADDRESS_MODE::AddrModeFlat
    stack_frame.addrStack.mode = LibC::ADDRESS_MODE::AddrModeFlat

    stack_frame.addrPC.offset = context.value.rip
    stack_frame.addrFrame.offset = context.value.rbp
    stack_frame.addrStack.offset = context.value.rsp

    stack = [] of Void*

    while true
      ret = LibC.StackWalk64(
        machine_type,
        LibC.GetCurrentProcess,
        LibC.GetCurrentThread,
        pointerof(stack_frame),
        context,
        nil,
        nil, # ->LibC.SymFunctionTableAccess64,
        nil, # ->LibC.SymGetModuleBase64,
        nil
      )
      break if ret == 0
      stack << Pointer(Void).new(stack_frame.addrPC.offset)
    end

    stack
  end

  protected def self.decode_line_number(pc)
    load_debug_info

    line_info = uninitialized LibC::IMAGEHLP_LINEW64
    line_info.sizeOfStruct = sizeof(LibC::IMAGEHLP_LINEW64)

    if LibC.SymGetLineFromAddrW64(LibC.GetCurrentProcess, pc, out displacement, pointerof(line_info)) != 0
      file_name = String.from_utf16(line_info.fileName)[0]
      line_number = line_info.lineNumber
    else
      line_number = 0
    end

    unless file_name
      module_info = Pointer(LibC::IMAGEHLP_MODULEW64).malloc(1)
      module_info.value.sizeOfStruct = sizeof(LibC::IMAGEHLP_MODULEW64)

      if LibC.SymGetModuleInfoW64(LibC.GetCurrentProcess, pc, module_info) != 0
        mod_displacement = pc - LibC.SymGetModuleBase64(LibC.GetCurrentProcess, pc)
        image_name = String.from_utf16(module_info.value.loadedImageName.to_unsafe)[0]
        file_name = "#{image_name} +#{mod_displacement}"
      else
        file_name = "??"
      end
    end

    {file_name, line_number, 0}
  end

  protected def self.decode_function_name(pc)
    load_debug_info

    symbol_size = sizeof(LibC::SYMBOL_INFOW) + (LibC::MAX_SYM_NAME - 1) * sizeof(LibC::WCHAR)
    symbol = Pointer(UInt8).malloc(symbol_size).as(LibC::SYMBOL_INFOW*)
    symbol.value.sizeOfStruct = sizeof(LibC::SYMBOL_INFOW)
    symbol.value.maxNameLen = LibC::MAX_SYM_NAME

    sym_displacement = LibC::DWORD64.zero
    if LibC.SymFromAddrW(LibC.GetCurrentProcess, pc, pointerof(sym_displacement), symbol) != 0
      String.from_utf16(symbol.value.name.to_unsafe.to_slice(symbol.value.nameLen))
    end
  end

  protected def self.decode_frame(pc)
  end

  protected def self.decode_address(ip)
    ip.address
  end
end
