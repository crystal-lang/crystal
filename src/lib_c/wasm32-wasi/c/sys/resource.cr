lib LibC
  RUSAGE_SELF     = 1
  RUSAGE_CHILDREN = 2

  struct Rusage
    ru_utime : Timeval
    ru_stime : Timeval
  end

  fun getrusage(who : Int, usage : Rusage*) : Int
end
