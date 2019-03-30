require "c/fcntl"
require "io/evented"

# :nodoc:
module Crystal::System::FileDescriptor
  include IO::Evented

  @fd : Int32

  private def unbuffered_read(slice : Bytes)
    evented_read(slice, "Error reading file") do
      LibC.read(@fd, slice, slice.size)
    end
  end

  private def unbuffered_write(slice : Bytes)
    evented_write(slice, "Error writing file") do |slice|
      LibC.write(@fd, slice, slice.size).tap do |return_code|
        if return_code == -1 && Errno.value == Errno::EBADF
          raise IO::Error.new "File not open for writing"
        end
      end
    end
  end

  private def system_blocking?
    flags = fcntl(LibC::F_GETFL)
    !flags.bits_set? LibC::O_NONBLOCK
  end

  private def system_blocking=(value)
    current_flags = fcntl(LibC::F_GETFL)
    new_flags = current_flags
    if value
      new_flags &= ~LibC::O_NONBLOCK
    else
      new_flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, new_flags) unless new_flags == current_flags
  end

  private def system_close_on_exec?
    flags = fcntl(LibC::F_GETFD)
    flags.bits_set? LibC::FD_CLOEXEC
  end

  private def system_close_on_exec=(arg : Bool)
    fcntl(LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
  end

  private def system_closed?
    LibC.fcntl(@fd, LibC::F_GETFL) == -1
  end

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl(fd, cmd, arg)
    raise Errno.new("fcntl() failed") if r == -1
    r
  end

  private def system_info
    if LibC.fstat(@fd, out stat) != 0
      raise Errno.new("Unable to get info")
    end

    FileInfo.new(stat)
  end

  private def system_seek(offset, whence : IO::Seek) : Nil
    seek_value = LibC.lseek(@fd, offset, whence)

    if seek_value == -1
      raise Errno.new "Unable to seek"
    end
  end

  private def system_pos
    pos = LibC.lseek(@fd, 0, IO::Seek::Current)
    raise Errno.new "Unable to tell" if pos == -1
    pos
  end

  private def system_tty?
    LibC.isatty(@fd) == 1
  end

  private def system_reopen(other : IO::FileDescriptor)
    {% if LibC.methods.includes? "dup3".id %}
      # dup doesn't copy the CLOEXEC flag, so copy it manually using dup3
      flags = other.close_on_exec? ? LibC::O_CLOEXEC : 0
      if LibC.dup3(other.@fd, @fd, flags) == -1
        raise Errno.new("Could not reopen file descriptor")
      end
    {% else %}
      # dup doesn't copy the CLOEXEC flag, copy it manually to the new
      if LibC.dup2(other.@fd, @fd) == -1
        raise Errno.new("Could not reopen file descriptor")
      end

      if other.close_on_exec?
        self.close_on_exec = true
      end
    {% end %}

    # Mark the handle open, since we had to have dup'd a live handle.
    @closed = false

    evented_reopen
  end

  private def system_close
    if LibC.close(@fd) != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        raise Errno.new("Error closing file")
      end
    end
  ensure
    evented_close
  end

  def self.pipe(read_blocking, write_blocking)
    pipe_fds = uninitialized StaticArray(LibC::Int, 2)
    if LibC.pipe(pipe_fds) != 0
      raise Errno.new("Could not create pipe")
    end

    r = IO::FileDescriptor.new(pipe_fds[0], read_blocking)
    w = IO::FileDescriptor.new(pipe_fds[1], write_blocking)
    r.close_on_exec = true
    w.close_on_exec = true
    w.sync = true

    {r, w}
  end

  def self.pread(fd, buffer, offset)
    bytes_read = LibC.pread(fd, buffer, buffer.size, offset)

    if bytes_read == -1
      raise Errno.new "Error reading file"
    end

    bytes_read
  end
end
