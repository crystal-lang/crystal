# :nodoc:
# Facilities for time zone lookup based on POSIX TZ strings
module Time::TZ
  # same as `Time.utc(year, 1, 1).to_unix`, except *year* is allowed to be
  # outside its normal range
  def self.jan1_to_unix(year : Int) : Int64
    # assume leap years have the same pattern beyond year 9999
    year -= 1
    days = year * 365 + year // 4 - year // 100 + year // 400
    SECONDS_PER_DAY.to_i64 * days - UNIX_EPOCH.total_seconds
  end

  # same as `Time.unix(unix_seconds).year`, except *unix_seconds* is allowed to
  # be outside its normal range
  def self.unix_to_year(unix_seconds : Int) : Int32
    total_days = ((UNIX_EPOCH.total_seconds + unix_seconds) // SECONDS_PER_DAY).to_i

    num400 = total_days // DAYS_PER_400_YEARS
    total_days -= num400 * DAYS_PER_400_YEARS

    num100 = total_days // DAYS_PER_100_YEARS
    if num100 == 4 # leap
      num100 = 3
    end
    total_days -= num100 * DAYS_PER_100_YEARS

    num4 = total_days // DAYS_PER_4_YEARS
    total_days -= num4 * DAYS_PER_4_YEARS

    numyears = total_days // 365
    if numyears == 4 # leap
      numyears = 3
    end

    num400 * 400 + num100 * 100 + num4 * 4 + numyears + 1
  end

  # `J*`: one-based ordinal day, excludes leap day
  record Julian1, ordinal : Int16, time : Int32 do
    def always_jan1? : Bool
      ordinal == 1
    end

    def always_dec31? : Bool
      ordinal == 365
    end

    def unix_date_in_year(year : Int) : Int64
      TZ.jan1_to_unix(year) + 86400_i64 * (Time.leap_year?((year - 1) % 400 + 1) && @ordinal >= 60 ? @ordinal : @ordinal - 1)
    end
  end

  # `*`: zero-based ordinal day, includes leap day
  record Julian0, ordinal : Int16, time : Int32 do
    def always_jan1? : Bool
      ordinal == 0
    end

    def always_dec31? : Bool
      # `365` is December 30th in leap years
      false
    end

    def unix_date_in_year(year : Int) : Int64
      TZ.jan1_to_unix(year) + 86400_i64 * @ordinal
    end
  end

  # `M*.*.*`: month-week-day, week 5 is last week
  # also used for Windows system time zones (ignoring the millisecond component)
  record MonthWeekDay, month : Int8, week : Int8, day : Int8, time : Int32 do
    def always_jan1? : Bool
      false
    end

    def always_dec31? : Bool
      false
    end

    def unix_date_in_year(year : Int) : Int64
      # this needs to handle years outside 1..9999; reduce `year` modulo 400 so
      # that it fits into 1..2000, since the number of days per 400 years is
      # divisible by 7
      cycles = (year - 1) // 400
      year = (year - 1) % 400 + 1
      Time.month_week_date(year, @month.to_i32, @week.to_i32, @day.to_i32, location: Time::Location::UTC).to_unix + SECONDS_PER_400_YEARS * cycles
    end

    # 24 * 60 * 60 * (365 * 400 + 100 - 25 + 1)
    SECONDS_PER_400_YEARS = 12622780800_i64

    def self.default : self
      new(0, 0, 0, 0)
    end
  end

  alias POSIXTransition = Julian1 | Julian0 | MonthWeekDay

  def self.lookup(
    unix_seconds : Int, zones : Array(Location::Zone),
    std_index : Int, dst_index : Int,
    transition1 : POSIXTransition, transition2 : POSIXTransition,
  ) : {Location::Zone, {Int64, Int64}}
    if std_index == dst_index
      # all-year standard time or DST time
      is_dst = false
      range_begin = Int64::MIN
      range_end = Int64::MAX
    else
      std_offset = -zones[std_index].offset
      dst_offset = -zones[dst_index].offset

      # Find the local year corresponding to `unix_seconds`, except we cannot
      # rely on `Time`'s timezone facilities since that is exactly what this
      # method implements. It may differ from the UTC year by 0 or 1. musl uses
      # a similar loop.
      utc_year = local_year = TZ.unix_to_year(unix_seconds)

      while true
        datetime1 = transition1.unix_date_in_year(local_year) + transition1.time + std_offset
        datetime2 = transition2.unix_date_in_year(local_year) + transition2.time + dst_offset
        new_year_is_dst = datetime2 < datetime1

        local_new_year = TZ.jan1_to_unix(local_year) + (new_year_is_dst ? dst_offset : std_offset)
        local_new_year_next = TZ.jan1_to_unix(local_year + 1) + (new_year_is_dst ? dst_offset : std_offset)
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
          range_begin = transition1.unix_date_in_year(local_year - 1) + transition1.time + std_offset
          range_end = datetime2
        elsif unix_seconds >= datetime1
          is_dst = true
          range_begin = datetime1
          range_end = transition2.unix_date_in_year(local_year + 1) + transition2.time + dst_offset
        else
          is_dst = false
          range_begin = datetime2
          range_end = datetime1
        end
      else
        if unix_seconds < datetime1
          is_dst = false
          range_begin = transition2.unix_date_in_year(local_year - 1) + transition2.time + dst_offset
          range_end = datetime1
        elsif unix_seconds >= datetime2
          is_dst = false
          range_begin = datetime2
          range_end = transition1.unix_date_in_year(local_year + 1) + transition1.time + std_offset
        else
          is_dst = true
          range_begin = datetime1
          range_end = datetime2
        end
      end
    end

    {zones[is_dst ? dst_index : std_index], {range_begin, range_end}}
  end

  # Parses the given *tz* string. Returns the `std_index`, `dst_index`,
  # `transition1`, and `transition2` fields for a yet to be constructed
  # `TZLocation`, or `nil` if *tz* is invalid.
  #
  # Both `std_index` and `dst_index` index into the given *zones* array, which
  # should belong to a `Time::TZLocation`. Missing entries in *zones* are
  # automatically created.
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
  def self.parse(tz : String, zones : Array(Location::Zone), hours_extension : Bool) : {Int32, Int32, POSIXTransition, POSIXTransition}?
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
      std_index = zone_index(std_zone, zones)
      default_transition = Julian0.new(0, 0)
      return std_index, std_index, default_transition, default_transition
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
    if transition1.always_jan1? && transition1.time == 0
      if transition2.always_dec31? && transition2.time == 86400 + std_offset - dst_offset
        dst_index = zone_index(dst_zone, zones)
        default_transition = Julian0.new(0, 0)
        return dst_index, dst_index, default_transition, default_transition
      end
    end

    std_index = zone_index(std_zone, zones)
    dst_index = zone_index(dst_zone, zones)
    {std_index, dst_index, transition1, transition2}
  end

  private def self.zone_index(zone : Location::Zone, zones : Array(Location::Zone)) : Int
    if index = zones.index(zone)
      index
    else
      zones.size.tap { zones << zone }
    end
  end

  private def self.parse_transition(reader : Char::Reader, hours_extension : Bool) : {Char::Reader, POSIXTransition}?
    case reader.current_char
    when 'J'
      reader.next_char
      reader, day = parse_int(reader, 365) || return
      return unless day >= 1

      reader, time = parse_transition_time(reader, hours_extension) || return
      {reader, Julian1.new(day.to_i16!, time)}
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

      reader, time = parse_transition_time(reader, hours_extension) || return
      {reader, MonthWeekDay.new(month.to_i8!, week.to_i8!, day.to_i8!, time)}
    else
      reader, day = parse_int(reader, 365) || return

      reader, time = parse_transition_time(reader, hours_extension) || return
      {reader, Julian0.new(day.to_i16!, time)}
    end
  end

  private def self.parse_transition_time(reader : Char::Reader, hours_extension : Bool) : {Char::Reader, Int32}?
    if reader.current_char == '/'
      reader.next_char
      parse_offset(reader, hours_extension ? 167 : 24, hours_extension)
    else
      {reader, 7200} # 02:00:00
    end
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

# A time location capable of computing recurring time zone transitions in the
# future using POSIX TZ strings, as defined in [POSIX.1-2024 Section 8.3](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap08.html),
# or in [IETF RFC 9636](https://datatracker.ietf.org/doc/html/rfc9636).
#
# These locations are returned by `Time::Location.posix_tz`.
class Time::TZLocation < Time::Location
  # Indices into this location's zones array. Identical if all-year standard
  # time or DST is in effect.
  @std_index : Int32
  @dst_index : Int32

  # The first and second transition times defined in the TZ string. Not
  # meaningful when `std_index == dst_index`.
  @transition1 : TZ::POSIXTransition
  @transition2 : TZ::POSIXTransition

  # The original TZ string that produced this location.
  @tz_string : String

  protected def initialize(name : String, zones : Array(Zone), @tz_string, @std_index, @dst_index, @transition1, @transition2, transitions = [] of ZoneTransition)
    super(name, zones, transitions)
  end

  def_equals_and_hash name, zones, transitions, @tz_string

  # :nodoc:
  def lookup_with_boundaries(unix_seconds : Int) : {Zone, {Int64, Int64}}
    case
    when zones.empty?
      {Zone::UTC, {Int64::MIN, Int64::MAX}}
    when transitions.empty?
      lookup_posix_tz(unix_seconds)
    when unix_seconds < transitions.first.when
      {lookup_first_zone, {Int64::MIN, transitions.first.when}}
    when unix_seconds >= transitions.last.when
      lookup_posix_tz(unix_seconds)
    else
      lookup_within_fixed_transitions(unix_seconds)
    end
  end

  private def lookup_posix_tz(unix_seconds : Int) : {Zone, {Int64, Int64}}
    zone, range = TZ.lookup(unix_seconds, @zones, @std_index, @dst_index, @transition1, @transition2)
    range_begin, range_end = range

    if last_transition = @transitions.last?
      range_begin = {range_begin, last_transition.when}.max
    end

    {zone, {range_begin, range_end}}
  end
end

# A time location capable of computing recurring time zone transitions in the
# past or future using definitions from the Windows Registry.
#
# These locations are returned by `Time::Location.load`.
class Time::WindowsLocation < Time::Location
  # Two sets of transition rules for times before the first transition or after
  # the last transition. Each corresponds to a `TZLocation`'s `@std_index`,
  # `@dst_index`, `@transition1`, and `@transition2` fields. If there are no
  # fixed transitions then the two sets are equal.
  @past_tz_args : {Int32, Int32, TZ::MonthWeekDay, TZ::MonthWeekDay}
  @future_tz_args : {Int32, Int32, TZ::MonthWeekDay, TZ::MonthWeekDay}

  # The original Windows Registry key name for this location.
  @key_name : String

  def initialize(name : String, zones : Array(Zone), @key_name, @past_tz_args, @future_tz_args = past_tz_args, transitions = [] of ZoneTransition)
    super(name, zones, transitions)
  end

  def_equals_and_hash name, zones, transitions, @key_name

  # :nodoc:
  def lookup_with_boundaries(unix_seconds : Int) : {Zone, {Int64, Int64}}
    case
    when zones.empty?
      {Zone::UTC, {Int64::MIN, Int64::MAX}}
    when transitions.empty?, unix_seconds < transitions.first.when
      lookup_past(unix_seconds)
    when unix_seconds >= transitions.last.when
      lookup_future(unix_seconds)
    else
      lookup_within_fixed_transitions(unix_seconds)
    end
  end

  private def lookup_past(unix_seconds : Int) : {Zone, {Int64, Int64}}
    zone, range = TZ.lookup(unix_seconds, @zones, *@past_tz_args)
    range_begin, range_end = range

    if first_transition = @transitions.first?
      range_end = {range_end, first_transition.when}.min
    end

    {zone, {range_begin, range_end}}
  end

  private def lookup_future(unix_seconds : Int) : {Zone, {Int64, Int64}}
    zone, range = TZ.lookup(unix_seconds, @zones, *@future_tz_args)
    range_begin, range_end = range

    if last_transition = @transitions.last?
      range_begin = {range_begin, last_transition.when}.max
    end

    {zone, {range_begin, range_end}}
  end
end
