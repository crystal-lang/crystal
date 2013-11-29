lib C
  struct Mutex
  end

  struct MutexAttr
  end

  fun pthread_mutex_init(mutex : Mutex*, mutex_attr : MutexAttr*) : Int32
  fun pthread_mutex_lock(mutex : Mutex*) : Int32
  fun pthread_mutex_trylock(mutex : Mutex*) : Int32
  fun pthread_mutex_unlock(mutex : Mutex*) : Int32
  fun pthread_mutex_destroy(mutex : Mutex*) : Int32
end

class Mutex
  def initialize
    C.pthread_mutex_init(out @mutex, nil)
  end

  def lock
    C.pthread_mutex_lock(@mutex.ptr)
  end

  def try_lock
    C.pthread_mutex_trylock(@mutex.ptr)
  end

  def unlock
    C.pthread_mutex_unlock(@mutex.ptr)
  end

  def synchronize
    lock
    value = yield
    unlock
    value
  end

  def destroy
    C.pthread_mutex_destroy(@mutex.ptr)
  end
end
