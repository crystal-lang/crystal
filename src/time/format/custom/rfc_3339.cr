# The [RFC 3339](https://tools.ietf.org/html/rfc3339) datetime format ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
module Time::Format::RFC_3339
  extend Format

  # :nodoc:
  module Visitor
    def visit
      year_month_day
      char 'T', 't', ' '
      twenty_four_hour_time_with_seconds
      second_fraction?
      time_zone_z_or_offset(force_colon: true)
    end
  end
end
