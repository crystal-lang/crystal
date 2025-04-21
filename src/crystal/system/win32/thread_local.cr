require "c/fibersapi"

class Thread
  struct Local(T)
    @key = uninitialized LibC::DWORD

    def initialize
      previous_def
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
      pointer.as(T) unless pointer.null?
    end

    def set(value : T) : T
      ret = LibC.FlsSetValue(@key, value.as(T))
      raise RuntimeError.from_winerror("FlsSetValue") if ret == 0
      value
    end
  end
end
