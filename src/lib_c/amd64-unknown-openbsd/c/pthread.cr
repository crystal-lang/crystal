require "./sys/types"
require "./pthread_np"

@[Link("pthread")]
lib LibC
  fun pthread_cond_broadcast(cond : PthreadCondT*) : Int
  fun pthread_cond_destroy(cond : PthreadCondT*) : Int
  fun pthread_cond_init(cond : PthreadCondT*, attr : PthreadCondattrT*) : Int
  fun pthread_cond_signal(cond : PthreadCondT*) : Int
  fun pthread_cond_wait(cond : PthreadCondT*, mutex : PthreadMutexT*) : Int
  fun pthread_create(thread : PthreadT*, attr : PthreadAttrT*, start_routine : Void* -> Void*, arg : Void*) : Int
  fun pthread_detach(thread : PthreadT) : Int
  fun pthread_equal(t1 : PthreadT, t2 : PthreadT) : Int
  fun pthread_join(thread : PthreadT, value_ptr : Void**) : Int
  fun pthread_mutex_destroy(xmutex0 : PthreadMutexT*) : Int
  fun pthread_mutex_init(mutex : PthreadMutexT*, attr : PthreadMutexattrT*) : Int
  fun pthread_mutex_lock(mutex : PthreadMutexT*) : Int
  fun pthread_mutex_trylock(mutex : PthreadMutexT*) : Int
  fun pthread_mutex_unlock(mutex : PthreadMutexT*) : Int
  fun pthread_self : PthreadT
end
