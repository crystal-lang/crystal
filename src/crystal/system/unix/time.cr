require "c/sys/time"
require "c/time"

module Crystal::System::Time
  def self.compute_offset(second)
    LibC.tzset
    offset = nil

    {% if LibC.methods.includes?("daylight".id) %}
      if LibC.daylight == 0
        # current TZ doesn't have any DST, neither in past, present or future
        offset = -LibC.timezone.to_i64
      end
    {% end %}

    unless offset
      # current TZ may have DST, either in past, present or future
      ret = LibC.localtime_r(pointerof(second), out tm)
      raise Errno.new("localtime_r") if ret.null?
      offset = tm.tm_gmtoff.to_i64
    end

    offset / 60 * TicksPerMinute
  end

  def self.compute_second_and_tenth_microsecond
    {% if flag?(:darwin) %}
      ret = LibC.gettimeofday(out timeval, nil)
      raise Errno.new("gettimeofday") unless ret == 0
      {timeval.tv_sec, timeval.tv_usec.to_i64 * 10}
    {% else %}
      ret = LibC.clock_gettime(LibC::CLOCK_REALTIME, out timespec)
      raise Errno.new("clock_gettime") unless ret == 0
      {timespec.tv_sec, timespec.tv_nsec / 100}
    {% end %}
  end
end
