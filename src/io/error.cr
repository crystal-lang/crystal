class IO
  class Error < Exception
    include SystemError
  end

  # Raised when an `IO` operation times out.
  #
  # ```
  # STDIN.read_timeout = 1
  # STDIN.gets # raises IO::TimeoutError (after 1 second)
  # ```
  class TimeoutError < Error
  end

  class EOFError < Error
    def initialize(message = "End of file reached")
      super(message)
    end
  end
end
