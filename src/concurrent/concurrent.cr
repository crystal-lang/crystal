require "fiber"
require "./*"

Fiber.rescheduler = -> do
  Scheduler.reschedule
end

def sleep(t : Int | Float)
  Scheduler.sleep(t)
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
