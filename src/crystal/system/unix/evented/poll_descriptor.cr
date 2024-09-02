module Crystal::Evented
  struct Waiters
    @ready = Atomic(Bool).new(false)
    @lock = SpinLock.new
    @list = PointerLinkedList(Event).new

    def add(event : Pointer(Event)) : Bool
      {% if flag?(:preview_mt) %}
        # we check for readyness to avoid a race condition with another thread
        # running the evloop and trying to wakeup a waiting fiber while we try to
        # add a waiting fiber
        return false if ready?

        @lock.sync do
          return false if ready?
          @list.push(event)
        end
      {% else %}
        @list.push(event)
      {% end %}

      true
    end

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
    @event_loop : Evented::EventLoop?
    @lock = SpinLock.new
    @readers = Waiters.new
    @writers = Waiters.new

    def take_ownership(event_loop : EventLoop, fd : Int32, gen_index : Int64) : Nil
      @lock.sync do
        current = @event_loop

        if event_loop == current
          raise "BUG: evloop already owns the poll-descriptor for fd=#{fd}"
        end

        # ensure we can't have cross enqueues after we transfer the fd, so we
        # can optimize (all enqueues are local)
        if current && @readers.@list.empty? && @writers.@list.empty?
          raise RuntimeError.new("BUG: transfering fd=#{fd} to another evloop with pending reader/writer fibers")
        end

        @event_loop = event_loop
        event_loop.system_add(fd, gen_index)
        current.try(&.system_del(fd))
      end
    end

    def release(fd : Int32) : Nil
      @lock.sync do
        current, @event_loop = @event_loop, nil
        current.try(&.system_del(fd))
      end
    end
  end
end
