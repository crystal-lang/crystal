require "../unix/file_descriptor"

# :nodoc:
module Crystal::System::FileDescriptor
  def self.from_stdio(fd)
    # TODO: WASI doesn't offer a way to detect if a 'fd' is a TTY.
    IO::FileDescriptor.new(fd).tap(&.flush_on_newline=(true))
  end

  def self.pipe(read_blocking, write_blocking)
    raise NotImplementedError.new "Crystal::System::FileDescriptor.pipe"
  end

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl(fd, cmd, arg)
    raise IO::Error.from_errno("fcntl() failed") if r == -1
    r
  end

  private def system_blocking_init(value)
  end

  private def system_reopen(other : IO::FileDescriptor)
    raise NotImplementedError.new "Crystal::System::FileDescriptor#system_reopen"
  end

  private def system_echo(enable : Bool, & : ->)
    raise NotImplementedError.new "Crystal::System::FileDescriptor#system_echo"
  end

  private def system_raw(enable : Bool, & : ->)
    raise NotImplementedError.new "Crystal::System::FileDescriptor#system_raw"
  end
end
