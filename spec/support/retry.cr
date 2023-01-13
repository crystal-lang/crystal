def retry(n = 5, &)
  exception = nil
  n.times do |i|
    yield
  rescue ex
    exception = ex
    if i == 0
      Fiber.yield
    else
      sleep 0.01 * (2**i)
    end
  else
    return
  end

  raise exception.not_nil!
end
