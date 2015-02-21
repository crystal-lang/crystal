ifdef evented
  require "uv"
  require "fiber"
  require "./*"

  Fiber.rescheduler = -> do
    Scheduler.reschedule
  end

  def sleep(t : Int | Float)
    timer = UV::Timer.new
    f = Fiber.current
    timer.start(t * 1000) do
      f.resume
    end
    Scheduler.reschedule
  end

  macro spawn
    fiber = Fiber.new do
      begin
        {{ yield }}
      rescue ex
        puts "Unhandled exception: #{ex}"
      end
    end

    Scheduler.enqueue fiber
  end

else

  def spawn
    yield
  end

end
