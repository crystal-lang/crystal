require "./types"
require "./time"
require "../time"
require "../signal"

lib LibC
  alias FdMask = Long

  struct FdSet
    fds_bits : FdMask[16] # FD_SETSIZE (1024) / NFDBITS (8 * sizeof(FdMask))
  end

  fun select(__max_fd_plus_one : Int, __read_fds : FdSet*, __write_fds : FdSet*, __exception_fds : FdSet*, __timeout : Timeval*) : Int
end
