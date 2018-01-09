require "./types"
require "../signal"

lib LibC
  WNOHANG    = 1
  WUNTRACED  = 2
  WCONTINUED = 8

  fun waitpid(wpid : PidT, status : Int*, options : Int) : PidT
end
