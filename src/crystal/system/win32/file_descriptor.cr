require "c/io"
require "c/consoleapi"
require "c/consoleapi2"
require "c/winnls"
require "crystal/system/win32/iocp"

module Crystal::System::FileDescriptor
  # Platform-specific type to represent a file descriptor handle to the operating
  # system.
  # NOTE: this should really be `LibC::HANDLE`, here it is an integer type of
  # the same size so that `IO::FileDescriptor#fd` continues to return an `Int`
  alias Handle = ::LibC::UIntPtrT

  STDIN_HANDLE  = LibC.GetStdHandle(LibC::STD_INPUT_HANDLE).address
  STDOUT_HANDLE = LibC.GetStdHandle(LibC::STD_OUTPUT_HANDLE).address
  STDERR_HANDLE = LibC.GetStdHandle(LibC::STD_ERROR_HANDLE).address

  @system_blocking = true

  private def system_read(slice : Bytes) : Int32
    handle = windows_handle
    if ConsoleUtils.console?(handle)
      ConsoleUtils.read(handle, slice)
    elsif system_blocking?
      read_blocking(handle, slice)
    else
      event_loop.read(self, slice)
    end
  end

  private def read_blocking(handle, slice)
    ret = LibC.ReadFile(handle, slice, slice.size, out bytes_read, nil)
    if ret.zero?
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
  end

  private def system_write(slice : Bytes) : Int32
    handle = windows_handle
    if system_blocking?
      write_blocking(handle, slice).to_i32
    else
      event_loop.write(self, slice)
    end
  end

  private def write_blocking(handle, slice)
    ret = LibC.WriteFile(handle, slice, slice.size, out bytes_written, nil)
    if ret.zero?
      case error = WinError.value
      when .error_access_denied?
        raise IO::Error.new "File not open for writing", target: self
      when .error_broken_pipe?
        return 0_u32
      else
        raise IO::Error.from_os_error("Error writing file", error, target: self)
      end
    end
    bytes_written
  end

  # :nodoc:
  def system_blocking?
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

  private def system_closed? : Bool
    file_type = LibC.GetFileType(windows_handle)

    if file_type == LibC::FILE_TYPE_UNKNOWN
      case error = WinError.value
      when .error_invalid_handle?
        return true
      else
        raise IO::Error.from_os_error("Unable to get info", error, target: self)
      end
    else
      false
    end
  end

  def self.fcntl(fd, cmd, arg = 0)
    raise NotImplementedError.new "Crystal::System::FileDescriptor.fcntl"
  end

  protected def windows_handle
    FileDescriptor.windows_handle(fd)
  end

  def self.windows_handle(fd)
    LibC::HANDLE.new(fd)
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
    LibC.GetConsoleMode(windows_handle, out _) != 0
  end

  private def system_reopen(other : IO::FileDescriptor)
    cur_proc = LibC.GetCurrentProcess
    if LibC.DuplicateHandle(cur_proc, other.windows_handle, cur_proc, out new_handle, 0, true, LibC::DUPLICATE_SAME_ACCESS) == 0
      raise IO::Error.from_winerror("Could not reopen file descriptor")
    end
    @volatile_fd.set(new_handle.address)

    # Mark the handle open, since we had to have dup'd a live handle.
    @closed = false
  end

  private def system_close
    event_loop.close(self)

    file_descriptor_close
  end

  def file_descriptor_close
    if LibC.CloseHandle(windows_handle) == 0
      raise IO::Error.from_winerror("Error closing file", target: self)
    end
  end

  private def system_flock_shared(blocking : Bool) : Nil
    flock(false, blocking)
  end

  private def system_flock_exclusive(blocking : Bool) : Nil
    flock(true, blocking)
  end

  private def system_flock_unlock : Nil
    unlock_file(windows_handle)
  end

  private def flock(exclusive, retry)
    flags = LibC::LOCKFILE_FAIL_IMMEDIATELY
    flags |= LibC::LOCKFILE_EXCLUSIVE_LOCK if exclusive

    handle = windows_handle
    if retry
      until lock_file(handle, flags)
        sleep 0.1
      end
    else
      lock_file(handle, flags) || raise IO::Error.from_winerror("Error applying file lock: file is already locked")
    end
  end

  private def lock_file(handle, flags)
    # lpOverlapped must be provided despite the synchronous use of this method.
    overlapped = LibC::OVERLAPPED.new
    # lock the entire file with offset 0 in overlapped and number of bytes set to max value
    if 0 != LibC.LockFileEx(handle, flags, 0, 0xFFFF_FFFF, 0xFFFF_FFFF, pointerof(overlapped))
      true
    else
      winerror = WinError.value
      if winerror == WinError::ERROR_LOCK_VIOLATION
        false
      else
        raise IO::Error.from_os_error("LockFileEx", winerror, target: self)
      end
    end
  end

  private def unlock_file(handle)
    # lpOverlapped must be provided despite the synchronous use of this method.
    overlapped = LibC::OVERLAPPED.new
    # unlock the entire file with offset 0 in overlapped and number of bytes set to max value
    if 0 == LibC.UnlockFileEx(handle, 0, 0xFFFF_FFFF, 0xFFFF_FFFF, pointerof(overlapped))
      raise IO::Error.from_winerror("UnLockFileEx")
    end
  end

  private def system_fsync(flush_metadata = true) : Nil
    if LibC.FlushFileBuffers(windows_handle) == 0
      raise IO::Error.from_winerror("Error syncing file", target: self)
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
    Crystal::EventLoop.current.create_completion_port(w_pipe) unless write_blocking

    r_pipe_flags = LibC::FILE_FLAG_NO_BUFFERING
    r_pipe_flags |= LibC::FILE_FLAG_OVERLAPPED unless read_blocking
    r_pipe = LibC.CreateFileW(System.to_wstr(pipe_name), LibC::GENERIC_READ | LibC::FILE_WRITE_ATTRIBUTES, 0, nil, LibC::OPEN_EXISTING, r_pipe_flags, nil)
    raise IO::Error.from_winerror("CreateFileW") if r_pipe == LibC::INVALID_HANDLE_VALUE
    Crystal::EventLoop.current.create_completion_port(r_pipe) unless read_blocking

    r = IO::FileDescriptor.new(r_pipe.address, read_blocking)
    w = IO::FileDescriptor.new(w_pipe.address, write_blocking)
    w.sync = true

    {r, w}
  end

  def self.pread(fd, buffer, offset)
    handle = windows_handle(fd)

    overlapped = LibC::OVERLAPPED.new
    overlapped.union.offset.offset = LibC::DWORD.new!(offset)
    overlapped.union.offset.offsetHigh = LibC::DWORD.new!(offset >> 32)
    if LibC.ReadFile(handle, buffer, buffer.size, out bytes_read, pointerof(overlapped)) == 0
      error = WinError.value
      return 0_i64 if error == WinError::ERROR_HANDLE_EOF
      raise IO::Error.from_os_error "Error reading file", error, target: self
    end

    bytes_read.to_i64
  end

  def self.from_stdio(fd)
    handle = case fd
             when 0 then LibC.GetStdHandle(LibC::STD_INPUT_HANDLE)
             when 1 then LibC.GetStdHandle(LibC::STD_OUTPUT_HANDLE)
             when 2 then LibC.GetStdHandle(LibC::STD_ERROR_HANDLE)
             else        LibC::INVALID_HANDLE_VALUE
             end

    console_handle = false
    if handle != LibC::INVALID_HANDLE_VALUE
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

    io = IO::FileDescriptor.new(handle.address, blocking: true)
    # Set sync or flush_on_newline as described in STDOUT and STDERR docs.
    # See https://crystal-lang.org/api/toplevel.html#STDERR
    if console_handle
      io.sync = true
    else
      io.flush_on_newline = true
    end
    io
  end

  private def system_echo(enable : Bool)
    system_console_mode(enable, LibC::ENABLE_ECHO_INPUT, 0)
  end

  private def system_echo(enable : Bool, & : ->)
    system_console_mode(enable, LibC::ENABLE_ECHO_INPUT, 0) { yield }
  end

  private def system_raw(enable : Bool)
    system_console_mode(enable, LibC::ENABLE_VIRTUAL_TERMINAL_INPUT, LibC::ENABLE_PROCESSED_INPUT | LibC::ENABLE_LINE_INPUT | LibC::ENABLE_ECHO_INPUT)
  end

  private def system_raw(enable : Bool, & : ->)
    system_console_mode(enable, LibC::ENABLE_VIRTUAL_TERMINAL_INPUT, LibC::ENABLE_PROCESSED_INPUT | LibC::ENABLE_LINE_INPUT | LibC::ENABLE_ECHO_INPUT) { yield }
  end

  @[AlwaysInline]
  private def system_console_mode(enable, on_mask, off_mask, old_mode = nil)
    windows_handle = self.windows_handle
    unless old_mode
      if LibC.GetConsoleMode(windows_handle, out mode) == 0
        raise IO::Error.from_winerror("GetConsoleMode")
      end
      old_mode = mode
    end

    old_on_bits = old_mode & on_mask
    old_off_bits = old_mode & off_mask
    if enable
      return if old_on_bits == on_mask && old_off_bits == 0
      new_mode = (old_mode | on_mask) & ~off_mask
    else
      return if old_on_bits == 0 && old_off_bits == off_mask
      new_mode = (old_mode | off_mask) & ~on_mask
    end

    if LibC.SetConsoleMode(windows_handle, new_mode) == 0
      raise IO::Error.from_winerror("SetConsoleMode")
    end
  end

  @[AlwaysInline]
  private def system_console_mode(enable, on_mask, off_mask, &)
    windows_handle = self.windows_handle
    if LibC.GetConsoleMode(windows_handle, out old_mode) == 0
      raise IO::Error.from_winerror("GetConsoleMode")
    end

    begin
      system_console_mode(enable, on_mask, off_mask, old_mode)
      yield
    ensure
      LibC.SetConsoleMode(windows_handle, old_mode)
    end
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
