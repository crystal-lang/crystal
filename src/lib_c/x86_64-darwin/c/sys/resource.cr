lib LibC
  alias RlimT = ULongLong

  struct Rlimit
    rlim_cur : RlimT
    rlim_max : RlimT
  end

  fun getrlimit(Int, Rlimit*) : Int

  RLIMIT_STACK = 3
end
