require "c/stdarg"

struct VaList
  # :nodoc:
  getter to_unsafe

  # :nodoc:
  def initialize(@to_unsafe : LibC::VaList)
  end

  def self.open(&)
    ap = uninitialized LibC::VaList
    Intrinsics.va_start pointerof(ap)
    begin
      yield new(ap)
    ensure
      Intrinsics.va_end pointerof(ap)
    end
  end

  {% if flag?(:aarch64) || flag?(:win32) %}
    {% platform = flag?(:aarch64) ? "AArch64" : "Windows" %}
    {% clang_impl = flag?(:aarch64) ? "https://github.com/llvm/llvm-project/blob/a574edbba2b24fcfb733aa2d82308131f5b7d2d6/clang/lib/CodeGen/TargetInfo.cpp#L5677-L5921" : "https://github.com/llvm/llvm-project/blob/a574edbba2b24fcfb733aa2d82308131f5b7d2d6/clang/lib/CodeGen/TargetInfo.cpp#L5958-L5964" %}
    # Do not call this, instead use C wrappers calling the va_arg macro for the types you need.
    #
    # Clang implements va_arg on {{ platform.id }} like this: {{ clang_impl.id }}
    # If somebody wants to fix the LLVM IR va_arg instruction on {{ platform }} upstream, or port the above here, that would be welcome.
    def next(type)
      \{% raise "Cannot get variadic argument on {{ platform.id }}. As a workaround implement wrappers in C calling the va_arg macro for the types you need and bind to those." %}
    end
  {% else %}
    @[Primitive(:va_arg)]
    def next(type)
    end
  {% end %}
end
