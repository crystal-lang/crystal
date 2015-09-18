# :nodoc:
class Process::WaitpidFuture
  def initialize pid
    @chan = Event::SignalChildHandler.instance.waitpid pid
    @has_value = false
    @value = nil
  end

  def value
    receive

    if value = @value
      return value
    else
      raise Channel::ClosedError.new("waitpid channel closed after forking")
    end
  end

  private def receive
    return if @has_value
    @value = @chan.receive
    @has_value = true
  end
end
