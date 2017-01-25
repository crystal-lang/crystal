require "c/sys/wait"

# :nodoc:
# Singleton that handles `SIG_CHLD` and queues events for `Process#waitpid`.
# `Process.waitpid` uses this class for nonblocking operation.
class Event::SignalChildHandler
  def self.instance : self
    @@instance ||= begin
      Signal.setup_default_handlers
      new
    end
  end

  alias ChanType = Channel::Buffered(Process::Status?)

  def initialize
    @pending = Hash(LibC::PidT, Process::Status).new
    @waiting = Hash(LibC::PidT, ChanType).new
  end

  def after_fork
    @pending.clear
    @waiting.each { |pid, chan| chan.send(nil) }
    @waiting.clear
  end

  def trigger
    loop do
      pid = LibC.waitpid(-1, out exit_code, LibC::WNOHANG)
      case pid
      when 0
        return nil
      when -1
        raise Errno.new("waitpid") unless Errno.value == Errno::ECHILD
        return nil
      else
        status = Process::Status.new exit_code
        send_pending pid, status
      end
    end
  end

  private def send_pending(pid, status)
    # BUG: needs mutexes with threads
    if chan = @waiting[pid]?
      chan.send status
      @waiting.delete pid
    else
      @pending[pid] = status
    end
  end

  # Returns a future that sends a `Process::Status` or raises after forking.
  def waitpid(pid : LibC::PidT)
    chan = ChanType.new(1)
    # BUG: needs mutexes with threads
    if status = @pending[pid]?
      chan.send status
      @pending.delete pid
    else
      @waiting[pid] = chan
    end

    lazy do
      chan.receive || raise Channel::ClosedError.new("waitpid channel closed after forking")
    end
  end
end
