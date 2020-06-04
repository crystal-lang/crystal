class Log
  module Dispatcher
    abstract def dispatch(entry : Entry, backend : Backend)

    def close
    end
  end

  module DirectDispatcher
    extend Dispatcher

    def self.dispatch(entry : Entry, backend : Backend)
      backend.write(entry)
    end
  end

  class AsyncDispatcher
    include Dispatcher

    def initialize(buffer_size = 2048)
      @channel = Channel({Entry, Backend}).new(buffer_size)
      spawn write_logs
    end

    def dispatch(entry : Entry, backend : Backend)
      @channel.send({entry, backend})
    end

    private def write_logs
      while msg = @channel.receive?
        entry, backend = msg
        backend.write(entry)
      end
    end

    def close
      @channel.close
    end
  end

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
