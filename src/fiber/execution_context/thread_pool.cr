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
          @mutex = Thread::Mutex.new
          @condition_variable = Thread::ConditionVariable.new
        end

        def synchronize(&)
          @mutex.synchronize { yield }
        end

        def wake
          @condition_variable.signal
        end

        def wait
          @condition_variable.wait(@mutex)
        end

        def wait(timeout, &)
          @condition_variable.wait(@mutex, timeout) { yield }
        end

        def linked?
          !@previous.null?
        end
      end

      def initialize
        @mutex = Thread::Mutex.new
        @condition_variable = Thread::ConditionVariable.new
        @pool = Crystal::PointerLinkedList(Parked).new
        @main_thread = Thread.current
      end

      protected def checkout(scheduler)
        thread =
          if parked = @mutex.synchronize { @pool.shift? }
            parked.value.synchronize do
              attach(parked.value.thread, scheduler)
              parked.value.wake
            end
            parked.value.thread
          else
            # OPTIMIZE: start thread with minimum stack size
            Thread.new do |thread|
              attach(thread, scheduler)
              enter_thread_loop(thread)
            end
          end
        Crystal.trace :sched, "thread.checkout", thread: thread
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
        Crystal.trace :sched, "thread.checkin"
        thread = Thread.current
        detach(thread)

        if thread == @main_thread
          resume(main_thread_loop)
        else
          Thread.name = ""
          resume(thread.main_fiber)
        end
      end

      private def main_thread_loop
        @main_thread_loop ||= begin
          # OPTIMIZE: allocate minimum stack size
          pointer = Crystal::System::Fiber.allocate_stack(StackPool::STACK_SIZE, protect: true)
          stack = Stack.new(pointer, StackPool::STACK_SIZE, reusable: true)
          Fiber.new(execution_context: ExecutionContext.default) { enter_thread_loop(@main_thread) }
        end
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
        parked.synchronize do
          loop do
            if scheduler = thread.scheduler?
              unless thread == @main_thread
                Thread.name = scheduler.name
              end

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

            @mutex.synchronize do
              @pool.push pointerof(parked)
            end

            if thread == @main_thread
              # never shutdown the main thread: the main fiber is running on its
              # original stack, terminating the main thread would invalidate the
              # main fiber stack (oops)
              parked.wait
            else
              parked.wait(ExecutionContext.thread_keepalive) do
                # reached timeout: try to shutdown thread, but another thread
                # might dequeue from @pool in parallel: run checks to avoid any
                # race condition:
                if !thread.scheduler? && parked.linked?
                  deleted = false

                  @mutex.synchronize do
                    if parked.linked?
                      @pool.delete pointerof(parked)
                      deleted = true
                    end
                  end

                  if deleted
                    # no attached scheduler and we removed ourselves from the
                    # pool: we can safely shutdown (no races)
                    Crystal.trace :sched, "thread.shutdown"
                    return
                  end

                  # no attached scheduler but another thread removed ourselves
                  # from the pool and is waiting to acquire parked.mutex to
                  # handoff a scheduler: unsync so it can progress
                  parked.wait
                end
              end
            end
          rescue exception
            Crystal.trace :sched, "thread.exception",
              class: exception.class.name,
              message: exception.message

            Crystal.print_error_buffered("BUG: %s#enter_thread_loop crashed",
              self.class.name, exception: exception)
          end
        end
      end

      private def resume(fiber) : Nil
        Crystal.trace :sched, "thread.resume", fiber: fiber

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
