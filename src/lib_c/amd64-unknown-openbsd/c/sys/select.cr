require "./types"
require "./time"
require "../time"
require "../signal"

lib LibC
  struct FdSet
    fds_bits : StaticArray(UInt32T, 32)
  end

  fun select(nfds : Int, readfds : FdSet*, writefds : FdSet*, exceptfds : FdSet*, timeout : Timeval*) : Int
end
