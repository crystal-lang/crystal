require "./types"
require "./time"
require "../time"
require "../signal"

lib LibC
  alias FdMask = Long

  struct FdSet
    fds_bits : StaticArray(FdMask, 32)
  end

  fun select(nfds : Int, readfds : FdSet*, writefds : FdSet*, exceptfds : FdSet*, timeout : Timeval*) : Int
end
