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

  {% if flag?(:aarch64) %}
    # Do not call this, instead use C wrappers calling the va_arg macro for the types you need.
    #
    # Clang implements va_arg on AArch64 like this: https://github.com/llvm/llvm-project/blob/1204f6b4e9d6bef8ec319d121942dca5cbf94a26/clang/lib/CodeGen/Targets/AArch64.cpp#L92
    # If somebody wants to fix the LLVM IR va_arg instruction on AArch64 upstream, or port the above to the Crystal compiler, that would be welcome.
    def next(type)
      \{% raise "Cannot get variadic argument on AArch64. As a workaround implement wrappers in C calling the va_arg macro for the types you need and bind to those." %}
    end
  {% else %}
    @[Primitive(:va_arg)]
    def next(type)
    end
  {% end %}
end
