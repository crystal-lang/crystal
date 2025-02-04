def wait_until_blocked(f : Fiber, timeout = 5.seconds)
  now = Time.monotonic

  until f.resumable?
    Fiber.yield
    raise "Fiber failed to block within #{timeout}" if (Time.monotonic - now) > timeout
  end
end

def wait_until_finished(f : Fiber, timeout = 5.seconds)
  now = Time.monotonic
  until f.dead?
    Fiber.yield
    raise "Fiber failed to finish within #{timeout}" if (Time.monotonic - now) > timeout
  end
end

# Fake stack for `makecontext` to have somewhere to write in #initialize; We
# don't actually run the fiber. The worst case is windows with ~300 bytes (with
# shadow space and alignment taken into account). We allocate more to be safe.
FAKE_FIBER_STACK = GC.malloc(512)

def new_fake_fiber(name = nil)
  stack = FAKE_FIBER_STACK
  stack_bottom = FAKE_FIBER_STACK + 128

  {% if flag?(:execution_context) %}
    execution_context = Fiber::ExecutionContext.current
    Fiber.new(name, stack, stack_bottom, execution_context) { }
  {% else %}
    Fiber.new(name, stack, stack_bottom) { }
  {% end %}
end

