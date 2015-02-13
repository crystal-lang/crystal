ifdef evented
  require "uv"
  require "fiber"
  require "./*"

  redefine_main do |main|
    {{ main }}
    Fiber.new do
      UV::Loop::DEFAULT.run
    end.resume
  end

  def sleep(t : Int | Float)
    timer = UV::Timer.new
    f = Fiber.current
    timer.start(t * 1000) do
      f.resume
    end
    Fiber.yield
  end

  macro spawn
    Fiber.new do
      begin
        {{ yield }}
      rescue ex
        puts "Unhandled exception: #{ex}"
      end
    end.resume
  end

else

  def spawn
    yield
  end

end
