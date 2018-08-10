require "./syscall"
require "./file_descriptor"

class IO::StdFileDescriptor < IO::FileDescriptor
  def initialize(@fd : Int32)
    @closed = false

    # If we have a TTY for stdin/out/err, it is a shared terminal.
    # We need to reopen it to use O_NONBLOCK without causing other programs to break
    if tty?
      # Figure out the terminal TTY name
      path = uninitialized UInt8[256]

      # XXX: Need to error somehow, if this doesn't return 0
      LibC.ttyname_r(@fd, path, 256)

      # Open a fresh handle to the TTY
      @fd = LibC.open(path, LibC::O_RDWR)

      self.close_on_exec = true
      self.blocking = false
    else
      self.blocking = true
    end
  end
end
