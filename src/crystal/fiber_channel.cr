# :nodoc:
#
# This struct wraps around a IO pipe to send and receive fibers between
# worker threads. The receiving thread will hang on listening for new fibers
# or fibers that become runnable by the execution of other threads, at the same
# time it waits for other IO events or timers within the event loop
struct Crystal::FiberChannel
  @worker_in : IO::FileDescriptor
  @worker_out : IO::FileDescriptor

  def initialize
    @worker_out, @worker_in = IO.pipe
  end

  def send(fiber : Fiber)
    @worker_in.write_bytes(fiber.object_id)
  end

  def receive
    oid = @worker_out.read_bytes(UInt64)
    Pointer(Fiber).new(oid).as(Fiber)
  end
end
