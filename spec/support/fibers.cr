def wait_until_blocked(f : Fiber, timeout = 5.seconds)
  now = Time.monotonic

  until f.resumable?
    Fiber.yield
    raise "fiber failed to block within #{timeout}" if (Time.monotonic - now) > timeout
  end
end

def wait_until_finished(f : Fiber, timeout = 5.seconds)
  now = Time.monotonic
  until f.dead?
    Fiber.yield
    raise "fiber failed to finish within #{timeout}" if (Time.monotonic - now) > timeout
  end
end
