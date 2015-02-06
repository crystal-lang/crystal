require "fiber"

class UV::File
  include IO

  def initialize(filename, mode = "r")
    oflag = open_flag(mode)
    req :: LibUV::FsReq
    req.data = Fiber.current as Void*

    LibUV.fs_open(Loop::DEFAULT, pointerof(req), filename, oflag, File::DEFAULT_CREATE_MODE, ->(fs) {
      fiber = fs.value.data as Fiber
      fiber.resume
    })
    Fiber.yield

    if req.result == -1
      raise Errno.new("Error opening file '#{filename}' with mode '#{mode}'")
    end

    @handle = req.result
  end

  def close
    req :: LibUV::FsReq
    req.data = Fiber.current as Void*
    LibUV.fs_close(Loop::DEFAULT, pointerof(req), @handle, ->(fs) {
      (fs.value.data as Fiber).resume
    })
    Fiber.yield
  end

  def read(slice : Slice(UInt8), count)
    req :: LibUV::FsReq
    req.data = Fiber.current as Void*
    buf :: LibUV::Buf
    buf.base = slice.pointer(slice.length) as Void*
    buf.len = LibC::SizeT.cast(Math.min(slice.length, count))

    LibUV.fs_read(Loop::DEFAULT, pointerof(req), @handle, pointerof(buf), 1_u32, -1_i64, ->(fs) {
      fiber = fs.value.data as Fiber
      fiber.resume
    })
    Fiber.yield

    # TODO: check errors
    req.result
  end

  def write(slice : Slice(UInt8), count)
    req :: LibUV::FsReq
    req.data = Fiber.current as Void*
    buf :: LibUV::Buf
    buf.base = slice.pointer(slice.length) as Void*
    buf.len = LibC::SizeT.cast(Math.min(slice.length, count))

    LibUV.fs_write(Loop::DEFAULT, pointerof(req), @handle, pointerof(buf), 1_u32, -1_i64, ->(fs) {
      fiber = fs.value.data as Fiber
      fiber.resume
    })
    Fiber.yield

    # TODO: check errors
    req.result
  end

end
