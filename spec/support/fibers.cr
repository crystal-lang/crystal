def wait_until_blocked(f : Fiber)
  until f.resumable?
    Fiber.yield
  end
end

def wait_until_finished(f : Fiber)
  until f.dead?
    Fiber.yield
  end
end
