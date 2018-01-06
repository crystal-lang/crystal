require "./types"
require "../signal"

lib LibC
  WNOHANG     = 1
  WUNTRACED   = 2
  WCONTINUED  = 8

  fun waitpid(x0 : PidT, x1 : Int*, x2 : Int) : PidT
end
