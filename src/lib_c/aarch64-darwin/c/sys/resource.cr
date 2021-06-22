lib LibC
  alias RlimT = ULongLong

  struct Rlimit
    rlim_cur : RlimT
    rlim_max : RlimT
  end

  fun getrlimit(Int, Rlimit*) : Int

  RLIMIT_STACK = 3

  struct RUsage
    ru_utime : Timeval
    ru_stime : Timeval
    ru_maxrss : Long
    ru_ix_rss : Long
    ru_idrss : Long
    ru_isrss : Long
    ru_minflt : Long
    ru_majflt : Long
    ru_nswap : Long
    ru_inblock : Long
    ru_oublock : Long
    ru_msgsnd : Long
    ru_msgrcv : Long
    ru_nsignals : Long
    ru_nvcsw : Long
    ru_nivcsw : Long
  end

  RUSAGE_SELF     =  0
  RUSAGE_CHILDREN = -1

  fun getrusage(who : Int, usage : RUsage*) : Int16
end
