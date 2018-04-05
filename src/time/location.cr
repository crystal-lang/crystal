require "./location/loader"

# `Location` represents a specific time zone.
#
# It can be either a time zone from the IANA Time Zone database,
# a fixed offset, or `UTC`.
#
# Creating a location from timezone data:
# ```
# location = Time::Location.load("Europe/Berlin")
# ```
#
# Initializing a `Time` instance with specified `Location`:
#
# ```
# time = Time.new(2016, 2, 15, 21, 1, 10, location: location)
# ```
#
# Alternatively, you can switch the `Location` for any `Time` instance:
#
# ```
# time.location.to_s # => "Europe/Berlin"
# time = time.in(Time::Location.load("Asia/Jerusalem"))
# time.location.to_s # => "Asia/Jerusalem"
# ```
#
# There are also a few special conversions:
# ```
# time.to_utc   # == time.in(Location::UTC)
# time.to_local # == time.in(Location.local)
# ```
class Time::Location
  class InvalidLocationNameError < Exception
    getter name, source

    def initialize(@name : String, @source : String? = nil)
      msg = "Invalid location name: #{name}"
      msg += " in #{source}" if source
      super msg
    end
  end

  class InvalidTimezoneOffsetError < Exception
    def initialize(offset : Int)
      super "Invalid time zone offset: #{offset}"
    end
  end

  struct Zone
    UTC = new "UTC", 0, false

    getter name : String
    getter offset : Int32
    getter? dst : Bool

    def initialize(@name : String, @offset : Int32, @dst : Bool)
      # Maximium offets of IANA timezone database are -12:00 and +14:00.
      # +/-24 hours allows a generous padding for unexpected offsets.
      # TODO: Maybe reduce to Int16 (+/- 18 hours).
      raise InvalidTimezoneOffsetError.new(offset) if offset >= SECONDS_PER_DAY || offset <= -SECONDS_PER_DAY
    end

    def inspect(io : IO)
      io << "Time::Zone<"
      io << offset
      io << ", " << name
      io << " (DST)" if dst?
      io << '>'
    end
  end

  # :nodoc:
  record ZoneTransition, when : Int64, index : UInt8, standard : Bool, utc : Bool do
    getter? standard, utc

    def inspect(io : IO)
      io << "Time::ZoneTransition<"
      io << '#' << index << ", "
      Time.epoch(self.when).to_s("%F %T", io)
      io << ", STD" if standard?
      io << ", UTC" if utc?
      io << '>'
    end
  end

  # Describes the Coordinated Universal Time (UTC).
  UTC = new "UTC", [Zone::UTC]

  property name : String
  property zones : Array(Zone)

  # Most lookups will be for the current time.
  # To avoid the binary search through tx, keep a
  # static one-element cache that gives the correct
  # zone for the time when the Location was created.
  # The units for @cached_range are seconds
  # since January 1, 1970 UTC, to match the argument
  # to `#lookup`.
  @cached_range : Tuple(Int64, Int64)
  @cached_zone : Zone

  # Creates a `Location` instance named *name* with fixed *offset*.
  def self.fixed(name : String, offset : Int32)
    new name, [Zone.new(name, offset, false)]
  end

  # Creates a `Location` instance with fixed *offset*.
  def self.fixed(offset : Int32)
    span = offset.abs.seconds
    name = sprintf("%s%02d:%02d", offset.sign < 0 ? '-' : '+', span.hours, span.minutes)
    fixed name, offset
  end

  # Returns the `Location` with the given name.
  #
  # This uses a list of paths to look for timezone data. Each path can
  # either point to a directory or an uncompressed ZIP file.
  # System-specific default paths are provided by the implementation.
  #
  # The first timezone data matching the given name that is successfully loaded
  # and parsed is returned.
  # A custom lookup path can be set as environment variable `ZONEINFO`.
  #
  # Special names:
  # * `"UTC"` and empty string `""` return `Location::UTC`
  # * `"Local"` returns `Location.local`
  #
  # This method caches files based on the modification time, so subsequent loads
  # of the same location name will return the same instance of `Location` unless
  # the timezone database has been updated in between.
  #
  # Example:
  # `ZONEINFO=/path/to/zoneinfo.zip crystal eval 'pp Location.load("Custom/Location")'`
  def self.load(name : String) : Location
    case name
    when "", "UTC"
      UTC
    when "Local"
      local
    when .includes?(".."), .starts_with?('/'), .starts_with?('\\')
      # No valid IANA Time Zone name contains a single dot,
      # much less dot dot. Likewise, none begin with a slash.
      raise InvalidLocationNameError.new(name)
    else
      if zoneinfo = ENV["ZONEINFO"]?
        if location = load_from_dir_or_zip(name, zoneinfo)
          return location
        else
          raise InvalidLocationNameError.new(name, zoneinfo)
        end
      end

      if location = load(name, Crystal::System::Time.zone_sources)
        return location
      end

      raise InvalidLocationNameError.new(name)
    end
  end

  # Returns the location representing the local time zone.
  #
  # The value is loaded on first access based on the current application environment  (see `.load_local` for details).
  class_property(local : Location) { load_local }

  # Loads the local location described by the current application environment.
  #
  # It consults the environment variable `ENV["TZ"]` to find the time zone to use.
  # * `"UTC"` and empty string `""` return `Location::UTC`
  # * `"Foo/Bar"` tries to load the zoneinfo from known system locations - such as `/usr/share/zoneinfo/Foo/Bar`,
  #   `/usr/share/lib/zoneinfo/Foo/Bar` or `/usr/lib/locale/TZ/Foo/Bar` on unix-based operating systems.
  #   See `Location.load` for details.
  # * If `ENV["TZ"]` is not set, the system's local timezone data will be used (`/etc/localtime` on unix-based systems).
  # * If no time zone data could be found, `Location::UTC` is returned.
  def self.load_local : Location
    case tz = ENV["TZ"]?
    when "", "UTC"
      UTC
    when Nil
      if localtime = Crystal::System::Time.load_localtime
        return localtime
      end
    else
      if location = load?(tz, Crystal::System::Time.zone_sources)
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

  def to_s(io : IO)
    io << name
  end

  def inspect(io : IO)
    io << "Time::Location<"
    to_s(io)
    io << '>'
  end

  def_equals_and_hash name, zones, transitions

  # Returns the time zone in use at `time`.
  def lookup(time : Time) : Zone
    lookup(time.epoch)
  end

  # Returns the time zone in use at `epoch` (time in seconds since UNIX epoch).
  def lookup(epoch : Int) : Zone
    unless @cached_range[0] <= epoch < @cached_range[1]
      @cached_zone, @cached_range = lookup_with_boundaries(epoch)
    end

    @cached_zone
  end

  # :nodoc:
  def lookup_with_boundaries(epoch : Int)
    case
    when zones.empty?
      return Zone::UTC, {Int64::MIN, Int64::MAX}
    when transitions.empty? || epoch < transitions.first.when
      return lookup_first_zone, {Int64::MIN, transitions[0]?.try(&.when) || Int64::MAX}
    else
      tx_index = transitions.bsearch_index do |transition|
        transition.when > epoch
      end || transitions.size

      tx_index -= 1 unless tx_index == 0
      transition = transitions[tx_index]
      range_end = transitions[tx_index + 1]?.try(&.when) || Int64::MAX

      return zones[transition.index], {transition.when, range_end}
    end
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
  private def lookup_first_zone
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

  # Returns `true` if this location equals to `Location.local`.
  def local? : Bool
    self == Location.local
  end

  # Returns `true` if this location has a fixed offset.
  def fixed? : Bool
    zones.size <= 1
  end
end
