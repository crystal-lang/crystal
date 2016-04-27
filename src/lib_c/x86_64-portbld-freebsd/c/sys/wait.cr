require "./types"
require "../signal"

lib LibC
  WNOHANG = 1

  fun waitpid(x0 : PidT, x1 : Int*, x2 : Int) : PidT
end
