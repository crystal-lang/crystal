require "./sys/types"

lib LibC
  fun pthread_join(th : PthreadT, thread_return : Void**) : Int
end
