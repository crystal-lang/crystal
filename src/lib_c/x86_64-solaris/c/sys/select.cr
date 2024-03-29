require "./types"
require "./time"
require "../time"
require "../signal"

lib LibC
  struct FdSet
    fds_bits : Long[1024] # FD_SETSIZE (65536) / FD_NFDBITS (64)
  end

  fun select(x0 : Int, x1 : FdSet*, x2 : FdSet*, x3 : FdSet*, x4 : Timeval*) : Int
end
