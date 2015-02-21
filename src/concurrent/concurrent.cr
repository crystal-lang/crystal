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

  # TODO: this doesn't work if a Call has a block or named arguments... yet
  macro spawn(exp)
    {% if exp.is_a?(Call) %}
      ->(
        {% for arg, i in exp.args %}
          __arg{{i}} : typeof({{arg}}),
        {% end %}
        ) {
        spawn do
          {{exp.name}}(
            {% for arg, i in exp.args %}
              __arg{{i}},
            {% end %}
          )
        end
      }.call({{*exp.args}})
    {% else %}
      spawn do
        {{exp}}
      end
    {% end %}
  end
else
  def spawn
    yield
  end

  macro spawn(exp)
    {{exp}}
  end
end
