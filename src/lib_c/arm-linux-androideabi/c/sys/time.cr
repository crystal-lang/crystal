require "./types"

lib LibC
  struct Timeval
    tv_sec : Long
    tv_usec : Long
  end

  struct Timezone
    tz_minuteswest : Int
    tz_dsttime : Int
  end

  fun gettimeofday(x0 : Timeval*, x1 : Timezone*) : Int
end
