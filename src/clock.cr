require "crystal/system/time"

# Monotonic Clock.
#
# A monotonic clock is tied to the system and isn't affected by time
# fluctuations, for example leap seconds or manually changing the computer's
# time.
#
# Compared to `Time`, a `Clock` value isn't interesting and most likely means
# nothing, but its value is guaranteed to be linearily increasing from a fixed
# point in time (whose origin is unspecified), thus useful to calculate the
# elapsed time between two clocks.
#
# Example:
#
# ```
# timeout = 5.seconds
# clock = Clock.monotonic
#
# until clock.elapsed?(timeout)
#   do_domething
# end
# ```
struct Clock
  include Comparable(self)
  include Comparable(Time::Span)
  include Comparable(Float64 | Float32)

  protected getter seconds : Int64
  protected getter nanoseconds : Int32

  # Creates a `Clock` from the system monotonic clock, which is guaranteed to be
  # always increasing as linearly as possible.
  def self.monotonic : self
    seconds, nanoseconds = Crystal::System::Time.monotonic
    new(seconds, nanoseconds)
  end

  # Measures how long the block takes to run.
  #
  # ```
  # seconds = Clock.duration { sleep(1.234) }
  # seconds # => close to 1.234
  # ```
  def self.duration : Time::Span
    start = monotonic
    yield
    monotonic - start
  end

  protected def initialize(@seconds, @nanoseconds)
  end

  def -(other : Time::Span)
    seconds = @seconds - other.to_i
    nanoseconds = @nanoseconds - other.nanoseconds
    Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
  end

  def -(other : self)
    seconds = @seconds - other.seconds
    nanoseconds = @nanoseconds - other.nanoseconds
    Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
  end

  def -(other : Float | Int)
    self - other.seconds
  end

  def <=>(other : Time::Span)
    cmp = @seconds <=> other.seconds
    cmp = @nanoseconds <=> other.nanoseconds if cmp == 0
    cmp
  end

  def <=>(other : self)
    cmp = @seconds <=> other.seconds
    cmp = @nanoseconds <=> other.nanoseconds if cmp == 0
    cmp
  end

  def <=>(other : Float | Int)
    self <=> other.seconds
  end

  # Returns true once *span* time has passed since the clock was created.
  #
  # ```
  # clock = Clock.monotonic
  #
  # until clock.elapsed?(5.seconds)
  #   do_domething
  # end
  # ```
  def elapsed?(span : Time::Span)
    (Clock.monotonic - self) >= span
  end

  # Returns true once *span* seconds have passed since the clock was created.
  def elapsed?(span : Float | Int)
    elapsed?(span.seconds)
  end

  def to_f
    @seconds + @nanoseconds.to_f / 1_000_000_000
  end

  def inspect(io : IO)
    @seconds.to_s(io)
    io << '.'
    io << '0' if @nanoseconds < 100_000_000
    io << '0' if @nanoseconds < 10_000_000
    io << '0' if @nanoseconds < 1_000_000
    io << '0' if @nanoseconds < 100_000
    io << '0' if @nanoseconds < 10_000
    io << '0' if @nanoseconds < 1_000
    io << '0' if @nanoseconds < 100
    io << '0' if @nanoseconds < 10
    @nanoseconds.to_s(io)
  end
end
