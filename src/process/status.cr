# The status of a terminated process.
class Process::Status
  getter exit_status : Int32

  def initialize(@exit_status : Int32)
  end

  # Returns `true` if the process was terminated by a signal.
  def signal_exit?
    # define __WIFSIGNALED(status) (((signed char) (((status) & 0x7f) + 1) >> 1) > 0)
    ((LibC::SChar.new(@exit_status & 0x7f) + 1) >> 1) > 0
  end

  # Returns `true` if the process terminated normally.
  def normal_exit?
    # define __WIFEXITED(status) (__WTERMSIG(status) == 0)
    signal_code == 0
  end

  # If `signal_exit?` is `true`, returns the *Signal* the process
  # received and didn't handle. Will raise if `signal_exit?` is `false`.
  def exit_signal
    Signal.from_value(signal_code)
  end

  # If `normal_exit?` is `true`, returns the exit code of the process.
  def exit_code
    # define __WEXITSTATUS(status) (((status) & 0xff00) >> 8)
    (@exit_status & 0xff00) >> 8
  end

  # Returns `true` if the process exited normally with an exit code of `0`.
  def success?
    normal_exit? && exit_code == 0
  end

  private def signal_code
    # define __WTERMSIG(status) ((status) & 0x7f)
    @exit_status & 0x7f
  end
end
