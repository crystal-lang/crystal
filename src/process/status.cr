# The status of a terminated process. Returned by `Process#wait`.
class Process::Status
  # Platform-specific exit status code, which usually contains either the exit code or a termination signal.
  # The other `Process::Status` methods extract the values from `exit_status`.
  def exit_status : Int32
    @exit_status.to_i32!
  end

  {% if flag?(:win32) %}
    # :nodoc:
    def initialize(@exit_status : UInt32)
    end
  {% else %}
    # :nodoc:
    def initialize(@exit_status : Int32)
    end
  {% end %}

  # Returns `true` if the process was terminated by a signal.
  def signal_exit? : Bool
    {% if flag?(:unix) %}
      # define __WIFSIGNALED(status) (((signed char) (((status) & 0x7f) + 1) >> 1) > 0)
      ((LibC::SChar.new(@exit_status & 0x7f) + 1) >> 1) > 0
    {% else %}
      false
    {% end %}
  end

  # Returns `true` if the process terminated normally.
  def normal_exit? : Bool
    {% if flag?(:unix) %}
      # define __WIFEXITED(status) (__WTERMSIG(status) == 0)
      signal_code == 0
    {% else %}
      true
    {% end %}
  end

  # If `signal_exit?` is `true`, returns the *Signal* the process
  # received and didn't handle. Will raise if `signal_exit?` is `false`.
  #
  # Available only on Unix-like operating systems.
  def exit_signal : Signal
    {% if flag?(:unix) %}
      Signal.from_value(signal_code)
    {% else %}
      raise NotImplementedError.new("Process::Status#exit_signal")
    {% end %}
  end

  {% if flag?(:wasm32) %}
    # wasm32 does not define `Signal`
    def exit_signal
      raise NotImplementedError.new("Process::Status#exit_signal")
    end
  {% end %}

  # If `normal_exit?` is `true`, returns the exit code of the process.
  def exit_code : Int32
    {% if flag?(:unix) %}
      # define __WEXITSTATUS(status) (((status) & 0xff00) >> 8)
      (@exit_status & 0xff00) >> 8
    {% else %}
      exit_status
    {% end %}
  end

  # Returns `true` if the process exited normally with an exit code of `0`.
  def success? : Bool
    normal_exit? && exit_code == 0
  end

  private def signal_code
    # define __WTERMSIG(status) ((status) & 0x7f)
    @exit_status & 0x7f
  end

  def_equals_and_hash @exit_status

  # Prints a textual representation of the process status to *io*.
  #
  # The result is equivalent to `#to_s`, but prefixed by the type name and
  # delimited by square brackets: `Process::Status[0]`, `Process::Status[1]`,
  # `Process::Status[Signal::HUP]`.
  def inspect(io : IO) : Nil
    io << "Process::Status["
    if normal_exit?
      exit_code.inspect(io)
    else
      exit_signal.inspect(io)
    end
    io << "]"
  end

  # Prints a textual representation of the process status to *io*.
  #
  # A normal exit status prints the numerical value (`0`, `1` etc).
  # A signal exit status prints the name of the `Signal` member (`HUP`, `INT`, etc.).
  def to_s(io : IO) : Nil
    if normal_exit?
      io << exit_code
    else
      io << exit_signal
    end
  end

  # Returns a textual representation of the process status.
  #
  # A normal exit status prints the numerical value (`0`, `1` etc).
  # A signal exit status prints the name of the `Signal` member (`HUP`, `INT`, etc.).
  def to_s : String
    if normal_exit?
      exit_code.to_s
    else
      exit_signal.to_s
    end
  end
end
