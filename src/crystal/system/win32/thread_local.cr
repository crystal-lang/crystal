require "c/fibersapi"

class Thread
  struct Local(T)
    @key : LibC::DWORD

    def initialize
      @key = fls_alloc(nil)
    end

    def initialize(&destructor : Proc(T, Nil))
      @key = fls_alloc(destructor.unsafe_as(LibC::FLS_CALLBACK_FUNCTION))
    end

    private def fls_alloc(destructor)
      key = LibC.FlsAlloc(destructor)
      raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if key == LibC::FLS_OUT_OF_INDEXES
      key
    end

    def get? : T?
      pointer = LibC.FlsGetValue(@key)
      Box(T).unbox(pointer) unless pointer.null?
    end

    def set(value : T) : T
      ret = LibC.FlsSetValue(@key, Box(T).box(value))
      raise RuntimeError.from_winerror("FlsSetValue") if ret == 0
      value
    end
  end
end
