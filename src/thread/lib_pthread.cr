lib PThread
  type Thread = Void*

  ifdef darwin
    type Mutex = Int64[8]
  else
    ifdef x86_64
      type Mutex = Int64[5]
    else
      type Mutex = Int64[3]
    end
  end

  type MutexAttr = Void*
  type Cond = Int64[6]
  type CondAttr = Void*

  fun create = pthread_create(thread : Thread*, attr : Void*, start : Void* ->, arg : Void*) : Int32
  fun exit = pthread_exit(value : Void*)
  fun join = pthread_join(thread : Thread, value : Void**) : Int32

  fun mutex_init = pthread_mutex_init(mutex : Mutex*, mutex_attr : MutexAttr) : Int32
  fun mutex_lock = pthread_mutex_lock(mutex : Mutex*) : Int32
  fun mutex_trylock = pthread_mutex_trylock(mutex : Mutex*) : Int32
  fun mutex_unlock = pthread_mutex_unlock(mutex : Mutex*) : Int32
  fun mutex_destroy = pthread_mutex_destroy(mutex : Mutex*) : Int32

  fun cond_init = pthread_cond_init(cond : Cond*, cond_attr : CondAttr) : Int32
  fun cond_signal = pthread_cond_signal(cond : Cond*) : Int32
  fun cond_wait = pthread_cond_wait(cond : Cond*, mutext : Mutex*) : Int32
  fun cond_destroy = pthread_cond_destroy(cond : Cond*) : Int32
end
