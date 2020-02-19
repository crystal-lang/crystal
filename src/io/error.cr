class IO
  class Error < Exception
    # :nodoc:
    def self.from_errno(message, errno = Errno.value)
      Error.new "#{message}: #{Errno.message(errno)}"
    end
  end

  class FileSystemError < Error
    getter file : String
    getter other : String?
    getter reason : String

    def self.from_errno(message : String, file : String, errno = Errno.value, *, other : String)
      errno_to_class(errno).new message, file, Errno.message(errno), other: other
    end

    def self.from_errno(message : String, file : String, errno = Errno.value)
      errno_to_class(errno).new message, file, Errno.message(errno)
    end

    private def self.errno_to_class(errno)
      if errno == Errno::ENOENT
        NotFoundError
      else
        FileSystemError
      end
    end

    def initialize(message, @file, @reason)
      super "#{message}: '#{file.inspect_unquoted}': #{reason}"
    end

    def initialize(message, @file, @reason, *, @other : String)
      super "#{message}: '#{file.inspect_unquoted}' -> '#{other.inspect_unquoted}': #{reason}"
    end
  end

  class NotFoundError < FileSystemError
  end

  class EOFError < Error
    def initialize(message = "End of file reached")
      super(message)
    end
  end
end
