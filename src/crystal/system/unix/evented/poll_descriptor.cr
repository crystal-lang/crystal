module Crystal::Evented
  struct Waiters
    @ready = Atomic(Bool).new(false)
    @lock = SpinLock.new
    @list = PointerLinkedList(Event).new

    def delete(event) : Nil
      @lock.sync { @list.delete(event) }
    end

    def consume_each(&) : Nil
      @lock.sync do
        @list.consume_each { |event| yield event }
      end
    end

    def ready? : Bool
      @ready.swap(false, :relaxed)
    end

    def ready! : Pointer(Event)?
      @lock.sync do
        {% if flag?(:preview_mt) %}
          if event = @list.shift?
            event
          else
            @ready.set(true, :relaxed)
            nil
          end
        {% else %}
          @list.shift?
        {% end %}
      end
    end
  end

  struct PollDescriptor
    @readers = Waiters.new
    @writers = Waiters.new
  end
end
