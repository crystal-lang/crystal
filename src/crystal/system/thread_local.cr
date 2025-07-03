class Thread
  struct Local(T)
    # Reserves space for saving a `T` reference on each thread.
    def initialize
      {% unless T < Reference || T < Pointer || T.union_types.all? { |t| t == Nil || t < Reference } %}
        {% raise "Can only create Thread::Local with reference types, nilable reference types, or pointer types, not {{T}}" %}
      {% end %}
    end

    # Reserves space for saving a `T` reference on each thread and registers a
    # destructor that will be called when a thread terminates if the local value
    # has been set.
    def initialize(&destructor : Proc(T, Nil))
      {% unless T < Reference || T < Pointer || T.union_types.all? { |t| t == Nil || t < Reference } %}
        {% raise "Can only create Thread::Local with reference types, nilable reference types, or pointer types, not {{T}}" %}
      {% end %}
    end

    # Returns the current local value for the thread; if unset constructs one by
    # yielding and sets it as the current local value.
    def get(& : -> T) : T
      get? || set(yield)
    end

    # Returns the current local value for the thread or `nil` if there is none.
    # def get? : T?

    # Sets *value* as the current local value for the thread.
    # def set(value : T) : T
  end
end

{% if flag?(:wasi) %}
  require "./wasi/thread_local"
{% elsif flag?(:unix) %}
  require "./unix/thread_local"
{% elsif flag?(:win32) %}
  require "./win32/thread_local"
{% else %}
  {% raise "Thread not supported" %}
{% end %}
