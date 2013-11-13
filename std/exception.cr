require "unwind.linux" if linux
require "unwind.darwin" if darwin

def caller
  cursor = Pointer(Int64).malloc(Unwind::CURSOR_SIZE)
  context = Pointer(Int64).malloc(Unwind::CONTEXT_SIZE)

  Unwind.get_context(context)
  Unwind.init_local(cursor, context)
  fname_size = 64
  fname_buffer = Pointer(Char).malloc(fname_size)

  backtrace = [] of String
  while Unwind.step(cursor) > 0
    Unwind.get_reg(cursor, Unwind::REG_IP, out pc)
    while true
      Unwind.get_proc_name(cursor, fname_buffer, fname_size, out offset)
      fname = String.new(fname_buffer)
      break if fname.length < fname_size - 1

      fname_size += 64
      fname_buffer = fname_buffer.realloc(fname_size)
    end
    backtrace << "#{fname} +#{offset} [#{pc}]"
  end
  backtrace
end

class Exception
  getter :message
  getter :inner_exception
  getter :backtrace

  def initialize(message = nil : String?, inner_exception = nil : Exception?)
    @message = message
    @inner_exception = inner_exception
    @backtrace = caller
  end

  def to_s
    bt = @backtrace.join("\n")
    if @message
      "#{@message}:\n#{bt}"
    else
      bt
    end
  end
end
