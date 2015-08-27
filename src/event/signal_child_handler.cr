# :nodoc:
# Singleton that handles SIG_CHLD and queues events for Process#waitpid.
# Process.waitpid uses this class for nonblocking operation.
class Event::SignalChildHandler
  def self.instance
    @@instance ||= new
  end

  alias ChanType = BufferedChannel(Process::Status?)

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
    while (pid = LibC.waitpid(-1, out exit_code, LibC::WNOHANG)) != -1
      status = Process::Status.new exit_code
      send_pending pid, status
    end
  end

  private def send_pending pid, status
# BUG: needs mutexes with threads
    if chan = @waiting[pid]?
      chan.send status
      @waiting.delete pid
    else
      @pending[pid] = status
    end
  end

  # returns a channel that sends a Process::Status
  def waitpid pid : LibC::PidT
    chan = ChanType.new(1)
# BUG: needs mutexes with threads
    if status = @pending[pid]?
      chan.send status
      @pending.delete pid
    else
      @waiting[pid] = chan
    end
    chan
  end
end
