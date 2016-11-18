require "callstack"

CallStack.skip(__FILE__)

class Exception
  getter message : String?
  getter cause : Exception?
  property callstack : CallStack?

  def initialize(@message : String? = nil, @cause : Exception? = nil)
  end

  def backtrace
    self.backtrace?.not_nil!
  end

  def backtrace?
    @callstack.try &.printable_backtrace
  end

  def to_s(io : IO)
    io << message
  end

  def inspect_with_backtrace
    String.build do |io|
      inspect_with_backtrace io
    end
  end

  def inspect_with_backtrace(io : IO)
    io << message << " (" << self.class << ")\n"
    backtrace?.try &.each do |frame|
      io.puts frame
    end
    io.flush
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
# [1, 2, 3].first(-4) # => ArgumentError: attempt to take negative size
# ```
class ArgumentError < Exception
  def initialize(message = "Argument error")
    super(message)
  end
end

# Raised when the type cast failed.
#
# ```
# [1, "hi"][1].as(Int32) # => TypeCastError: cast to Int32 failed
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
