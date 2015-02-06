abstract class UV::Stream < UV::Handle
  include IO

  def write(slice : Slice(UInt8), count)
    write_req :: LibUV::Write
    write_req.data = Fiber.current as Void*
    buf :: LibUV::Buf
    buf.base = slice.pointer(slice.length) as Void*
    buf.len = LibC::SizeT.cast(slice.length)

    LibUV.write(pointerof(write_req), stream, pointerof(buf), 1_u32, ->(write, status) {
      fiber = write.value.data as Fiber
      write.value.data = Pointer(Void).new(status.to_u64)
      fiber.resume
    })

    Fiber.yield
  end

  def read(slice : Slice(UInt8), count)
    @reading = true
    @current_buf.len = LibC::SizeT.cast(Math.min(slice.length, count))
    @current_buf.base = slice.pointer(@current_buf.len) as Void*
    @current_fiber = Fiber.current

    LibUV.read_start(stream,
      ->(handle, size, buf) {
        this = handle.value.data as TCPSocket
        buf.value = this.@current_buf
      },
      ->(stream, nread, buf) {
        if nread != 0
          this = stream.value.data as TCPSocket
          this.set_nread nread
          this.@current_fiber.not_nil!.resume

          unless this.@reading
            LibUV.read_stop(stream)
          end
        end
      })

    Fiber.yield
    @reading = false
    @nread.not_nil!
  end

  def handle
    stream as LibUV::Handle*
  end

  abstract def stream
end
