require "c/io"
require "c/consoleapi"
require "c/winnls"
require "io/overlapped"

module Crystal::System::FileDescriptor
  include IO::Overlapped

  @volatile_fd : Atomic(LibC::Int)
  @system_blocking = true

  # Residual bytes for character.
  @console_bytes = Slice(UInt8).empty
  @console_bytes_buffer : Slice(UInt8)?

  # UTF-16 code units from/to console.
  @console_units = Slice(UInt16).empty
  @console_units_buffer : Slice(UInt16)?

  private def unbuffered_read(slice : Bytes)
    handle = windows_handle
    if LibC.GetConsoleMode(handle, out _) != 0
      read_console(handle, slice)
    elsif system_blocking?
      bytes_read = LibC._read(fd, slice, slice.size)
      if bytes_read == -1
        if Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for reading"
        else
          raise IO::Error.from_errno("Error reading file")
        end
      end
      bytes_read
    else
      overlapped_operation(handle, "ReadFile", read_timeout) do |overlapped|
        ret = LibC.ReadFile(handle, slice, slice.size, out byte_count, overlapped)
        {ret, byte_count}
      end
    end
  end

  private def unbuffered_write(slice : Bytes)
    handle = windows_handle
    until slice.empty?
      if LibC.GetConsoleMode(handle, out _) != 0
        bytes_written = write_console(handle, slice)
      elsif system_blocking?
        bytes_written = LibC._write(fd, slice, slice.size)
        if bytes_written == -1
          if Errno.value == Errno::EBADF
            raise IO::Error.new "File not open for writing"
          else
            raise IO::Error.from_errno("Error writing file")
          end
        end
      else
        bytes_written = overlapped_operation(handle, "WriteFile", write_timeout, writing: true) do |overlapped|
          ret = LibC.WriteFile(handle, slice, slice.size, out byte_count, overlapped)
          {ret, byte_count}
        end
      end

      slice += bytes_written
    end
  end

  private def system_blocking?
    @system_blocking
  end

  private def system_blocking=(blocking)
    unless blocking == @system_blocking
      raise IO::Error.new("Cannot reconfigure `IO::FileDescriptor#blocking` after creation")
    end
  end

  private def system_blocking_init(value)
    @system_blocking = value
  end

  private def system_close_on_exec?
    false
  end

  private def system_close_on_exec=(close_on_exec)
    raise NotImplementedError.new("Crystal::System::FileDescriptor#system_close_on_exec=") if close_on_exec
  end

  private def system_closed?
    false
  end

  def self.fcntl(fd, cmd, arg = 0)
    raise NotImplementedError.new "Crystal::System::FileDescriptor.fcntl"
  end

  private def windows_handle
    FileDescriptor.windows_handle!(fd)
  end

  def self.windows_handle(fd)
    ret = LibC._get_osfhandle(fd)
    return LibC::INVALID_HANDLE_VALUE if ret == -1 || ret == -2
    LibC::HANDLE.new(ret)
  end

  def self.windows_handle!(fd)
    ret = LibC._get_osfhandle(fd)
    raise RuntimeError.from_errno("_get_osfhandle") if ret == -1
    raise RuntimeError.new("_get_osfhandle returned -2") if ret == -2
    LibC::HANDLE.new(ret)
  end

  def self.system_info(handle, file_type = nil)
    unless file_type
      file_type = LibC.GetFileType(handle)

      if file_type == LibC::FILE_TYPE_UNKNOWN
        error = WinError.value
        raise IO::Error.from_os_error("Unable to get info", error) unless error == WinError::ERROR_SUCCESS
      end
    end

    if file_type == LibC::FILE_TYPE_DISK
      if LibC.GetFileInformationByHandle(handle, out file_info) == 0
        raise IO::Error.from_winerror("Unable to get info")
      end

      ::File::Info.new(file_info, file_type)
    else
      ::File::Info.new(file_type)
    end
  end

  private def system_info
    FileDescriptor.system_info windows_handle
  end

  private def system_seek(offset, whence : IO::Seek) : Nil
    seek_value = LibC._lseeki64(fd, offset, whence)

    if seek_value == -1
      raise IO::Error.from_errno "Unable to seek"
    end
  end

  private def system_pos
    pos = LibC._lseeki64(fd, 0, IO::Seek::Current)
    raise IO::Error.from_errno "Unable to tell" if pos == -1
    pos
  end

  private def system_tty?
    LibC._isatty(fd) != 0
  end

  private def system_reopen(other : IO::FileDescriptor)
    # Windows doesn't implement the CLOEXEC flag
    if LibC._dup2(other.fd, self.fd) == -1
      raise IO::Error.from_errno("Could not reopen file descriptor")
    end

    # Mark the handle open, since we had to have dup'd a live handle.
    @closed = false
  end

  private def system_close
    LibC.CancelIoEx(windows_handle, nil) unless system_blocking?

    file_descriptor_close
  end

  def file_descriptor_close
    if LibC._close(fd) != 0
      case Errno.value
      when Errno::EINTR
        # ignore
      else
        raise IO::Error.from_errno("Error closing file")
      end
    end
  end

  private PIPE_BUFFER_SIZE = 8192

  def self.pipe(read_blocking, write_blocking)
    pipe_name = ::Path.windows(::File.tempname("crystal", nil, dir: %q(\\.\pipe))).normalize.to_s
    pipe_mode = 0 # PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT

    w_pipe_flags = LibC::PIPE_ACCESS_OUTBOUND | LibC::FILE_FLAG_FIRST_PIPE_INSTANCE
    w_pipe_flags |= LibC::FILE_FLAG_OVERLAPPED unless write_blocking
    w_pipe = LibC.CreateNamedPipeA(pipe_name, w_pipe_flags, pipe_mode, 1, PIPE_BUFFER_SIZE, PIPE_BUFFER_SIZE, 0, nil)
    raise IO::Error.from_winerror("CreateNamedPipeA") if w_pipe == LibC::INVALID_HANDLE_VALUE
    Crystal::Scheduler.event_loop.create_completion_port(w_pipe) unless write_blocking

    r_pipe_flags = LibC::FILE_FLAG_NO_BUFFERING
    r_pipe_flags |= LibC::FILE_FLAG_OVERLAPPED unless read_blocking
    r_pipe = LibC.CreateFileW(System.to_wstr(pipe_name), LibC::GENERIC_READ | LibC::FILE_WRITE_ATTRIBUTES, 0, nil, LibC::OPEN_EXISTING, r_pipe_flags, nil)
    raise IO::Error.from_winerror("CreateFileW") if r_pipe == LibC::INVALID_HANDLE_VALUE
    Crystal::Scheduler.event_loop.create_completion_port(r_pipe) unless read_blocking

    r = IO::FileDescriptor.new(LibC._open_osfhandle(r_pipe, 0), read_blocking)
    w = IO::FileDescriptor.new(LibC._open_osfhandle(w_pipe, 0), write_blocking)
    w.sync = true

    {r, w}
  end

  def self.pread(fd, buffer, offset)
    handle = windows_handle!(fd)

    overlapped = LibC::OVERLAPPED.new
    overlapped.union.offset.offset = LibC::DWORD.new(offset)
    overlapped.union.offset.offsetHigh = LibC::DWORD.new(offset >> 32)
    if LibC.ReadFile(handle, buffer, buffer.size, out bytes_read, pointerof(overlapped)) == 0
      error = WinError.value
      return 0_i64 if error == WinError::ERROR_HANDLE_EOF
      raise IO::Error.from_os_error "Error reading file", error
    end

    bytes_read.to_i64
  end

  def self.from_stdio(fd)
    console_handle = false
    handle = windows_handle(fd)
    if handle != LibC::INVALID_HANDLE_VALUE
      LibC._setmode fd, LibC::O_BINARY
      if LibC.GetConsoleMode(handle, out old_mode) != 0
        console_handle = true
        if fd == 1 || fd == 2 # STDOUT or STDERR
          if LibC.SetConsoleMode(handle, old_mode | LibC::ENABLE_VIRTUAL_TERMINAL_PROCESSING) != 0
            at_exit { LibC.SetConsoleMode(handle, old_mode) }
          end
        end
      end
    end

    io = IO::FileDescriptor.new(fd, blocking: true)
    # Set sync or flush_on_newline as described in STDOUT and STDERR docs.
    # See https://crystal-lang.org/api/toplevel.html#STDERR
    if console_handle
      io.sync = true
    else
      io.flush_on_newline = true
    end
    io
  end

  private def system_echo(enable : Bool, & : ->)
    system_console_mode(enable, LibC::ENABLE_ECHO_INPUT, 0) { yield }
  end

  private def system_raw(enable : Bool, & : ->)
    system_console_mode(enable, LibC::ENABLE_VIRTUAL_TERMINAL_INPUT, LibC::ENABLE_PROCESSED_INPUT | LibC::ENABLE_LINE_INPUT | LibC::ENABLE_ECHO_INPUT) { yield }
  end

  @[AlwaysInline]
  private def system_console_mode(enable, on_mask, off_mask, &)
    windows_handle = self.windows_handle
    if LibC.GetConsoleMode(windows_handle, out old_mode) == 0
      raise IO::Error.from_winerror("GetConsoleMode")
    end

    old_on_bits = old_mode & on_mask
    old_off_bits = old_mode & off_mask
    if enable
      return yield if old_on_bits == on_mask && old_off_bits == 0
      new_mode = (old_mode | on_mask) & ~off_mask
    else
      return yield if old_on_bits == 0 && old_off_bits == off_mask
      new_mode = (old_mode | off_mask) & ~on_mask
    end

    if LibC.SetConsoleMode(windows_handle, new_mode) == 0
      raise IO::Error.from_winerror("SetConsoleMode")
    end

    ret = yield
    if LibC.GetConsoleMode(windows_handle, pointerof(old_mode)) != 0
      new_mode = (old_mode & ~on_mask & ~off_mask) | old_on_bits | old_off_bits
      LibC.SetConsoleMode(windows_handle, new_mode)
    end
    ret
  end

  private CONSOLE_UNITS_BUFFER_SIZE = 1024

  private def console_bytes_buffer
    # Memory is allocated only when needed.
    # A character can be up to 4 bytes.
    @console_bytes_buffer ||= Slice(UInt8).new(4)
  end

  private def console_units_buffer
    # Memory is allocated only when needed.
    @console_units_buffer ||= Slice(UInt16).new(CONSOLE_UNITS_BUFFER_SIZE)
  end

  private def read_console(handle : LibC::HANDLE, slice : Bytes) : Int32
    # Handles residual bytes for character.
    bytes_read = Utils.safe_copy(@console_bytes, slice)
    @console_bytes += bytes_read
    slice += bytes_read
    return bytes_read if slice.empty?

    reader = Utils::UTF16Reader.new(@console_units)
    if reader.current_char_width == 0
      units_buffer = console_units_buffer

      # Handles residual UTF-16 code units.
      @console_units.copy_to(units_buffer)
      units_to_read = units_buffer.size - @console_units.size
      units_to_read = slice.size if slice.size < units_to_read

      # Reads code units from console.
      if 0 == LibC.ReadConsoleW(handle, units_buffer + @console_units.size, units_to_read, out units_read, nil)
        raise IO::Error.from_winerror("ReadConsoleW")
      end
      return bytes_read if units_read == 0
      @console_units = units_buffer[0, @console_units.size + units_read]
      reader = Utils::UTF16Reader.new(@console_units)
    end

    bytes_buffer = console_bytes_buffer
    reader.each do |char, width|
      # Handles `Ctrl-Z` (`EOF`)
      if char == '\u001A'
        @console_units += reader.pos > 0 ? reader.pos : width
        return bytes_read
      end

      char_bytes = Utils.to_utf8(char)
      count = Utils.safe_copy(char_bytes, slice)
      @console_bytes = bytes_buffer[0, char_bytes.size - count]
      @console_bytes.fill { |i| char_bytes[count + i] }

      bytes_read += count
      slice += count
      if slice.empty?
        @console_units += reader.pos + width
        return bytes_read
      end
    end
    @console_units += reader.pos
    bytes_read
  end

  private def write_console(handle : LibC::HANDLE, slice : Bytes) : Int32
    bytes_buffer = console_bytes_buffer
    units_buffer = console_units_buffer

    # Handles residual bytes for character.
    bytes_residual = @console_bytes.size
    count = Utils.safe_copy(slice, bytes_buffer + bytes_residual)
    @console_bytes = bytes_buffer[0, bytes_residual + count]
    reader = Utils::UTF8Reader.new(@console_bytes)
    return count if reader.current_char_width == 0

    units_to_write = Utils.safe_copy(Utils.to_utf16(reader.current_char), units_buffer)
    bytes_written = reader.current_char_width - bytes_residual
    slice += bytes_written

    reader = Utils::UTF8Reader.new(slice)
    reader.each do |char|
      char_units = Utils.to_utf16(char)
      break if units_to_write + char_units.size > units_buffer.size
      units_to_write += Utils.safe_copy(char_units, units_buffer + units_to_write)
    end
    bytes_written += reader.pos

    # NOTE: `@console_bytes` must hold bytes for incomplete (not complete) characters.
    if reader.current_char_width == 0
      count = Utils.safe_copy(slice + reader.pos, bytes_buffer)
      bytes_written += count
      @console_bytes = bytes_buffer[0, count]
    else
      @console_bytes = Slice(UInt8).empty
    end

    units = units_buffer[0, units_to_write]
    until units.empty?
      if 0 == LibC.WriteConsoleW(handle, units, units.size, out units_written, nil)
        raise IO::Error.from_winerror("WriteConsoleW")
      end
      units += units_written
    end
    bytes_written
  end

  # TODO: Some basic common APIs may be placed in the standard library in the future,
  # but more discussion and design are needed, so let's put them in this private module for now.
  private module Utils
    extend self

    private SURR0 = 0xD800
    private SURR1 = 0xDC00
    private SURR2 = 0xE000

    def safe_copy(src, dst) : Int32
      count = src.size < dst.size ? src.size : dst.size
      count.times { |i| dst[i] = src[i] }
      count
    end

    def safe_copy(src : Slice(T), dst : Slice(T)) : Int32 forall T
      count = src.size < dst.size ? src.size : dst.size
      src.copy_to(dst.to_unsafe, count)
      count
    end

    def valid_char?(char : Char) : Bool
      ord = char.ord
      0 <= ord < SURR0 || SURR2 <= ord <= Char::MAX_CODEPOINT
    end

    def codepoint(char : Char) : Int32
      valid_char?(char) ? char.ord : Char::REPLACEMENT.ord
    end

    def to_utf8(char : Char)
      code = codepoint(char)
      return {code.to_u8} if code < 0x80

      unit0 = code & 0x3F | 0x80
      code >>= 6
      return {(code | 0xC0).to_u8, unit0.to_u8} if code < 0x20

      unit1 = code & 0x3F | 0x80
      code >>= 6
      return {(code | 0xE0).to_u8, unit1.to_u8, unit0.to_u8} if code < 0x10

      unit2 = code & 0x3F | 0x80
      code >>= 6
      {(code | 0xF0).to_u8, unit2.to_u8, unit1.to_u8, unit0.to_u8}
    end

    def to_utf16(char : Char)
      code = codepoint(char)
      return {code.to_u16} if 0 <= code < SURR1 || SURR2 <= code < 0x10000

      code -= 0x10000
      unit0 = (SURR0 | code >> 10).to_u16
      unit1 = (SURR1 | code & 0x3FF).to_u16
      {unit0, unit1}
    end

    # Similar to `Char::Reader`, but more basic and common,
    # `Char::Reader` may be implemented by inheriting this class in the future.
    abstract class CharReader(T)
      # Returns the position of the current character.
      getter pos : Int32 = 0

      # Returns the current character.
      getter current_char : Char = Char::ZERO

      # Returns the code units width of the `#current_char`.
      getter current_char_width : Int32 = 0

      # If there was an error decoding the current char.
      # Returns the code unit that produced the invalid encoding.
      # Otherwise returns `nil`.
      getter error : T?

      private abstract def decode_char_at(pos : Int32) : {Char, Int32, T?}

      def each(&) : Nil
        @pos = 0
        loop do
          @current_char, @current_char_width, @error = decode_char_at(@pos)
          break if @current_char_width == 0
          yield @current_char, @current_char_width, @error
          @pos += @current_char_width
        end
      end
    end

    class UTF8Reader < CharReader(UInt8)
      def initialize(@units : Slice(UInt8))
        @current_char, @current_char_width, @error = decode_char_at(0)
      end

      private def decode_char_at(pos : Int32) : {Char, Int32, T?}
        units = @units + pos
        return Char::ZERO, 0, nil if units.empty?
        return units[0].unsafe_chr, 1, nil if units[0] < 0x80

        if units[0] & 0xE0 == 0xC0
          return Char::ZERO, 0, nil if units.size < 2
          return Char::REPLACEMENT, 1, units[0] if units[1] & 0xC0 != 0x80
          unit0 = (0x1F & units[0]) << 6
          unit1 = 0x3F & units[1]
          return (unit0 | unit1).unsafe_chr, 2, nil
        end

        if units[0] & 0xF0 == 0xE0
          return Char::ZERO, 0, nil if units.size < 2
          return Char::REPLACEMENT, 1, units[0] if units[1] & 0xC0 != 0x80
          return Char::ZERO, 0, nil if units.size < 3
          return Char::REPLACEMENT, 1, units[0] if units[2] & 0xC0 != 0x80
          unit0 = (0x0F & units[0]) << 12
          unit1 = (0x3F & units[1]) << 6
          unit2 = 0x3F & units[2]
          return (unit0 | unit1 | unit2).unsafe_chr, 3, nil
        end

        if units[0] & 0xF8 == 0xF0
          return Char::ZERO, 0, nil if units.size < 2
          return Char::REPLACEMENT, 1, units[0] if units[1] & 0xC0 != 0x80
          return Char::ZERO, 0, nil if units.size < 3
          return Char::REPLACEMENT, 1, units[0] if units[2] & 0xC0 != 0x80
          return Char::ZERO, 0, nil if units.size < 4
          return Char::REPLACEMENT, 1, units[0] if units[3] & 0xC0 != 0x80
          unit0 = (0x07 & units[0]) << 18
          unit1 = (0x3F & units[1]) << 12
          unit2 = (0x3F & units[2]) << 6
          unit3 = 0x3F & units[3]
          return (unit0 | unit1 | unit2 | unit3).unsafe_chr, 4, nil
        end

        {Char::REPLACEMENT, 1, units[0]}
      end
    end

    class UTF16Reader < CharReader(UInt16)
      def initialize(@units : Slice(UInt16))
        @current_char, @current_char_width, @error = decode_char_at(0)
      end

      private def decode_char_at(pos : Int32) : {Char, Int32, T?}
        units = @units + pos
        return Char::ZERO, 0, nil if units.empty?
        return units[0].unsafe_chr, 1, nil if units[0] < SURR0 || SURR2 <= units[0] < 0x10000
        return Char::REPLACEMENT, 1, units[0] if SURR1 <= units[0]
        return Char::ZERO, 0, nil if units.size < 2
        return Char::REPLACEMENT, 1, units[0] if units[1] < SURR1

        unit0 = units[0].to_i32 - SURR0
        unit1 = units[1].to_i32 - SURR1
        {(0x10000 + (unit0 << 10 | unit1)).unsafe_chr, 2, nil}
      end
    end
  end
end
