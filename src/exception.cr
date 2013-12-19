require "exception.linux32" if linux && !x86_64
require "exception.linux64" if linux && x86_64
require "exception.darwin" if darwin

def caller
  cursor = Pointer(C::SizeT).malloc(Unwind::CURSOR_SIZE)
  context = Pointer(C::SizeT).malloc(Unwind::CONTEXT_SIZE)

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
  def initialize(message = nil : String?, inner_exception = nil : Exception?)
    @message = message
    @inner_exception = inner_exception
    @backtrace = caller
  end

  def message
    @message
  end

  def inner_exception
    @inner_exception
  end

  def backtrace
    @backtrace
  end

  def to_s
    bt = @backtrace
    if Exception.needs_to_unescape_backtraces?
      bt = bt.map! { |frame| Exception.unescape_backtrace(frame) }
    end
    bt = bt.join("\n")
    if @message
      "#{@message}:\n#{bt}"
    else
      bt
    end
  end

  def self.unescape_linux_backtrace_frame(frame)
    frame.replace(/_(\d|A|B|C|D|E|F)(\d|A|B|C|D|E|F)_/) do |match|
      first = match[1].to_i(16) * 16
      second = match[2].to_i(16)
      value = first + second
      value.chr
    end
  end
end

class IndexOutOfBounds < Exception
end

class ArgumentError < Exception
end
