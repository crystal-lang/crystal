require "./types"
require "../signal"

lib LibC
  WNOHANG = 1
  WEXITED = 4

  P_PID   = 1
  P_PIDFD = 3

  fun waitid(idtype : Int, id : IdT, infop : SiginfoT*, options : Int) : Int
  fun waitpid(pid : PidT, stat_loc : Int*, options : Int) : PidT
end
