def wait_until_blocked(f : Fiber, timeout = 5.seconds)
  now = Time.instant

  until f.resumable?
    Fiber.yield
    raise "Fiber failed to block within #{timeout}" if now.elapsed > timeout
  end
end

def wait_until_finished(f : Fiber, timeout = 5.seconds)
  now = Time.instant
  until f.dead?
    Fiber.yield
    raise "Fiber failed to finish within #{timeout}" if now.elapsed > timeout
  end
end

# Fake stack for `makecontext` to have somewhere to write in #initialize. We
# don't actually run the fiber. The worst case is windows with ~300 bytes (with
# shadow space and alignment taken into account). We allocate more to be safe.
FAKE_FIBER_STACK = GC.malloc(512)

def new_fake_fiber(name = nil)
  stack = Fiber::Stack.new(FAKE_FIBER_STACK, FAKE_FIBER_STACK + 512)
  Fiber.new(name, stack) { }
end
