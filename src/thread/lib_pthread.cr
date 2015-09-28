lib LibPThread
  alias Int = LibC::Int

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

  ifdef darwin
    type Attr = UInt8[64]
    type MutexAttr = UInt8[16]
  else
    type Attr = UInt8[56]
    type MutexAttr = UInt8[4]
  end

  type Cond = Int64[6]
  type CondAttr = Void*

  fun create = pthread_create(thread : Thread*, attr : Attr*, start : Void* ->, arg : Void*) : Int
  fun exit = pthread_exit(value : Void*)
  fun join = pthread_join(thread : Thread, value : Void**) : Int
  fun detach = pthread_detach(thread : Thread) : Int

  fun attr_init = pthread_attr_init(attr : Attr*) : Int
  fun attr_getstack = pthread_attr_getstack(attr : Attr*, addr : Void**, ssize : LibC::SizeT*) : Int
  fun attr_setstack = pthread_attr_setstack(attr : Attr*, addr : Void*, ssize : LibC::SizeT) : Int
  fun attr_destroy = pthread_attr_destroy(attr : Attr*) : Int

  fun mutex_init = pthread_mutex_init(mutex : Mutex*, mutex_attr : MutexAttr*) : Int
  fun mutex_lock = pthread_mutex_lock(mutex : Mutex*) : Int
  fun mutex_trylock = pthread_mutex_trylock(mutex : Mutex*) : Int
  fun mutex_unlock = pthread_mutex_unlock(mutex : Mutex*) : Int
  fun mutex_destroy = pthread_mutex_destroy(mutex : Mutex*) : Int

  fun cond_init = pthread_cond_init(cond : Cond*, cond_attr : CondAttr) : Int
  fun cond_signal = pthread_cond_signal(cond : Cond*) : Int
  fun cond_wait = pthread_cond_wait(cond : Cond*, mutext : Mutex*) : Int
  fun cond_destroy = pthread_cond_destroy(cond : Cond*) : Int
end
