require "fiber"
require "./concurrent/*"

# Blocks the current fiber for the specified number of seconds.
#
# While this fiber is waiting this time other ready-to-execute
# fibers might start their execution.
def sleep(seconds : Number)
  if seconds < 0
    raise ArgumentError.new "Sleep seconds must be positive"
  end

  Fiber.sleep(seconds)
end

# Blocks the current Fiber for the specified time span.
#
# While this fiber is waiting this time other ready-to-execute
# fibers might start their execution.
def sleep(time : Time::Span)
  sleep(time.total_seconds)
end

# Blocks the current fiber forever.
#
# Meanwhile, other ready-to-execute fibers might start their execution.
def sleep
  Scheduler.reschedule
end

# Spawns a new fiber.
#
# The newly created fiber doesn't run as soon as spawned.
#
# Example:
# ```
# # Write "1" every 1 second and "2" every 2 seconds for 6 seconds.
#
# ch = Channel(Nil).new
#
# spawn do
#   6.times do
#     sleep 1
#     puts 1
#   end
#   ch.send(nil)
# end
#
# spawn do
#   3.times do
#     sleep 2
#     puts 2
#   end
#   ch.send(nil)
# end
#
# 2.times { ch.receive }
# ```
def spawn(*, name : String? = nil, &block)
  fiber = Fiber.new(name, &block)
  Scheduler.enqueue fiber
  fiber
end

# Spawns a fiber by first creating a `Proc`, passing the *call*'s
# expressions to it, and letting the `Proc` finally invoke the *call*.
#
# Compare this:
#
# ```
# i = 0
# while i < 5
#   spawn { print(i) }
#   i += 1
# end
# Fiber.yield
# # Output: 55555
# ```
#
# To this:
#
# ```
# i = 0
# while i < 5
#   spawn print(i)
#   i += 1
# end
# Fiber.yield
# # Output: 01234
# ```
#
# This is because in the first case all spawned fibers refer to
# the same local variable, while in the second example copies of
# *i* are passed to a `Proc` that eventually invokes the call.
macro spawn(call, *, name = nil)
  {% if call.is_a?(Call) %}
    ->(
      {% for arg, i in call.args %}
        __arg{{i}} : typeof({{arg}}),
      {% end %}
      {% if call.named_args %}
        {% for narg, i in call.named_args %}
          __narg{{i}} : typeof({{narg.value}}),
        {% end %}
      {% end %}
      ) {
      spawn(name: {{name}}) do
        {% if call.receiver %}{{ call.receiver }}.{% end %}{{call.name}}(
          {% for arg, i in call.args %}
            __arg{{i}},
          {% end %}
          {% if call.named_args %}
            {% for narg, i in call.named_args %}
              {{narg.name}}: __narg{{i}},
            {% end %}
          {% end %}
        )
      end
    {% if call.named_args %}
      }.call({{*call.args}}, {{*call.named_args.map(&.value)}})
    {% else %}
      }.call({{*call.args}})
    {% end %}
  {% else %}
    spawn do
      {{call}}
    end
  {% end %}
end

# Wraps around exceptions re-raised from concurrent calls.
# The original exception can be accessed via `#cause`.
class ConcurrentExecutionException < Exception
end

# Runs the commands passed as arguments concurrently (in Fibers) and waits
# for them to finish.
#
# ```
# def say(word)
#   puts word
# end
#
# # Will print out the three words concurrently
# parallel(
#   say("concurrency"),
#   say("is"),
#   say("easy")
# )
# ```
#
# Can also be used to conveniently collect the return values of the
# concurrent operations.
#
# ```
# def concurrent_job(word)
#   word
# end
#
# a, b, c =
#   parallel(
#     concurrent_job("concurrency"),
#     concurrent_job("is"),
#     concurrent_job("easy")
#   )
#
# puts a # => "concurrency"
# puts b # => "is"
# puts c # => "easy"
# ```
#
# Due to the concurrent nature of this macro, it is highly recommended
# to handle any exceptions within the concurrent calls. Unhandled
# exceptions raised within the concurrent operations will be re-raised
# inside the parent fiber as `ConcurrentExecutionException`, with the
# `cause` attribute set to the original exception.
macro parallel(*jobs)
  %channel = Channel(Exception | Nil).new

  {% for job, i in jobs %}
    %ret{i} = uninitialized typeof({{job}})
    spawn do
      begin
        %ret{i} = {{job}}
      rescue e : Exception
        %channel.send e
      else
        %channel.send nil
      end
    end
  {% end %}

  {{ jobs.size }}.times do
    %value = %channel.receive
    if %value.is_a?(Exception)
      raise ConcurrentExecutionException.new(
        "An unhandled error occured inside a `parallel` call",
        cause: %value
      )
    end
  end

  {
    {% for job, i in jobs %}
      %ret{i},
    {% end %}
  }
end
