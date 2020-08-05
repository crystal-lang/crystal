require "./types"
require "../signal"

lib LibC
  WNOHANG = 1

  fun waitpid(pid : PidT, stat_loc : Int*, options : Int) : PidT
end
