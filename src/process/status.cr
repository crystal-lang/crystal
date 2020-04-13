# The status of a terminated process. Returned by `Process#wait`.
abstract struct Process::Status
  # Returns `Signaled` if the process was terminated by a signal, otherwise `nil`.
  def signal_exit? : Signaled?
    self.as? Signaled
  end

  # Returns `Exited` if the process terminated normally, otherwise `nil`.
  def normal_exit? : Exited?
    self.as? Exited
  end

  # If `signal_exit?` is `true`, returns the *Signal* the process
  # received and didn't handle. Will raise if `signal_exit?` is `false`.
  #
  # Available only on Unix-like operating systems.
  def exit_signal : Signal
    self.as(Signaled).signal
  end

  # If `normal_exit?` is `true`, returns the exit code of the process.
  #
  # * POSIX: Otherwise, returns a placeholder negative value related to the exit signal.
  # * Windows: The exit is always "normal" but the exit codes can be negative
  #   (wrapped around after `Int32::MAX`; take them modulo 2**32 if the actual value is needed)
  abstract def exit_code : Int32

  # Returns `true` if the process exited normally with an exit code of `0`.
  def success? : Bool
    false
  end

  struct Exited < Status
    # :nodoc:
    def initialize(@exit_code : Int32)
    end

    getter exit_code : Int32

    def success? : Bool
      exit_code == 0
    end
  end

  struct Signaled < Status
    # :nodoc:
    def initialize(signal_code : Int32, @core_dumped : Bool)
      @signal_code = UInt8.new(signal_code)
    end

    def signal : Signal
      Signal.new(signal_code)
    end

    def signal_code : Int32
      @signal_code.to_i32
    end

    def exit_code : Int32
      -signal_code
    end

    getter? core_dumped : Bool
  end

  struct Stopped < Status
    # :nodoc:
    def initialize(@stop_signal : Int32)
    end

    getter stop_signal : Int32

    def exit_code : Int32
      -0x7F
    end
  end

  struct Continued < Status
    def exit_code : Int32
      -0x7F
    end
  end

  # POSIX-specific exit status code, a complex bitmask of an exit code or termination signal.
  @[Deprecated("Use `Process::Status#exit_code`")]
  def exit_status : Int32
    case self
    when Exited
      self.exit_code << 8
    when Signaled
      self.signal_code + (core_dumped? ? 0x80 : 0)
    when Stopped
      (self.stop_signal << 8) + 0x7f
    when Continued
      0xffff
    end
  end

  class UnexpectedStatusError < RuntimeError
    def initialize(@exit_status : Int32, msg = "The process exited with an unknown status")
      super("#{msg} (#{@exit_status})")
    end

    getter exit_status : Int32
  end
end
