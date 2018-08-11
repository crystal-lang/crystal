require "./syscall"
require "./file_descriptor"

class IO::StdFileDescriptor < IO::FileDescriptor
  def initialize(@fd)
    # XXX: This is -supposed- to work, but something (libevent?) is changing the FD before here.
    # strace confirms it.
    @closed = LibC.fcntl(@fd, LibC::F_GETFD) < 0
    return if @closed

    path = uninitialized UInt8[256]

    # If we have a TTY for stdin/out/err, it is a shared terminal.
    # We need to reopen it to use O_NONBLOCK without causing other programs to break

    # Figure out the terminal TTY name
    if LibC.ttyname_r(@fd, path, 256) == 0
      # Open a fresh handle to the TTY
      @fd = LibC.open(path, LibC::O_RDWR)

      self.close_on_exec = true
      self.blocking = false
    else
      # We are accidentally trying to block on closed handles due to the fcntl issue above.
      self.blocking = true
    end
  end
end
