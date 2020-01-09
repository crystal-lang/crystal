require "c/stdarg"

struct VaList
  # :nodoc:
  getter to_unsafe

  # :nodoc:
  def initialize(@to_unsafe : LibC::VaList)
  end

  def self.open
    ap = uninitialized LibC::VaList
    Intrinsics.va_start pointerof(ap)
    begin
      yield new(ap)
    ensure
      Intrinsics.va_end pointerof(ap)
    end
  end

  {% if compare_versions(Crystal::VERSION, "0.33.0-0") > 0 %}
    @[Primitive(:va_arg)]
    def next(type)
    end
  {% end %}
end
