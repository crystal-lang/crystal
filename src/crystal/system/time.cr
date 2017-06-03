# :nodoc:
module Crystal
  # :nodoc:
  module System
    # :nodoc:
    module Time
      TicksPerMillisecond = 10_000_i64
      TicksPerSecond      = TicksPerMillisecond * 1000
      TicksPerMinute      = TicksPerSecond * 60
      TicksPerHour        = TicksPerMinute * 60
      TicksPerDay         = TicksPerHour * 24

      # Returns the number of ticks that you must add to UTC to get local time.
      # def self.compute_offset(second)

      # Returns the current system time meassured from unix epoch.
      # def self.compute_second_and_tenth_microsecond
    end
  end
end

require "./unix/time"
