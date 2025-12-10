require "./location/loader"

# `Location` maps time instants to the zone in use at that time.
# It typically represents the collection of time offsets observed in
# a certain geographical area.
#
# It contains a list of zone offsets and rules for transitioning between them.
#
# If a location has only one offset (such as `UTC`) it is considered
# *fixed*.
#
# A `Location` instance is usually retrieved by name using
# `Time::Location.load`.
# It loads the zone offsets and transitioning rules from the time zone database
# provided by the operating system.
#
# ```
# location = Time::Location.load("Europe/Berlin")
# location # => #<Time::Location Europe/Berlin>
# time = Time.local(2016, 2, 15, 21, 1, 10, location: location)
# time # => 2016-02-15 21:01:10+01:00[Europe/Berlin]
# ```
#
# A custom time zone database can be configured through the environment variable
# `TZDIR`. See `.load` for details.
#
# ### Fixed Offset
#
# A fixed offset location is created using `Time::Location.fixed`:
#
# ```
# location = Time::Location.fixed(3600)
# location       # => #<Time::Location +01:00>
# location.zones # => [#<Time::Location::Zone +01:00 (0s) STD>]
# ```
#
#
# ### Local Time Zone
#
# The local time zone can be accessed as `Time::Location.local`.
#
# It is initially configured according to system environment settings,
# but its value can be changed:
#
# ```
# location = Time::Location.local
# Time::Location.local = Time::Location.load("America/New_York")
# ```
class Time::Location
  # `InvalidLocationNameError` is raised if a location name cannot be found in
  # the time zone database.
  #
  # See `Time::Location.load` for details.
  class InvalidLocationNameError < Time::Error
    getter name, source

    def initialize(@name : String, @source : String? = nil)
      msg = "Invalid location name: #{name}"
      msg += " in #{source}" if source
      super msg
    end
  end

  # `InvalidTimezoneOffsetError` is raised if `Time::Location::Zone.new`
  # receives an invalid time zone offset.
  class InvalidTimezoneOffsetError < Time::Error
    def initialize(offset : Int)
      super "Invalid time zone offset: #{offset}"
    end
  end

  # A `Zone` represents a time zone offset in effect in a specific `Location`.
  #
  # Some zones have a `name` or abbreviation (such as `PDT`, `CEST`).
  # For an unnamed zone the formatted offset should be used as name.
  struct Zone
    # This is the `UTC` time zone with offset `+00:00`.
    #
    # It is the only zone offset used in `Time::Location::UTC`.
    UTC = new "UTC", 0, false

    # Returns the offset from UTC in seconds.
    getter offset : Int32

    # Returns `true` if this zone offset is daylight savings time.
    getter? dst : Bool

    # Creates a new `Zone` named *name* with *offset* from UTC in seconds.
    # The parameter *dst* is used to declare this zone as daylight savings time.
    #
    # If `name` is `nil`, the formatted `offset` will be used as `name` (see
    # `#format`).
    #
    # Raises `InvalidTimezoneOffsetError` if *seconds* is outside the supported
    # value range `-89_999..93_599` seconds (`-24:59:59` to `+25:59:59`).
    def initialize(@name : String?, @offset : Int32, @dst : Bool)
      # Maximum offsets of IANA time zone database are -12:00 and +14:00.
      # The hours component can be up to -24/+25 as required by POSIX TZ
      # strings (e.g. `EST-24:59:59EDT,...`).
      raise InvalidTimezoneOffsetError.new(offset) unless -89999 <= offset <= 93599
    end

    # Returns the name of the zone.
    def name : String
      @name || format
    end

    # Prints this `Zone` to *io*.
    #
    # It contains the `name`, hour-minute-second format (see `#format`),
    # `offset` in seconds and `"DST"` if `#dst?`, otherwise `"STD"`.
    def inspect(io : IO) : Nil
      io << "Time::Location::Zone("
      io << @name << ' ' unless @name.nil?
      format(io)
      io << " (" << offset << "s)"
      if dst?
        io << " DST"
      else
        io << " STD"
      end
      io << ')'
    end

    # Prints `#offset` to *io* in the format `+HH:mm:ss`.
    # When *with_colon* is `false`, the format is `+HHmmss`.
    #
    # When *with_seconds* is `false`, seconds are omitted; when `:auto`, seconds
    # are omitted if `0`.
    def format(io : IO, with_colon = true, with_seconds = :auto)
      sign, hours, minutes, seconds = sign_hours_minutes_seconds

      io << sign
      io << '0' if hours < 10
      io << hours
      io << ':' if with_colon
      io << '0' if minutes < 10
      io << minutes

      if with_seconds == true || (seconds != 0 && with_seconds == :auto)
        io << ':' if with_colon
        io << '0' if seconds < 10
        io << seconds
      end
    end

    # Returns the `#offset` formatted as `+HH:mm:ss`.
    # When *with_colon* is `false`, the format is `+HHmmss`.
    #
    # When *with_seconds* is `false`, seconds are omitted; when `:auto`, seconds
    # are omitted if `0`.
    def format(with_colon = true, with_seconds = :auto)
      String.build do |io|
        format(io, with_colon: with_colon, with_seconds: with_seconds)
      end
    end

    # :nodoc:
    def sign_hours_minutes_seconds
      offset = @offset
      if offset < 0
        offset = -offset
        sign = '-'
      else
        sign = '+'
      end
      seconds = offset % 60
      minutes = offset // 60
      hours = minutes // 60
      minutes = minutes % 60
      {sign, hours, minutes, seconds}
    end
  end

  # :nodoc:
  record ZoneTransition, when : Int64, index : UInt8, standard : Bool, utc : Bool do
    getter? standard, utc

    def inspect(io : IO) : Nil
      io << "Time::Location::ZoneTransition("
      io << '#' << index << ' '
      Time.unix(self.when).to_s(io, "%F %T")
      if standard?
        io << " STD"
      else
        io << " DST"
      end
      io << " UTC" if utc?
      io << ')'
    end
  end

  # Describes the Coordinated Universal Time (UTC).
  #
  # The only time zone offset in this location is `Zone::UTC`.
  UTC = new "UTC", [Zone::UTC]

  # Returns the name of this location.
  #
  # It usually consists of a continent and city name separated by a slash, for
  # example `Europe/Berlin`.
  getter name : String

  # Returns the array of time zone offsets (`Zone`) used in this time zone.
  getter zones : Array(Zone)

  # Most lookups will be for the current time.
  # To avoid the binary search through tx, keep a
  # static one-element cache that gives the correct
  # zone for the time when the Location was created.
  # The units for @cached_range are seconds
  # since January 1, 1970 UTC, to match the argument
  # to `#lookup`.
  @cached_range : Tuple(Int64, Int64)
  @cached_zone : Zone

  # Creates a `Location` instance named *name* with fixed *offset* in seconds
  # from UTC.
  def self.fixed(name : String, offset : Int32) : Location
    new name, [Zone.new(name, offset, false)]
  end

  # Creates a `Location` instance with fixed *offset* in seconds from UTC.
  #
  # The formatted *offset* is used as name.
  def self.fixed(offset : Int32) : self
    zone = Zone.new(nil, offset, false)
    new zone.name, [zone]
  end

  # Creates a `Location` instance named *name* with the given POSIX TZ string
  # *str*, as defined in [POSIX.1-2024 Section 8.3](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap08.html).
  #
  # *str* must begin with a standard time designator followed by a time offset;
  # implementation-defined TZ strings beginning with a colon, as well as names
  # from the time zone database, are not supported.
  #
  # If *str* designates a daylight saving time, then the transition times must
  # also be present. A TZ string like `"PST8PDT"` alone is considered invalid,
  # since no default transition rules are assumed.
  #
  # ```
  # location = Time::Location.posix_tz("America/New_York", "EST5EDT,M3.2.0,M11.1.0")
  # Time.utc(2025, 3, 9, 6).in(location)  # => 2025-03-09 01:00:00.0 -05:00 America/New_York
  # Time.utc(2025, 3, 9, 7).in(location)  # => 2025-03-09 03:00:00.0 -04:00 America/New_York
  # Time.utc(2025, 11, 2, 5).in(location) # => 2025-11-02 01:00:00.0 -04:00 America/New_York
  # Time.utc(2025, 11, 2, 6).in(location) # => 2025-11-02 01:00:00.0 -05:00 America/New_York
  # ```
  def self.posix_tz(name : String, str : String) : TZLocation
    zones = Array(Location::Zone).new(initial_capacity: 2)
    tz_args = TZ.parse(str, zones, true) || raise ArgumentError.new("Invalid TZ string: #{str}")
    TZLocation.new(name, zones, str, *tz_args)
  end

  # Loads the `Location` with the given *name*.
  #
  # ```
  # location = Time::Location.load("Europe/Berlin")
  # ```
  #
  # *name* is understood to be a location name in the IANA Time
  # Zone database, such as `"America/New_York"`. As special cases,
  # `"UTC"`, `"Etc/UTC"` and empty string (`""`) return `Location::UTC`, and
  # `"Local"` returns `Location.local`.
  #
  # The implementation uses a list of system-specific paths to look for a time
  # zone database.
  # The first time zone database entry matching the given name that is
  # successfully loaded and parsed is returned.
  # Typical paths on Unix-based operating systems are `/usr/share/zoneinfo/`,
  # `/usr/share/lib/zoneinfo/`, or `/usr/lib/locale/TZ/`.
  #
  # A time zone database may not be present on all systems, especially non-Unix
  # systems. In this case, you may need to distribute a copy of the database
  # with an application that depends on time zone data being available.
  #
  # A custom lookup path can be set as environment variable `TZDIR`(`ZONEINFO`
  # is also supported as legacy option).
  # The path can point to the root of a directory structure or an
  # uncompressed ZIP file, each representing the time zone database using files
  # and folders of the expected names.
  #
  # Example:
  #
  # ```
  # # This tries to load the file `/usr/share/zoneinfo/Custom/Location`
  # ENV["TZDIR"] = "/usr/share/zoneinfo/"
  # Time::Location.load("Custom/Location")
  #
  # # This tries to load the file `Custom/Location` in the uncompressed ZIP
  # # file at `/path/to/zoneinfo.zip`
  # ENV["TZDIR"] = "/path/to/zoneinfo.zip"
  # Time::Location.load("Custom/Location")
  # ```
  #
  # If the location name cannot be found, `InvalidLocationNameError` is raised.
  # If the loader encounters a format error in the time zone database,
  # `InvalidTZDataError` is raised.
  #
  # Files are cached based on the modification time, so subsequent request for
  # the same location name will most likely return the same instance of
  # `Location`, unless the time zone database has been updated in between.
  #
  # - `.load?` returns `nil` if the location is unavailable.
  def self.load(name : String) : Location
    load?(name) { |source| raise InvalidLocationNameError.new(name, source) }
  end

  # :ditto:
  #
  # Returns `nil` if the location is unavailable.
  # Raises `InvalidLocationNameError` if the name is invalid.
  # Raises `InvalidTZDataError` if the loader encounters a format error in the
  # time zone database.
  #
  # - `.load` raises if the location is unavailable.
  def self.load?(name : String) : Location?
    load?(name) { return }
  end

  # :nodoc:
  def self.load?(name : String, & : String? ->) : Location?
    case name
    when "", "UTC", "Etc/UTC", "GMT", "Etc/GMT"
      # `UTC` is a special identifier, empty string represents a fallback mechanism.
      # `Etc/UTC` is technically a tzdb identifier which could potentially point to anything.
      # But we map it to `Location::UTC` directly for convenience which allows it to work
      # without a copy of the database.
      UTC
    when "Local"
      local
    when .includes?(".."), .starts_with?('/'), .starts_with?('\\')
      # No valid IANA Time Zone name contains a single dot,
      # much less dot dot. Likewise, none begin with a slash.
      raise InvalidLocationNameError.new(name)
    else
      # DEPRECATED: `ZONEINFO` is supported only for backwards compatibility.
      if zoneinfo = ENV["TZDIR"]? || ENV["ZONEINFO"]?
        if location = load_from_dir_or_zip(name, zoneinfo)
          return location
        else
          yield zoneinfo
        end
      end

      if location = load(name, Crystal::System::Time.zone_sources) { |source| yield source }
        return location
      end

      {% if flag?(:android) %}
        if location = load_android(name, Crystal::System::Time.android_tzdata_sources)
          return location
        end
      {% end %}

      # If none of the database sources contains a suitable location,
      # try getting it from the operating system.
      # This is only implemented on Windows. Unix systems usually have a
      # copy of the time zone database available, and no system API
      # for loading time zone information.
      if location = Crystal::System::Time.load_iana_zone(name)
        return location
      end

      yield nil
    end
  end

  # Returns the `Location` representing the application's local time zone.
  #
  # `Time` uses this property as default value for most method arguments
  # expecting a `Location`.
  #
  # The initial value depends on the current application environment, see
  # `.load_local` for details.
  #
  # The value can be changed to overwrite the system default:
  #
  # ```
  # Time.local.location # => #<Time::Location America/New_York>
  # Time::Location.local = Time::Location.load("Europe/Berlin")
  # Time.local.location # => #<Time::Location Europe/Berlin>
  # ```
  class_property(local : Location) { load_local }

  # Loads the local time zone according to the current application environment.
  #
  # The environment variable `ENV["TZ"]` is consulted for finding the time zone
  # to use.
  #
  # * `"UTC"`, `"Etc/UTC"` and empty string (`""`) return `Location::UTC`.
  # * POSIX TZ strings (such as `"EST5EDT,M3.2.0,M11.1.0"`) are parsed using
  #   `Location.posix_tz`.
  # * Values beginning with a colon are implementation-defined according to
  #   POSIX, and not supported in Crystal.
  # * Any other value (such as `"Europe/Berlin"`) is tried to be resolved using
  #   `Location.load`.
  # * If `ENV["TZ"]` is not set, the system's local time zone data will be used
  #   (`/etc/localtime` on unix-based systems).
  # * If no time zone data could be found (i.e. the previous methods failed),
  #   `Location::UTC` is returned.
  def self.load_local : Location
    case tz_string = ENV["TZ"]?
    when "", "UTC", "Etc/UTC"
      return UTC
    when Nil
      if localtime = Crystal::System::Time.load_localtime
        return localtime
      end
    when .starts_with?(':')
      # Do not perform time zone database lookup here. POSIX.1-2024 says:
      #
      # > If _TZ_ is of the third format (that is, if the first character is not
      # > a <colon> and the value does not match the syntax for the second
      # > format), the value indicates either a geographical timezone or a
      # > special timezone from an implementation-defined timezone database.
    else
      zones = Array(Location::Zone).new(initial_capacity: 2)
      if tz_args = TZ.parse(tz_string, zones, true)
        return TZLocation.new("Local", zones, tz_string, *tz_args)
      end

      # DEPRECATED: `ZONEINFO` is supported only for backwards compatibility.
      if zoneinfo = ENV["TZDIR"]? || ENV["ZONEINFO"]?
        if location = load_from_dir_or_zip(tz_string, zoneinfo)
          return location
        end
      end
      if location = load?(tz_string, Crystal::System::Time.zone_sources)
        return location
      end
    end

    UTC
  end

  # :nodoc:
  def initialize(@name : String, @zones : Array(Zone), @transitions = [] of ZoneTransition)
    @cached_zone = lookup_first_zone
    @cached_range = {Int64::MIN, @zones.size <= 1 ? Int64::MAX : Int64::MIN}
  end

  protected def transitions
    @transitions
  end

  # Prints `name` to *io*.
  def to_s(io : IO) : Nil
    io << name
  end

  def inspect(io : IO) : Nil
    io << "#<Time::Location "
    to_s(io)
    io << '>'
  end

  # Returns `true` if *other* is equal to `self`.
  #
  # Two `Location` instances are considered equal if they have the same name,
  # offset zones and transition rules.
  def_equals_and_hash name, zones, transitions

  # Returns the time zone offset observed at *time*.
  def lookup(time : Time) : Zone
    lookup(time.to_unix)
  end

  # Returns the time zone offset observed at *unix_seconds*.
  #
  # *unix_seconds* expresses the number of seconds since UNIX epoch
  # (`1970-01-01 00:00:00Z`).
  def lookup(unix_seconds : Int) : Zone
    unless @cached_range[0] <= unix_seconds < @cached_range[1]
      @cached_zone, @cached_range = lookup_with_boundaries(unix_seconds)
    end

    @cached_zone
  end

  # :nodoc:
  def lookup_with_boundaries(unix_seconds : Int) : {Zone, {Int64, Int64}}
    case
    when zones.empty?
      {Zone::UTC, {Int64::MIN, Int64::MAX}}
    when transitions.empty?
      {lookup_first_zone, {Int64::MIN, Int64::MAX}}
    when unix_seconds < transitions.first.when
      {lookup_first_zone, {Int64::MIN, transitions.first.when}}
    when unix_seconds >= transitions.last.when
      transition = transitions.last
      {zones[transition.index], {transition.when, Int64::MAX}}
    else
      lookup_within_fixed_transitions(unix_seconds)
    end
  end

  private def lookup_within_fixed_transitions(unix_seconds)
    tx_index = transitions.bsearch_index do |transition|
      transition.when > unix_seconds
    end.not_nil!

    tx_index -= 1 unless tx_index == 0
    transition = transitions[tx_index]
    range_end = transitions[tx_index + 1]?.try(&.when) || Int64::MAX

    {zones[transition.index], {transition.when, range_end}}
  end

  # Returns the time zone to use for times before the first transition
  # time, or when there are no transition times.
  #
  # The reference implementation in localtime.c from
  # http:#www.iana.org/time-zones/repository/releases/tzcode2013g.tar.gz
  # implements the following algorithm for these cases:
  # 1) If the first zone is unused by the transitions, use it.
  # 2) Otherwise, if there are transition times, and the first
  #    transition is to a zone in daylight time, find the first
  #    non-daylight-time zone before and closest to the first transition
  #    zone.
  # 3) Otherwise, use the first zone that is not daylight time, if
  #    there is one.
  # 4) Otherwise, use the first zone.
  private def lookup_first_zone : Zone
    unless transitions.any? { |tx| tx.index == 0 }
      return zones.first
    end

    if (tx = transitions[0]?) && zones[tx.index].dst?
      index = tx.index
      while index > 0
        index -= 1
        zone = zones[index]
        return zone unless zone.dst?
      end
    end

    first_zone_without_dst = zones.find { |tx| !tx.dst? }

    first_zone_without_dst || zones.first
  end

  # Returns `true` if this location equals to `UTC`.
  def utc? : Bool
    self == UTC
  end

  # Returns `true` if this location equals to `Time::Location.local`.
  def local? : Bool
    self == Location.local
  end

  # Returns `true` if this location has a fixed offset.
  #
  # Locations returned by `Location.posix_tz` have a fixed offset if the TZ
  # string specifies either no daylight saving time at all, or an all-year
  # daylight saving time (e.g. `"EST5EDT,0/0,J365/25"`).
  def fixed? : Bool
    zones.size <= 1
  end
end

require "./tz"
