module Crystal
  # :nodoc:
  module System
    # :nodoc:
    module Time
      # Returns the number of seconds that you must add to UTC to get local time.
      # *seconds* are absolutes.
      # def self.compute_utc_offset(seconds)

      # Returns the current utc time meassured in absolute `{seconds, tenth_microsecond}`
      # def self.compute_utc_second_and_tenth_microsecond
    end
  end
end

require "./unix/time"
