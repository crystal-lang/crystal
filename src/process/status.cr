class Process::Status
  getter pid
  getter exit
  property input, output, error :: IO | Nil
  setter manage_input, manage_output, manage_error :: Bool

  def initialize(@pid, input = nil, output = nil, error = nil)
    @input = io_param(input)
    @output = io_param(output)
    @error = io_param(error)

    @manage_input = false
    @manage_output = false
    @manage_error = false
  end

  def success?
    @exit == 0
  end

  def alive?
    if @exit
      false
    else
      begin
        kill(Signal::NONE)
        true
      rescue ex : Errno
        raise ex unless ex.errno == Errno::ESRCH
        false
      end
    end
  end

  def kill sig = Signal::TERM
    Process.kill(sig, @pid)
  end

  # closes any pipes to the child and waits for the process to exit
  def close
    i = @input
    o = @output
    e = @error
    if @manage_input && i
      i.close rescue nil
      @input = nil
    end
    if @manage_output && o
      o.close rescue nil
      @output = nil
    end
    if @manage_error && e
      e.close rescue nil
      @error = nil
    end

    wait
  end

  def input= io
    @input = io_param(io)
  end

  def output= io
    @output = io_param(io)
  end

  def error= io
    @error = io_param(io)
  end

  private def wait
    @exit = Process.waitpid(pid)
  rescue err : Errno
    raise err unless err.errno == Errno::ESRCH # process may have been reaped elsewhere or SIGCHLD ignored
  end

  # drop Bool type
  private def io_param io
    case io
    when Bool
      nil
    else
      io
    end
  end
end

