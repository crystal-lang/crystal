require "c/processthreadsapi"

class Thread
  struct Local(T)
    @key : LibC::DWORD

    def initialize
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
      @key = LibC.TlsAlloc()
      raise RuntimeError.from_winerror("TlsAlloc: out of indexes") if @key == LibC::TLS_OUT_OF_INDEXES
    end

    def get? : T?
      pointer = LibC.TlsGetValue(@key)
      pointer.as(T) if pointer
    end

    def set(value : T) : T
      ret = LibC.TlsSetValue(@key, value.as(Void*))
      raise RuntimeError.from_winerror("TlsAlloc: no more indexes") if ret == 0
      value
    end
  end
end
