require "c/pthread"

class Thread
  struct Local(T)
    @key : LibC::PthreadKeyT

    def initialize
      @key = pthread_key_create(nil)
    end

    def initialize(&destructor : Proc(T, Nil))
      @key = pthread_key_create(destructor.unsafe_as(Proc(Void*, Nil)))
    end

    private def pthread_key_create(destructor)
      err = LibC.pthread_key_create(out key, destructor)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
      key
    end

    def get? : T?
      pointer = LibC.pthread_getspecific(@key)
      Box(T).unbox(pointer) unless pointer.null?
    end

    def set(value : T) : T
      err = LibC.pthread_setspecific(@key, Box(T).box(value))
      raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(err)) unless err == 0
      value
    end
  end
end
