{% if flag?(:wasip3) %}
  # The wasm32-wasip3 sysroot introduced in wasi-sdk 34 requires LLVM 23+ and
  # the new TLS representation based on cooperative threading, regardless of
  # using threads or cooperative threading or none.

  {% if compare_versions(Crystal::LLVM_VERSION, "23.0.0") < 0 %}
    {% raise "WASI preview 3 requires Crystal to have been compiled with LLVM 23 or later." %}
  {% end %}

  @[Link(ldflags: "--cooperative-threading -lpthread")]
{% end %}
lib LibC
end
