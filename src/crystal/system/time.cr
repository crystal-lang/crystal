module Crystal::System::Time
  # Returns the number of seconds that you must add to UTC to get local time.
  # *seconds* are measured from `0001-01-01 00:00:00`.
  # def self.compute_utc_offset(seconds : Int64) : Int32

  # Returns the current UTC time measured in `{seconds, nanoseconds}`
  # since `0001-01-01 00:00:00`.
  # def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}
end

require "./unix/time"
