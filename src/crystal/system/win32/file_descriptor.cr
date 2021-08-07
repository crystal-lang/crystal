require "c/io"
require "c/consoleapi"

module Crystal::System::FileDescriptor
  @volatile_fd : Atomic(LibC::Int)

  private def unbuffered_read(slice : Bytes)
    bytes_read = LibC._read(fd, slice, slice.size)
    if bytes_read == -1
      if Errno.value == Errno::EBADF
        raise IO::Error.new "File not open for reading"
      else
        raise IO::Error.from_errno("Error reading file")
      end
    end
    bytes_read
  end

  private def unbuffered_write(slice : Bytes)
    until slice.empty?
      bytes_written = LibC._write(fd, slice, slice.size)
      if bytes_written == -1
        if Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing"
        else
          raise IO::Error.from_errno("Error writing file")
        end
      end

      slice += bytes_written
    end
  end

  private def system_blocking?
    true
  end

  private def system_blocking=(blocking)
    raise NotImplementedError.new("Crystal::System::FileDescriptor#system_blocking=") unless blocking
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

  private def windows_handle
    ret = LibC._get_osfhandle(fd)
    raise RuntimeError.from_errno("_get_osfhandle") if ret == -1
    LibC::HANDLE.new(ret)
  end

  private def system_info
    handle = windows_handle

    file_type = LibC.GetFileType(handle)

    if file_type == LibC::FILE_TYPE_UNKNOWN
      error = WinError.value
      raise IO::Error.from_os_error("Unable to get info", error) unless error == WinError::ERROR_SUCCESS
    end

    if file_type == LibC::FILE_TYPE_DISK
      if LibC.GetFileInformationByHandle(handle, out file_info) == 0
        raise IO::Error.from_winerror("Unable to get info")
      end

      FileInfo.new(file_info, file_type)
    else
      FileInfo.new(file_type)
    end
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
    {% if LibC.has_method?("dup3") %}
      # dup doesn't copy the CLOEXEC flag, so copy it manually using dup3
      flags = other.close_on_exec? ? LibC::O_CLOEXEC : 0
      if LibC.dup3(other.fd, self.fd, flags) == -1
        raise IO::Error.from_errno("Could not reopen file descriptor")
      end
    {% else %}
      # dup doesn't copy the CLOEXEC flag, copy it manually to the new
      if LibC._dup2(other.fd, self.fd) == -1
        raise IO::Error.from_errno("Could not reopen file descriptor")
      end

      if other.close_on_exec?
        self.close_on_exec = true
      end
    {% end %}

    # Mark the handle open, since we had to have dup'd a live handle.
    @closed = false
  end

  private def system_close
    file_descriptor_close
  end

  def file_descriptor_close
    err = nil
    if LibC._close(fd) != 0
      case Errno.value
      when Errno::EINTR
        # ignore
      else
        raise IO::Error.from_errno("Error closing file")
      end
    end
  end

  def self.pipe(read_blocking, write_blocking)
    pipe_fds = uninitialized StaticArray(LibC::Int, 2)
    if LibC._pipe(pipe_fds, 8192, LibC::O_BINARY | LibC::O_NOINHERIT) != 0
      raise IO::Error.from_errno("Could not create pipe")
    end

    r = IO::FileDescriptor.new(pipe_fds[0], read_blocking)
    w = IO::FileDescriptor.new(pipe_fds[1], write_blocking)
    w.sync = true

    {r, w}
  end

  def self.pread(fd, buffer, offset)
    handle = LibC._get_osfhandle(fd)
    raise IO::Error.from_errno("_get_osfhandle") if handle == -1
    handle = LibC::HANDLE.new(handle)

    overlapped = LibC::OVERLAPPED.new
    overlapped.union.offset.offset = LibC::DWORD.new(offset)
    overlapped.union.offset.offsetHigh = LibC::DWORD.new(offset >> 32)
    if LibC.ReadFile(handle, buffer, buffer.size, out bytes_read, pointerof(overlapped)) == 0
      error = WinError.value
      return 0_i64 if error == WinError::ERROR_HANDLE_EOF
      raise IO::Error.from_winerror "Error reading file", error
    end

    bytes_read.to_i64
  end

  def self.from_stdio(fd)
    console_handle = false
    handle = LibC._get_osfhandle(fd)
    if handle != -1
      if LibC.GetConsoleMode(LibC::HANDLE.new(handle), out _) != 0
        console_handle = true
      end
    end

    io = IO::FileDescriptor.new(fd)
    # Set sync or flush_on_newline as described in STDOUT and STDERR docs.
    # See https://crystal-lang.org/api/toplevel.html#STDERR
    if console_handle
      io.sync = true
    else
      io.flush_on_newline = true
    end
    io
  end
end
