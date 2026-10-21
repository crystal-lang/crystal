require "./types"
require "../signal"

lib LibC
  WNOHANG = 1
  WEXITED = 4

  P_PID   = 1
  P_PIDFD = 3

  fun waitid(idtype : Int, id : IdT, infop : SiginfoT*, options : Int) : Int
  fun waitpid(__pid : PidT, __status : Int*, __options : Int) : PidT
end
