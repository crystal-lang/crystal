require "fiber"
require "channel"
require "crystal/scheduler"

# Blocks the current fiber for the specified number of seconds.
#
# While this fiber is waiting this time, other ready-to-execute
# fibers might start their execution.
def sleep(seconds : Number)
  if seconds < 0
    raise ArgumentError.new "Sleep seconds must be positive"
  end

  Crystal::Scheduler.sleep(seconds.seconds)
end

# Blocks the current Fiber for the specified time span.
#
# While this fiber is waiting this time, other ready-to-execute
# fibers might start their execution.
def sleep(time : Time::Span)
  Crystal::Scheduler.sleep(time)
end

# Blocks the current fiber forever.
#
# Meanwhile, other ready-to-execute fibers might start their execution.
def sleep
  Crystal::Scheduler.reschedule
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
def spawn(*, name : String? = nil, same_thread = false, &block)
  fiber = Fiber.new(name, &block)
  if same_thread
    fiber.@current_thread.set(Thread.current)
  end
  Crystal::Scheduler.enqueue fiber
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
macro spawn(call, *, name = nil, same_thread = false, &block)
  {% if block %}
    {% raise "`spawn(call)` can't be invoked with a block, did you mean `spawn(name: ...) { ... }`?" %}
  {% end %}

  {% if call.is_a?(Call) %}
    ->(
      {% for arg, i in call.args %}
        __arg{{i}} : typeof({{arg.is_a?(Splat) ? arg.exp : arg}}),
      {% end %}
      {% if call.named_args %}
        {% for narg, i in call.named_args %}
          __narg{{i}} : typeof({{narg.value}}),
        {% end %}
      {% end %}
      ) {
      spawn(name: {{name}}, same_thread: {{same_thread}}) do
        {% if call.receiver %}{{ call.receiver }}.{% end %}{{call.name}}(
          {% for arg, i in call.args %}
            {% if arg.is_a?(Splat) %}*{% end %}__arg{{i}},
          {% end %}
          {% if call.named_args %}
            {% for narg, i in call.named_args %}
              {{narg.name}}: __narg{{i}},
            {% end %}
          {% end %}
        )
      end
      }.call(
        {% for arg in call.args %}
          {{arg.is_a?(Splat) ? arg.exp : arg}},
        {% end %}
        {% if call.named_args %}
          {{call.named_args.map(&.value).splat}}
        {% end %}
      )
  {% else %}
    spawn do
      {{call}}
    end
  {% end %}
end
