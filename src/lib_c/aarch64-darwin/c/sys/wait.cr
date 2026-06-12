require "./types"
require "../signal"

lib LibC
  WNOHANG = 0x00000001
  WEXITED = 0x00000004

  P_PID = 1

  fun waitid(idtype : Int, id : IdT, infop : SiginfoT*, options : Int) : Int
  fun waitpid(x0 : PidT, x1 : Int*, x2 : Int) : PidT
end
