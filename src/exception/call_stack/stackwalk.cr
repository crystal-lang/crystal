require "c/dbghelp"

# :nodoc:
struct Exception::CallStack
  skip(__FILE__)

  @@sym_loaded = false

  # :nodoc:
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
    if LibC.SymInitializeW(LibC.GetCurrentProcess, nil, 1) == 0
      raise RuntimeError.from_errno("SymInitializeW")
    end
    LibC.SymSetOptions(LibC.SymGetOptions | LibC::SYMOPT_LOAD_LINES | LibC::SYMOPT_FAIL_CRITICAL_ERRORS | LibC::SYMOPT_NO_PROMPTS)
  end

  def self.unwind
    load_debug_info

    # TODO: use stack if possible (must be 16-byte aligned)
    context = Pointer(LibC::CONTEXT).malloc(1)
    context.value.contextFlags = LibC::CONTEXT_FULL
    LibC.RtlCaptureContext(context)

    stack_frame = LibC::STACKFRAME64.new
    stack_frame.addrPC.mode = LibC::ADDRESS_MODE::AddrModeFlat
    stack_frame.addrFrame.mode = LibC::ADDRESS_MODE::AddrModeFlat
    stack_frame.addrStack.mode = LibC::ADDRESS_MODE::AddrModeFlat

    machine_type = LibC::IMAGE_FILE_MACHINE_AMD64
    {% if flag?(:x86_64) %}
      stack_frame.addrPC.offset = context.value.rip
      stack_frame.addrFrame.offset = context.value.rbp
      stack_frame.addrStack.offset = context.value.rsp
    {% elsif flag?(:i386) %}
      machine_type = LibC::IMAGE_FILE_MACHINE_I386
      stack_frame.addrPC.offset = context.value.eip
      stack_frame.addrFrame.offset = context.value.ebp
      stack_frame.addrStack.offset = context.value.esp
    {% else %}
      {% raise "architecture not supported" %}
    {% end %}

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

  private def decode_backtrace
    show_full_info = ENV["CRYSTAL_CALLSTACK_FULL_INFO"]? == "1"

    @callstack.compact_map do |ip|
      pc = decode_address(ip)

      file, line_number, _ = CallStack.decode_line_number(pc)

      if file && file != "??"
        next if @@skip.includes?(file)

        # Turn to relative to the current dir, if possible
        if current_dir = CURRENT_DIR
          if rel = Path[file].relative_to?(current_dir)
            rel = rel.to_s
            file = rel unless rel.starts_with?("..")
          end
        end

        file_line = "#{file}:#{line_number}" unless line_number == "??"
      end

      if name = CallStack.decode_function_name(pc)
        function = name
      elsif frame = CallStack.decode_frame(ip)
        _, function, file = frame
        # Crystal methods (their mangled name) start with `*`, so
        # we remove that to have less clutter in the output.
        function = function.lchop('*')
      else
        function = "??"
      end

      if file_line
        line = "#{file_line} in '#{function}'"
      else
        if file == "??" && function == "??"
          line = "???"
        else
          line = "#{file} in '#{function}'"
        end
      end

      if show_full_info
        line = "#{line} at 0x#{ip.address.to_s(16)}"
      end

      line
    end
  end

  protected def self.decode_line_number(pc)
    load_debug_info

    line_info = uninitialized LibC::IMAGEHLP_LINEW64
    line_info.sizeOfStruct = sizeof(LibC::IMAGEHLP_LINEW64)

    displacement = uninitialized LibC::DWORD
    if LibC.SymGetLineFromAddrW64(LibC.GetCurrentProcess, pc, pointerof(displacement), pointerof(line_info)) != 0
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
        file_name = "#{String.from_utf16(module_info.value.loadedImageName.to_unsafe)[0]}+0x#{mod_displacement.to_s(16)}"
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
      String.from_utf16(symbol.value.name.to_unsafe)[0]
      # UnDecorateSymbolNameW
    end
  end

  protected def self.decode_frame(pc)
  end

  private def decode_address(ip)
    ip.address
  end
end
