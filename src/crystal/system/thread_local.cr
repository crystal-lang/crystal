{% if flag?(:win32) %}
  require "c/processthreadsapi"
{% else %}
  require "c/pthread"
{% end %}

class Thread
  struct Local(T)
    {% if flag?(:win32) %}
      @key : LibC::DWORD
    {% else %}
      @key : LibC::PthreadKeyT
    {% end %}

    def initialize
      @key =
        {% if flag?(:win32) %}
          key = LibC.TlsAlloc()
          raise RuntimeError.from_winerror("TlsAlloc: out of indexes") if @key == LibC::TLS_OUT_OF_INDEXES
          key
        {% else %}
          err = LibC.pthread_key_create(out key, nil)
          raise RuntimeError.from_os_error("pthread_key_create", Errno.new(err)) unless err == 0
          key
      {% end %}
    end

    def get : T
      get? || raise KeyError.new
    end

    def get(& : -> T) : T
      get? || set(yield)
    end

    def get? : T?
      pointer =
        {% if flag?(:win32) %}
          LibC.TlsGetValue(@key)
        {% else %}
          LibC.pthread_getspecific(@key)
        {% end %}
      pointer.as(T) if pointer
    end

    def set(value : T) : T
      {% if flag?(:win32) %}
        ret = LibC.TlsSetValue(@key, value.as(Void*))
        raise RuntimeError.from_winerror("TlsAlloc: no more indexes") if ret == 0
      {% else %}
        err = LibC.pthread_setspecific(@key, value.as(Void*))
        raise RuntimeError.from_os_error("pthread_setspecific", Errno.new(err)) unless err == 0
      {% end %}
      value
    end
  end
end
