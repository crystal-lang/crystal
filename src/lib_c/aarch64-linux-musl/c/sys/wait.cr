require "./types"
require "../signal"

lib LibC
  WNOHANG = 1
  WEXITED = 4

  P_PID   = 1
  P_PIDFD = 3

  fun waitid(idtype : Int, id : IdT, infop : SiginfoT*, options : Int) : Int
  fun waitpid(x0 : PidT, x1 : Int*, x2 : Int) : PidT
end
