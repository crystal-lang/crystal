require "crystal/system/time"

struct Time
  # Measure elapsed time.
  #
  # Time measurement relies on a monotonic clock, that should be independent to
  # time fluctuations, such as leap seconds or manually changing the computer
  # time.
  struct Measure
    private getter seconds : Int64
    private getter nanoseconds : Int32

    # Starts a clock to measure elapsed time, or repeatedly report elapsed time
    # since an initial start time.
    def initialize
      @seconds, @nanoseconds = Crystal::System::Time.monotonic
    end

    # Returns the time span since the clock was started.
    #
    # ```
    # timer = Time::Measure.new
    #
    # loop do
    #   do_something
    #   p timer.elapsed # => 00:00:01.000000023
    # end
    # ```
    def elapsed
      seconds, nanoseconds = Crystal::System::Time.monotonic
      Time::Span.new(seconds: seconds - @seconds, nanoseconds: nanoseconds - @nanoseconds)
    end

    # Returns true once *span* time has passed since the clock was created.
    #
    # ```
    # timeout = 5.seconds
    # timer = Time::Measure.new
    #
    # until timer.elapsed?(timeout)
    #   do_domething
    # end
    # ```
    def elapsed?(span : Time::Span)
      elapsed >= span
    end

    # Returns true once *span* seconds have passed since the clock was created.
    #
    # ```
    # timer = Time::Measure.new
    #
    # until timer.elapsed?(5.0)
    #   do_domething
    # end
    # ```
    def elapsed?(span : Int | Float)
      elapsed?(span.seconds)
    end
  end

  # Measures how long the block took to run.
  #
  # ```
  # elapsed = Time.measure { do_something } # => 00:01:53.009871361
  # ```
  def self.measure(&block) : Time::Span
    clock = Measure.new
    yield
    clock.elapsed
  end
end
