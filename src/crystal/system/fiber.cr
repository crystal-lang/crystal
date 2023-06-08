module Crystal::System::Fiber
  # Allocates memory for a stack.
  # def self.allocate_stack(stack_size : Int) : Void*

  # Frees memory of a stack.
  # def self.free_stack(stack : Void*, stack_size : Int) : Nil

  # Determines location of the top of the main process fiber's stack.
  # def self.main_fiber_stack(stack_bottom : Void*) : Void*
end

{% if flag?(:wasi) %}
  require "./wasi/fiber"
{% elsif flag?(:unix) %}
  require "./unix/fiber"
{% elsif flag?(:win32) %}
  require "./win32/fiber"
{% else %}
  {% raise "Fiber not supported" %}
{% end %}
