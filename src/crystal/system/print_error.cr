module Crystal::System
  # Prints directly to stderr without going through an `IO::FileDescriptor`.
  # This is useful for error messages from components that are required for
  # IO to work (fibers, scheduler, event_loop).
  def self.print_error(message, *args)
    print_error(message, *args) do |bytes|
      {% if flag?(:unix) %}
        LibC.write 2, bytes, bytes.size
      {% elsif flag?(:win32) %}
        LibC._write 2, bytes, bytes.size
      {% end %}
    end
  end

  # Minimal drop-in replacement for a C `printf` function. Currently the only
  # supported format specifiers are `%(l|ll)?[dpsux]`; more should be added only
  # when we need them or an external library passes its own format string here.
  # Since `print_error` may be called under low memory conditions or even with
  # a corrupted heap, this implementation should be as low-level as possible,
  # avoiding memory allocations wherever possible.
  #
  # Yields successive `Bytes` to the block, which should do the actual printing.
  #
  # Note that C's `printf` is incompatible with Crystal's `sprintf`, because the
  # latter does not support argument width specifiers nor `%p`.
  def self.print_error(format, *args, &)
    ptr, format_len = to_unsafe_string(format)
    finish = ptr + format_len
    arg_index = 0

    while ptr < finish
      next_percent = ptr
      while next_percent < finish && !(next_percent.value === '%')
        next_percent += 1
      end
      yield Slice.new(ptr, next_percent - ptr)

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
        if (arg = args[arg_index].as?(String | UInt8*)).nil?
          yield "(???)".to_slice
        else
          yield Slice.new(*to_unsafe_string(arg))
        end
        arg_index += 1
      when 'd'
        if (arg = args[arg_index].as?(Int::Primitive)).nil?
          yield "(???)".to_slice
        else
          to_unsafe_int(arg, 10, true, width) { |bytes| yield bytes }
        end
        arg_index += 1
      when 'u'
        if (arg = args[arg_index].as?(Int::Primitive)).nil?
          yield "(???)".to_slice
        else
          to_unsafe_int(arg, 10, false, width) { |bytes| yield bytes }
        end
        arg_index += 1
      when 'x'
        if (arg = args[arg_index].as?(Int::Primitive)).nil?
          yield "(???)".to_slice
        else
          to_unsafe_int(arg, 16, false, width) { |bytes| yield bytes }
        end
        arg_index += 1
      when 'p'
        if (arg = args[arg_index].as?(Void*)).nil?
          yield "(???)".to_slice
        else
          # NOTE: MSVC uses `%X` rather than `0x%x`, we follow the latter on all platforms
          yield "0x".to_slice
          to_unsafe_int(arg.address, 16, false, 2) { |bytes| yield bytes }
        end
        arg_index += 1
      else
        yield Slice.new(next_percent, fmt_ptr + 1 - next_percent)
      end

      ptr = fmt_ptr + 1
    end
  end

  private def self.to_unsafe_string(str)
    if str.is_a?(UInt8*)
      {str, LibC.strlen(str)}
    else
      str = str.to_s
      {str.to_unsafe, str.bytesize}
    end
  end

  # simplified version of `Int#internal_to_s`
  private def self.to_unsafe_int(num, base, signed, width, &)
    if num == 0
      yield "0".to_slice
      return
    end

    # Given sizeof(num) <= 64 bits, we need at most 20 bytes for `%d` or `%u`
    # note that `chars` does not have to be null-terminated, since we are
    # only yielding a `Bytes`
    chars = uninitialized UInt8[20]
    ptr_end = chars.to_unsafe + 20
    ptr = ptr_end

    num = case {signed, width}
          when {true, 2}  then LibC::LongLong.new!(num)
          when {true, 1}  then LibC::Long.new!(num)
          when {true, 0}  then LibC::Int.new!(num)
          when {false, 2} then LibC::ULongLong.new!(num)
          when {false, 1} then LibC::ULong.new!(num)
          else                 LibC::UInt.new!(num)
          end

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

    yield Slice.new(ptr, ptr_end - ptr)
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
