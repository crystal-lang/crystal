struct Time::Format
  # The [RFC 3339](https://tools.ietf.org/html/rfc3339) datetime format ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
  module RFC_3339
    # Parses a string into a `Time`.
    def self.parse(string, location = Time::Location::UTC) : Time
      parser = Parser.new(string)
      parser.rfc_3339
      parser.time(location)
    end

    # Formats a `Time` into the given *io*.
    def self.format(time : Time, io : IO, fraction_digits = nil)
      formatter = Formatter.new(time, io)
      formatter.rfc_3339(fraction_digits: fraction_digits)
      io
    end

    # Formats a `Time` into a `String`.
    def self.format(time : Time, fraction_digits = nil)
      String.build do |io|
        format(time, io, fraction_digits: fraction_digits)
      end
    end
  end

  module Pattern
    def rfc_3339(fraction_digits = nil)
      year_month_day
      char 'T', 't', ' '
      twenty_four_hour_time_with_seconds
      second_fraction?(fraction_digits: fraction_digits)
      time_zone_z_or_offset(force_colon: true)
    end
  end
end
