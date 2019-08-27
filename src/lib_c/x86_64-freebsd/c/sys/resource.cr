lib LibC
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

  RUSAGE_SELF     =  0
  RUSAGE_CHILDREN = -1

  fun getrusage(who : Int, usage : RUsage*) : Int16
end
