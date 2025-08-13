{% unless flag?(:win32) %}
  require "c/dlfcn"
{% end %}
require "c/stdio"
require "c/string"
require "../lib_unwind"

{% if flag?(:darwin) || flag?(:bsd) || flag?(:linux) || flag?(:solaris) || flag?(:win32) %}
  require "./dwarf"
{% else %}
  require "./null"
{% end %}

struct Exception::CallStack
  skip(__FILE__)

  {% if flag?(:gnu) && flag?(:i386) %}
    # This is only used for the workaround described in `Exception.unwind`
    @@makecontext_range : Range(Void*, Void*)?

    def self.makecontext_range
      @@makecontext_range ||= begin
        makecontext_start = makecontext_end = LibC.dlsym(LibC::RTLD_DEFAULT, "makecontext")

        while true
          ret = LibC.dladdr(makecontext_end, out info)
          break if ret == 0 || info.dli_sname.null?
          break unless LibC.strcmp(info.dli_sname, "makecontext") == 0
          makecontext_end += 1
        end

        (makecontext_start...makecontext_end)
      end
    end
  {% end %}

  def self.setup_crash_handler
    {% if flag?(:win32) %}
      Crystal::System::Signal.setup_seh_handler
    {% else %}
      Crystal::System::Signal.setup_segfault_handler
    {% end %}
  end

  {% if flag?(:interpreted) %} @[Primitive(:interpreter_call_stack_unwind)] {% end %}
  protected def self.unwind : Array(Void*)
    callstack = Array(Void*).new(32)
    backtrace_fn = ->(context : LibUnwind::Context, data : Void*) do
      bt = data.as(typeof(callstack))

      ip = {% if flag?(:arm) %}
             Pointer(Void).new(__crystal_unwind_get_ip(context))
           {% else %}
             Pointer(Void).new(LibUnwind.get_ip(context))
           {% end %}
      bt << ip

      {% if flag?(:gnu) && flag?(:i386) %}
        # This is a workaround for glibc bug: https://sourceware.org/bugzilla/show_bug.cgi?id=18635
        # The unwind info is corrupted when `makecontext` is used.
        # Stop the backtrace here. There is nothing interest beyond this point anyway.
        if CallStack.makecontext_range.includes?(ip)
          return LibUnwind::ReasonCode::END_OF_STACK
        end
      {% end %}

      LibUnwind::ReasonCode::NO_REASON
    end

    LibUnwind.backtrace(backtrace_fn, callstack.as(Void*))
    callstack
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

  def self.print_backtrace : Nil
    backtrace_fn = ->(context : LibUnwind::Context, data : Void*) do
      last_frame = data.as(RepeatedFrame*)

      ip = {% if flag?(:arm) %}
             Pointer(Void).new(__crystal_unwind_get_ip(context))
           {% else %}
             Pointer(Void).new(LibUnwind.get_ip(context))
           {% end %}

      if last_frame.value.ip == ip
        last_frame.value.incr
      else
        print_frame(last_frame.value) unless last_frame.value.ip.address == 0
        last_frame.value = RepeatedFrame.new ip
      end
      LibUnwind::ReasonCode::NO_REASON
    end

    rf = RepeatedFrame.new(Pointer(Void).null)
    LibUnwind.backtrace(backtrace_fn, pointerof(rf).as(Void*))
    print_frame(rf)
  end

  private def self.print_frame(repeated_frame)
    Crystal::System.print_error "[%p] ", repeated_frame.ip
    print_frame_location(repeated_frame)
    Crystal::System.print_error " (%d times)", repeated_frame.count + 1 unless repeated_frame.count == 0
    Crystal::System.print_error "\n"
  end

  private def self.print_frame_location(repeated_frame)
    {% if flag?(:debug) %}
      if @@dwarf_loaded
        pc = CallStack.decode_address(repeated_frame.ip)
        if name = decode_function_name(pc)
          file, line, column = Exception::CallStack.decode_line_number(pc)
          if file && file != "??"
            Crystal::System.print_error "%s at %s:%d:%d", name, file, line, column
            return
          end
        end
      end
    {% end %}

    unsafe_decode_frame(repeated_frame.ip) do |offset, sname, fname|
      Crystal::System.print_error "%s +%lld in %s", sname, offset.to_i64, fname
      return
    end

    Crystal::System.print_error "???"
  end

  protected def self.decode_frame(ip)
    decode_frame(ip) do |offset, symbol, file|
      symbol = symbol ? String.new(symbol) : "??"
      file = file ? String.new(file) : "??"
      {offset, symbol, file}
    end
  end

  # variant of `.decode_frame` that returns the C strings directly instead of
  # wrapping them in `String.new`, since the SIGSEGV handler cannot allocate
  # memory via the GC
  protected def self.unsafe_decode_frame(ip, &)
    decode_frame(ip) do |offset, symbol, file|
      symbol ||= "??".to_unsafe
      file ||= "??".to_unsafe
      yield offset, symbol, file
    end
  end

  private def self.decode_frame(ip, &)
    original_ip = ip
    while true
      retry = dladdr(ip) do |file, symbol, address|
        offset = original_ip - address
        if offset == 0
          ip -= 1
          true
        elsif symbol.null? && file.null?
          false
        else
          return yield offset, symbol, file
        end
      end
      break unless retry
    end
  end

  {% if flag?(:win32) %}
    def self.dladdr(ip, &)
      if LibC.GetModuleHandleExW(LibC::GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT | LibC::GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, ip.as(LibC::LPWSTR), out hmodule) != 0
        symbol, address = internal_symbol(hmodule, ip) || external_symbol(hmodule, ip) || return

        utf16_file = uninitialized LibC::WCHAR[LibC::MAX_PATH]
        len = LibC.GetModuleFileNameW(hmodule, utf16_file, utf16_file.size)
        if 0 < len < utf16_file.size
          utf8_file = uninitialized UInt8[sizeof(UInt8[LibC::MAX_PATH][3])]
          file = utf8_file.to_unsafe
          appender = file.appender
          String.each_utf16_char(utf16_file.to_slice[0, len + 1]) do |ch|
            ch.each_byte { |b| appender << b }
          end
        else
          file = Pointer(UInt8).null
        end

        yield file, symbol, address
      end
    end

    private def self.internal_symbol(hmodule, ip)
      if coff_symbols = @@coff_symbols
        if LibC.GetModuleHandleExW(LibC::GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, nil, out this_hmodule) != 0 && this_hmodule == hmodule
          section_base, section_index = lookup_section(hmodule, ip) || return
          offset = ip - section_base
          section_coff_symbols = coff_symbols[section_index]? || return
          next_sym = section_coff_symbols.bsearch_index { |sym| offset < sym.offset } || return
          sym = section_coff_symbols[next_sym - 1]? || return

          {sym.name.to_unsafe, section_base + sym.offset}
        end
      end
    end

    private def self.external_symbol(hmodule, ip)
      if dir = data_directory(hmodule, LibC::IMAGE_DIRECTORY_ENTRY_EXPORT)
        exports = dir.to_unsafe.as(LibC::IMAGE_EXPORT_DIRECTORY*).value

        found_address = Pointer(Void).null
        found_index = -1

        func_address_offsets = (hmodule + exports.addressOfFunctions).as(LibC::DWORD*).to_slice(exports.numberOfFunctions)
        func_address_offsets.each_with_index do |offset, i|
          address = hmodule + offset
          if found_address < address <= ip
            found_address, found_index = address, i
          end
        end

        return unless found_address

        func_name_ordinals = (hmodule + exports.addressOfNameOrdinals).as(LibC::WORD*).to_slice(exports.numberOfNames)
        if ordinal_index = func_name_ordinals.index(&.== found_index)
          symbol = (hmodule + (hmodule + exports.addressOfNames).as(LibC::DWORD*)[ordinal_index]).as(UInt8*)
          {symbol, found_address}
        end
      end
    end

    private def self.lookup_section(hmodule, ip)
      dos_header = hmodule.as(LibC::IMAGE_DOS_HEADER*)
      return unless dos_header.value.e_magic == 0x5A4D # MZ

      nt_header = (hmodule + dos_header.value.e_lfanew).as(LibC::IMAGE_NT_HEADERS*)
      return unless nt_header.value.signature == 0x00004550 # PE\0\0

      section_headers = (nt_header + 1).as(LibC::IMAGE_SECTION_HEADER*).to_slice(nt_header.value.fileHeader.numberOfSections)
      section_headers.each_with_index do |header, i|
        base = hmodule + header.virtualAddress
        if base <= ip < base + header.virtualSize
          return base, i
        end
      end
    end

    private def self.data_directory(hmodule, index)
      dos_header = hmodule.as(LibC::IMAGE_DOS_HEADER*)
      return unless dos_header.value.e_magic == 0x5A4D # MZ

      nt_header = (hmodule + dos_header.value.e_lfanew).as(LibC::IMAGE_NT_HEADERS*)
      return unless nt_header.value.signature == 0x00004550 # PE\0\0
      return unless nt_header.value.optionalHeader.magic == {{ flag?(:bits64) ? 0x20b : 0x10b }}
      return unless index.in?(0...{16, nt_header.value.optionalHeader.numberOfRvaAndSizes}.min)

      directory = nt_header.value.optionalHeader.dataDirectory.to_unsafe[index]
      if directory.virtualAddress != 0
        Bytes.new(hmodule.as(UInt8*) + directory.virtualAddress, directory.size, read_only: true)
      end
    end
  {% else %}
    private def self.dladdr(ip, &)
      if LibC.dladdr(ip, out info) != 0
        yield info.dli_fname, info.dli_sname, info.dli_saddr
      end
    end
  {% end %}
end
