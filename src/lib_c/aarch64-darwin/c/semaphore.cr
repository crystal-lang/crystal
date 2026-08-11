lib LibC
  type SemT = Int
  fun sem_destroy(SemT*) : Int
  fun sem_init(SemT*, Int, UInt) : Int
  fun sem_post(SemT*) : Int
  fun sem_wait(SemT*) : Int
end
