require "./types"
require "c/stdlib"
require "c/sys/times"
require "c/unistd"

lib LibC
  struct Tms
    tms_utime : ClockT
    tms_stime : ClockT
    tms_cutime : ClockT
    tms_cstime : ClockT
  end

  struct RUsage
    ru_utime : Timeval
    ru_stime : Timeval
    ru_maxrss : Int32
    ru_ix_rss : Int32
    ru_idrss : Int32
    ru_isrss : Int32
    ru_minflt : Int32
    ru_majflt : Int32
    ru_nswap : Int32
    ru_inblock : Int32
    ru_oublock : Int32
    ru_msgsnd : Int32
    ru_msgrcv : Int32
    ru_nsignals : Int32
    ru_nvcsw : Int32
    ru_nivcsw : Int32
  end

  RUSAGE_SELF = 0
  RUSAGE_CHILDREN = -1

  fun times(x0 : Tms*) : ClockT
  fun getrusage(who : Int, usage : RUsage*) : Int16
end
