# :nodoc:
{% if flag?(:preview_mt) %}
  struct Crystal::ThreadLocalValue(T)
    @values = Hash(Thread, T).new
    @mutex = Crystal::SpinLock.new

    def get(&block : -> T)
      th = Thread.current
      @mutex.sync do
        @values.fetch(th) do
          @values[th] = yield
        end
      end
    end

    def get?
      @mutex.sync do
        @values[Thread.current]?
      end
    end

    def set(value : T)
      @mutex.sync do
        @values[Thread.current] = value
      end
    end

    def consume_each
      @mutex.sync do
        @values.each_value { |t| yield t }
        @values.clear
      end
    end
  end
{% else %}
  struct Crystal::ThreadLocalValue(T)
    @value : T? = nil

    def get(&block : -> T)
      @value ||= yield
    end

    def get?
      @value
    end

    def set(value : T)
      @value = value
    end

    def consume_each
      @value.try { |v| yield v }
      @value = nil
    end
  end
{% end %}
