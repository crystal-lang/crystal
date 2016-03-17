require "fiber"
require "./*"

def sleep(seconds : Number)
  if seconds < 0
    raise ArgumentError.new "sleep seconds must be positive"
  end

  Fiber.sleep(seconds)
end

def sleep(time : Time::Span)
  sleep(time.total_seconds)
end

def sleep
  Scheduler.reschedule
end

def spawn(&block)
  fiber = Fiber.new(&block)
  Scheduler.enqueue fiber
  fiber
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

macro parallel(*jobs)
  %channel = Channel(Bool).new

  {% for job, i in jobs %}
    %ret{i} = uninitialized typeof({{job}})
    spawn do
      %ret{i} = {{job}}
      %channel.send true
    end
  {% end %}

  {{ jobs.size }}.times { %channel.receive }

  {
    {% for job, i in jobs %}
      %ret{i},
    {% end %}
  }
end
