module Crystal::System::Fiber
  # Allocates memory for a stack.
  # def self.allocate_stack(stack_size : Int, protect : Bool) : Void*

  # Prepares an existing, unused stack for use again.
  # def self.reset_stack(stack : Void*, stack_size : Int, protect : Bool) : Nil

  # Frees memory of a stack.
  # def self.free_stack(stack : Void*, stack_size : Int) : Nil
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
