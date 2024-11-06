require "./types"

lib LibC
  struct Timeval
    tv_sec : TimeT
    tv_usec : SusecondsT
  end

  struct Timezone
    tz_minuteswest : Int
    tz_dsttime : Int
  end

  fun gettimeofday = __gettimeofday50(x0 : Timeval*, x1 : Timezone*) : Int
  fun utimes = __utimes50(path : Char*, times : Timeval[2]) : Int
  fun futimens(fd : Int, times : Timespec[2]) : Int
end
