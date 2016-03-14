# :nodoc:
# Singleton that runs Signal events (libevent2) in it's own Fiber.
class Event::SignalHandler
  def self.add_handler(*args)
    instance.add_handler *args
  end

  def self.del_handler(signal)
    @@instance.try &.del_handler(signal)
  end

  def self.after_fork
    @@instance.try &.after_fork
  end

  # finish processing signals
  def self.close
    @@instance.try &.close
    @@instance = nil
  end

  @@instance : Event::SignalHandler?

  private def self.instance
    @@instance ||= new
  end

  @callbacks : Hash(Signal, (Signal ->))
  @read_pipe : IO::FileDescriptor
  @write_pipe : IO::FileDescriptor

  @@write_pipe : IO::FileDescriptor?

  def initialize
    @callbacks = Hash(Signal, (Signal ->)).new
    @read_pipe, @write_pipe = IO.pipe
    @@write_pipe = @write_pipe

    spawn_reader
  end

  # :nodoc:
  def run
    read_pipe = @read_pipe
    sig = 0
    slice = Slice(UInt8).new pointerof(sig) as Pointer(UInt8), sizeof(typeof(sig))

    loop do
      bytes = read_pipe.read slice
      break if bytes == 0
      raise "bad read #{bytes} : #{slice.size}" if bytes != slice.size
      handle_signal Signal.new(sig)
    end
  end

  def after_fork
    close
    @read_pipe, @write_pipe = IO.pipe
    @@write_pipe = @write_pipe
    spawn_reader
  end

  def close
    # Close writer only: reader will give EOF
    @write_pipe.close
  end

  def add_handler(signal : Signal, callback)
    @callbacks[signal] = callback

    LibC.signal signal.value, ->(sig) do
      slice = Slice(UInt8).new pointerof(sig) as Pointer(UInt8), sizeof(typeof(sig))
      @@write_pipe.not_nil!.write slice
      nil
    end
  end

  def del_handler(signal : Signal)
    if callback = @callbacks[signal]?
      @callbacks.delete signal
    end
  end

  private def handle_signal(sig)
    if callback = @callbacks[sig]?
      callback.call sig
    else
      raise "missing #{sig} callback"
    end
  rescue ex
    ex.inspect_with_backtrace STDERR
    STDERR.puts "FATAL ERROR: uncaught signal #{sig} exception, exiting"
    STDERR.flush
    LibC._exit 1
  end

  private def spawn_reader
    spawn { run }
  end
end
