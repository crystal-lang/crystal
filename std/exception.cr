lib C
  fun backtrace(array : Void**, size : Int32) : Int32
  fun backtrace_symbols(array : Void**, size : Int32) : Char**
end

class Exception
  getter :message
  getter :inner_exception
  getter :backtrace

  def initialize(message = nil : String, inner_exception = nil : Exception)
    @message = message
    @inner_exception = inner_exception

    callstack = Pointer(Pointer(Void)).malloc(128)
    frames = C.backtrace(callstack, 128)
    strs = C.backtrace_symbols(callstack, frames)
    @backtrace = strs.map(frames) { |c_str| String.from_cstr(c_str) }
  end

  def to_s
    @message
  end
end
