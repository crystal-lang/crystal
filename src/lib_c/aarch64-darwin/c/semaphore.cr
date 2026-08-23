require "c/fcntl"

lib LibC
  SEM_FAILED = Pointer(SemT).new(-1.to_u64!)

  type SemT = Int

  fun sem_close(SemT*) : Int
  fun sem_open(Char*, Int, ...) : SemT*
  fun sem_post(SemT*) : Int
  fun sem_unlink(Char*) : Int
  fun sem_wait(SemT*) : Int
end
