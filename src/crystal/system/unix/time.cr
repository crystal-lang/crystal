require "c/sys/time"
require "c/time"

module Crystal::System::Time
  UnixEpochInSeconds = 62135596800_i64

  def self.compute_utc_offset(seconds : Int64) : Int32
    LibC.tzset
    offset = nil

    {% if LibC.methods.includes?("daylight".id) %}
      if LibC.daylight == 0
        # current TZ doesn't have any DST, neither in past, present or future
        offset = -LibC.timezone.to_i
      end
    {% end %}

    unless offset
      seconds_from_epoch = LibC::TimeT.new(seconds - UnixEpochInSeconds)
      # current TZ may have DST, either in past, present or future
      ret = LibC.localtime_r(pointerof(seconds_from_epoch), out tm)
      raise Errno.new("localtime_r") if ret.null?
      offset = tm.tm_gmtoff.to_i
    end

    offset
  end

  def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}
    {% if LibC.methods.includes?("clock_gettime".id) %}
      ret = LibC.clock_gettime(LibC::CLOCK_REALTIME, out timespec)
      raise Errno.new("clock_gettime") unless ret == 0
      {timespec.tv_sec.to_i64 + UnixEpochInSeconds, timespec.tv_nsec.to_i}
    {% else %}
      ret = LibC.gettimeofday(out timeval, nil)
      raise Errno.new("gettimeofday") unless ret == 0
      {timeval.tv_sec.to_i64 + UnixEpochInSeconds, timeval.tv_usec.to_i * 1_000}
    {% end %}
  end
end
