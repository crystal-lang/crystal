# A type-safe, immutable object representing the result of an
# operation which may fail. A `Maybe` can be used instead of
# exception handling. This provides a less ambiguous API and more
# idiomatic flow control. Additionally, `Nil` is a valid value so its
# use is never ambiguous. `Maybe` can also replace the Null Object
# pattern in many cases.
#
# A `Maybe` object has only two possible states: `#succeeded?` or
# `#failed?`. When a `Maybe` reprsents success, the `#result` of the
# operation is available via getter method. A value of `Nil` is
# valid on success. When a `Maybe` represents failure, the `Exception`
# can is available via the `#failure` getter. For convenience the
# `#message` getter can be used to retrieve a simple string describing
# the reason.
#
# When the reason for a failure is irrelevant, simpler control flow
# is facilitated by the `#result_or` methods, which provide either a
# value or a block operation to be substituted when the `Maybe` is a
# failure.
#
# Because a `Maybe` is immutable, creation is via factory method. The
# `.succeed` factory creates a successful `Maybe` and sets the result.
# The `.fail` factory creates a failed `Maybe` and set the `failure`.
# The only constructor method available takes a block. If the block
# operation succeeds the `Maybe` is successful and the block's return
# value becomes the result. If the block operation raises an exception
# the `Maybe` is failed and the raised exception becomes the failure.
#
# ```
# require "json"
#
# json_str = "[1, 2, 3]"
# value = Maybe(JSON::Any).new do
#   JSON.parse(json_str) # will succeed
# end
#
# value.succeeded? # => true
# value.failed?    # => false
# value.result     # => [1, 2, 3]
# value.failure    # => nil
#
# json_str = "not valid json"
# value = Maybe(JSON::Any).new do
#   JSON.parse(json_str) # will raise an exception
# end
#
# value.succeeded? # => false
# value.failed?    # => true
# value.result     # => nil
# value.failure    # => #<JSON::ParseException:0x10b367d00 @message="unexpected char...
#
# value = Maybe.succeed(42)
# value.succeeded? # => true
# value.result     # => 42
#
# value = Maybe(Int32).fail("What do you get when you multiply 6 by 9?")
# value.failed? # => true
# value.failure # => #<Exception:0x107cf0d40 @message="What do you get...
# value.message # => "What do you get when you multiply 6 by 9?"
# ```
struct Maybe(T)
  getter result, failure

  def succeeded?
    @failure.nil?
  end

  def failed?
    !succeeded?
  end

  # A string explaining the failure when failed, else `Nil`.
  def message
    failed? ? @failure.to_s : ""
  end

  # Returns the result of the operation when it was successful else
  # returns the given value.
  def result_or(value : T)
    succeeded? ? result : value
  end

  # Returns the result of the operation when it was successful else
  # returns the result of the given block operation. Note that no
  # exception handling for the block is provided. Exceptions raised
  # from within the block will bubble normally.
  def result_or(&block : -> T)
    result_or(yield)
  end

  # Construct a new `Maybe` representing success, using the given
  # value as the result.
  def self.succeed(result : T | Nil)
    Maybe.new(result)
  end

  # Construct a new `Maybe` representing failure, using the given
  # `Exception` as the failure reason.
  def self.fail(failure : Exception)
    Maybe(T).new(failure)
  end

  # Construct a new `Maybe` representing failure. Will construct a
  # new `Exception` using the given message and use it as the failure
  # reason.
  def self.fail(message : String)
    Maybe(T).new(Exception.new(message))
  end

  # Create a new `Maybe` using the result of the block operation. If
  # the block raises an exception it will be rescued, the `Maybe` will
  # be failed, and the raised `Exception` will be used as the failure
  # reason. If no exception is raised the `Maybe` will have succeeded
  # and the value returned by the block will be the result.
  def initialize(&block : -> T | Nil | Exception)
    begin
      @result = yield
      @failure = nil
    rescue ex
      @result = nil
      @failure = ex
    end
  end

  protected def initialize(@result : T | Nil)
    @failure = nil
  end

  protected def initialize(@failure : Exception)
    @result = nil
  end
end
