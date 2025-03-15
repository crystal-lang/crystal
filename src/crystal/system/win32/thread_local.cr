require "c/fibersapi"

class Thread
  struct Local(T)
    @key : LibC::DWORD

    def initialize
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
      @key = LibC.FlsAlloc
      raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if @key == LibC::FLS_OUT_OF_INDEXES
    end

    def initialize(&destructor : Proc(T, Nil))
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
      @key = LibC.FlsAlloc(destructor.unsafe_as(Proc(Void*, Nil)))
      raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if @key == LibC::FLS_OUT_OF_INDEXES
    end

    def get? : T?
      pointer = LibC.FlsGetValue(@key)
      pointer.as(T) if pointer
    end

    def set(value : T) : T
      ret = LibC.FlsSetValue(@key, value.as(Void*))
      raise RuntimeError.from_winerror("FlsSetValue") if ret == 0
      value
    end
  end
end
