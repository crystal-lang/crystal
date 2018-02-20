require "./types"

lib LibC
  struct Tms
    tms_utime : ClockT  # User CPU time
    tms_stime : ClockT  # System CPU time
    tms_cutime : ClockT # User CPU time of terminated child procs
    tms_cstime : ClockT # System CPU time of terminated child procs
  end

  fun times(tp : Tms*) : ClockT
end
