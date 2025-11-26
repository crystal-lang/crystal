require "./types"
require "../signal"

lib LibC
  WNOHANG = 1

  fun waitpid(__pid : PidT, __status : Int*, __options : Int) : PidT
end
