def wait_for(timeout = 100.milliseconds, sleeping = 10.microseconds, &)
  now = Time.instant

  Fiber.yield

  until value = yield
    sleep sleeping

    if now.elapsed > timeout
      return nil
    end

    sleeping *= 2
  end
  value
end
