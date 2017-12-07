require "callstack"

CallStack.skip(__FILE__)

# Represents errors that occur during application execution.
#
# Exception and it's descendants are used to communicate between raise and
# rescue statements in `begin ... end` blocks.
# Exception objects carry information about the exception – its type (the
# exception’s class name), an optional descriptive string, and
# optional traceback information.
# Exception subclasses may add additional information.
class Exception
  class_getter colorize
  
  getter message : String?
  # Returns the previous exception at the time this exception was raised.
  # This is useful for wrapping exceptions and retaining the original
  # exception information.
  getter cause : Exception?
  property callstack : CallStack?

  def initialize(@message : String? = nil, @cause : Exception? = nil)
    {% if flag?(:release) %}
      @@colorize = STDERR.tty?
    {% else %}
      @@colorize = false
    {% end %}
  end

  def self.colorize=(@@colorize)
    CallStack.colorize = @@colorize
  end

  # Returns any backtrace associated with the exception.
  # The backtrace is an array of strings, each containing
  # “0xAddress: Function at File Line Column”.
  def backtrace
    self.backtrace?.not_nil!
  end

  # Returns any backtrace associated with the exception if the call stack exists.
  # The backtrace is an array of strings, each containing
  # “0xAddress: Function at File Line Column”.
  def backtrace?
    @callstack.try &.printable_backtrace
  end

  def to_s(io : IO)
    io << message
  end

  def inspect(io : IO)
    io << "#<" << self.class.name << ":" << message << ">"
  end

  def inspect_with_backtrace
    String.build do |io|
      inspect_with_backtrace io
    end
  end

  def Exception.colorize_backtrace(io, class_name, message)
    if @@colorize
      if message.nil?
        io << "\e[1m\e[31m" << class_name << "\e[0m\n"
      else
        io << "\e[1m\e[31m" << class_name << ": \e[0m\e[1m" << message.not_nil! << "\e[0m\n"
      end
    else
      io << class_name << (message.nil? ? "\n" : ": #{message}\n")
    end
  end

  def inspect_with_backtrace(io : IO)
    Exception.colorize_backtrace(io, self.class.name, message)

    backtrace?.try &.each do |frame|
      io.print "  from "
      io.puts frame
    end
    io.flush
  end
end

# Raised when the given index is invalid.
#
# ```
# a = [:foo, :bar]
# a[2] # raises IndexError
# ```
class IndexError < Exception
  def initialize(message = "Index out of bounds")
    super(message)
  end
end

# Raised when the arguments are wrong and there isn't a more specific `Exception` class.
#
# ```
# [1, 2, 3].first(-4) # raises ArgumentError (attempt to take negative size)
# ```
class ArgumentError < Exception
  def initialize(message = "Argument error")
    super(message)
  end
end

# Raised when the type cast failed.
#
# ```
# [1, "hi"][1].as(Int32) # raises TypeCastError (cast to Int32 failed)
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
# h["baz"] # raises KeyError (Missing hash key: "baz")
# ```
class KeyError < Exception
end

# Raised when attempting to divide an integer by 0.
#
# ```
# 1 / 0 # raises DivisionByZero (Division by zero)
# ```
class DivisionByZero < Exception
  def initialize(message = "Division by zero")
    super(message)
  end
end
