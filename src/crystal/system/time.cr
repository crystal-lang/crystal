module Crystal::System::Time
  # Returns the current UTC time measured in `{seconds, nanoseconds}`
  # since `0001-01-01 00:00:00`.
  # def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}

  # def self.monotonic : {Int64, Int32}

  # Returns a list of paths where time zone data should be looked up.
  # def self.zone_sources : Enumerable(String)

  # Loads a time zone by its IANA zone identifier directly. May return `nil` on
  # systems where tzdata is assumed to be available.
  # def self.load_iana_zone(iana_name : String) : ::Time::Location?

  # Returns the system's current local time zone
  # def self.load_localtime : ::Time::Location?
end

{% if flag?(:unix) %}
  require "./unix/time"
{% elsif flag?(:win32) %}
  require "./win32/time"
{% else %}
  {% raise "No Crystal::System::Time implementation available" %}
{% end %}
