require "c/pthread"

class Thread
  struct Local(T)
    @key = uninitialized LibC::PthreadKeyT

    def initialize
      previous_def
      @key = pthread_key_create(nil)
    end

    def initialize(&destructor : Proc(T, Nil))
      previous_def(&destructor)
      ptr = destructor.unsafe_as(Proc(Void*, Nil))
      @key = pthread_key_create(ptr)
    end

    private def pthread_key_create(destructor)
      err = LibC.pthread_key_create(out key, destructor)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
      key
    end

    def get? : T?
      pointer = LibC.pthread_getspecific(@key)
      pointer.as(T) unless pointer.null?
    end

    def set(value : T) : T
      err = LibC.pthread_setspecific(@key, value.as(Void*))
      raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(err)) unless err == 0
      value
    end
  end
end
