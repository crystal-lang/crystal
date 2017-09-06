module Crystal::System::Time
  # Returns the number of seconds that you must add to UTC to get local time.
  # *seconds* are measured from `0001-01-01 00:00:00`.
  # def self.compute_utc_offset(seconds : Int64) : Int64

  # Returns the current UTC time measured in `{seconds, tenth_microsecond}`
  # since `0001-01-01 00:00:00`.
  # def self.compute_utc_second_and_tenth_microsecond : {Int64, Int64}
end

require "./unix/time"
