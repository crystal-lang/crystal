require "callstack"
require "system_error"

CallStack.skip(__FILE__)

# This alias is defined to make the standard library code compatible with
# Crystal version < 0.34 and should be removed after the release of 0.34
{% unless @type.has_constant?("Raisable") %}
  alias Raisable = Exception
{% end %}

# Represents errors that occur during application execution.
#
# Raisable and its descendants are used to communicate between raise and
# rescue statements in `begin ... end` blocks.
# Raisable objects carry information about the exception – its type (the
# exception’s class name), an optional descriptive string, and
# optional traceback information.
# Raisable subclasses may add additional information.
# Raisable objects that are not subclasses of `Exception` are not handled
# by default on a `rescue` statement, and the type must be explicitly specified:
# ```
# begin
#   raise Raisable.new
# rescue Raisable
# end
# ```
class Raisable
  getter message : String?
  # Returns the previous exception at the time this exception was raised.
  # This is useful for wrapping exceptions and retaining the original
  # exception information.
  getter cause : Raisable?
  property callstack : CallStack?

  def initialize(@message : String? = nil, @cause : Raisable? = nil)
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
    {% if flag?(:win32) %}
      Array(String).new
    {% else %}
      @callstack.try &.printable_backtrace
    {% end %}
  end

  def to_s(io : IO) : Nil
    io << message
  end

  def inspect(io : IO) : Nil
    io << "#<" << self.class.name << ':' << message << '>'
  end

  def inspect_with_backtrace : String
    String.build do |io|
      inspect_with_backtrace io
    end
  end

  def inspect_with_backtrace(io : IO) : Nil
    io << message << " (" << self.class << ")\n"
    backtrace?.try &.each do |frame|
      io.print "  from "
      io.puts frame
    end

    if cause = @cause
      io << "Caused by: "
      cause.inspect_with_backtrace(io)
    end

    io.flush
  end
end

# The base class for most common errors that might be handled at runtime
#
# Instances of this class (and subclasses) are handled by `rescue` statements
# without types.
#
# ```
# begin
#   # ...
# rescue
#   # Any exception of `Exception` class is handled here
# end
# ```
class Exception
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
class TypeCastError < Raisable
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
# 1 // 0 # raises DivisionByZeroError (Division by 0)
# ```
class DivisionByZeroError < Exception
  def initialize(message = "Division by 0")
    super(message)
  end
end

# Raised when the result of an arithmetic operation is outside of the range
# that can be represented within the given operands types.
#
# ```
# Int32::MAX + 1      # raises OverflowError (Arithmetic overflow)
# Int32::MIN - 1      # raises OverflowError (Arithmetic overflow)
# Float64::MAX.to_f32 # raises OverflowError (Arithmetic overflow)
# ```
class OverflowError < Exception
  def initialize(message = "Arithmetic overflow")
    super(message)
  end
end

# Raised when a method is not implemented.
#
# This can be used either to stub out method bodies, or when the method is not
# implemented on the current platform.
class NotImplementedError < Raisable
  def initialize(item)
    super("Not Implemented: #{item}")
  end
end

# Raised when a `not_nil!` assertion fails.
#
# ```
# "hello".index('x').not_nil! # raises NilAssertionError ("hello" does not contain 'x')
# ```
class NilAssertionError < Raisable
  def initialize(message = "Nil assertion failed")
    super(message)
  end
end

# Raised when there is an internal runtime error
class RuntimeError < Exception
  include SystemError
end

# Raised when there is an inconsistent or unreachable state
class UnexpectedStateError < Raisable
end
