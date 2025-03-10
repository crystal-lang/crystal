require "c/fibersapi"

class Thread
  protected class_getter(destructors : Array({LibC::DWORD, Proc(Void*, Nil)})) do
    Array({LibC::DWORD, Proc(Void*, Nil)}).new
  end

  struct Local(T)
    @key : LibC::DWORD

    def initialize
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
      @key = LibC.TlsAlloc()
      raise RuntimeError.from_winerror("TlsAlloc: out of indexes") if @key == LibC::TLS_OUT_OF_INDEXES
    end

    def initialize(&destructor : Proc(T, Nil))
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
      @key = LibC.TlsAlloc()
      raise RuntimeError.from_winerror("TlsAlloc: out of indexes") if @key == LibC::TLS_OUT_OF_INDEXES
      Thread.destructors << {@key, destructor.unsafe_as(Proc(Void*, Nil))}
    end

    def get? : T?
      pointer = LibC.TlsGetValue(@key)
      pointer.as(T) if pointer
    end

    def set(value : T) : T
      ret = LibC.TlsSetValue(@key, value.as(Void*))
      raise RuntimeError.from_winerror("TlsSetValue") if ret == 0
      value
    end
  end

  private def run_destructors
    @@destructors.try(&.each do |(key, destructor)|
      if pointer = LibC.TlsGetValue(key)
        destructor.call(pointer) # rescue nil
      end
    end)
  end
end
