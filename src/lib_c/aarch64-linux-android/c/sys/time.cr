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

  fun gettimeofday(__tv : Timeval*, __tz : Timezone*) : Int
  fun utimes(__path : Char*, __times : Timeval[2]) : Int
  {% if ANDROID_API >= 19 %}
    fun futimens(__dir_fd : Int, __times : Timespec[2]) : Int
  {% end %}
end
