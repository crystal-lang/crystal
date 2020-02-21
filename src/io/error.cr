class IO
  class Error < Exception
    # :nodoc:
    def self.from_errno(message, errno = Errno.value)
      Error.new "#{message}: #{Errno.message(errno)}"
    end
  end

  class EOFError < Error
    def initialize(message = "End of file reached")
      super(message)
    end
  end
end
