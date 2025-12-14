# Returns the current reading of the monotonic clock.
#
# The execution time of a block can be measured using `.measure`.
def Time.instant : Time::Instant
  Crystal::System::Time.instant
end

# `Time::Instant` represents a reading of a monotonic non-decreasing
# clock for the purpose of measuring elapsed time or timing an event in the future.
#
# Instants are opaque values that have no public constructor or raw accessors by
# default. They can only be obtained from the clock (`Time.instant`) and compared to one another.
# The only useful values are differences between readings, represented as `Time::Span`.
#
# ## Clock properties
#
# Clock readings are guaranteed, barring platform bugs, to be no less than any
# previous reading (monotonic clock).
#
# The measurement itself is expected to be fast (low latency) and precise within
# nanosecond resolution. This means it might not provide the best available
# accuracy for long-term measurements.
#
# The clock is not guaranteed to be steady. Ticks of the underlying clock might
# vary in length. The clock may jump forwards or experience time dilation. But
# it never goes backwards.
#
# The clock is expected to tick while the system is suspended. But this cannot be
# guaranteed on all platforms.
#
# The clock is only guaranteed to apply to the current process. In practice, it is
# usually relative to system boot, so should be interchangeable between processes.
# But this is not guaranteed on all platforms.
#
# ## Example
#
# ```
# start = Time.instant
# # do something
# elapsed = start.elapsed
# ```
#
# `Time.measure(&)` is a convenient alternative for measuring elapsed time of an
# individual code block.
struct Time::Instant
  include Comparable(self)

  # :nodoc:
  def initialize(@seconds : Int64, @nanoseconds : Int32)
  end

  def -(other : self) : Time::Span
    Time::Span.new(seconds: @seconds - other.@seconds, nanoseconds: @nanoseconds - other.@nanoseconds)
  end

  def +(other : Time::Span) : self
    span = Time::Span.new(seconds: @seconds, nanoseconds: @nanoseconds) + other
    Instant.new(span.@seconds, span.@nanoseconds)
  end

  def -(other : Time::Span) : self
    span = Time::Span.new(seconds: @seconds, nanoseconds: @nanoseconds) - other
    Instant.new(span.@seconds, span.@nanoseconds)
  end

  def <=>(other : self) : Int32
    cmp = @seconds <=> other.@seconds
    cmp = @nanoseconds <=> other.@nanoseconds if cmp == 0
    cmp
  end

  # Returns the duration between `other` and `self`.
  #
  # The resulting duration is positive or zero.
  def duration_since(other : self) : Time::Span
    (self - other).clamp(Time::Span.zero..)
  end

  # Returns the amount of time elapsed since `self`.
  #
  # The resulting duration is positive or zero.
  def elapsed : Time::Span
    Time.instant.duration_since(self)
  end
end
