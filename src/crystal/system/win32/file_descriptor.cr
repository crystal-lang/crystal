require "c/io"
require "c/consoleapi"
require "c/consoleapi2"
require "c/winnls"
require "io/overlapped"

module Crystal::System::FileDescriptor
  include IO::Overlapped

  # Platform-specific type to represent a file descriptor handle to the operating
  # system.
  alias Handle = ::LibC::Int

  @system_blocking = true

  private def unbuffered_read(slice : Bytes) : Int32
    handle = windows_handle
    if ConsoleUtils.console?(handle)
      ConsoleUtils.read(handle, slice)
    elsif system_blocking?
      if LibC.ReadFile(handle, slice, slice.size, out bytes_read, nil) == 0
        case error = WinError.value
        when .error_access_denied?
          raise IO::Error.new "File not open for reading", target: self
        when .error_broken_pipe?
          return 0_i32
        else
          raise IO::Error.from_os_error("Error reading file", error, target: self)
        end
      end
      bytes_read.to_i32
    else
      overlapped_operation(handle, "ReadFile", read_timeout) do |overlapped|
        ret = LibC.ReadFile(handle, slice, slice.size, out byte_count, overlapped)
        {ret, byte_count}
      end.to_i32
    end
  end

  private def unbuffered_write(slice : Bytes) : Nil
    handle = windows_handle
    until slice.empty?
      if system_blocking?
        if LibC.WriteFile(handle, slice, slice.size, out bytes_written, nil) == 0
          case error = WinError.value
          when .error_access_denied?
            raise IO::Error.new "File not open for writing", target: self
          when .error_broken_pipe?
            return 0_u32
          else
            raise IO::Error.from_os_error("Error writing file", error, target: self)
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
        raise IO::Error.from_os_error("Unable to get info", error, target: self) unless error == WinError::ERROR_SUCCESS
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
    if LibC.SetFilePointerEx(windows_handle, offset, nil, whence) == 0
      raise IO::Error.from_winerror("Unable to seek", target: self)
    end
  end

  private def system_pos
    if LibC.SetFilePointerEx(windows_handle, 0, out pos, IO::Seek::Current) == 0
      raise IO::Error.from_winerror("Unable to tell", target: self)
    end
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
        raise IO::Error.from_errno("Error closing file", target: self)
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
      raise IO::Error.from_os_error "Error reading file", error, target: self
    end

    bytes_read.to_i64
  end

  def self.from_stdio(fd)
    console_handle = false
    handle = windows_handle(fd)
    if handle != LibC::INVALID_HANDLE_VALUE
      LibC._setmode fd, LibC::O_BINARY
      # TODO: use `out old_mode` after implementing interpreter out closured var
      old_mode = uninitialized LibC::DWORD
      if LibC.GetConsoleMode(handle, pointerof(old_mode)) != 0
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
end

private module ConsoleUtils
  # N UTF-16 code units correspond to no more than 3*N UTF-8 code units.
  # NOTE: For very large buffers, `ReadConsoleW` may fail.
  private BUFFER_SIZE = 10000
  @@utf8_buffer = Slice(UInt8).new(3 * BUFFER_SIZE)

  # `@@buffer` points to part of `@@utf8_buffer`.
  # It represents data that has not been read yet.
  @@buffer : Bytes = @@utf8_buffer[0, 0]

  # Remaining UTF-16 code unit.
  @@remaining_unit : UInt16?

  # Determines if *handle* is a console.
  def self.console?(handle : LibC::HANDLE) : Bool
    LibC.GetConsoleMode(handle, out _) != 0
  end

  # Reads to *slice* from the console specified by *handle*,
  # and return the actual number of bytes read.
  def self.read(handle : LibC::HANDLE, slice : Bytes) : Int32
    return 0 if slice.empty?
    fill_buffer(handle) if @@buffer.empty?

    bytes_read = {slice.size, @@buffer.size}.min
    @@buffer[0, bytes_read].copy_to(slice)
    @@buffer += bytes_read
    bytes_read
  end

  private def self.fill_buffer(handle : LibC::HANDLE) : Nil
    utf16_buffer = uninitialized UInt16[BUFFER_SIZE]
    remaining_unit = @@remaining_unit
    if remaining_unit
      utf16_buffer[0] = remaining_unit
      index = read_console(handle, utf16_buffer.to_slice + 1)
    else
      index = read_console(handle, utf16_buffer.to_slice) - 1
    end

    if index >= 0 && utf16_buffer[index] & 0xFC00 == 0xD800
      @@remaining_unit = utf16_buffer[index]
      index -= 1
    else
      @@remaining_unit = nil
    end
    return if index < 0

    appender = @@utf8_buffer.to_unsafe.appender
    String.each_utf16_char(utf16_buffer.to_slice[..index]) do |char|
      char.each_byte do |byte|
        appender << byte
      end
    end
    @@buffer = @@utf8_buffer[0, appender.size]
  end

  private def self.read_console(handle : LibC::HANDLE, slice : Slice(UInt16)) : Int32
    if 0 == LibC.ReadConsoleW(handle, slice, slice.size, out units_read, nil)
      raise IO::Error.from_winerror("ReadConsoleW")
    end
    units_read.to_i32
  end
end

# Enable UTF-8 console I/O for the duration of program execution
if LibC.IsValidCodePage(LibC::CP_UTF8) != 0
  old_input_cp = LibC.GetConsoleCP
  if LibC.SetConsoleCP(LibC::CP_UTF8) != 0
    at_exit { LibC.SetConsoleCP(old_input_cp) }
  end

  old_output_cp = LibC.GetConsoleOutputCP
  if LibC.SetConsoleOutputCP(LibC::CP_UTF8) != 0
    at_exit { LibC.SetConsoleOutputCP(old_output_cp) }
  end
end
