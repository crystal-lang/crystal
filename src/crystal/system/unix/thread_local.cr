require "c/pthread"

class Thread
  struct Local(T)
    @key : LibC::PthreadKeyT

    def initialize
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
      err = LibC.pthread_key_create(out @key, nil)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
    end

    def initialize(&destructor : Proc(T, Nil))
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
      err = LibC.pthread_key_create(out @key, destructor.unsafe_as(Proc(Void*, Nil)))
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
    end

    def get? : T?
      pointer = LibC.pthread_getspecific(@key)
      pointer.as(T) if pointer
    end

    def set(value : T) : T
      err = LibC.pthread_setspecific(@key, value.as(Void*))
      raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(err)) unless err == 0
      value
    end
  end
end
