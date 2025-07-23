require "c/pthread"

class Thread
  struct Local(T)
    def self.new : self
      err = LibC.pthread_key_create(out key, nil)
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
      new(key)
    end

    def self.new(&destructor : Proc(T, Nil)) : self
      err = LibC.pthread_key_create(out key, destructor.unsafe_as(Proc(Void*, Nil)))
      raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
      new(key)
    end

    def initialize(@key : LibC::PthreadKeyT)
      {% unless T < Reference || T < Pointer || T.union_types.all? { |t| t == Nil || t < Reference } %}
        {% raise "Can only create Thread::Local with reference types, nilable reference types, or pointer types, not {{T}}" %}
      {% end %}
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
