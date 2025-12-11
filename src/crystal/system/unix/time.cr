require "c/sys/time"
require "c/time"

{% if flag?(:android) %}
  # needed for accessing local timezone
  require "c/sys/system_properties"
{% end %}

module Crystal::System::Time
  UNIX_EPOCH_IN_SECONDS  = 62135596800_i64
  NANOSECONDS_PER_SECOND =   1_000_000_000

  def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}
    ret = LibC.clock_gettime(LibC::CLOCK_REALTIME, out timespec)
    raise RuntimeError.from_errno("clock_gettime") unless ret == 0
    {timespec.tv_sec.to_i64 + UNIX_EPOCH_IN_SECONDS, timespec.tv_nsec.to_i}
  end

  def self.monotonic : {Int64, Int32}
    clock = {% if flag?(:darwin) %}
              LibC::CLOCK_UPTIME_RAW
            {% else %}
              LibC::CLOCK_MONOTONIC
            {% end %}

    ret = LibC.clock_gettime(clock, out tp)
    raise RuntimeError.from_errno("clock_gettime()") unless ret == 0
    {tp.tv_sec.to_i64, tp.tv_nsec.to_i32}
  end

  def self.ticks : UInt64
    clock = {% if flag?(:darwin) %}
              LibC::CLOCK_UPTIME_RAW
            {% else %}
              LibC::CLOCK_MONOTONIC
            {% end %}

    LibC.clock_gettime(clock, out tp)
    tp.tv_sec.to_u64! &* NANOSECONDS_PER_SECOND &+ tp.tv_nsec.to_u64!
  end

  def self.to_timespec(time : ::Time)
    t = uninitialized LibC::Timespec
    t.tv_sec = typeof(t.tv_sec).new(time.to_unix)
    t.tv_nsec = typeof(t.tv_nsec).new(time.nanosecond)
    t
  end

  def self.to_timeval(time : ::Time)
    t = uninitialized LibC::Timeval
    t.tv_sec = typeof(t.tv_sec).new(time.to_unix)
    t.tv_usec = typeof(t.tv_usec).new(time.nanosecond // ::Time::NANOSECONDS_PER_MICROSECOND)
    t
  end

  # Many systems use /usr/share/zoneinfo, Solaris 2 has
  # /usr/share/lib/zoneinfo, IRIX 6 has /usr/lib/locale/TZ,
  # NixOS has /etc/zoneinfo.
  ZONE_SOURCES = {
    "/usr/share/zoneinfo/",
    "/usr/share/lib/zoneinfo/",
    "/usr/lib/locale/TZ/",
    "/etc/zoneinfo/",
  }

  # Android Bionic C-specific locations. These are files rather than directories
  # and use a different format (see `Time::Location.read_android_tzdata`).
  ANDROID_TZDATA_SOURCES = {
    "/apex/com.android.tzdata/etc/tz/tzdata",
    "/system/usr/share/zoneinfo/tzdata",
  }

  def self.zone_sources : Enumerable(String)
    ZONE_SOURCES
  end

  def self.android_tzdata_sources : Enumerable(String)
    ANDROID_TZDATA_SOURCES
  end

  def self.load_iana_zone(iana_name : String) : ::Time::Location?
    nil
  end

  {% if flag?(:android) %}
    def self.load_localtime : ::Time::Location?
      # NOTE: although reading a system property is expensive, we don't cache it
      # here since it is expected that most code should only ever be calling
      # `Time::Location.load`, which is already a cached class property, rather
      # than `.load_local`. Bionic itself caches the property like this:
      # https://android.googlesource.com/platform/bionic/+/master/libc/private/CachedProperty.h
      return nil unless timezone = getprop("persist.sys.timezone")
      return nil unless path = ::Time::Location.find_android_tzdata_file(android_tzdata_sources)

      ::File.open(path) do |file|
        ::Time::Location.read_android_tzdata(file, true) do |name, location|
          return location if name == timezone
        end
      end
    end

    private def self.getprop(key : String) : String?
      {% if LibC.has_method?("__system_property_read_callback") %}
        pi = LibC.__system_property_find(key)
        value = ""
        LibC.__system_property_read_callback(pi, ->(data, _name, value, _serial) do
          data.as(String*).value = String.new(value)
        end, pointerof(value))
        value.presence
      {% else %}
        buf = uninitialized LibC::Char[LibC::PROP_VALUE_MAX]
        len = LibC.__system_property_get(key, buf)
        String.new(buf.to_slice[0, len]) if len > 0
      {% end %}
    end
  {% else %}
    private LOCALTIME = "/etc/localtime"

    def self.load_localtime : ::Time::Location?
      # Try to defer the name of the zoneinfo file from the link target (e.g.
      # `/usr/share/zoneinfo/Europe/Berlin`) and load the corresponding
      # location.
      # We do not load the actual target file, only extract the name so the
      # resulting location is exactly the same as when loading it explicitly
      # as `Time::Location.load("Europe/Berlin")`.
      if ::File.symlink?("/etc/localtime") && (realpath = ::File.readlink?("/etc/localtime"))
        if pos = realpath.rindex("zoneinfo/")
          name = realpath[(pos + "zoneinfo/".size)..]
          return ::Time::Location.load(name)
        end
      end

      # Only when /etc/localtime is not a symlink or doesn't point to a
      # zoneinfo/ directory, we read the TZif data from the actual target file
      # as a fallback.
      if ::File.file?(LOCALTIME) && ::File::Info.readable?(LOCALTIME)
        ::File.open(LOCALTIME) do |file|
          begin
            ::Time::Location.read_zoneinfo("Local", file)
          rescue ::Time::Location::InvalidTZDataError
            nil
          end
        end
      end
    end
  {% end %}
end
