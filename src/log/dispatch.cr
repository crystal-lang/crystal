class Log
  # Base interface implemented by log entry dispatchers
  #
  # Dispatchers are in charge of sending log entries according
  # to different strategies.
  module Dispatcher
    alias Spec = Dispatcher | DispatchMode

    # Dispatch a log entry to the specified backend
    abstract def dispatch(entry : Entry, backend : Backend)

    # Close the dispatcher, releasing resources
    def close
    end

    # :nodoc:
    def self.for(mode : DispatchMode) : self
      case mode
      in .sync?
        SyncDispatcher.new
      in .async?
        AsyncDispatcher.new
      in .direct?
        DirectDispatcher
      end
    end
  end

  enum DispatchMode
    Sync
    Async
    Direct
  end

  # Stateless dispatcher that deliver log entries immediately
  module DirectDispatcher
    extend Dispatcher

    def self.dispatch(entry : Entry, backend : Backend)
      backend.write(entry)
    end
  end

  # Deliver log entries asynchronously through a channels
  class AsyncDispatcher
    include Dispatcher

    def initialize(buffer_size = 2048)
      @channel = Channel({Entry, Backend}).new(buffer_size)
      @done = Channel(Nil).new
      spawn write_logs
    end

    def dispatch(entry : Entry, backend : Backend) : Nil
      @channel.send({entry, backend})
    end

    private def write_logs
      while msg = @channel.receive?
        entry, backend = msg
        backend.write(entry)
      end

      @done.send nil
    end

    def close : Nil
      # TODO: this might fail if being closed from different threads
      unless @channel.closed?
        @channel.close
        @done.receive
      end
    end

    def finalize
      close
    end
  end

  # Deliver log entries directly. It uses a mutex to guarantee
  # one entry is delivered at a time.
  class SyncDispatcher
    include Dispatcher

    def initialize
      @mutex = Mutex.new(:unchecked)
    end

    def dispatch(entry : Entry, backend : Backend)
      @mutex.synchronize do
        backend.write(entry)
      end
    end
  end
end
