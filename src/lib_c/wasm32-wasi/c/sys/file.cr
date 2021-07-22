lib LibC
  LOCK_SH = 1
  LOCK_EX = 2
  LOCK_NB = 4
  LOCK_UN = 8

  fun flock(x0 : Int, x1 : Int) : Int
end
