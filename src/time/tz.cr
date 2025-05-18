# :nodoc:
# Structure that holds the local time transition rules of a TZ string as defined
# in [POSIX.1-2024 Section 8.3](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap08.html).
# Also used by TZif database files (version 2 or higher) as defined in
# [IETF RFC 9636](https://datatracker.ietf.org/doc/html/rfc9636).
struct Time::TZ
  # `J*`: one-based ordinal day, excludes leap day
  record Julian1, ordinal : Int32

  # `*`: zero-based ordinal day, includes leap day
  record Julian0, ordinal : Int32

  # `M*.*.*`: month-week-day, week 5 is last week
  record MonthWeekDay, month : Int32, week : Int32, day : Int32

  record Transition, date : Julian1 | Julian0 | MonthWeekDay, time : Int32 do
    def unix_date_in_year(year : Int) : Int64
      case date = @date
      in Julian1
        Time.utc(year, 1, 1).to_unix + 86400_i64 * (Time.leap_year?(year) && date.ordinal >= 60 ? date.ordinal : date.ordinal - 1)
      in Julian0
        Time.utc(year, 1, 1).to_unix + 86400_i64 * date.ordinal
      in MonthWeekDay
        Time.month_week_date(year, date.month, date.week, date.day, location: Time::Location::UTC).to_unix
      end
    end
  end

  # Indices into a parent `Time::Location`'s zones array. Identical if all-year
  # standard time or DST is in effect.
  getter std_index : Int32
  getter dst_index : Int32

  # The first and second transition times defined in the TZ string. Not
  # meaningful when `std_index == dst_index`.
  getter transition1 : Transition
  getter transition2 : Transition

  def initialize(@std_index, @dst_index, @transition1, @transition2)
  end

  private def self.new(index : Int32) : self
    default_transition = Transition.new(Julian0.new(0), 0)
    new(index, index, default_transition, default_transition)
  end

  def lookup_with_boundaries(unix_seconds : Int, location : Location) : {Location::Zone, {Int64, Int64}}
    if @std_index == @dst_index
      # all-year standard time or DST time
      is_dst = false
      range_begin = Int64::MIN
      range_end = Int64::MAX
    else
      std_offset = -location.zones[@std_index].offset
      dst_offset = -location.zones[@dst_index].offset

      # Find the local year corresponding to `unix_seconds`, except we cannot
      # rely on `Time`'s timezone facilities since that is exactly what this
      # method implements. It may differ from the UTC year by 0 or 1. musl uses
      # a similar loop.
      utc_time = Time.unix(unix_seconds)
      utc_year = local_year = utc_time.year

      while true
        datetime1 = @transition1.unix_date_in_year(local_year) + @transition1.time + std_offset
        datetime2 = @transition2.unix_date_in_year(local_year) + @transition2.time + dst_offset
        new_year_is_dst = datetime2 < datetime1

        local_new_year = Time.utc(local_year, 1, 1).to_unix + (new_year_is_dst ? dst_offset : std_offset)
        local_new_year_next = Time.utc(local_year + 1, 1, 1).to_unix + (new_year_is_dst ? dst_offset : std_offset)
        break if local_new_year <= unix_seconds < local_new_year_next

        if local_year == utc_year
          local_year += unix_seconds >= local_new_year_next ? 1 : -1
        else
          # Normally `new_year_is_dst` should be identical across all years, but
          # POSIX does not technically forbid something like `M1.1.0,J4`, where
          # one transition could be anything within January 1 - 7, and the other
          # one is January 4 in all years. In this extremely unlikely case there
          # could be a gap after the `local_new_year_next` for a given year and
          # before the `local_new_year` for its next year. We assume this is not
          # practically useful, so we just bail out here.
          raise Time::Error.new "BUG: Failed to determine local year"
        end
      end

      if new_year_is_dst
        if unix_seconds < datetime2
          is_dst = true
          range_begin = @transition1.unix_date_in_year(local_year - 1) + @transition1.time + std_offset
          range_end = datetime2
        elsif unix_seconds >= datetime1
          is_dst = true
          range_begin = datetime1
          range_end = @transition2.unix_date_in_year(local_year + 1) + @transition2.time + dst_offset
        else
          is_dst = false
          range_begin = datetime2
          range_end = datetime1
        end
      else
        if unix_seconds < datetime1
          is_dst = false
          range_begin = @transition2.unix_date_in_year(local_year - 1) + @transition2.time + dst_offset
          range_end = datetime1
        elsif unix_seconds >= datetime2
          is_dst = false
          range_begin = datetime2
          range_end = @transition1.unix_date_in_year(local_year + 1) + @transition1.time + std_offset
        else
          is_dst = true
          range_begin = datetime1
          range_end = datetime2
        end
      end
    end

    if last_transition = location.transitions.last?
      range_begin = {range_begin, last_transition.when}.max
    end

    {location.zones[is_dst ? @dst_index : @std_index], {range_begin, range_end}}
  end

  # Parses the given *tz* string. Returns `nil` if *tz* is invalid.
  #
  # The returned `TZ`'s `std_index` and `dst_index` members index into the giben
  # *zones* array, which should belong to a `Time::Location`. Missing entries in
  # *zones* are automatically created.
  #
  # *hours_extension* increases the hours range of transition time offsets from
  # 0..24 to -167..+167, according to POSIX.1-2024 or RFC 9636 Section 3.3.2
  # (the latter only for TZif version 3 or higher).
  #
  # C runtime library implementations:
  #
  # * glibc https://sourceware.org/git/?p=glibc.git;a=blob;f=time/tzset.c;hb=2642002380aafb71a1d3b569b6d7ebeab3284816#l321
  # * musl https://git.musl-libc.org/cgit/musl/tree/src/time/__tz.c?id=ef7d0ae21240eac9fc1e8088112bfb0fac507578#n239
  # * bionic https://android.googlesource.com/platform/bionic/+/31fc69f67fc49b1a08f5561ae62d098106da6565/libc/tzcode/localtime.c#1148
  # * wine msvcrt https://gitlab.winehq.org/wine/wine/-/blob/7f833db11ffea4f3f4fa07be31d30559aff9c5fb/dlls/msvcrt/time.c#L127
  def self.parse(tz : String, zones : Array(Location::Zone), hours_extension : Bool) : TZ?
    reader = Char::Reader.new(tz)

    # colon prefix: implementation-defined (not supported in Crystal)
    # glibc treats the rest of the TZ string as a TZif database path name
    # (`parse_std_or_dst` will reject strings beginning with a `:` anyway so it
    # doesn't have to be checked here)

    # std offset [dst [offset] [, start [/ time] , end [/ time]]]
    reader, std_name = parse_std_or_dst(reader) || return nil
    reader, std_offset = parse_offset(reader, 24, true) || return nil
    std_zone = Location::Zone.new(std_name, -std_offset, false)

    unless reader.has_next?
      # no DST component means all-year standard time
      return new(zone_index(std_zone, zones))
    end

    reader, dst_name = parse_std_or_dst(reader) || return nil
    if result = parse_offset(reader, 24, true)
      reader, dst_offset = result
    else
      dst_offset = std_offset - 3600
    end
    dst_zone = Time::Location::Zone.new(dst_name, -dst_offset, true)

    # missing transitions: implementation-defined (not supported in Crystal)
    # msvcrt and bionic fall back to `M3.2.0,M11.1.0`, i.e. US rules since 2007
    return nil unless reader.current_char == ','
    reader.next_char
    reader, transition1 = parse_transition(reader, hours_extension) || return nil

    return nil unless reader.current_char == ','
    reader.next_char
    reader, transition2 = parse_transition(reader, hours_extension) || return nil

    # if there are no trailing characters, we have a valid TZ string with
    # transition rules
    return nil if reader.has_next?

    # all-year DST according to POSIX.1-2024 or RFC 9636 Section 3.3.1
    # (we check here so that these locations return true for `#fixed?`)
    if transition1.date.in?(Time::TZ::Julian1.new(1), Time::TZ::Julian0.new(0)) && transition1.time == 0
      # `Julian0` does not represent the last day in all years, so only check
      # for `J365` exactly
      if transition2.date == Time::TZ::Julian1.new(365) && transition2.time == 86400 + std_offset - dst_offset
        return new(zone_index(dst_zone, zones))
      end
    end

    std_index = zone_index(std_zone, zones)
    dst_index = zone_index(dst_zone, zones)
    new(std_index, dst_index, transition1, transition2)
  end

  private def self.zone_index(zone : Location::Zone, zones : Array(Location::Zone)) : Int
    if index = zones.index(zone)
      index
    else
      zones.size.tap { zones << zone }
    end
  end

  private def self.parse_transition(reader : Char::Reader, hours_extension : Bool) : {Char::Reader, Transition}?
    date =
      case reader.current_char
      when 'J'
        reader.next_char
        reader, day = parse_int(reader, 365) || return
        return unless day >= 1
        Julian1.new(day)
      when 'M'
        reader.next_char
        reader, month = parse_int(reader, 12) || return
        return unless month >= 1

        return unless reader.current_char == '.'
        reader.next_char
        reader, week = parse_int(reader, 5) || return
        return unless week >= 1

        return unless reader.current_char == '.'
        reader.next_char
        reader, day = parse_int(reader, 6) || return

        MonthWeekDay.new(month, week, day)
      else
        reader, day = parse_int(reader, 365) || return
        Julian0.new(day)
      end

    if reader.current_char == '/'
      reader.next_char
      reader, time = parse_offset(reader, hours_extension ? 167 : 24, hours_extension) || return
    else
      time = 7200 # 02:00:00
    end

    {reader, Transition.new(date, time)}
  end

  private def self.parse_offset(reader : Char::Reader, hour_limit : Int, allow_sign : Bool) : {Char::Reader, Int32}?
    sign = 1
    if allow_sign
      case reader.current_char
      when '-'
        sign = -1
        reader.next_char
      when '+'
        reader.next_char
      end
    end

    reader, hours = parse_int(reader, hour_limit) || return
    minutes = 0
    seconds = 0

    if reader.current_char == ':'
      reader.next_char
      reader, minutes = parse_int(reader, 59) || return
      if reader.current_char == ':'
        reader.next_char
        reader, seconds = parse_int(reader, 59) || return
      end
    end

    total_seconds = sign * (3600 * hours + 60 * minutes + seconds)
    {reader, total_seconds}
  end

  private def self.parse_int(reader : Char::Reader, limit : Int) : {Char::Reader, Int32}?
    start = reader.pos
    while reader.current_char == '0'
      reader.next_char
    end

    value = 0
    while digit = reader.current_char.to_i?
      value = value * 10 + digit
      return unless value <= limit
      reader.next_char
    end

    if reader.pos > start
      {reader, value}
    end
  end

  private def self.parse_std_or_dst(reader : Char::Reader) : {Char::Reader, String}?
    quoted = false
    if reader.current_char == '<'
      reader.next_char
      quoted = true
    end

    start = reader.pos
    while ch = reader.current_char?
      break unless ch.ascii_letter? || (quoted && (ch.ascii_number? || ch.in?('+', '-')))
      reader.next_char
    end
    return unless reader.pos - start >= 3
    finish = reader.pos

    if quoted
      return unless reader.current_char == '>'
      reader.next_char
    end

    name = reader.string.byte_slice(start, finish - start)
    {reader, name}
  end
end
