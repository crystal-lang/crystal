require "unwind"
require "dl"

def caller
  backtrace = [] of String
  backtrace_fn = ->(context : LibUnwind::Context, data : Void*) do
    bt = data as Array(String)
    ip = LibUnwind.get_ip(context)
    LibDL.dladdr(Pointer(Void).new(ip), out info)
    offset = ip - info.saddr.address

    if offset == 0
      LibDL.dladdr(Pointer(Void).new(ip - 1), pointerof(info))
      offset = ip - info.saddr.address
    end

    if info.sname.nil?
      bt << "[#{ip}] ???"
      LibUnwind::ReasonCode::NO_REASON
    else
      sname = String.new(info.sname)
      bt << "[#{ip}] #{sname} +#{offset}"
      ifdef i686
        # This is a workaround for glibc bug: https://sourceware.org/bugzilla/show_bug.cgi?id=18635
        # The unwind info is corrupted when `makecontext` is used.
        # Stop the backtrace here. There is nothing interest beyond this point anyway.
        sname == "makecontext" ? LibUnwind::ReasonCode::END_OF_STACK : LibUnwind::ReasonCode::NO_REASON
      else
        LibUnwind::ReasonCode::NO_REASON
      end
    end
  end
  LibUnwind.backtrace(backtrace_fn, backtrace as Void*)
  backtrace
end

class Exception
  getter message
  getter cause
  getter backtrace

  def initialize(message = nil : String?, cause = nil : Exception?)
    @message = message
    @cause = cause
    @backtrace = caller
  end

  def backtrace
    backtrace = @backtrace
    ifdef linux
      backtrace = backtrace.map do |frame|
        Exception.unescape_linux_backtrace_frame(frame)
      end
    end
    backtrace
  end

  def to_s(io : IO)
    if @message
      io << @message
    end
  end

  def inspect_with_backtrace
    String.build do |io|
      inspect_with_backtrace io
    end
  end

  def inspect_with_backtrace(io : IO)
    io << self << " (" << self.class << ")\n"
    backtrace.each do |frame|
      io.puts frame
    end
    io.flush
  end

  def self.unescape_linux_backtrace_frame(frame)
    frame.gsub(/_(\d|A|B|C|D|E|F)(\d|A|B|C|D|E|F)_/) do |match|
      first = match[1].to_i(16) * 16
      second = match[2].to_i(16)
      value = first + second
      value.chr
    end
  end
end

module Enumerable(T)
  class EmptyError < Exception
    def initialize(message = "Empty enumerable")
      super(message)
    end
  end
end

# Raised when the given index is invalid.
#
# ```
# a = [:foo, :bar]
# a[2] #=> IndexError: index out of bounds
# ```
class IndexError < Exception
  def initialize(message = "Index out of bounds")
    super(message)
  end
end

# Raised when the arguments are wrong and there isn't a more specific `Exception` class.
#
# ```
# [1, 2, 3].take(-4) #=> ArgumentError: attempt to take negative size
# ```
class ArgumentError < Exception
  def initialize(message = "Argument error")
    super(message)
  end
end

# Raised when the type cast failed.
#
# ```
# [1, "hi"][1] as Int32 #=> TypeCastError: cast to Int32 failed
# ```
class TypeCastError < Exception
  def initialize(message = "Type Cast error")
    super(message)
  end
end

class InvalidByteSequenceError < Exception
  def initialize(message = "Invalid byte sequence in UTF-8 string")
    super(message)
  end
end

# Raised when the specified key is not found.
#
# ```
# h = {"foo" => "bar"}
# h["baz"] #=> KeyError: Missing hash key: "baz"
# ```
class KeyError < Exception
end

class DivisionByZero < Exception
  def initialize(message = "Division by zero")
    super(message)
  end
end
