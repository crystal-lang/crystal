require "./types"

lib LibC
  struct Tms
    tms_utime : ClockT
    tms_stime : ClockT
    tms_cutime : ClockT
    tms_cstime : ClockT
  end

  fun times(x0 : Tms*) : ClockT
end
