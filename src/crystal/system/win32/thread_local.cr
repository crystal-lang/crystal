require "c/fibersapi"

class Thread
  struct Local(T)
    def self.new : self
      key = LibC.FlsAlloc(nil)
      raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if key == LibC::FLS_OUT_OF_INDEXES
      new(key)
    end

    def self.new(&destructor : Proc(T, Nil))
      key = LibC.FlsAlloc(destructor.unsafe_as(LibC::FLS_CALLBACK_FUNCTION))
      raise RuntimeError.from_winerror("FlsAlloc: out of indexes") if key == LibC::FLS_OUT_OF_INDEXES
      new(key)
    end

    def initialize(@key : LibC::DWORD)
      {% unless T < Reference || T < Pointer || T.union_types.all? { |t| t == Nil || t < Reference } %}
        {% raise "Can only create Thread::Local with reference types, nilable reference types, or pointer types, not {{T}}" %}
      {% end %}
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
