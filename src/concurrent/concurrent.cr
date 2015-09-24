require "fiber"
require "./*"

def sleep(seconds : Number)
  if seconds < 0
    raise ArgumentError.new "sleep seconds must be positive"
  end

  Scheduler.sleep(seconds)
end

def sleep(time : Time::Span)
  sleep(time.total_seconds)
end

macro spawn
  %fiber = Fiber.new do
    begin
      {{ yield }}
    rescue %ex
      STDERR.puts "Unhandled exception:"
      %ex.inspect_with_backtrace STDERR
      STDERR.flush
    end
  end

  Scheduler.enqueue %fiber
end

macro parallel(*jobs)
  %channel = Channel(Bool).new

  {% for job, i in jobs %}
    %ret{i} = nil
    spawn do
      %ret{i} = {{job}}
      %channel.send true
    end
  {% end %}

  {{ jobs.size }}.times { %channel.receive }

  {
    {% for job, i in jobs %}
      %ret{i}.not_nil!,
    {% end %}
  }
end
