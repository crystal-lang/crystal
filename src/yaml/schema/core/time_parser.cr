# :nodoc:
struct YAML::Schema::Core::TimeParser
  # Even though the standard library has Time parsers given a *fixed* format,
  # the format in YAML, http://yaml.org/type/timestamp.html,
  # can consist of just the date part, and following it any number of spaces,
  # or 't', or 'T' can follow, with many optional components. So, we implement
  # this in a more efficient way to avoid parsing the same string with many
  # possible formats (there's also no way to specify any number of spaces
  # with Time::Format, or an "or" like in a Regex).
  #
  # As an additional note, Ruby's Psych YAML parser also implements a
  # custom time parser, probably for this same reason.
  def initialize(string)
    @reader = Char::Reader.new(string)
  end

  def current_char
    @reader.current_char
  end

  def next_char
    @reader.next_char
  end

  def parse
    year = parse_number(4)
    return nil unless year

    return nil unless dash?

    month = parse_number_1_or_2
    return nil unless month

    return nil unless dash?

    day = parse_number_1_or_2
    return nil unless day

    case current_char
    when 'T', 't'
      next_char
      parse_after_date(year, month, day)
    when .ascii_whitespace?
      skip_space

      if @reader.has_next?
        parse_after_date(year, month, day)
      else
        new_time(year, month, day)
      end
    else
      if @reader.has_next?
        nil
      else
        new_time(year, month, day)
      end
    end
  end

  def parse_after_date(year, month, day)
    hour = parse_number_1_or_2
    return nil unless hour

    return nil unless colon?

    minute = parse_number(2)
    return nil unless minute

    return nil unless colon?

    second = parse_number(2)
    return nil unless second

    unless @reader.has_next?
      return new_time(year, month, day, hour, minute, second)
    end

    nanosecond = 0

    if current_char == '.'
      next_char

      nanosecond = parse_nanoseconds
      return nil unless nanosecond
    end

    skip_space

    case current_char
    when 'Z'
      next_char
    when '+', '-'
      tz_sign = current_char == '+' ? 1 : -1
      next_char

      tz_hour = parse_number_1_or_2
      return nil unless tz_hour

      if colon?
        tz_minute = parse_number(2)
        return nil unless tz_minute
      else
        tz_minute = parse_number(2)
        tz_minute = 0 unless tz_minute
      end

      tz_offset = tz_sign * (tz_hour * 60 + tz_minute)
    end

    return nil if @reader.has_next?

    time = new_time(year, month, day, hour, minute, second, nanosecond: nanosecond)
    if time && tz_offset
      time = time - tz_offset.minutes
    end
    time
  end

  def parse_nanoseconds
    return nil unless current_char.ascii_number?

    multiplier = Time::NANOSECONDS_PER_SECOND / 10
    number = current_char.to_i

    next_char

    8.times do
      break unless current_char.ascii_number?

      number *= 10
      number += current_char.to_i
      multiplier /= 10

      next_char
    end

    while current_char.ascii_number?
      next_char
    end

    number * multiplier
  end

  def parse_number(n)
    number = 0

    n.times do
      return nil unless current_char.ascii_number?

      number *= 10
      number += current_char.to_i

      next_char
    end

    number
  end

  def parse_number_1_or_2
    return nil unless current_char.ascii_number?

    number = current_char.to_i
    next_char

    if current_char.ascii_number?
      number *= 10
      number += current_char.to_i
      next_char
    end

    number
  end

  def skip_space
    while current_char.ascii_whitespace?
      next_char
    end
  end

  def dash?
    return false unless current_char == '-'

    next_char
    true
  end

  def colon?
    return false unless current_char == ':'

    next_char
    true
  end

  def new_time(*args, **named_args)
    Time.utc(*args, **named_args)
  rescue
    nil
  end
end
