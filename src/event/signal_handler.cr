# :nodoc:
# Singleton that runs Signal events (libevent2) in it's own Fiber.
class Event::SignalHandler
  def self.add_handler *args
    instance.add_handler *args
  end

  def self.del_handler signal
    inst = @@instance
    if inst
      inst.del_handler signal
    end
  end

  def self.instance
    @@instance ||= begin
      inst = new
      spawn { inst.run }
      inst
    end
  end

  # finish processing signals
  def self.close
    @@instance.try &.close
    @@instance = nil
  end

  record CallbackEvent, callback, event

  def initialize
    @channel = Channel(Signal).new(32)
    @callbacks = Hash(Signal, CallbackEvent).new
  end

  # :nodoc:
  def run
    while sig = @channel.receive
      handle_signal sig
    end
  end

  def close
     @channel.close
  end

  def add_handler signal : Signal, callback
    event = Scheduler.create_signal_event signal, @channel
    @callbacks[signal] = CallbackEvent.new callback, event
  end

  def del_handler signal : Signal
    if cbe = @callbacks[signal]?
      cbe.event.free
      @callbacks.delete signal
    end
  end

  private def handle_signal sig
    if cbe = @callbacks[sig]?
      cbe.callback.call sig
    else
      raise "missing #{sig} callback"
    end
  rescue ex
    ex.inspect_with_backtrace STDERR
    STDERR.puts "FATAL ERROR: uncaught signal exception, exiting"
    STDERR.flush
    LibC._exit 1
  end
end


