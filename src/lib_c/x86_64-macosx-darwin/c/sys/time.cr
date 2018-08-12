require "./types"

lib LibC
  ITIMER_REAL    = 0
  ITIMER_VIRTUAL = 1
  ITIMER_PROF    = 2

  struct Timeval
    tv_sec : TimeT
    tv_usec : SusecondsT
  end

  struct Timezone
    tz_minuteswest : Int
    tz_dsttime : Int
  end

  struct Itimerval
    it_interval : Timeval
    it_value : Timeval
  end

  fun gettimeofday(x0 : Timeval*, x1 : Void*) : Int
  fun setitimer(Int, Itimerval*, Itimerval*) : Int
  fun utimes(path : Char*, times : Timeval[2]) : Int
end
