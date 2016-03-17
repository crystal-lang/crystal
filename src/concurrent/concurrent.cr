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

macro spawn(exp)
  {% if exp.is_a?(Call) %}
    ->(
      {% for arg, i in exp.args %}
        __arg{{i}} : typeof({{arg}}),
      {% end %}
      {% if exp.named_args %}
        {% for narg, i in exp.named_args %}
          __narg{{i}} : typeof({{narg.value}}),
        {% end %}
      {% end %}
      ) {
      spawn do
        {{exp.name}}(
          {% for arg, i in exp.args %}
            __arg{{i}},
          {% end %}
          {% if exp.named_args %}
            {% for narg, i in exp.named_args %}
              {{narg.name}}: __narg{{i}},
            {% end %}
          {% end %}
        )
      end
    {% if exp.named_args %}
      }.call({{*exp.args}}, {{*exp.named_args.map(&.value)}})
    {% else %}
      }.call({{*exp.args}})
    {% end %}
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
