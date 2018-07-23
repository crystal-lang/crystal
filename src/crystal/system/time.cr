module Crystal::System::Time
  # Returns the current UTC time measured in `{seconds, nanoseconds}`
  # since `0001-01-01 00:00:00`.
  # def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}

  # def self.monotonic : {Int64, Int32}

  # Returns a list of paths where time zone data should be looked up.
  # def self.zone_sources : Enumerable(String)

  # Returns the system's current local time zone
  # def self.load_localtime : ::Time::Location?
end

{% if flag?(:win32) %}
  require "./win32/time"
{% else %}
  require "./unix/time"
{% end %}
