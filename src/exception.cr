require "unwind"
require "dl"

def caller
  CallStack.new.printable_backtrace
end

# :nodoc:
struct CallStack
  def initialize
    @callstack = CallStack.unwind
  end

  def printable_backtrace
    @backtrace ||= decode_backtrace
  end

  # This is only used for the workaround described in `Exception.callstack`
  protected def self.makecontext_range
    @@makecontext_range ||= begin
      makecontext_start = makecontext_end = LibDL.dlsym(LibDL::RTLD_DEFAULT, "makecontext")

      while true
        ret = LibDL.dladdr(makecontext_end, out info)
        break if ret == 0 || info.sname.nil?
        break unless LibC.strcmp(info.sname, "makecontext") == 0
        makecontext_end += 1
      end

      (makecontext_start...makecontext_end)
    end
  end

  protected def self.unwind
    callstack = [] of Void*
    backtrace_fn = ->(context : LibUnwind::Context, data : Void*) do
      bt = data as typeof(callstack)
      ip = Pointer(Void).new(LibUnwind.get_ip(context))
      bt << ip

      ifdef i686
        # This is a workaround for glibc bug: https://sourceware.org/bugzilla/show_bug.cgi?id=18635
        # The unwind info is corrupted when `makecontext` is used.
        # Stop the backtrace here. There is nothing interest beyond this point anyway.
        if CallStack.makecontext_range.includes?(ip)
          return LibUnwind::ReasonCode::END_OF_STACK
        end
      end

      LibUnwind::ReasonCode::NO_REASON
    end

    LibUnwind.backtrace(backtrace_fn, callstack as Void*)
    callstack
  end

  private def decode_backtrace
    backtrace = Array(String).new(@callstack.size)
    @callstack.each do |ip|
      frame = CallStack.decode_frame(ip)
      if frame
        offset, sname = frame
        backtrace << "[#{ip.address}] #{sname} +#{offset}"
      else
        backtrace << "[#{ip.address}] ???"
      end
    end
    backtrace
  end

  protected def self.decode_frame(ip, original_ip = ip)
    if LibDL.dladdr(ip, out info) != 0
      offset = original_ip - info.saddr

      if offset == 0
        return decode_frame(ip - 1, original_ip)
      end

      unless info.sname.nil?
        {offset, String.new(info.sname)}
      end
    end
  end
end

class Exception
  getter message
  getter cause

  def initialize(message = nil : String?, cause = nil : Exception?)
    @message = message
    @cause = cause
    @callstack = CallStack.new
  end

  def backtrace
    @callstack.printable_backtrace
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
# a[2] # => IndexError: index out of bounds
# ```
class IndexError < Exception
  def initialize(message = "Index out of bounds")
    super(message)
  end
end

# Raised when the arguments are wrong and there isn't a more specific `Exception` class.
#
# ```
# [1, 2, 3].take(-4) # => ArgumentError: attempt to take negative size
# ```
class ArgumentError < Exception
  def initialize(message = "Argument error")
    super(message)
  end
end

# Raised when the type cast failed.
#
# ```
# [1, "hi"][1] as Int32 # => TypeCastError: cast to Int32 failed
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
# h["baz"] # => KeyError: Missing hash key: "baz"
# ```
class KeyError < Exception
end

class DivisionByZero < Exception
  def initialize(message = "Division by zero")
    super(message)
  end
end

# Created when the program exit.
#
# This exception is not raised, but created in `exit` method internaly.
# You can see this in `at_exit` block.
#
# ```
# at_exit do |error|
#   p error
# end
#
# exit 1 # SystemExit: Program exit with status 1
# ```
class SystemExit < Exception
  def initialize(status, message = "Program exit with status #{status}")
    super(message)
  end
end
