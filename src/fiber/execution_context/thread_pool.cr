class Fiber
  module ExecutionContext
    # How long a parked thread will be kept waiting in the thread pool.
    # Defaults to 5 minutes.
    class_property thread_keepalive : Time::Span = 5.minutes

    # :nodoc:
    class ThreadPool
      # :nodoc:
      struct Parked
        include Crystal::PointerLinkedList::Node

        getter thread : Thread

        def initialize(@thread : Thread)
          @condition_variable = Thread::ConditionVariable.new
        end

        def wake
          Crystal.trace :thread, "wake", thread: @thread
          @condition_variable.signal
        end

        def wait(mutex)
          Crystal.trace :thread, "wait"
          @condition_variable.wait(mutex)
        end

        def wait(mutex, timeout, &)
          Crystal.trace :thread, "wait", timeout: timeout.to_nanoseconds
          @condition_variable.wait(mutex, timeout) { yield }
        end
      end

      def initialize
        @mutex = Thread::Mutex.new
        @pool = Crystal::PointerLinkedList(Parked).new
        @main_thread = Thread.current
      end

      protected def checkout(scheduler)
        thread = nil

        @mutex.synchronize do
          if parked = @pool.shift?
            thread = parked.value.thread

            attach(thread, scheduler)
            parked.value.wake
          end
        end

        thread ||= Thread.new do |thread|
          Crystal.trace :thread, "start"

          attach(thread, scheduler)
          enter_thread_loop(thread)
        end

        Crystal.trace :thread, "checkout", thread: thread
        thread
      end

      protected def attach(thread, scheduler) : Nil
        thread.execution_context = scheduler.execution_context
        thread.scheduler = scheduler
        scheduler.thread = thread
      end

      protected def detach(thread) : Nil
        thread.execution_context = nil
        thread.scheduler = nil
      end

      protected def checkin : Nil
        Crystal.trace :thread, "checkin"

        thread = Thread.current
        detach(thread)

        Thread.name = "" unless thread == @main_thread
        thread.internal_name = "?"

        resume(thread.main_fiber)
      end

      def enter_main_thread_loop(fiber : Fiber) : Nil
        # switch execution to the main user code fiber
        resume(fiber)

        # execution switched back to the main fiber, which means that the thread
        # has checkin into the thread pool: enter the main loop
        enter_thread_loop(@main_thread)
      end

      # Each thread has a general loop, which is used to park the thread while
      # it's in the thread pool. On startup then on wakeup it will resume the
      # associated scheduler's main fiber, which itself is running the
      # scheduler's run loop.
      #
      # Upon checkout the thread pool will merely resume the thread's main loop,
      # leaving the scheduler's main fiber available for resume by another
      # thread if needed, or left dead if the scheduler has shut down (e.g.
      # isolated context).
      private def enter_thread_loop(thread)
        parked = Parked.new(thread)

        while true
          scheduler = wait_for_scheduler?(thread, pointerof(parked))

          unless scheduler
            Crystal.trace :thread, "shutdown"
            return
          end

          Thread.name = scheduler.name unless thread == @main_thread
          thread.internal_name = scheduler.name

          resume(scheduler.main_fiber)

          {% unless flag?(:interpreted) %}
            if (stack = Thread.current.dead_fiber_stack?) && stack.reusable?
              # release pending fiber stack left after swapcontext; we don't
              # know which stack pool to return it to, and it may not even
              # have one (e.g. isolated fiber stack)
              Crystal::System::Fiber.free_stack(stack.pointer, stack.size)
            end
          {% end %}
        end
      rescue exception
        Crystal.trace :thread, "exception", class: exception.class.name, message: exception.message

        # panic: the thread loop crashing is an unexpected runtime error
        Crystal.print_error_buffered("BUG: %s#enter_thread_loop crashed", self.class.name, exception: exception)
        LibC.exit(1)
      end

      private def wait_for_scheduler?(thread, parked)
        # usually empty, save for the first iteration of a new thread
        if scheduler = thread.scheduler?
          return scheduler
        end

        @mutex.synchronize do
          # always empty, but quick check just in case
          if scheduler = thread.scheduler?
            return scheduler
          end

          @pool.push(parked)

          while true
            if can_terminate?(thread)
              parked.value.wait(@mutex, ExecutionContext.thread_keepalive) do
                # reached timeout: synchronize with #checkout
                if scheduler = thread.scheduler?
                  return scheduler
                end

                # no race: cleanup and terminate
                @pool.delete(parked)
                return
              end
            else
              parked.value.wait(@mutex)
            end

            if scheduler = thread.scheduler?
              return scheduler
            end
          end
        end
      end

      private def can_terminate?(thread)
        {% if flag?(:win32) || Crystal::EventLoop.has_constant?(:IOCP) %}
          # never shutdown a thread on windows: it would abort pending I/O
          # operations (for example `Socket#accept`) that the thread has started
          #
          # TODO: keep an async operation counter on the thread, so we may
          # eventually terminate the thread (check on every keepalive timeout)
          false
        {% else %}
          # never shutdown the main thread: the process would exit immediately
          # while the main user code fiber is still running
          thread != @main_thread
        {% end %}
      end

      private def resume(fiber) : Nil
        Crystal.trace :thread, "resume", fiber: fiber

        # FIXME: duplicates Fiber::ExecutionContext::MultiThreaded::Scheduler#resume:
        attempts = 0
        until fiber.resumable?
          raise "BUG: tried to resume dead fiber #{fiber} (#{inspect})" if fiber.dead?
          attempts = Thread.delay(attempts)
        end

        # FIXME: duplicates Fiber::ExecutionContext::Scheduler#swapcontext:
        thread = Thread.current
        current_fiber = thread.current_fiber

        GC.lock_read
        thread.current_fiber = fiber
        Fiber.swapcontext(pointerof(current_fiber.@context), pointerof(fiber.@context))
        GC.unlock_read
      end
    end
  end
end
