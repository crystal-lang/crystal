abstract class UV::Handle
  def close
    handle.value.data = Fiber.current as Void*
    LibUV.close(handle, ->(handle) {
      fiber = handle.value.data as Fiber
      fiber.resume
    })
    Fiber.yield
  end

  abstract def handle
end
