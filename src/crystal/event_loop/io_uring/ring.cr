require "../../system/unix/io_uring"

class Crystal::EventLoop::IoUring < Crystal::EventLoop
  # Extends the system abstraction with additional state and helpers tailored
  # for the event loop implementation.
  class Ring < System::IoUring
    getter? waiting : Bool = false

    {% if flag?(:preview_mt) %}
      @sq_lock : Thread::Mutex?
    {% end %}

    {% if flag?(:execution_context) %}
      # uninitialized-safety: compiler fails to notice the actual initialization
      # because of comptime flags
      @cq_lock = uninitialized Thread::Mutex
    {% end %}

    def initialize(*args, **kwargs)
      super(*args, **kwargs)

      # TODO: not needed after <https://github.com/crystal-lang/crystal/issues/16157>
      @rng = Random::PCG32.new

      {% if flag?(:preview_mt) %}
        # unless IORING_REGISTER_SYNC_CANCEL (Linux 6.0) and
        # IORING_REGISTER_SEND_MSG_RING (Linux 6.13) are supported we may have
        # multiple threads trying to submit to the ring (on evloop interrupt and
        # before closing an IO::FileDescriptor)
        unless System::IoUring.supports_register_sync_cancel? && System::IoUring.supports_register_send_msg_ring?
          @sq_lock = Thread::Mutex.new
        end
      {% end %}

      {% if flag?(:execution_context) %}
        @cq_lock = Thread::Mutex.new
      {% end %}
    end

    def waiting(&)
      @waiting = true
      yield
    ensure
      @waiting = false
    end

    # Acquires the SQ lock for the duration of the block if required.
    def sq_lock(&)
      {% if flag?(:preview_mt) %}
        if sq_lock = @sq_lock
          return sq_lock.synchronize { yield }
        end
      {% end %}

      yield
    end

    # Acquires the CQ lock for the duration of the block.
    def cq_lock(&)
      {% if flag?(:execution_context) %}
        @cq_lock.synchronize { yield }
      {% else %}
        yield
      {% end %}
    end

    # Tries to acquire the CQ lock for the duration of the block. Returns
    # immediately if the CQ lock couldn't be acquired.
    def cq_trylock?(&)
      {% if flag?(:execution_context) %}
        if @cq_lock.try_lock
          begin
            yield
          ensure
            @cq_lock.unlock
          end
        end
      {% else %}
        yield
      {% end %}
    end

    # Locks the SQ ring, reserves exactly one SQE and submits before returning.
    def submit(&)
      sq_lock do
        sqe = next_sqe
        yield sqe
        System::IoUring.trace(sqe)

        submit
      end
    end

    # Locks the SQ ring, reserves as many SQE as needed to fill *sqes* and
    # submits before returning.
    def submit(sqes : Slice(LibC::IoUringSqe*), &)
      sq_lock do
        reserve(sqes.size)

        sqes.size.times { |i| sqes[i] = unsafe_next_sqe }
        yield sqes
        sqes.each { |sqe| System::IoUring.trace(sqe) }

        submit
      end
    end
  end
end
