module Crystal::System
  # Prints directly to stderr without going through an `IO::FileDescriptor`.
  # This is useful for error messages from components that are required for
  # IO to work (fibers, scheduler, event_loop).
  def self.print_error(message, *args)
    printf(message, *args) { |bytes| print_error(bytes) }
  end

  def self.print_error(bytes : Bytes) : Nil
    {% if flag?(:unix) || flag?(:wasm32) %}
      LibC.write 2, bytes, bytes.size
    {% elsif flag?(:win32) %}
      LibC.WriteFile(LibC.GetStdHandle(LibC::STD_ERROR_HANDLE), bytes, bytes.size, out _, nil)
    {% end %}
  end

  # Print a UTF-16 slice as UTF-8 directly to stderr. Useful on Windows to print
  # strings returned from the unicode variant of the Win32 API.
  def self.print_error(bytes : Slice(UInt16)) : Nil
    utf8 = uninitialized UInt8[512]
    appender = utf8.to_unsafe.appender

    String.each_utf16_char(bytes) do |char|
      if appender.size > utf8.size - char.bytesize
        # buffer is full (char won't fit)
        print_error appender.to_slice
        appender = utf8.to_unsafe.appender
      end

      char.each_byte do |byte|
        appender << byte
      end
    end

    if appender.size > 0
      print_error appender.to_slice
    end
  end

  def self.print(handle : FileDescriptor::Handle, bytes : Bytes) : Nil
    {% if flag?(:unix) || flag?(:wasm32) %}
      LibC.write handle, bytes, bytes.size
    {% elsif flag?(:win32) %}
      LibC.WriteFile(Pointer(FileDescriptor::Handle).new(handle), bytes, bytes.size, out _, nil)
    {% end %}
  end

  # Minimal drop-in replacement for C `printf` function. Yields successive
  # non-empty `Bytes` to the block, which should do the actual printing.
  #
  # *format* only supports the `%(l|ll)?[dpsux]` format specifiers; more should
  # be added only when we need them or an external library passes its own format
  # string to here. *format* must also be null-terminated.
  #
  # Since this method may be called under low memory conditions or even with a
  # corrupted heap, its implementation should be as low-level as possible,
  # avoiding memory allocations.
  #
  # NOTE: Crystal's `printf` only supports a subset of C's `printf` format specifiers.
  # NOTE: MSVC uses `%X` rather than `0x%x`, we follow the latter on all platforms.
  def self.printf(format, *args, &)
    format = to_string_slice(format)
    format_len = format.size
    ptr = format.to_unsafe
    finish = ptr + format_len
    arg_index = 0

    # The widest integer types supported by the format specifier are `%lld` and
    # `%llu`, which do not exceed 64 bits, so we only need 20 digits maximum
    # note that `chars` does not have to be null-terminated, since we are
    # only yielding a `Bytes`
    int_chars = uninitialized UInt8[20]

    while ptr < finish
      next_percent = ptr
      while next_percent < finish && !(next_percent.value === '%')
        next_percent += 1
      end
      unless next_percent == ptr
        yield Slice.new(ptr, next_percent - ptr)
      end

      fmt_ptr = next_percent + 1
      width = 0
      if fmt_ptr.value === 'l'
        width = 1
        fmt_ptr += 1
        if fmt_ptr.value === 'l'
          width = 2
          fmt_ptr += 1
        end
      end

      break unless fmt_ptr < finish

      case fmt_ptr.value
      when 's'
        read_arg(String | Pointer(UInt8)) do |arg|
          yield to_string_slice(arg)
        end
      when 'd'
        read_arg(Int::Primitive) do |arg|
          yield to_int_slice(int_chars.to_slice, arg, 10, true, width)
        end
      when 'u'
        read_arg(Int::Primitive) do |arg|
          yield to_int_slice(int_chars.to_slice, arg, 10, false, width)
        end
      when 'x'
        read_arg(Int::Primitive) do |arg|
          yield to_int_slice(int_chars.to_slice, arg, 16, false, width)
        end
      when 'p'
        read_arg(Pointer(Void)) do |arg|
          yield "0x".to_slice
          yield to_int_slice(int_chars.to_slice, arg.address, 16, false, 2)
        end
      else
        yield Slice.new(next_percent, fmt_ptr + 1 - next_percent)
      end

      ptr = fmt_ptr + 1
    end
  end

  private macro read_arg(type, &block)
    {{ block.args[0] }} = args[arg_index]
    if {{ block.args[0] }}.is_a?({{ type }})
      {{ block.body }}
    else
      yield "(???)".to_slice
    end
    arg_index += 1
  end

  private def self.to_string_slice(str)
    if str.is_a?(UInt8*)
      if str.null?
        "(null)".to_slice
      else
        Slice.new(str, LibC.strlen(str))
      end
    else
      str.to_s.to_slice
    end
  end

  # simplified version of `Int#internal_to_s`
  protected def self.to_int_slice(buf, num, base, signed, width)
    if num == 0
      "0".to_slice
    else
      # NOTE: do not factor out `num`! it is written this way to inhibit
      # unnecessary union dispatches
      case {signed, width}
      when {true, 2}  then to_int_slice_impl(buf, LibC::LongLong.new!(num), base)
      when {true, 1}  then to_int_slice_impl(buf, LibC::Long.new!(num), base)
      when {true, 0}  then to_int_slice_impl(buf, LibC::Int.new!(num), base)
      when {false, 2} then to_int_slice_impl(buf, LibC::ULongLong.new!(num), base)
      when {false, 1} then to_int_slice_impl(buf, LibC::ULong.new!(num), base)
      else                 to_int_slice_impl(buf, LibC::UInt.new!(num), base)
      end
    end
  end

  private def self.to_int_slice_impl(buf, num, base)
    ptr_end = buf.to_unsafe + buf.size
    ptr = ptr_end

    neg = num < 0

    # do not assume Crystal constant initialization succeeds, hence not `DIGITS`
    digits = "0123456789abcdef".to_unsafe

    while num != 0
      ptr -= 1
      ptr.value = digits[num.remainder(base).abs]
      num = num.tdiv(base)
    end

    if neg
      ptr -= 1
      ptr.value = '-'.ord.to_u8
    end

    Slice.new(ptr, ptr_end - ptr)
  end

  def self.print_exception(message, ex)
    print_error "%s: %s (%s)\n", message, ex.message || "(no message)", ex.class.name
    begin
      if bt = ex.backtrace?
        bt.each do |frame|
          print_error "  from %s\n", frame
        end
      else
        print_error "  (no backtrace)\n"
      end
    rescue ex
      print_error "Error while trying to dump the backtrace: %s (%s)\n", ex.message || "(no message)", ex.class.name
    end
  end
end
