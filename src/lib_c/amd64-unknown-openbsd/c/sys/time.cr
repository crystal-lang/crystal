require "./types"

lib LibC
  struct Timeval
    tv_sec : TimeT        # seconds
    tv_usec : SusecondsT  # and microseconds
  end

  struct Timezone
    tz_minuteswest : Int  # minutes west of Greenwich
    tz_dsttime : Int      # type of dst correction
  end

  fun gettimeofday(x0 : Timeval*, x1 : Timezone*) : Int
  fun utimes(path : Char*, times : Timeval[2]) : Int
end
