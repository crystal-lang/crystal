require "./sys/types"

lib LibC
  fun pthread_cond_broadcast(x0 : PthreadCondT*) : Int
  fun pthread_cond_destroy(x0 : PthreadCondT*) : Int
  fun pthread_cond_init(x0 : PthreadCondT*, x1 : PthreadCondattrT*) : Int
  fun pthread_cond_signal(x0 : PthreadCondT*) : Int
  fun pthread_cond_wait(x0 : PthreadCondT*, x1 : PthreadMutexT*) : Int
  fun pthread_create(x0 : PthreadT*, x1 : PthreadAttrT*, x2 : Void* -> Void*, x3 : Void*) : Int
  fun pthread_detach(x0 : PthreadT) : Int
  fun pthread_join(x0 : PthreadT, x1 : Void**) : Int
  fun pthread_mutex_destroy(x0 : PthreadMutexT*) : Int
  fun pthread_mutex_init(x0 : PthreadMutexT*, x1 : PthreadMutexattrT*) : Int
  fun pthread_mutex_lock(x0 : PthreadMutexT*) : Int
  fun pthread_mutex_trylock(x0 : PthreadMutexT*) : Int
  fun pthread_mutex_unlock(x0 : PthreadMutexT*) : Int
  fun pthread_self : PthreadT
end
