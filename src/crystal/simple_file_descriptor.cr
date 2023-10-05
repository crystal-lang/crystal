module Crystal
  # This "simple" wrapper over a file descriptor calls the C I/O functions
  # directly, without going through `IO::Buffered` or `IO::Evented`. This is
  # necessary deep inside the Crystal runtime to break a method call loop where
  # `IO::Buffered#read` calls itself and leads to type inference problems, see
  # https://github.com/crystal-lang/crystal/issues/8163#issuecomment-1748962979
  class SimpleFileDescriptor < IO
    def initialize(@fd : Int32)
    end

    def read(slice : Bytes)
      LibC.read(@fd, slice, slice.size)
    end

    def write(slice : Bytes) : Nil
      LibC.write(@fd, slice, slice.size)
    end

    def pos
      LibC.lseek(@fd, 0, IO::Seek::Current).to_i64
    end

    def pos=(value)
      seek(value)
    end

    def seek(offset, whence : Seek = Seek::Set)
      LibC.lseek(@fd, offset, whence)
    end

    def seek(offset, whence : Seek = Seek::Set, &)
      original_pos = tell
      begin
        seek(offset, whence)
        yield
      ensure
        seek(original_pos)
      end
    end
  end
end
