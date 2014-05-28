lib PThread
  type Thread : Void*
  struct Mutex
    a : Int64; b : Int64; c : Int64; d : Int64; e : Int64; f : Int64; g : Int64; h : Int64
  end

  struct MutexAttr
  end

  fun create = pthread_create(thread : Thread*, attr : Void*, start : Void* ->, arg : Void*)
  fun exit = pthread_exit(value : Void*)
  fun join = pthread_join(thread : Thread, value : Void**) : Int32

  fun mutex_init = pthread_mutex_init(mutex : Mutex*, mutex_attr : MutexAttr*) : Int32
  fun mutex_lock = pthread_mutex_lock(mutex : Mutex*) : Int32
  fun mutex_trylock = pthread_mutex_trylock(mutex : Mutex*) : Int32
  fun mutex_unlock = pthread_mutex_unlock(mutex : Mutex*) : Int32
  fun mutex_destroy = pthread_mutex_destroy(mutex : Mutex*) : Int32
end

class Thread(T, R)
  def self.new(func : -> R)
    Thread(Nil, R).new(nil, ->(x : Nil) { func.call })
  end

  def initialize(arg : T, func : T -> R)
    @func = func
    @arg = arg
    PThread.create(out @th, nil, ->(x : Void*) {
        obj = x as Thread(T, R)
        obj.start
      },
      Pointer(Void).new(object_id))
  end

  def start
    ret = Pointer(R).malloc(1)
    ret.value = @func.call(@arg)
    PThread.exit(ret as Void*)
  end

  def join
    PThread.join(@th, out ret)
    (ret as R*).value
  end
end

class Mutex
  def initialize
    PThread.mutex_init(out @mutex, nil)
  end

  def lock
    PThread.mutex_lock(pointerof(@mutex))
  end

  def try_lock
    PThread.mutex_trylock(pointerof(@mutex))
  end

  def unlock
    PThread.mutex_unlock(pointerof(@mutex))
  end

  def synchronize
    lock
    yield
  ensure
    unlock
  end

  def destroy
    PThread.mutex_destroy(pointerof(@mutex))
  end
end
