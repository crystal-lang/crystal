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

  fun gettimeofday(x0 : Timeval*, x1 : Void*) : Int
  fun utimes(path : Char*, times : Timeval[2]) : Int
end
