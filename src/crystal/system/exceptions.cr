{% if flag?(:win32) && flag?(:msvc) %}
  require "./win32/exceptions"
{% elsif flag?(:wasm32) %}
  require "./wasi/exceptions"
{% elsif flag?(:interpreted) %}
  @[Primitive(:interpreter_raise_without_backtrace)]
  def raise_without_backtrace(exception : Exception) : NoReturn
  end
{% else %}
  require "../../exception/lib_unwind"
  require "./unix/exceptions"
{% end %}
