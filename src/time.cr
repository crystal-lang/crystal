lib C
  struct Tm
    tm_sec    : Int32
    tm_min    : Int32
    tm_hour   : Int32
    tm_mday   : Int32
    tm_mon    : Int32
    tm_year   : Int32
    tm_wday   : Int32
    tm_yday   : Int32
    tm_isdst  : Int32
    tm_gmtoff : Int64
    tm_zone   : UInt8*
  end

  struct TimeSpec
    tv_sec  : C::TimeT
    tv_nsec : C::TimeT
  end

  struct TimeVal
    tv_sec  : C::TimeT
    tv_usec : Int32
  end

  struct TimeZone
    tz_minuteswest : Int32
    tz_dsttime     : Int32
  end

  fun gmtime(clock : TimeT*) : Tm*
  fun localtime(clock : TimeT*) : Tm*
  fun mktime(time : Tm*) : TimeT

  fun gettimeofday(tp : TimeVal*, tzp : TimeZone*) : Int32
  fun strftime(buf : UInt8*, bufsize : SizeT, format : UInt8*, time : Tm*) : SizeT
end

ifdef linux
  lib Librt("rt")
    fun clock_gettime(clk_id : Int32, tp : C::TimeSpec*)
  end
end

class Time
  def initialize
    ifdef darwin
      C.gettimeofday(out tp, out tzp)
      @seconds = tp.tv_sec + tp.tv_usec / 1e6
    elsif linux
      Librt.clock_gettime(0, out ts)
      @seconds = ts.tv_sec + ts.tv_nsec / 1e9
    end
  end

  def initialize(year, month=1, day=1, hour=0, min=0, sec=0, utc_offset=0)
    time :: C::Tm
    time.tm_year   = year - 1900
    time.tm_mon    = month - 1
    time.tm_mday   = day
    time.tm_hour   = hour
    time.tm_min    = min 
    time.tm_sec    = sec
    time.tm_isdst  = 0
    time.tm_gmtoff = utc_offset.to_i64

    @seconds = C.mktime(pointerof(time)).to_f64
  end

  def initialize(time : C::TimeSpec)
    @seconds = time.tv_sec + time.tv_nsec / 1e9
  end

  def -(other : Number)
    Time.at(to_f - other)
  end

  def -(other : Time)
    to_f - other.to_f
  end

  def to_f
    @seconds
  end

  def to_i
    @seconds.to_timet
  end

  def to_s
    if utc?
      strftime("%F %T UTC")
    else
      strftime("%F %T %z")
    end
  end

  def tm
    return @tm if @tm
    clock = to_i
    @tm   = C.localtime(pointerof(clock))
  end

  def utc?
    @is_utc ? true : false
  end

  def utc
    time    = to_i
    @tm     = C.gmtime(pointerof(time))
    @is_utc = true

    self
  end

  def localtime
    time    = to_i
    @tm     = C.localtime(pointerof(time))
    @is_utc = false

    self
  end

  def strftime(format)
    buf = Pointer(UInt8).malloc(128)
    C.strftime(buf, 128.to_sizet, format, tm)
    String.new(buf)
  end

  def self.at(seconds)
    time :: C::TimeSpec
    time.tv_sec  = seconds.to_timet
    time.tv_nsec = ((seconds - time.tv_sec) * 1e9).to_timet

    new(time)
  end

  def self.utc(year, month=1, day=1, hour=0, min=0, sec=0, utc_offset=0)
    new(year, month, day, hour, min, sec, utc_offset).utc
  end

  def self.local(year, month=1, day=1, hour=0, min=0, sec=0)
    new(year, month, day, hour, min, sec, utc_offset)
  end

  def self.now
    new
  end
end
